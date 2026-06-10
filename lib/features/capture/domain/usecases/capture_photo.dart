import 'package:injectable/injectable.dart';
import 'package:okey_acar_mi/core/time/clock.dart';
import 'package:okey_acar_mi/features/capture/domain/entities/capture_payload.dart';
import 'package:okey_acar_mi/features/capture/domain/repositories/capture_repository.dart';

/// Captures a single still photo and stamps it with the injected [Clock].
@injectable
class CapturePhoto {
  /// Creates a [CapturePhoto].
  const CapturePhoto(this._repository, this._clock);

  final CaptureRepository _repository;
  final Clock _clock;

  /// Executes the use case. Throws `Failure.captureFailed` when the capture
  /// fails.
  Future<CapturePayload> call() async {
    final imagePath = await _repository.captureStillToFile();
    return CapturePayload.still(
      imagePath: imagePath,
      source: CaptureSource.photo,
      capturedAt: _clock.now(),
    );
  }
}
