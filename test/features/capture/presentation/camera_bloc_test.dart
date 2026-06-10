import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:checks/checks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:okey_acar_mi/core/error/failure.dart';
import 'package:okey_acar_mi/core/time/clock.dart';
import 'package:okey_acar_mi/features/capture/domain/entities/capture_mode.dart';
import 'package:okey_acar_mi/features/capture/domain/entities/capture_payload.dart';
import 'package:okey_acar_mi/features/capture/domain/entities/permission_verdict.dart';
import 'package:okey_acar_mi/features/capture/domain/repositories/capture_repository.dart';
import 'package:okey_acar_mi/features/capture/domain/usecases/capture_photo.dart';
import 'package:okey_acar_mi/features/capture/domain/usecases/capture_video_frames.dart';
import 'package:okey_acar_mi/features/capture/domain/usecases/pick_from_gallery.dart';
import 'package:okey_acar_mi/features/capture/presentation/blocs/camera_bloc.dart';

class _MockCaptureRepository extends Mock implements CaptureRepository {}

/// Pinned instant for every payload's `capturedAt` — never `DateTime.now()`.
class _FixedClock implements Clock {
  const _FixedClock();

  static final DateTime instant = DateTime.utc(2026, 6, 10, 12);

  @override
  DateTime now() => instant;
}

/// The payload a single still capture produces with the default stubs.
final _stillPayload = CapturePayload.still(
  imagePath: '/captures/shot_1.png',
  source: CaptureSource.photo,
  capturedAt: _FixedClock.instant,
);

/// The payload a gallery pick produces with the default stubs.
final _galleryPayload = CapturePayload.still(
  imagePath: '/captures/picked.png',
  source: CaptureSource.gallery,
  capturedAt: _FixedClock.instant,
);

