import 'dart:io';
import 'dart:isolate';

import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image/image.dart' as img;
import 'package:okey_acar_mi/core/error/failure.dart';
import 'package:okey_acar_mi/core/game/tile_color.dart';
import 'package:okey_acar_mi/core/time/clock.dart';
import 'package:okey_acar_mi/features/capture/domain/entities/capture_payload.dart';
import 'package:okey_acar_mi/features/detection/data/isolate/detection_worker_channel.dart';
import 'package:okey_acar_mi/features/detection/data/processing/frame_aggregator.dart';
import 'package:okey_acar_mi/features/detection/data/processing/hsv_classifier.dart';
import 'package:okey_acar_mi/features/detection/data/processing/numeral_parser.dart';
import 'package:okey_acar_mi/features/detection/data/processing/rack_geometry.dart';
import 'package:okey_acar_mi/features/detection/data/services/opencv_rack_segmenter.dart';
import 'package:okey_acar_mi/features/detection/data/services/rack_segmenter.dart';
import 'package:okey_acar_mi/features/detection/domain/entities/detected_tile.dart';
import 'package:okey_acar_mi/features/detection/domain/entities/detection_result.dart';
import 'package:okey_acar_mi/features/detection/domain/entities/detection_stage.dart';
import 'package:okey_acar_mi/features/detection/domain/entities/detection_update.dart';

/// Sendable configuration for [detectionWorkerMain], snapshotted on the main
/// isolate by `PipelineTileDetector`. The segmenters are NOT part of the
/// config: the worker constructs them itself (see [_buildSegmenter]) so
/// nothing tied to native resources ever crosses the isolate boundary.
class DetectionWorkerConfig {
  /// Creates a [DetectionWorkerConfig].
  const DetectionWorkerConfig({
    required this.rootIsolateToken,
    required this.recognizer,
    required this.clock,
  });

  /// Lets the worker register [BackgroundIsolateBinaryMessenger] so ML Kit's
  /// platform channel works off the UI isolate.
  final RootIsolateToken rootIsolateToken;

  /// The main-isolate-owned recognizer (its lifecycle — `close()` — belongs
  /// to `PipelineTileDetector`). Sendable: plain `script` + `id` fields over
  /// a static channel.
  final TextRecognizer recognizer;

  /// Stamps `DetectionResult.detectedAt` (injected, never `DateTime.now()`).
  final Clock clock;
}

/// Joker candidates carry this fixed confidence: "no numeral found" is solid
/// evidence but still worth a user glance on review.
const double _jokerCandidateConfidence = 0.6;

/// Fraction of a tile box (centered) sampled for color classification —
/// biased to the glyph region, away from the tile's edges and shadows.
const double _glyphSampleFraction = 0.6;

/// Upper bound of color samples taken per tile.
const int _maxColorSamples = 400;

/// Prod worker entrypoint: the full single-pass detection pipeline.
///
/// Decode (package:image) → segment ([RackSegmenter]) → 2-row geometry
/// ([RackGeometry]) → one full-image `TextRecognizer.processImage` →
/// per-cell numeral parse + HSV color vote → (multi-frame: aggregate) →
/// `completed`. Every throw is converted to a terminal `failed` update; the
/// channel's error port is the backstop for anything that escapes.
Future<void> detectionWorkerMain(DetectionWorkerRequest request) async {
  final send = request.sendPort;
  try {
    final config = request.config! as DetectionWorkerConfig;
    BackgroundIsolateBinaryMessenger.ensureInitialized(
      config.rootIsolateToken,
    );
    await _runPipeline(send, request.payload, config);
  } on Failure catch (failure) {
    send.send(DetectionUpdate.failed(failure));
  } on Object catch (error, stackTrace) {
    send.send(
      DetectionUpdate.failed(
        Failure.detectionFailed('$error\n$stackTrace'),
      ),
    );
  }
}

/// Builds the worker's segmentation strategy: OpenCV primary, pure-Dart luma
/// fallback when OpenCV **throws** (never when it merely finds nothing).
/// Constructed inside the worker isolate — segmenters never cross the
/// boundary — with primary failures forwarded as [DetectionWorkerLog]s.
RackSegmenter _buildSegmenter(SendPort send) => FallbackRackSegmenter(
  primary: const OpenCvRackSegmenter(),
  fallback: const LumaProjectionSegmenter(),
  onPrimaryError: (description) => send.send(
    DetectionWorkerLog(
      'opencv-segmenter-failed; fell back to luma projection: $description',
    ),
  ),
);

