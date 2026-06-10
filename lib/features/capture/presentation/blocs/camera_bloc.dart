import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';
import 'package:okey_acar_mi/core/error/error_mapper.dart';
import 'package:okey_acar_mi/core/error/failure.dart';
import 'package:okey_acar_mi/features/capture/domain/entities/capture_mode.dart';
import 'package:okey_acar_mi/features/capture/domain/entities/capture_payload.dart';
import 'package:okey_acar_mi/features/capture/domain/entities/permission_verdict.dart';
import 'package:okey_acar_mi/features/capture/domain/repositories/capture_repository.dart';
import 'package:okey_acar_mi/features/capture/domain/usecases/capture_photo.dart';
import 'package:okey_acar_mi/features/capture/domain/usecases/capture_video_frames.dart';
import 'package:okey_acar_mi/features/capture/domain/usecases/pick_from_gallery.dart';

part 'camera_bloc.freezed.dart';
part 'camera_event.dart';
part 'camera_state.dart';

/// How many stills a "video" burst captures (D1).
const int _burstFrameTarget = 5;

/// Screen-scoped bloc for the capture screen: permission flow, camera
/// lifecycle, photo/burst/gallery captures.
///
/// The shutter is `droppable` (D4): presses while a capture is in flight are
/// ignored, never queued. Capture failures surface as a one-shot
/// [CameraReady.failure] (SnackBar via `BlocListener`), cleared on the next
/// emission. Holds the camera, so [close] releases it.
@injectable
class CameraBloc extends Bloc<CameraEvent, CameraState> {
  /// Creates a [CameraBloc].
  CameraBloc(
    this._repository,
    this._capturePhoto,
    this._captureVideoFrames,
    this._pickFromGallery,
  ) : super(const CameraState.initializing()) {
    on<CameraStarted>(_onStarted);
    on<CameraModeChanged>(_onModeChanged);
    on<CameraShutterPressed>(_onShutterPressed, transformer: droppable());
    on<CameraRecordingStopped>(_onRecordingStopped);
    on<CameraGalleryRequested>(_onGalleryRequested);
    on<CameraFlashToggled>(_onFlashToggled);
    on<CameraFlipRequested>(_onFlipRequested);
    on<CameraPermissionRetryRequested>(_onPermissionRetryRequested);
    on<CameraOpenSettingsRequested>(_onOpenSettingsRequested);
    on<CameraAppBackgrounded>(_onAppBackgrounded);
    on<CameraAppResumed>(_onAppResumed);
    on<CameraReturnedFromCapture>(_onReturnedFromCapture);
  }

  final CaptureRepository _repository;
  final CapturePhoto _capturePhoto;
  final CaptureVideoFrames _captureVideoFrames;
  final PickFromGallery _pickFromGallery;

  CaptureMode _mode = CaptureMode.photo;
  bool _flashOn = false;
  bool _frontCamera = false;
  bool _flashAvailable = false;
  bool _stopRequested = false;
  bool _initializing = false;

  /// Whether backgrounding released the camera while a gallery pick was in
  /// flight (the system picker backgrounds the app): the pick's captured
  /// `restoreTo` ready state is then stale — the camera is no longer held —
  /// so the cancel/failure restore paths must re-acquire instead of emitting
  /// it verbatim. Cleared whenever the camera is (re)acquired.
  bool _releasedWhilePicking = false;

  CameraReady _ready({Failure? failure}) => CameraReady(
    mode: _mode,
    flashOn: _flashOn,
    frontCamera: _frontCamera,
    flashAvailable: _flashAvailable,
    failure: failure,
  );

