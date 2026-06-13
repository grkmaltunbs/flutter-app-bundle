import 'dart:async';

import 'package:okey_acar_mi/core/env/gemini_config.dart';
import 'package:okey_acar_mi/core/error/failure.dart';
import 'package:okey_acar_mi/core/logging/app_logger.dart';
import 'package:okey_acar_mi/core/time/clock.dart';
import 'package:okey_acar_mi/features/capture/domain/entities/capture_payload.dart';
import 'package:okey_acar_mi/features/detection/data/processing/gemini_rack_parser.dart';
import 'package:okey_acar_mi/features/detection/data/processing/rack_image_prep.dart';
import 'package:okey_acar_mi/features/detection/data/services/gemini_client.dart';
import 'package:okey_acar_mi/features/detection/domain/entities/detection_result.dart';
import 'package:okey_acar_mi/features/detection/domain/entities/detection_stage.dart';
import 'package:okey_acar_mi/features/detection/domain/entities/detection_update.dart';
import 'package:okey_acar_mi/features/detection/domain/services/tile_detector.dart';

/// [TileDetector] backed by Gemini 3.1 Flash-Lite via Firebase AI Logic.
///
/// One still photo → downscaled JPEG → a single structured-output request →
/// parsed tiles. Network I/O, so (unlike the old CPU pipeline) it needs no
/// worker isolate — only the image prep runs off the UI isolate. Emits the same
/// staged `DetectionUpdate` protocol the analyzing screen expects.
class GeminiTileDetector implements TileDetector {
  /// Creates a detector. [maxImageDimension] overrides the configured default
  /// (the lab varies it to A/B reading accuracy vs. cost).
  GeminiTileDetector(
    this._client,
    this._clock,
    this._logger, {
    this.maxImageDimension = GeminiConfig.maxImageDimension,
  });

  final GeminiClient _client;
  final Clock _clock;
  final AppLogger _logger;

  /// Longest-edge cap for the uploaded image.
  final int maxImageDimension;

  /// Pause before each per-tile reveal. All tiles arrive at once from a single
  /// request, so a small stagger keeps the analyzing animation lively. Set to
  /// [Duration.zero] in tests.
  Duration revealPause = const Duration(milliseconds: 40);

  @override
  Stream<DetectionUpdate> detect(CapturePayload payload) async* {
    try {
      yield const DetectionUpdate.stage(DetectionStage.preparing);

      final path = switch (payload) {
        StillCapture(:final imagePath) => imagePath,
        FramesCapture(:final framePaths) => framePaths.first,
      };

      final jpeg = await prepareRackJpeg(
        path,
        maxDimension: maxImageDimension,
        quality: GeminiConfig.jpegQuality,
      );

      yield const DetectionUpdate.stage(DetectionStage.readingTiles);

      final json = await _client.generateRackJson(jpeg);
      final tiles = GeminiRackParser.parse(json);

      yield DetectionUpdate.stage(
        DetectionStage.readingTiles,
        totalTiles: tiles.length,
      );
      for (final tile in tiles) {
        if (revealPause > Duration.zero) {
          await Future<void>.delayed(revealPause);
        }
        yield DetectionUpdate.tile(tile);
      }

      yield const DetectionUpdate.stage(DetectionStage.finalizing);

      final overall =
          tiles.fold<double>(0, (sum, tile) => sum + tile.confidence) /
          tiles.length;
      yield DetectionUpdate.completed(
        DetectionResult(
          tiles: tiles,
          overallConfidence: overall,
          sourceImagePath: path,
          frameCount: 1,
          detectedAt: _clock.now(),
        ),
      );
    } on Failure catch (failure) {
      _logger.warning('Gemini detection failed: $failure');
      yield DetectionUpdate.failed(failure);
    } on Object catch (error, stackTrace) {
      _logger.error('Gemini detection crashed', error, stackTrace);
      yield DetectionUpdate.failed(Failure.detectionFailed('$error'));
    }
  }
}
