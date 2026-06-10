import 'package:bloc_test/bloc_test.dart';
import 'package:checks/checks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:okey_acar_mi/core/camera/viewfinder_service.dart';
import 'package:okey_acar_mi/core/error/failure.dart';
import 'package:okey_acar_mi/core/router/app_router.dart';
import 'package:okey_acar_mi/core/theme/app_accent.dart';
import 'package:okey_acar_mi/core/theme/app_theme.dart';
import 'package:okey_acar_mi/core/theme/tile_style.dart';
import 'package:okey_acar_mi/features/capture/domain/entities/capture_mode.dart';
import 'package:okey_acar_mi/features/capture/domain/entities/capture_payload.dart';
import 'package:okey_acar_mi/features/capture/presentation/blocs/camera_bloc.dart';
import 'package:okey_acar_mi/features/capture/presentation/pages/camera_page.dart';
import 'package:okey_acar_mi/l10n/app_localizations.dart';

class _MockCameraBloc extends MockBloc<CameraEvent, CameraState>
    implements CameraBloc {}

/// A deterministic stand-in viewfinder (no assets, no image decoding).
class _StubViewfinder implements ViewfinderService {
  const _StubViewfinder();

  @override
  bool get hasLivePreview => false;

  @override
  Widget buildViewfinder(BuildContext context) => const ColoredBox(
    key: ValueKey('stub-viewfinder'),
    color: Colors.black,
  );
}

/// The recording red used by the shutter ring (design token).
const _recordRed = Color(0xFFE53935);

/// The locale every assertion reads its strings from.
final AppLocalizations _l10n = lookupAppLocalizations(const Locale('en'));

/// The concrete ready variant (so tests can `copyWith` mode/flash variants).
const CameraReady _ready = CameraReady(
  mode: CaptureMode.photo,
  flashOn: false,
  frontCamera: false,
  flashAvailable: true,
);