  /// Permission check → in-context request → camera acquisition → ready.
  ///
  /// [failure] is attached to the final ready emission, so a one-shot
  /// failure survives a forced re-acquisition (a pick failing after the
  /// camera was released mid-pick).
  Future<void> _initialize(
    Emitter<CameraState> emit, {
    Failure? failure,
  }) async {
    // Re-entrancy guard: lifecycle events can overlap (e.g. a resume landing
    // while the start sequence is still acquiring the camera).
    if (_initializing) return;
    _initializing = true;
    try {
      emit(const CameraState.initializing());
      // The screen can be disposed (closing this bloc) while an await is
      // pending, so every emit after an await is guarded against isClosed.
      var verdict = await _repository.checkCameraPermission();
      if (verdict == PermissionVerdict.denied) {
        verdict = await _repository.requestCameraPermission();
      }
      if (isClosed) return;
      switch (verdict) {
        case PermissionVerdict.granted:
          break;
        case PermissionVerdict.denied:
          emit(const CameraState.cameraDenied(permanent: false));
          return;
        case PermissionVerdict.permanentlyDenied:
          emit(const CameraState.cameraDenied(permanent: true));
          return;
      }
      try {
        await _repository.initializeCamera(frontCamera: _frontCamera);
        _releasedWhilePicking = false;
        // Re-acquisition always resets the torch.
        _flashOn = false;
        _flashAvailable = _repository.isFlashAvailable;
        if (isClosed) return;
        emit(_ready(failure: failure));
      } on NoCameraFailure {
        if (isClosed) return;
        emit(const CameraState.unavailable());
      } on Object {
        // Any other acquisition failure (camera busy, platform error)
        // degrades to the no-camera view — its gallery fallback still works.
        if (isClosed) return;
        emit(const CameraState.unavailable());
      }
    } finally {
      _initializing = false;
    }
  }

  Future<void> _onStarted(
    CameraStarted event,
    Emitter<CameraState> emit,
  ) => _initialize(emit);

  void _onModeChanged(CameraModeChanged event, Emitter<CameraState> emit) {
    if (state is! CameraReady) return;
    _mode = event.mode;
    emit(_ready());
  }

  Future<void> _onShutterPressed(
    CameraShutterPressed event,
    Emitter<CameraState> emit,
  ) async {
    if (state is! CameraReady) return;
    switch (_mode) {
      case CaptureMode.photo:
        await _runStillCapture(emit);
      case CaptureMode.video:
        await _runBurstCapture(emit);
      case CaptureMode.gallery:
        await _runGalleryPick(emit);
    }
  }

  Future<void> _runStillCapture(Emitter<CameraState> emit) async {
    emit(const CameraState.capturing());
    try {
      final payload = await _capturePhoto();
      await _succeed(emit, payload);
    } on Failure catch (failure) {
      if (isClosed) return;
      emit(_ready(failure: failure));
    } on Object catch (error) {
      if (isClosed) return;
      emit(_ready(failure: mapToFailure(error)));
    }
  }

  Future<void> _runBurstCapture(Emitter<CameraState> emit) async {
    _stopRequested = false;
    emit(
      const CameraState.recording(
        framesCaptured: 0,
        frameTarget: _burstFrameTarget,
      ),
    );
    try {
      final payload = await _captureVideoFrames(
        onProgress: (captured) {
          // The callback fires mid-burst, after awaits inside the use case,
          // so it carries the same isClosed guard as the post-await emits.
          if (isClosed) return;
          emit(
            CameraState.recording(
              framesCaptured: captured,
              frameTarget: _burstFrameTarget,
            ),
          );
        },
        isCancelled: () => _stopRequested,
      );
      await _succeed(emit, payload);
    } on Failure catch (failure) {
      if (isClosed) return;
      emit(_ready(failure: failure));
    } on Object catch (error) {
      if (isClosed) return;
      emit(_ready(failure: mapToFailure(error)));
    }
  }

  void _onRecordingStopped(
    CameraRecordingStopped event,
    Emitter<CameraState> emit,
  ) {
    _stopRequested = true;
  }

  Future<void> _onGalleryRequested(
    CameraGalleryRequested event,
    Emitter<CameraState> emit,
  ) async {
    // The gallery escape works from the live viewfinder AND from the
    // camera-denied / no-camera views.
    final previous = state;
    if (previous is! CameraReady &&
        previous is! CameraDenied &&
        previous is! CameraUnavailable &&
        previous is! CameraGalleryDenied) {
      return;
    }
    await _runGalleryPick(emit, previous: previous);
  }

