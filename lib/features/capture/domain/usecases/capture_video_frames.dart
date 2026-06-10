import 'package:injectable/injectable.dart';
import 'package:okey_acar_mi/core/time/clock.dart';
import 'package:okey_acar_mi/features/capture/domain/entities/capture_payload.dart';
import 'package:okey_acar_mi/features/capture/domain/repositories/capture_repository.dart';

/// Runs the "video" capture as a timed still-burst (D1/D5): up to [call]'s
/// `maxFrames` stills via repeated `captureStillToFile`, presented in the UI
/// as a recording.
///
/// Pure Dart; pacing comes from the capture latency itself (no artificial
/// timers, so the demo fake stays instant and deterministic).
@injectable
class CaptureVideoFrames {
  /// Creates a [CaptureVideoFrames].
  const CaptureVideoFrames(this._repository, this._clock);

  final CaptureRepository _repository;
  final Clock _clock;

  /// Captures up to [maxFrames] stills, calling [onProgress] after each frame
  /// lands.
  ///
  /// [isCancelled] is polled between frames: a stop request ends the burst
  /// early, but never before the first frame — the payload always carries at
  /// least one frame. Throws `Failure.captureFailed` when a capture fails.
  Future<CapturePayload> call({
    required void Function(int captured) onProgress,
    required bool Function() isCancelled,
    int maxFrames = 5,
  }) async {
    final framePaths = <String>[];
    for (var i = 0; i < maxFrames; i++) {
      if (framePaths.isNotEmpty && isCancelled()) break;
      framePaths.add(await _repository.captureStillToFile());
      onProgress(framePaths.length);
    }
    return CapturePayload.frames(
      framePaths: framePaths,
      capturedAt: _clock.now(),
    );
  }
}