void main() {
  setUpAll(() {
    registerFallbackValue(const CameraEvent.started());
  });

  late _MockCameraBloc bloc;

  /// What the fake analyzing route received via `state.extra`.
  Object? analyzingExtra;

  setUp(() {
    bloc = _MockCameraBloc();
    analyzingExtra = null;
  });

  /// Pins [state] on the mocked bloc; [emitAfter] states stream in after the
  /// first frame (driving `BlocListener`).
  void stubState(CameraState state, {List<CameraState> emitAfter = const []}) {
    whenListen(bloc, Stream.fromIterable(emitAfter), initialState: state);
  }

  /// `CameraView` under a real router (the top bar reads `context.canPop()`),
  /// with a stub `/analyzing` route capturing the navigation extra.
  Widget harness() {
    final router = GoRouter(
      initialLocation: AppRoutes.camera,
      routes: [
        GoRoute(
          path: AppRoutes.camera,
          builder: (context, state) => BlocProvider<CameraBloc>.value(
            value: bloc,
            child: const CameraView(viewfinder: _StubViewfinder()),
          ),
        ),
        GoRoute(
          path: AppRoutes.analyzing,
          builder: (context, state) {
            analyzingExtra = state.extra;
            return const Scaffold(
              body: Center(child: Text('analyzing-stub')),
            );
          },
        ),
      ],
    );
    return MaterialApp.router(
      theme: AppTheme.light(AppAccent.sage, TileStyle.classic),
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: const [Locale('tr'), Locale('en')],
      routerConfig: router,
    );
  }

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(harness());
    await tester.pump();
  }

  Finder key(String value) => find.byKey(ValueKey(value));

  /// The fill color of the shutter ring's inner shape.
  Color? shutterFill(WidgetTester tester) {
    final inner = tester
        .widgetList<Container>(
          find.descendant(
            of: key('camera-shutter'),
            matching: find.byType(Container),
          ),
        )
        .last;
    return (inner.decoration as BoxDecoration?)?.color;
  }

  group('ready state', () {
    testWidgets('renders the full capture chrome', (tester) async {
      stubState(_ready);
      await pump(tester);

      for (final control in const [
        'camera-back',
        'camera-frame-hint',
        'camera-flash',
        'camera-mode-photo',
        'camera-mode-video',
        'camera-mode-gallery',
        'camera-gallery',
        'camera-shutter',
        'camera-flip',
        'stub-viewfinder',
      ]) {
        check(
          because: '$control must be present while ready',
          key(control).evaluate(),
        ).length.equals(1);
      }
      check(find.text(_l10n.cameraFrameHint).evaluate()).length.equals(1);
      check(key('camera-permission-retry').evaluate()).isEmpty();
      check(key('camera-open-settings').evaluate()).isEmpty();
      check(key('camera-gallery-fallback').evaluate()).isEmpty();
      check(tester.takeException()).isNull();
    });

    testWidgets('the shutter ring fill is white in photo mode', (
      tester,
    ) async {
      stubState(_ready);
      await pump(tester);

      check(shutterFill(tester)).equals(Colors.white);
    });

    testWidgets('the shutter ring fill is red in video mode', (tester) async {
      stubState(_ready.copyWith(mode: CaptureMode.video));
      await pump(tester);

      check(shutterFill(tester)).equals(_recordRed);
    });

    testWidgets('the flash toggle is hidden when no flash is available', (
      tester,
    ) async {
      stubState(_ready.copyWith(flashAvailable: false));
      await pump(tester);

      check(key('camera-flash').evaluate()).isEmpty();
    });

    testWidgets('every icon-only control carries a Semantics label', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      stubState(_ready);
      await pump(tester);

      for (final label in [
        _l10n.cameraShutterSemantics,
        _l10n.cameraFlipSemantics,
        _l10n.cameraGallerySemantics,
        _l10n.cameraFlashOffSemantics,
        // canPop is false in this harness, so the back slot is the Home escape.
        _l10n.navHome,
      ]) {
        check(
          because: 'a control must be labeled "$label"',
          find.bySemanticsLabel(label).evaluate(),
        ).isNotEmpty();
      }
      handle.dispose();
    });

    testWidgets('a flash-on state shows the active icon and its label', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      stubState(_ready.copyWith(flashOn: true));
      await pump(tester);

      check(find.byIcon(Icons.flash_on_rounded).evaluate()).length.equals(1);
      check(
        find.bySemanticsLabel(_l10n.cameraFlashOnSemantics).evaluate(),
      ).isNotEmpty();
      handle.dispose();
    });

    testWidgets('shutter, flash, flip, gallery, and mode pills dispatch '
        'their events', (tester) async {
      stubState(_ready);
      await pump(tester);

      await tester.tap(key('camera-shutter'));
      await tester.tap(key('camera-flash'));
      await tester.tap(key('camera-flip'));
      await tester.tap(key('camera-gallery'));
      await tester.tap(key('camera-mode-video'));

      verify(() => bloc.add(const CameraEvent.shutterPressed())).called(1);
      verify(() => bloc.add(const CameraEvent.flashToggled())).called(1);
      verify(() => bloc.add(const CameraEvent.flipRequested())).called(1);
      verify(() => bloc.add(const CameraEvent.galleryRequested())).called(1);
      verify(
        () => bloc.add(const CameraEvent.modeChanged(CaptureMode.video)),
      ).called(1);
    });
  });

  group('recording state', () {
    const recording = CameraState.recording(framesCaptured: 2, frameTarget: 5);

    testWidgets('shows the frame counter, hides the flash, and turns the '
        'shutter into the red stop control', (tester) async {
      stubState(recording);
      await pump(tester);

      check(
        find.text(_l10n.cameraRecordingProgress(2, 5)).evaluate(),
      ).length.equals(1);
      check(find.text(_l10n.cameraFrameHint).evaluate()).isEmpty();
      check(key('camera-flash').evaluate()).isEmpty();
      check(shutterFill(tester)).equals(_recordRed);
      check(tester.takeException()).isNull();
    });

    testWidgets('the shutter dispatches recordingStopped while recording', (
      tester,
    ) async {
      stubState(recording);
      await pump(tester);

      await tester.tap(key('camera-shutter'));

      verify(() => bloc.add(const CameraEvent.recordingStopped())).called(1);
      verifyNever(() => bloc.add(const CameraEvent.shutterPressed()));
    });
  });

  group('blocked states', () {
    testWidgets('cameraDenied (re-promptable): rationale + Retry + gallery '
        'fallback, no Settings, no shutter', (tester) async {
      stubState(const CameraState.cameraDenied(permanent: false));
      await pump(tester);

      check(find.text(_l10n.cameraDeniedTitle).evaluate()).length.equals(1);
      check(find.text(_l10n.cameraDeniedBody).evaluate()).length.equals(1);
      check(key('camera-permission-retry').evaluate()).length.equals(1);
      check(key('camera-gallery-fallback').evaluate()).length.equals(1);
      check(key('camera-open-settings').evaluate()).isEmpty();
      check(key('camera-shutter').evaluate()).isEmpty();
      check(tester.takeException()).isNull();
    });

    testWidgets('cameraDenied (permanent): Open Settings + gallery fallback, '
        'no Retry', (tester) async {
      stubState(const CameraState.cameraDenied(permanent: true));
      await pump(tester);

      check(
        find.text(_l10n.cameraPermanentlyDeniedBody).evaluate(),
      ).length.equals(1);
      check(key('camera-open-settings').evaluate()).length.equals(1);
      check(key('camera-gallery-fallback').evaluate()).length.equals(1);
      check(key('camera-permission-retry').evaluate()).isEmpty();
      check(tester.takeException()).isNull();
    });

    testWidgets('unavailable: gallery fallback only', (tester) async {
      stubState(const CameraState.unavailable());
      await pump(tester);

      check(find.text(_l10n.cameraNoCameraTitle).evaluate()).length.equals(1);
      check(key('camera-gallery-fallback').evaluate()).length.equals(1);
      check(key('camera-permission-retry').evaluate()).isEmpty();
      check(key('camera-open-settings').evaluate()).isEmpty();
      check(key('camera-shutter').evaluate()).isEmpty();
      check(tester.takeException()).isNull();
    });

    testWidgets('galleryDenied (re-promptable): Retry only — no gallery '
        'fallback into the same denied picker', (tester) async {
      stubState(const CameraState.galleryDenied(permanent: false));
      await pump(tester);

      check(
        find.text(_l10n.cameraGalleryDeniedTitle).evaluate(),
      ).length.equals(1);
      check(key('camera-permission-retry').evaluate()).length.equals(1);
      check(key('camera-gallery-fallback').evaluate()).isEmpty();
      check(key('camera-open-settings').evaluate()).isEmpty();
      check(tester.takeException()).isNull();
    });

    testWidgets('galleryDenied (permanent): Open Settings only', (
      tester,
    ) async {
      stubState(const CameraState.galleryDenied(permanent: true));
      await pump(tester);

      check(
        find.text(_l10n.cameraGalleryPermanentlyDeniedBody).evaluate(),
      ).length.equals(1);
      check(key('camera-open-settings').evaluate()).length.equals(1);
      check(key('camera-permission-retry').evaluate()).isEmpty();
      check(key('camera-gallery-fallback').evaluate()).isEmpty();
      check(tester.takeException()).isNull();
    });

    testWidgets('the camera-denied Retry re-runs the permission flow', (
      tester,
    ) async {
      stubState(const CameraState.cameraDenied(permanent: false));
      await pump(tester);

      await tester.tap(key('camera-permission-retry'));

      verify(
        () => bloc.add(const CameraEvent.permissionRetryRequested()),
      ).called(1);
    });

    testWidgets('the gallery-denied Retry re-opens the picker instead', (
      tester,
    ) async {
      stubState(const CameraState.galleryDenied(permanent: false));
      await pump(tester);

      await tester.tap(key('camera-permission-retry'));

      verify(() => bloc.add(const CameraEvent.galleryRequested())).called(1);
      verifyNever(() => bloc.add(const CameraEvent.permissionRetryRequested()));
    });

    testWidgets('Open Settings dispatches openSettingsRequested', (
      tester,
    ) async {
      stubState(const CameraState.cameraDenied(permanent: true));
      await pump(tester);

      await tester.tap(key('camera-open-settings'));

      verify(
        () => bloc.add(const CameraEvent.openSettingsRequested()),
      ).called(1);
    });

    testWidgets('the gallery fallback dispatches galleryRequested', (
      tester,
    ) async {
      stubState(const CameraState.unavailable());
      await pump(tester);

      await tester.tap(key('camera-gallery-fallback'));

      verify(() => bloc.add(const CameraEvent.galleryRequested())).called(1);
    });
  });

  group('listener side effects', () {
    testWidgets('a success state pushes /analyzing with the payload as '
        'extra', (tester) async {
      final payload = CapturePayload.still(
        imagePath: '/captures/shot.png',
        source: CaptureSource.photo,
        capturedAt: DateTime.utc(2026, 6, 10, 12),
      );
      stubState(
        _ready,
        emitAfter: [
          CameraState.success(payload: payload),
          const CameraState.suspended(),
        ],
      );
      await pump(tester);
      await tester.pumpAndSettle();

      check(find.text('analyzing-stub').evaluate()).length.equals(1);
      check(analyzingExtra).equals(payload);
      check(tester.takeException()).isNull();
    });

    testWidgets('a one-shot ready.failure shows the capture-failed SnackBar', (
      tester,
    ) async {
      stubState(
        _ready,
        emitAfter: [
          _ready.copyWith(failure: const Failure.captureFailed('boom')),
        ],
      );
      await pump(tester);
      await tester.pump();

      check(find.byType(SnackBar).evaluate()).length.equals(1);
      check(find.text(_l10n.cameraCaptureFailed).evaluate()).length.equals(1);

      // Drain the SnackBar's display timer so no timer outlives the test.
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      check(tester.takeException()).isNull();
    });
  });
}
