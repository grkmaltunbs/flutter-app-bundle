import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:okey_acar_mi/core/error/failure.dart';
import 'package:okey_acar_mi/core/game/tile_color.dart';
import 'package:okey_acar_mi/core/logging/app_logger.dart';
import 'package:okey_acar_mi/core/time/clock.dart';
import 'package:okey_acar_mi/features/capture/domain/entities/capture_payload.dart';
import 'package:okey_acar_mi/features/detection/data/services/gemini_client.dart';
import 'package:okey_acar_mi/features/detection/data/services/gemini_tile_detector.dart';
import 'package:okey_acar_mi/features/detection/domain/entities/detection_update.dart';

/// A [GeminiClient] that returns canned JSON or throws, without any network.
class _StubClient implements GeminiClient {
  _StubClient.json(this.json) : error = null;
  _StubClient.fails(this.error) : json = null;

  final String? json;
  final Exception? error;

  @override
  Future<String> generateRackJson(Uint8List jpegBytes) async {
    final e = error;
    if (e != null) throw e;
    return json!;
  }
}

class _FixedClock implements Clock {
  const _FixedClock();
  @override
  DateTime now() => DateTime.utc(2026, 6, 13);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late String imagePath;
  late AppLogger logger;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('gemini_detector_test');
    imagePath = '${tempDir.path}/rack.jpg';
    File(imagePath).writeAsBytesSync(
      img.encodeJpg(img.Image(width: 16, height: 8)),
    );
    logger = AppLogger();
  });

  tearDown(() => tempDir.deleteSync(recursive: true));

  CapturePayload buildPayload() => CapturePayload.still(
    imagePath: imagePath,
    source: CaptureSource.photo,
    capturedAt: DateTime.utc(2026),
  );

  test('streams stages + tiles then completes with a mapped result', () async {
    const json =
        '{"rows":['
        '[{"kind":"numbered","color":"red","number":5,"confidence":0.9},'
        '{"kind":"false_joker","confidence":0.8}],'
        '[{"kind":"numbered","color":"blue","number":12,"confidence":0.7},'
        '{"kind":"face_down","confidence":0.8}]]}';
    final detector = GeminiTileDetector(
      _StubClient.json(json),
      const _FixedClock(),
      logger,
    )..revealPause = Duration.zero;

    final updates = await detector.detect(buildPayload()).toList();

    expect(updates.whereType<DetectionFailedUpdate>(), isEmpty);
    expect(updates.whereType<DetectionTileUpdate>(), hasLength(4));

    final result = updates.whereType<DetectionCompletedUpdate>().single.result;
    expect(result.tiles, hasLength(4));
    expect(result.tiles[0].color, TileColor.red);
    expect(result.tiles[0].number, 5);
    expect(result.tiles[1].color, TileColor.joker);
    expect(result.tiles[3].color, TileColor.joker);
    expect(result.frameCount, 1);
    expect(result.sourceImagePath, imagePath);
    expect(result.detectedAt, DateTime.utc(2026, 6, 13));
  });

  test('a client failure ends the stream with a terminal failed', () async {
    final detector = GeminiTileDetector(
      _StubClient.fails(const Failure.network()),
      const _FixedClock(),
      logger,
    )..revealPause = Duration.zero;

    final updates = await detector.detect(buildPayload()).toList();

    expect(updates.whereType<DetectionCompletedUpdate>(), isEmpty);
    final failed = updates.whereType<DetectionFailedUpdate>().single;
    expect(failed.failure, isA<NetworkFailure>());
  });
}