  Future<void> _runGalleryPick(
    Emitter<CameraState> emit, {
    CameraState? previous,
  }) async {
    final restoreTo = previous ?? state;
    emit(const CameraState.pickingGallery());
    try {
      // The picker await is long-lived (the user can browse indefinitely),
      // so the bloc may well be closed by the time it resolves.
      final payload = await _pickFromGallery();
      if (isClosed) return;
      if (payload == null) {
        // Cancelled: silently back to where the user was — unless the
        // backgrounding caused by the system picker released the camera,
        // in which case the captured ready state is stale and the camera
        // must be re-acquired.
        if (_releasedWhilePicking && restoreTo is CameraReady) {
          await _initialize(emit);
          return;
        }
        emit(restoreTo);
        return;
      }
      await _succeed(emit, payload);
    } on PhotoAccessDeniedFailure catch (failure) {
      if (isClosed) return;
      emit(CameraState.galleryDenied(permanent: failure.permanent));
    } on Failure catch (failure) {
      if (isClosed) return;
      if (_releasedWhilePicking && restoreTo is CameraReady) {
        await _initialize(emit, failure: failure);
        return;
      }
      emit(
        restoreTo is CameraReady ? _ready(failure: failure) : restoreTo,
      );
    } on Object catch (error) {
      if (isClosed) return;
      final failure = mapToFailure(error);
      if (_releasedWhilePicking && restoreTo is CameraReady) {
        await _initialize(emit, failure: failure);
        return;
      }
      emit(
        restoreTo is CameraReady ? _ready(failure: failure) : restoreTo,
      );
    }
  }

  /// Emits the transient success (the listener navigates on it), then parks
  /// the camera so it is not held while the downstream flow runs.
  Future<void> _succeed(
    Emitter<CameraState> emit,
    CapturePayload payload,
  ) async {
    // Every caller arrives here straight after a capture await; if the bloc
    // closed during it, skip — close() releases the camera itself.
    if (isClosed) return;
    emit(CameraState.success(payload: payload));
    await _repository.releaseCamera();
    _flashOn = false;
    if (isClosed) return;
    emit(const CameraState.suspended());
  }

  Future<void> _onFlashToggled(
    CameraFlashToggled event,
    Emitter<CameraState> emit,
  ) async {
    if (state is! CameraReady || !_flashAvailable) return;
    try {
      await _repository.setFlash(enabled: !_flashOn);
      _flashOn = !_flashOn;
      if (isClosed) return;
      emit(_ready());
    } on Failure catch (failure) {
      if (isClosed) return;
      emit(_ready(failure: failure));
    } on Object catch (error) {
      if (isClosed) return;
      emit(_ready(failure: mapToFailure(error)));
    }
  }

  Future<void> _onFlipRequested(
    CameraFlipRequested event,
    Emitter<CameraState> emit,
  ) async {
    if (state is! CameraReady) return;
    _frontCamera = !_frontCamera;
    await _initialize(emit);
  }

  Future<void> _onPermissionRetryRequested(
    CameraPermissionRetryRequested event,
    Emitter<CameraState> emit,
  ) => _initialize(emit);

  Future<void> _onOpenSettingsRequested(
    CameraOpenSettingsRequested event,
    Emitter<CameraState> emit,
  ) => _repository.openSystemSettings();

  Future<void> _onAppBackgrounded(
    CameraAppBackgrounded event,
    Emitter<CameraState> emit,
  ) async {
    // Stop any running burst, free the camera, and park. Denial / unavailable
    // states are kept so their views survive backgrounding (resume re-checks
    // denials); an open picker is kept because its in-flight pick — not the
    // resume — drives the next state.
    _stopRequested = true;
    // Releasing the camera invalidates an in-flight pick's captured restore
    // target (see _runGalleryPick); the picking state itself is kept below.
    if (state is CameraPickingGallery) _releasedWhilePicking = true;
    await _repository.releaseCamera();
    _flashOn = false;
    if (isClosed) return;
    if (state is CameraReady ||
        state is CameraInitializing ||
        state is CameraCapturing ||
        state is CameraRecording) {
      emit(const CameraState.suspended());
    }
  }

  Future<void> _onAppResumed(
    CameraAppResumed event,
    Emitter<CameraState> emit,
  ) async {
    // An open gallery picker is intentionally left alone: the system picker
    // itself backgrounded the app, and the in-flight _pickFromGallery await
    // completes on dismissal and drives the next state — re-initializing
    // here would clobber the picking state mid-pick.
    if (state is CameraPickingGallery) return;
    // Re-acquire after a park, and re-check after a denial: returning from
    // the system Settings auto-recovers without a manual retry.
    if (state is CameraSuspended ||
        state is CameraDenied ||
        state is CameraGalleryDenied ||
        state is CameraInitializing) {
      await _initialize(emit);
    }
  }

  Future<void> _onReturnedFromCapture(
    CameraReturnedFromCapture event,
    Emitter<CameraState> emit,
  ) => _initialize(emit);

  @override
  Future<void> close() async {
    await _repository.releaseCamera();
    return super.close();
  }
}
