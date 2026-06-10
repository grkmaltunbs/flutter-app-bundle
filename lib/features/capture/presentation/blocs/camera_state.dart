part of 'camera_bloc.dart';

/// Sealed screen state for [CameraBloc].
@freezed
sealed class CameraState with _$CameraState {
  /// Permission check / camera acquisition in progress.
  const factory CameraState.initializing() = CameraInitializing;

  /// Live viewfinder: the camera is acquired and idle. [failure] carries a
  /// one-shot capture error for the SnackBar; it is cleared on the next
  /// emission.
  const factory CameraState.ready({
    required CaptureMode mode,
    required bool flashOn,
    required bool frontCamera,
    required bool flashAvailable,
    Failure? failure,
  }) = CameraReady;

  /// Camera permission is denied. [permanent] selects the Settings escape
  /// over the in-context retry.
  const factory CameraState.cameraDenied({required bool permanent}) =
      CameraDenied;

  /// Photo-library access is denied. [permanent] selects the Settings escape
  /// over the in-context retry.
  const factory CameraState.galleryDenied({required bool permanent}) =
      CameraGalleryDenied;

  /// The device has no camera; only the gallery fallback is offered.
  const factory CameraState.unavailable() = CameraUnavailable;

  /// A still capture is in flight.
  const factory CameraState.capturing() = CameraCapturing;

  /// The still-burst "recording" is in flight ([framesCaptured] of
  /// [frameTarget] frames landed so far).
  const factory CameraState.recording({
    required int framesCaptured,
    required int frameTarget,
  }) = CameraRecording;

  /// The system gallery picker is open.
  const factory CameraState.pickingGallery() = CameraPickingGallery;

  /// The camera is parked (app backgrounded, or a capture was handed off to
  /// the downstream flow).
  const factory CameraState.suspended() = CameraSuspended;

  /// A capture finished: the listener navigates to analyzing with [payload].
  /// Transient — immediately followed by [CameraState.suspended].
  const factory CameraState.success({required CapturePayload payload}) =
      CameraSuccess;
}
