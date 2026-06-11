import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:okey_acar_mi/core/error/failure.dart';
import 'package:okey_acar_mi/core/logging/app_logger.dart';
import 'package:okey_acar_mi/core/time/clock.dart';
import 'package:okey_acar_mi/features/capture/domain/entities/capture_payload.dart';
import 'package:okey_acar_mi/features/detection/data/isolate/detection_worker.dart';
import 'package:okey_acar_mi/features/detection/data/isolate/detection_worker_channel.dart';
import 'package:okey_acar_mi/features/detection/domain/entities/detection_update.dart';
import 'package:okey_acar_mi/features/detection/domain/services/tile_detector.dart';

/// The production [TileDetector]: spawns [detectionWorkerMain] off the UI
/// isolate via [DetectionWorkerChannel] and owns the ML Kit [TextRecognizer]
/// lifecycle (created lazily on first run, closed by [dispose] when the DI
/// container resets).
///
/// The recognizer instance crosses the isolate boundary inside the worker
/// config — safe because it is a plain `{script, id}` value over a static
/// method channel, which the worker drives through
/// `BackgroundIsolateBinaryMessenger`.
class PipelineTileDetector implements TileDetector {
  /// Creates a [PipelineTileDetector].
  PipelineTileDetector(this._clock, this._logger);

  final Clock _clock;
  final AppLogger _logger;

  TextRecognizer? _recognizer;

  @override
  Stream<DetectionUpdate> detect(CapturePayload payload) {
    final token = RootIsolateToken.instance;
    if (token == null) {
      // No root isolate (e.g. called from a background isolate): ML Kit's
      // platform channel cannot be wired up.
      return Stream.value(
        const DetectionUpdate.failed(
          Failure.detectionFailed('no-root-isolate-token'),
        ),
      );
    }
    return DetectionWorkerChannel.run(
      entrypoint: detectionWorkerMain,
      payload: payload,
      config: DetectionWorkerConfig(
        rootIsolateToken: token,
        recognizer: _recognizer ??= TextRecognizer(),
        clock: _clock,
      ),
      // Non-terminal worker diagnostics (e.g. OpenCV threw and the run fell
      // back to the pure-Dart segmenter) — logged, never user-facing.
      onLog: (message) => _logger.warning('Tile detection worker: $message'),
    ).map((update) {
      // Raw worker errors were already mapped to Failure.detectionFailed by
      // the worker/channel; log terminal failures main-side.
      if (update is DetectionFailedUpdate) {
        _logger.warning('Tile detection failed: ${update.failure}');
      }
      return update;
    });
  }

  /// Closes the ML Kit recognizer; invoked by the DI container's dispose
  /// hook (see `DetectionBindings`).
  Future<void> dispose() async {
    await _recognizer?.close();
    _recognizer = null;
  }
}
