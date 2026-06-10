import 'package:injectable/injectable.dart';
import 'package:okey_acar_mi/core/time/clock.dart';
import 'package:okey_acar_mi/features/capture/domain/entities/capture_payload.dart';
import 'package:okey_acar_mi/features/capture/domain/repositories/capture_repository.dart';

/// Imports a still image from the system gallery.
@injectable
class PickFromGallery {
  /// Creates a [PickFromGallery].
  const PickFromGallery(this._repository, this._clock);

  final CaptureRepository _repository;
  final Clock _clock;

  /// Executes the use case. Returns `null` when the user cancelled the
  /// picker; throws `Failure.photoAccessDenied` when access is blocked.
  Future<CapturePayload?> call() async {
    final imagePath = await _repository.pickImageFromGallery();
    if (imagePath == null) return null;
    return CapturePayload.still(
      imagePath: imagePath,
      source: CaptureSource.gallery,
      capturedAt: _clock.now(),
    );
  }
}
