import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:okey_acar_mi/core/error/failure.dart';

/// `image_picker` platform codes that mean photo-library access is blocked
/// (iOS denial and the legacy-Android storage-permission path). Both are only
/// fixable from the system Settings app, so they map to a permanent denial.
const Set<String> _photoAccessDeniedCodes = {
  'photo_access_denied',
  'read_external_storage_denied',
};

/// Maps a camera-plugin or platform error thrown while controlling the
/// camera into a typed [Failure].
Failure mapCameraError(Object error) {
  return switch (error) {
    final Failure failure => failure,
    final CameraException exception => Failure.captureFailed(exception.code),
    final PlatformException exception => Failure.captureFailed(exception.code),
    _ => Failure.unexpected(error.toString()),
  };
}

/// Maps a [PlatformException] thrown by the gallery picker into a typed
/// [Failure]: permission codes become [Failure.photoAccessDenied], anything
/// else [Failure.captureFailed].
Failure mapGalleryError(PlatformException exception) {
  if (_photoAccessDeniedCodes.contains(exception.code)) {
    return const Failure.photoAccessDenied(permanent: true);
  }
  return Failure.captureFailed(exception.code);
}