Future<void> _runPipeline(
  SendPort send,
  CapturePayload payload,
  DetectionWorkerConfig config,
) async {
  send.send(const DetectionUpdate.stage(DetectionStage.preparing));

  final paths = switch (payload) {
    StillCapture(:final imagePath) => [imagePath],
    FramesCapture(:final framePaths) => framePaths,
  };

  final segmenter = _buildSegmenter(send);
  final frames = <List<DetectedTile>>[];
  var announced = false;
  for (final path in paths) {
    final reading = await _readFrame(
      send: send,
      path: path,
      config: config,
      segmenter: segmenter,
      announce: !announced,
    );
    if (reading == null) continue; // Frame unusable; later frames may serve.
    announced = true;
    frames.add(reading);
  }

  if (frames.isEmpty) {
    send.send(const DetectionUpdate.failed(Failure.noTilesDetected()));
    return;
  }

  List<DetectedTile> tiles;
  if (frames.length > 1) {
    send.send(
      DetectionUpdate.stage(
        DetectionStage.aggregatingFrames,
        totalTiles: frames.first.length,
      ),
    );
    tiles = FrameAggregator.aggregate(frames);
  } else {
    tiles = frames.single;
  }
  if (tiles.isEmpty) {
    send.send(const DetectionUpdate.failed(Failure.noTilesDetected()));
    return;
  }

  for (final tile in tiles) {
    send.send(DetectionUpdate.tile(tile));
  }
  send.send(const DetectionUpdate.stage(DetectionStage.finalizing));

  final overall =
      tiles.fold<double>(0, (sum, tile) => sum + tile.confidence) /
      tiles.length;
  send.send(
    DetectionUpdate.completed(
      DetectionResult(
        tiles: tiles,
        overallConfidence: overall,
        sourceImagePath: paths.first,
        frameCount: frames.length,
        detectedAt: config.clock.now(),
      ),
    ),
  );
}

/// Reads one frame into a full rack reading, or null when the frame holds no
/// usable 2-row rack. [announce] emits the locating/reading stage updates
/// (only the first usable frame announces, so stages do not bounce backward
/// during a burst).
Future<List<DetectedTile>?> _readFrame({
  required SendPort send,
  required String path,
  required DetectionWorkerConfig config,
  required RackSegmenter segmenter,
  required bool announce,
}) async {
  final bytes = await File(path).readAsBytes();
  final decoded = img.decodeImage(bytes);
  if (decoded == null) {
    throw const Failure.detectionFailed('undecodable-image');
  }
  // ML Kit reads the file with EXIF orientation applied; bake the same
  // orientation into the decoded pixels so the two coordinate spaces match.
  final image = img.bakeOrientation(decoded);

  final boxes = segmenter.segment(image);
  if (boxes.isEmpty) return null;
  final positioned = RackGeometry.assignPositions(boxes);
  if (positioned == null) return null; // Not a 2-row layout.

  if (announce) {
    send.send(
      DetectionUpdate.stage(
        DetectionStage.locatingRack,
        totalTiles: positioned.length,
      ),
    );
  }

  final recognized = await config.recognizer.processImage(
    InputImage.fromFilePath(path),
  );
  if (announce) {
    send.send(
      DetectionUpdate.stage(
        DetectionStage.readingTiles,
        totalTiles: positioned.length,
      ),
    );
  }
  final elements = _normalizedElements(recognized, image);

  return [
    for (final box in positioned)
      _readTile(box: box, elements: elements, image: image),
  ];
}

/// Flattens ML Kit's block→line→element tree into plugin-agnostic elements
/// with image-normalized bounds.
List<RecognizedTextElement> _normalizedElements(
  RecognizedText recognized,
  img.Image image,
) {
  final width = image.width.toDouble();
  final height = image.height.toDouble();
  return [
    for (final block in recognized.blocks)
      for (final line in block.lines)
        for (final element in line.elements)
          RecognizedTextElement(
            text: element.text,
            bounds: NormalizedRect(
              left: element.boundingBox.left / width,
              top: element.boundingBox.top / height,
              width: element.boundingBox.width / width,
              height: element.boundingBox.height / height,
            ),
          ),
  ];
}

DetectedTile _readTile({
  required PositionedBox box,
  required List<RecognizedTextElement> elements,
  required img.Image image,
}) {
  final numeral = NumeralParser.readCell(box.bounds, elements);

  // No numeral at all → joker candidate (DetectedTile invariant).
  if (numeral.number == null) {
    return DetectedTile(
      color: TileColor.joker,
      position: box.position,
      confidence: _jokerCandidateConfidence,
      bounds: box.bounds,
    );
  }

  final color = HsvClassifier.classify(_glyphSamples(image, box.bounds));
  // ML Kit element confidence is deliberately unused (often null on iOS):
  // per-tile confidence = numeral certainty × color vote margin.
  final confidence = (numeral.confidence * color.confidence).clamp(0.01, 1.0);
  return DetectedTile(
    color: color.color,
    position: box.position,
    confidence: confidence,
    number: numeral.number,
    bounds: box.bounds,
  );
}

/// Samples RGB pixels from the centered glyph region of a tile box.
Iterable<(int, int, int)> _glyphSamples(
  img.Image image,
  NormalizedRect bounds,
) sync* {
  const inset = (1 - _glyphSampleFraction) / 2;
  final left = ((bounds.left + bounds.width * inset) * image.width).round();
  final top = ((bounds.top + bounds.height * inset) * image.height).round();
  final width = (bounds.width * _glyphSampleFraction * image.width).round();
  final height = (bounds.height * _glyphSampleFraction * image.height).round();
  if (width <= 0 || height <= 0) return;

  final total = width * height;
  final stride = total <= _maxColorSamples
      ? 1
      : (total / _maxColorSamples).ceil();
  for (var offset = 0; offset < total; offset += stride) {
    final x = (left + offset % width).clamp(0, image.width - 1);
    final y = (top + offset ~/ width).clamp(0, image.height - 1);
    final pixel = image.getPixel(x, y);
    yield (pixel.r.toInt(), pixel.g.toInt(), pixel.b.toInt());
  }
}
