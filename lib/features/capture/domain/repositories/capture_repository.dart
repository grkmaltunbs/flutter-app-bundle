import 'package:okey_acar_mi/features/capture/domain/entities/permission_verdict.dart';

/// Camera + gallery capture contract (pure Dart).
///
/// Permission checks return [PermissionVerdict] values — denial is a state,
/// not an error (D3). Capture commands throw typed `Failure`s
/// (`Failure.noCamera`, `Failure.captureFailed`, `Failure.photoAccessDenied`);
/// a user-cancelled gallery pick resolves to `null`, never a failure
/// (the auth provider-cancel convention).
abstract class CaptureRepository {
  /// Reads the current camera permission without prompting.
  Future<PermissionVerdict> checkCameraPermission();

  /// Shows the system camera-permission prompt (when still possible) and
  /// returns the resulting verdict.
  Future<PermissionVerdict> requestCameraPermission();

  /// Opens the system settings page for this app (permanently-denied escape).
  Future<void> openSystemSettings();

  /// Acquires and initializes the camera ([frontCamera] selects the lens).
  ///
  /// Throws `Failure.noCamera` when the device has no camera at all, and
  /// `Failure.captureFailed` for any other initialization error.
  Future<void> initializeCamera({required bool frontCamera});

  /// Releases the camera and turns the torch off. Idempotent: safe to call
  /// when nothing is held.
  Future<void> releaseCamera();

  /// Whether the active camera offers a flash/torch.
  bool get isFlashAvailable;

  /// Turns the torch on/off. Throws `Failure.captureFailed` when the
  /// hardware refuses.
  Future<void> setFlash({required bool enabled});

  /// Captures a still image to a file and returns its path.
  ///
  /// Throws `Failure.captureFailed` when the capture fails.
  Future<String> captureStillToFile();

  /// Opens the system gallery picker and returns the picked image path, or
  /// `null` when the user cancelled.
  ///
  /// Throws `Failure.photoAccessDenied` when photo-library access is blocked.
  Future<String?> pickImageFromGallery();
}
