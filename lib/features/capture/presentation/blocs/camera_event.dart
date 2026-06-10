part of 'camera_bloc.dart';

/// Intent events for [CameraBloc] (past-tense, no `BuildContext`).
@freezed
sealed class CameraEvent with _$CameraEvent {
  /// The capture screen opened.
  const factory CameraEvent.started() = CameraStarted;

  /// The user picked a capture mode from the toggle.
  const factory CameraEvent.modeChanged(CaptureMode mode) = CameraModeChanged;

  /// The user pressed the shutter (photo, burst, or gallery per mode).
  const factory CameraEvent.shutterPressed() = CameraShutterPressed;

  /// The user asked the running burst to stop early.
  const factory CameraEvent.recordingStopped() = CameraRecordingStopped;

  /// The user requested the gallery picker.
  const factory CameraEvent.galleryRequested() = CameraGalleryRequested;

  /// The user toggled the torch.
  const factory CameraEvent.flashToggled() = CameraFlashToggled;

  /// The user asked to flip between back and front camera.
  const factory CameraEvent.flipRequested() = CameraFlipRequested;

  /// The user retried after a (re-promptable) camera denial.
  const factory CameraEvent.permissionRetryRequested() =
      CameraPermissionRetryRequested;

  /// The user asked to open the system settings (permanent denial escape).
  const factory CameraEvent.openSettingsRequested() =
      CameraOpenSettingsRequested;

  /// The app left the foreground.
  const factory CameraEvent.appBackgrounded() = CameraAppBackgrounded;

  /// The app returned to the foreground.
  const factory CameraEvent.appResumed() = CameraAppResumed;

  /// The user navigated back from the downstream (analyzing) flow.
  const factory CameraEvent.returnedFromCapture() = CameraReturnedFromCapture;
}