void main() {
  late _MockCaptureRepository repository;

  /// The bloc under test: mocked repository, real use cases, fixed clock —
  /// so the emitted payloads are asserted exactly.
  CameraBloc buildBloc() => CameraBloc(
    repository,
    CapturePhoto(repository, const _FixedClock()),
    CaptureVideoFrames(repository, const _FixedClock()),
    PickFromGallery(repository, const _FixedClock()),
  );

  /// The bloc's ready state with the default stubs (flash available).
  CameraState ready({
    CaptureMode mode = CaptureMode.photo,
    bool flashOn = false,
    bool frontCamera = false,
    bool flashAvailable = true,
    Failure? failure,
  }) => CameraState.ready(
    mode: mode,
    flashOn: flashOn,
    frontCamera: frontCamera,
    flashAvailable: flashAvailable,
    failure: failure,
  );

  setUp(() {
    repository = _MockCaptureRepository();
    when(
      repository.checkCameraPermission,
    ).thenAnswer((_) async => PermissionVerdict.granted);
    when(
      repository.requestCameraPermission,
    ).thenAnswer((_) async => PermissionVerdict.granted);
    when(
      () => repository.initializeCamera(frontCamera: any(named: 'frontCamera')),
    ).thenAnswer((_) async {});
    when(repository.releaseCamera).thenAnswer((_) async {});
    when(() => repository.isFlashAvailable).thenReturn(true);
    when(
      () => repository.setFlash(enabled: any(named: 'enabled')),
    ).thenAnswer((_) async {});
    when(
      repository.captureStillToFile,
    ).thenAnswer((_) async => '/captures/shot_1.png');
    when(
      repository.pickImageFromGallery,
    ).thenAnswer((_) async => '/captures/picked.png');
  });

  /// Starts the bloc and lets the permission/acquisition awaits settle.
  Future<void> start(CameraBloc bloc) async {
    bloc.add(const CameraEvent.started());
    await pumpEventQueue();
  }

  test('initial state is initializing', () {
    final bloc = buildBloc();
    addTearDown(bloc.close);

    check(bloc.state).equals(const CameraState.initializing());
  });

  group('started', () {
    blocTest<CameraBloc, CameraState>(
      'permission granted → acquires the back camera and lands ready',
      build: buildBloc,
      act: (bloc) => bloc.add(const CameraEvent.started()),
      expect: () => [const CameraState.initializing(), ready()],
      verify: (_) {
        verify(() => repository.initializeCamera(frontCamera: false)).called(1);
      },
    );

    blocTest<CameraBloc, CameraState>(
      'denied at check and at the in-context prompt → cameraDenied '
      '(re-promptable)',
      setUp: () {
        when(
          repository.checkCameraPermission,
        ).thenAnswer((_) async => PermissionVerdict.denied);
        when(
          repository.requestCameraPermission,
        ).thenAnswer((_) async => PermissionVerdict.denied);
      },
      build: buildBloc,
      act: (bloc) => bloc.add(const CameraEvent.started()),
      expect: () => const [
        CameraState.initializing(),
        CameraState.cameraDenied(permanent: false),
      ],
      verify: (_) {
        verify(repository.requestCameraPermission).called(1);
        verifyNever(
          () => repository.initializeCamera(
            frontCamera: any(named: 'frontCamera'),
          ),
        );
      },
    );

    blocTest<CameraBloc, CameraState>(
      'permanently denied at check → cameraDenied(permanent) without '
      're-prompting',
      setUp: () {
        when(
          repository.checkCameraPermission,
        ).thenAnswer((_) async => PermissionVerdict.permanentlyDenied);
      },
      build: buildBloc,
      act: (bloc) => bloc.add(const CameraEvent.started()),
      expect: () => const [
        CameraState.initializing(),
        CameraState.cameraDenied(permanent: true),
      ],
      verify: (_) => verifyNever(repository.requestCameraPermission),
    );

    blocTest<CameraBloc, CameraState>(
      'denied at check, permanently denied at the prompt → '
      'cameraDenied(permanent)',
      setUp: () {
        when(
          repository.checkCameraPermission,
        ).thenAnswer((_) async => PermissionVerdict.denied);
        when(
          repository.requestCameraPermission,
        ).thenAnswer((_) async => PermissionVerdict.permanentlyDenied);
      },
      build: buildBloc,
      act: (bloc) => bloc.add(const CameraEvent.started()),
      expect: () => const [
        CameraState.initializing(),
        CameraState.cameraDenied(permanent: true),
      ],
    );

    blocTest<CameraBloc, CameraState>(
      'Failure.noCamera during acquisition → unavailable',
      setUp: () => when(
        () => repository.initializeCamera(
          frontCamera: any(named: 'frontCamera'),
        ),
      ).thenThrow(const Failure.noCamera()),
      build: buildBloc,
      act: (bloc) => bloc.add(const CameraEvent.started()),
      expect: () => const [
        CameraState.initializing(),
        CameraState.unavailable(),
      ],
    );

    blocTest<CameraBloc, CameraState>(
      'any other acquisition error degrades to unavailable',
      setUp: () => when(
        () => repository.initializeCamera(
          frontCamera: any(named: 'frontCamera'),
        ),
      ).thenThrow(Exception('camera busy')),
      build: buildBloc,
      act: (bloc) => bloc.add(const CameraEvent.started()),
      expect: () => const [
        CameraState.initializing(),
        CameraState.unavailable(),
      ],
    );
  });

  group('permission recovery', () {
    blocTest<CameraBloc, CameraState>(
      'appResumed after the user granted in Settings auto-recovers from '
      'cameraDenied without a manual retry',
      build: buildBloc,
      seed: () => const CameraState.cameraDenied(permanent: false),
      act: (bloc) => bloc.add(const CameraEvent.appResumed()),
      expect: () => [const CameraState.initializing(), ready()],
    );

    blocTest<CameraBloc, CameraState>(
      'permissionRetryRequested re-runs the permission flow',
      build: buildBloc,
      seed: () => const CameraState.cameraDenied(permanent: false),
      act: (bloc) => bloc.add(const CameraEvent.permissionRetryRequested()),
      expect: () => [const CameraState.initializing(), ready()],
    );

    blocTest<CameraBloc, CameraState>(
      'openSettingsRequested opens the system settings and emits nothing',
      setUp: () => when(repository.openSystemSettings).thenAnswer((_) async {}),
      build: buildBloc,
      seed: () => const CameraState.cameraDenied(permanent: true),
      act: (bloc) => bloc.add(const CameraEvent.openSettingsRequested()),
      expect: () => const <CameraState>[],
      verify: (_) => verify(repository.openSystemSettings).called(1),
    );
  });

  group('photo shutter', () {
    blocTest<CameraBloc, CameraState>(
      'capturing → success(payload) → suspended (camera parked for the '
      'downstream flow)',
      build: buildBloc,
      act: (bloc) async {
        await start(bloc);
        bloc.add(const CameraEvent.shutterPressed());
      },
      expect: () => [
        const CameraState.initializing(),
        ready(),
        const CameraState.capturing(),
        CameraState.success(payload: _stillPayload),
        const CameraState.suspended(),
      ],
    );

    blocTest<CameraBloc, CameraState>(
      'a second shutter press while a capture is in flight is dropped, '
      'never queued (droppable)',
      build: buildBloc,
      act: (bloc) async {
        final gate = Completer<String>();
        when(repository.captureStillToFile).thenAnswer((_) => gate.future);
        await start(bloc);
        bloc.add(const CameraEvent.shutterPressed());
        await pumpEventQueue();
        bloc.add(const CameraEvent.shutterPressed());
        await pumpEventQueue();
        gate.complete('/captures/shot_1.png');
        await pumpEventQueue();
      },
      expect: () => [
        const CameraState.initializing(),
        ready(),
        const CameraState.capturing(),
        CameraState.success(payload: _stillPayload),
        const CameraState.suspended(),
      ],
      verify: (_) => verify(repository.captureStillToFile).called(1),
    );

    blocTest<CameraBloc, CameraState>(
      'a capture failure returns to ready with the one-shot failure, '
      'cleared on the next emission',
      setUp: () => when(
        repository.captureStillToFile,
      ).thenThrow(const Failure.captureFailed('boom')),
      build: buildBloc,
      act: (bloc) async {
        await start(bloc);
        bloc.add(const CameraEvent.shutterPressed());
        await pumpEventQueue();
        bloc.add(const CameraEvent.modeChanged(CaptureMode.video));
      },
      expect: () => [
        const CameraState.initializing(),
        ready(),
        const CameraState.capturing(),
        ready(failure: const Failure.captureFailed('boom')),
        // The next emission carries no failure — the SnackBar is one-shot.
        ready(mode: CaptureMode.video),
      ],
    );

    blocTest<CameraBloc, CameraState>(
      'a shutter press while not ready is ignored',
      build: buildBloc,
      act: (bloc) => bloc.add(const CameraEvent.shutterPressed()),
      expect: () => const <CameraState>[],
      verify: (_) => verifyNever(repository.captureStillToFile),
    );
  });

  group('video burst', () {
    blocTest<CameraBloc, CameraState>(
      'a full burst records 1..5 and succeeds with the five frames in order',
      setUp: () {
        var frame = 0;
        when(
          repository.captureStillToFile,
        ).thenAnswer((_) async => '/captures/frame_${++frame}.png');
      },
      build: buildBloc,
      act: (bloc) async {
        await start(bloc);
        bloc
          ..add(const CameraEvent.modeChanged(CaptureMode.video))
          ..add(const CameraEvent.shutterPressed());
      },
      expect: () => [
        const CameraState.initializing(),
        ready(),
        ready(mode: CaptureMode.video),
        for (var frames = 0; frames <= 5; frames++)
          CameraState.recording(framesCaptured: frames, frameTarget: 5),
        CameraState.success(
          payload: CapturePayload.frames(
            framePaths: const [
              '/captures/frame_1.png',
              '/captures/frame_2.png',
              '/captures/frame_3.png',
              '/captures/frame_4.png',
              '/captures/frame_5.png',
            ],
            capturedAt: _FixedClock.instant,
          ),
        ),
        const CameraState.suspended(),
      ],
    );

    blocTest<CameraBloc, CameraState>(
      'recordingStopped ends the burst early with at least one frame',
      build: buildBloc,
      act: (bloc) async {
        final gate = Completer<String>();
        when(repository.captureStillToFile).thenAnswer((_) => gate.future);
        await start(bloc);
        bloc
          ..add(const CameraEvent.modeChanged(CaptureMode.video))
          ..add(const CameraEvent.shutterPressed());
        await pumpEventQueue();
        // The stop lands while frame 1 is still in flight…
        bloc.add(const CameraEvent.recordingStopped());
        await pumpEventQueue();
        // …so when it completes, the burst stops with that single frame.
        gate.complete('/captures/frame_1.png');
        await pumpEventQueue();
      },
      expect: () => [
        const CameraState.initializing(),
        ready(),
        ready(mode: CaptureMode.video),
        const CameraState.recording(framesCaptured: 0, frameTarget: 5),
        const CameraState.recording(framesCaptured: 1, frameTarget: 5),
        CameraState.success(
          payload: CapturePayload.frames(
            framePaths: const ['/captures/frame_1.png'],
            capturedAt: _FixedClock.instant,
          ),
        ),
        const CameraState.suspended(),
      ],
      verify: (_) => verify(repository.captureStillToFile).called(1),
    );
  });

  group('gallery', () {
    blocTest<CameraBloc, CameraState>(
      'a successful pick from ready → pickingGallery → success → suspended',
      build: buildBloc,
      act: (bloc) async {
        await start(bloc);
        bloc.add(const CameraEvent.galleryRequested());
      },
      expect: () => [
        const CameraState.initializing(),
        ready(),
        const CameraState.pickingGallery(),
        CameraState.success(payload: _galleryPayload),
        const CameraState.suspended(),
      ],
    );

    blocTest<CameraBloc, CameraState>(
      'the gallery capture mode routes the shutter to the picker',
      build: buildBloc,
      act: (bloc) async {
        await start(bloc);
        bloc
          ..add(const CameraEvent.modeChanged(CaptureMode.gallery))
          ..add(const CameraEvent.shutterPressed());
      },
      expect: () => [
        const CameraState.initializing(),
        ready(),
        ready(mode: CaptureMode.gallery),
        const CameraState.pickingGallery(),
        CameraState.success(payload: _galleryPayload),
        const CameraState.suspended(),
      ],
    );

    blocTest<CameraBloc, CameraState>(
      'a cancelled pick silently restores the prior ready state '
      '(no failure)',
      setUp: () =>
          when(repository.pickImageFromGallery).thenAnswer((_) async => null),
      build: buildBloc,
      act: (bloc) async {
        await start(bloc);
        bloc.add(const CameraEvent.galleryRequested());
      },
      expect: () => [
        const CameraState.initializing(),
        ready(),
        const CameraState.pickingGallery(),
        ready(),
      ],
    );

    blocTest<CameraBloc, CameraState>(
      'a cancelled pick from the camera-denied view restores that view',
      setUp: () {
        when(
          repository.checkCameraPermission,
        ).thenAnswer((_) async => PermissionVerdict.denied);
        when(
          repository.requestCameraPermission,
        ).thenAnswer((_) async => PermissionVerdict.denied);
        when(repository.pickImageFromGallery).thenAnswer((_) async => null);
      },
      build: buildBloc,
      act: (bloc) async {
        await start(bloc);
        bloc.add(const CameraEvent.galleryRequested());
      },
      expect: () => const [
        CameraState.initializing(),
        CameraState.cameraDenied(permanent: false),
        CameraState.pickingGallery(),
        CameraState.cameraDenied(permanent: false),
      ],
    );

    blocTest<CameraBloc, CameraState>(
      'a re-promptable photo-access denial → galleryDenied(permanent: false)',
      setUp: () => when(
        repository.pickImageFromGallery,
      ).thenThrow(const Failure.photoAccessDenied(permanent: false)),
      build: buildBloc,
      act: (bloc) async {
        await start(bloc);
        bloc.add(const CameraEvent.galleryRequested());
      },
      expect: () => [
        const CameraState.initializing(),
        ready(),
        const CameraState.pickingGallery(),
        const CameraState.galleryDenied(permanent: false),
      ],
    );

    blocTest<CameraBloc, CameraState>(
      'a permanent photo-access denial → galleryDenied(permanent: true)',
      setUp: () => when(
        repository.pickImageFromGallery,
      ).thenThrow(const Failure.photoAccessDenied(permanent: true)),
      build: buildBloc,
      act: (bloc) async {
        await start(bloc);
        bloc.add(const CameraEvent.galleryRequested());
      },
      expect: () => [
        const CameraState.initializing(),
        ready(),
        const CameraState.pickingGallery(),
        const CameraState.galleryDenied(permanent: true),
      ],
    );

    blocTest<CameraBloc, CameraState>(
      'the gallery escape works from the camera-denied view',
      setUp: () {
        when(
          repository.checkCameraPermission,
        ).thenAnswer((_) async => PermissionVerdict.denied);
        when(
          repository.requestCameraPermission,
        ).thenAnswer((_) async => PermissionVerdict.denied);
      },
      build: buildBloc,
      act: (bloc) async {
        await start(bloc);
        bloc.add(const CameraEvent.galleryRequested());
      },
      expect: () => [
        const CameraState.initializing(),
        const CameraState.cameraDenied(permanent: false),
        const CameraState.pickingGallery(),
        CameraState.success(payload: _galleryPayload),
        const CameraState.suspended(),
      ],
    );

    blocTest<CameraBloc, CameraState>(
      'the gallery escape works from the no-camera view',
      setUp: () => when(
        () => repository.initializeCamera(
          frontCamera: any(named: 'frontCamera'),
        ),
      ).thenThrow(const Failure.noCamera()),
      build: buildBloc,
      act: (bloc) async {
        await start(bloc);
        bloc.add(const CameraEvent.galleryRequested());
      },
      expect: () => [
        const CameraState.initializing(),
        const CameraState.unavailable(),
        const CameraState.pickingGallery(),
        CameraState.success(payload: _galleryPayload),
        const CameraState.suspended(),
      ],
    );

    blocTest<CameraBloc, CameraState>(
      'the retry from the gallery-denied view re-opens the picker',
      build: buildBloc,
      seed: () => const CameraState.galleryDenied(permanent: false),
      act: (bloc) => bloc.add(const CameraEvent.galleryRequested()),
      expect: () => [
        const CameraState.pickingGallery(),
        CameraState.success(payload: _galleryPayload),
        const CameraState.suspended(),
      ],
    );

    blocTest<CameraBloc, CameraState>(
      'a gallery request while initializing is ignored',
      build: buildBloc,
      act: (bloc) => bloc.add(const CameraEvent.galleryRequested()),
      expect: () => const <CameraState>[],
      verify: (_) => verifyNever(repository.pickImageFromGallery),
    );
  });

  group('flash / flip / mode round-trips', () {
    blocTest<CameraBloc, CameraState>(
      'the flash toggles on then back off, driving the torch each time',
      build: buildBloc,
      act: (bloc) async {
        await start(bloc);
        bloc.add(const CameraEvent.flashToggled());
        await pumpEventQueue();
        bloc.add(const CameraEvent.flashToggled());
      },
      expect: () => [
        const CameraState.initializing(),
        ready(),
        ready(flashOn: true),
        ready(),
      ],
      verify: (_) {
        verifyInOrder([
          () => repository.setFlash(enabled: true),
          () => repository.setFlash(enabled: false),
        ]);
      },
    );

    blocTest<CameraBloc, CameraState>(
      'the flash toggle is a no-op when the camera has no flash',
      setUp: () => when(() => repository.isFlashAvailable).thenReturn(false),
      build: buildBloc,
      act: (bloc) async {
        await start(bloc);
        bloc.add(const CameraEvent.flashToggled());
      },
      expect: () => [
        const CameraState.initializing(),
        ready(flashAvailable: false),
      ],
      verify: (_) => verifyNever(
        () => repository.setFlash(enabled: any(named: 'enabled')),
      ),
    );

    blocTest<CameraBloc, CameraState>(
      'a refused torch surfaces the failure and keeps the flash off',
      setUp: () => when(
        () => repository.setFlash(enabled: any(named: 'enabled')),
      ).thenThrow(const Failure.captureFailed('torch')),
      build: buildBloc,
      act: (bloc) async {
        await start(bloc);
        bloc.add(const CameraEvent.flashToggled());
      },
      expect: () => [
        const CameraState.initializing(),
        ready(),
        ready(failure: const Failure.captureFailed('torch')),
      ],
    );

    blocTest<CameraBloc, CameraState>(
      'the flip re-acquires the front camera, then back, resetting the torch',
      build: buildBloc,
      act: (bloc) async {
        await start(bloc);
        bloc.add(const CameraEvent.flipRequested());
        await pumpEventQueue();
        bloc.add(const CameraEvent.flipRequested());
      },
      expect: () => [
        const CameraState.initializing(),
        ready(),
        const CameraState.initializing(),
        ready(frontCamera: true),
        const CameraState.initializing(),
        ready(),
      ],
      verify: (_) {
        verify(() => repository.initializeCamera(frontCamera: true)).called(1);
        verify(() => repository.initializeCamera(frontCamera: false)).called(2);
      },
    );

    blocTest<CameraBloc, CameraState>(
      'the mode cycles photo → video → gallery → photo',
      build: buildBloc,
      act: (bloc) async {
        await start(bloc);
        bloc
          ..add(const CameraEvent.modeChanged(CaptureMode.video))
          ..add(const CameraEvent.modeChanged(CaptureMode.gallery))
          ..add(const CameraEvent.modeChanged(CaptureMode.photo));
      },
      expect: () => [
        const CameraState.initializing(),
        ready(),
        ready(mode: CaptureMode.video),
        ready(mode: CaptureMode.gallery),
        ready(),
      ],
    );

    blocTest<CameraBloc, CameraState>(
      'a mode change while not ready is ignored',
      build: buildBloc,
      act: (bloc) => bloc.add(const CameraEvent.modeChanged(CaptureMode.video)),
      expect: () => const <CameraState>[],
    );
  });

  group('app lifecycle', () {
    blocTest<CameraBloc, CameraState>(
      'backgrounding parks the camera into suspended',
      build: buildBloc,
      act: (bloc) async {
        await start(bloc);
        bloc.add(const CameraEvent.appBackgrounded());
      },
      expect: () => [
        const CameraState.initializing(),
        ready(),
        const CameraState.suspended(),
      ],
    );

    blocTest<CameraBloc, CameraState>(
      'resuming after a park re-acquires the camera back to ready',
      build: buildBloc,
      act: (bloc) async {
        await start(bloc);
        bloc.add(const CameraEvent.appBackgrounded());
        await pumpEventQueue();
        bloc.add(const CameraEvent.appResumed());
      },
      expect: () => [
        const CameraState.initializing(),
        ready(),
        const CameraState.suspended(),
        const CameraState.initializing(),
        ready(),
      ],
    );

    blocTest<CameraBloc, CameraState>(
      'a resume while the gallery picker is open is a no-op — the in-flight '
      'pick drives the next state, not the resume',
      build: buildBloc,
      act: (bloc) async {
        final gate = Completer<String?>();
        when(repository.pickImageFromGallery).thenAnswer((_) => gate.future);
        await start(bloc);
        bloc.add(const CameraEvent.galleryRequested());
        await pumpEventQueue();
        // The system picker backgrounded/resumed the app mid-pick.
        bloc.add(const CameraEvent.appResumed());
        await pumpEventQueue();
        gate.complete('/captures/picked.png');
        await pumpEventQueue();
      },
      expect: () => [
        const CameraState.initializing(),
        ready(),
        const CameraState.pickingGallery(),
        CameraState.success(payload: _galleryPayload),
        const CameraState.suspended(),
      ],
      verify: (_) {
        // Only the initial start acquired the camera — the resume did not.
        verify(() => repository.initializeCamera(frontCamera: false)).called(1);
      },
    );

    blocTest<CameraBloc, CameraState>(
      'cancelling the picker after backgrounding released the camera '
      're-acquires it instead of restoring a stale ready',
      build: buildBloc,
      act: (bloc) async {
        final gate = Completer<String?>();
        when(repository.pickImageFromGallery).thenAnswer((_) => gate.future);
        await start(bloc);
        bloc.add(const CameraEvent.galleryRequested());
        await pumpEventQueue();
        // The system picker backgrounded the app: the camera is released
        // but the picking state is kept…
        bloc.add(const CameraEvent.appBackgrounded());
        await pumpEventQueue();
        // …and the resume is a no-op while the picker is open.
        bloc.add(const CameraEvent.appResumed());
        await pumpEventQueue();
        // The user cancels the picker: the captured ready state is stale
        // (the camera is no longer held), so the bloc must re-initialize.
        gate.complete(null);
        await pumpEventQueue();
      },
      expect: () => [
        const CameraState.initializing(),
        ready(),
        const CameraState.pickingGallery(),
        const CameraState.initializing(),
        ready(),
      ],
      verify: (_) {
        // The start plus the post-cancel re-acquisition.
        verify(() => repository.initializeCamera(frontCamera: false)).called(2);
      },
    );

    blocTest<CameraBloc, CameraState>(
      'a pick failure after backgrounding released the camera re-acquires '
      'it, still surfacing the one-shot failure',
      build: buildBloc,
      act: (bloc) async {
        final gate = Completer<String?>();
        when(repository.pickImageFromGallery).thenAnswer((_) => gate.future);
        await start(bloc);
        bloc.add(const CameraEvent.galleryRequested());
        await pumpEventQueue();
        bloc.add(const CameraEvent.appBackgrounded());
        await pumpEventQueue();
        bloc.add(const CameraEvent.appResumed());
        await pumpEventQueue();
        gate.completeError(const Failure.captureFailed('pick'));
        await pumpEventQueue();
      },
      expect: () => [
        const CameraState.initializing(),
        ready(),
        const CameraState.pickingGallery(),
        const CameraState.initializing(),
        ready(failure: const Failure.captureFailed('pick')),
      ],
      verify: (_) {
        verify(() => repository.initializeCamera(frontCamera: false)).called(2);
      },
    );

    blocTest<CameraBloc, CameraState>(
      'a resume while already ready is a no-op',
      build: buildBloc,
      act: (bloc) async {
        await start(bloc);
        bloc.add(const CameraEvent.appResumed());
      },
      expect: () => [const CameraState.initializing(), ready()],
      verify: (_) {
        verify(() => repository.initializeCamera(frontCamera: false)).called(1);
      },
    );
  });

  group('close', () {
    test('releases the camera', () async {
      final bloc = buildBloc();

      await bloc.close();

      verify(repository.releaseCamera).called(1);
    });

    test('closing the bloc mid-capture neither throws nor emits '
        '(isClosed guards after every await)', () async {
      final gate = Completer<String>();
      when(repository.captureStillToFile).thenAnswer((_) => gate.future);
      final bloc = buildBloc()..add(const CameraEvent.started());
      await pumpEventQueue();
      bloc.add(const CameraEvent.shutterPressed());
      await pumpEventQueue();
      check(bloc.state).equals(const CameraState.capturing());

      await bloc.close();
      gate.complete('/captures/late.png');
      // Must not throw an emit-after-close StateError out of the handler.
      await pumpEventQueue();

      check(bloc.state).equals(const CameraState.capturing());
    });

    test('closing the bloc mid-pick neither throws nor emits', () async {
      final gate = Completer<String?>();
      when(repository.pickImageFromGallery).thenAnswer((_) => gate.future);
      final bloc = buildBloc()..add(const CameraEvent.started());
      await pumpEventQueue();
      bloc.add(const CameraEvent.galleryRequested());
      await pumpEventQueue();
      check(bloc.state).equals(const CameraState.pickingGallery());

      await bloc.close();
      gate.complete('/captures/picked.png');
      await pumpEventQueue();

      check(bloc.state).equals(const CameraState.pickingGallery());
    });
  });
}
