import 'package:checks/checks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:okey_acar_mi/app.dart';
import 'package:okey_acar_mi/core/di/injection.dart';
import 'package:okey_acar_mi/core/extensions/context_extensions.dart';
import 'package:okey_acar_mi/core/widgets/placeholder_page.dart';
import 'package:okey_acar_mi/features/capture/data/fakes/fake_capture_service.dart';
import 'package:okey_acar_mi/features/capture/presentation/blocs/camera_bloc.dart';
import 'package:okey_acar_mi/features/capture/presentation/pages/camera_page.dart';
import 'package:okey_acar_mi/features/detection/presentation/pages/analyzing_page.dart';
import 'package:okey_acar_mi/features/home/presentation/pages/home_page.dart';

// ---------------------------------------------------------------------------
// Robot helpers
// ---------------------------------------------------------------------------

/// The demo fake driving every capture behavior in these flows (registered
/// as itself in the demo environment).
FakeCaptureService fakeCapture() => getIt<FakeCaptureService>();

Future<void> pumpApp(WidgetTester tester) async {
  await tester.pumpWidget(const App());
  await tester.pumpAndSettle();
}

Future<void> tapKey(WidgetTester tester, String key) async {
  final finder = find.byKey(ValueKey(key));
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// Awaits [condition] with real async waits — **no frame pumping**.
///
/// While the app lifecycle is `paused`, a live device binding's engine stops
/// producing frames, so any pump-based wait (`pumpAndSettle`) never completes
/// (its timeout only fires between completed pumps). The Dart event loop keeps
/// running, though, so bloc handlers still execute: poll the non-UI condition
/// until it holds, and let the caller's `check` fail loudly on timeout.
Future<void> waitForCondition(
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 5),
}) async {
  final stopwatch = Stopwatch()..start();
  while (!condition() && stopwatch.elapsed < timeout) {
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
}

/// Splash → guest entry → Home.
Future<void> goHomeAsGuest(WidgetTester tester) async {
  await tapKey(tester, 'splash-guest');
  check(find.byType(HomePage).evaluate()).length.equals(1);
}

/// Taps the Home scan CTA (its camera glyph is unique on Home) and lands on
/// the capture screen.
Future<void> openCamera(WidgetTester tester) async {
  final cta = find.byIcon(Icons.photo_camera_outlined);
  await tester.ensureVisible(cta);
  await tester.pumpAndSettle();
  await tester.tap(cta);
  await tester.pumpAndSettle();
  check(find.byType(CameraView).evaluate()).length.equals(1);
}

/// The live capture chrome: fixture viewfinder + shutter row.
void expectCameraReady(WidgetTester tester) {
  check(
    find.byKey(const ValueKey('camera-shutter')).evaluate(),
  ).length.equals(1);
  check(
    find
        .descendant(of: find.byType(CameraView), matching: find.byType(Image))
        .evaluate(),
  ).isNotEmpty();
}

/// The downstream hand-off: the capture landed on the real [AnalyzingPage].
///
/// The demo detector auto-completes and auto-advances, so by the time
/// `pumpAndSettle` rests, analyzing has already pushed the review placeholder
/// on top of itself (it pops itself only when review pops — that keeps the
/// camera's push-future pending). Assert both halves of that contract: the
/// AnalyzingPage is alive beneath (offstage) and review is on top.
void expectOnAnalyzing(WidgetTester tester) {
  check(
    find.byType(AnalyzingPage, skipOffstage: false).evaluate(),
  ).length.equals(1);
  final page = tester.widget<PlaceholderPage>(find.byType(PlaceholderPage));
  check(page.screen).equals(PlaceholderScreen.review);
}

// ---------------------------------------------------------------------------
// Scenarios
// ---------------------------------------------------------------------------

/// End-to-end capture flows on the demo flavor (no hardware, no screenshots).
/// Run with:
///
/// ```bash
/// flutter test integration_test/capture_flow_test.dart \
///   --dart-define=APP_ENV=demo -d <device>
/// ```
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Capture flows end-to-end (demo flavor)', () {
    setUp(() async => configureDependencies('demo'));
    tearDown(() async {
      // Restore the fake's defaults before the container reset rebuilds it.
      fakeCapture().reset();
      await getIt.reset();
    });

    testWidgets('1. Home scan CTA → ready camera → photo shutter → analyzing '
        '→ back returns to a ready camera', (tester) async {
      await pumpApp(tester);
      await goHomeAsGuest(tester);
      await openCamera(tester);
      expectCameraReady(tester);

      await tapKey(tester, 'camera-shutter');
      expectOnAnalyzing(tester);

      // Back from review unwinds analyzing too (its auto-pop completes the
      // camera's push-future) and re-acquires the camera into ready.
      await tester.tap(
        find.descendant(
          of: find.byType(PlaceholderPage),
          matching: find.byIcon(Icons.arrow_back),
        ),
      );
      await tester.pumpAndSettle();
      expectCameraReady(tester);
      check(tester.takeException()).isNull();
    });

    testWidgets('2. video mode burst → analyzing', (tester) async {
      await pumpApp(tester);
      await goHomeAsGuest(tester);
      await openCamera(tester);

      await tapKey(tester, 'camera-mode-video');
      await tapKey(tester, 'camera-shutter');

      expectOnAnalyzing(tester);
      check(tester.takeException()).isNull();
    });

    testWidgets('3. gallery import → analyzing', (tester) async {
      await pumpApp(tester);
      await goHomeAsGuest(tester);
      await openCamera(tester);

      await tapKey(tester, 'camera-gallery');

      expectOnAnalyzing(tester);
      check(tester.takeException()).isNull();
    });

    testWidgets('4. camera denied: rationale + retry visible; the gallery '
        'fallback still reaches analyzing', (tester) async {
      await pumpApp(tester);
      fakeCapture().mode = FakeCaptureMode.cameraDenied;
      await goHomeAsGuest(tester);
      await openCamera(tester);

      final retry = find.byKey(const ValueKey('camera-permission-retry'));
      check(retry.evaluate()).length.equals(1);
      check(
        find.byKey(const ValueKey('camera-shutter')).evaluate(),
      ).isEmpty();

      // Retrying while still denied keeps the rationale on screen.
      await tapKey(tester, 'camera-permission-retry');
      check(retry.evaluate()).length.equals(1);

      // The gallery escape works even while the camera is blocked.
      await tapKey(tester, 'camera-gallery-fallback');
      expectOnAnalyzing(tester);
      check(tester.takeException()).isNull();
    });

    testWidgets('5. camera permanently denied: Open Settings reaches the '
        'system settings (counted by the fake)', (tester) async {
      await pumpApp(tester);
      fakeCapture().mode = FakeCaptureMode.cameraPermanentlyDenied;
      await goHomeAsGuest(tester);
      await openCamera(tester);

      check(
        find.byKey(const ValueKey('camera-permission-retry')).evaluate(),
      ).isEmpty();
      await tapKey(tester, 'camera-open-settings');

      check(fakeCapture().openSystemSettingsCount).equals(1);
      check(tester.takeException()).isNull();
    });

    testWidgets('6. backgrounding mid-session parks the camera; resuming '
        'restores a ready camera without crashing', (tester) async {
      await pumpApp(tester);
      await goHomeAsGuest(tester);
      await openCamera(tester);
      expectCameraReady(tester);
      final bloc = BlocProvider.of<CameraBloc>(
        tester.element(find.byType(CameraView)),
      );

      // Walk the OS's legal background chain (AppLifecycleListener asserts
      // on skipped transitions). While hidden/paused the engine produces no
      // frames, so do NOT pump here — pumpAndSettle would hang forever on a
      // real device. The paused-side effects are asserted on the fake and
      // the bloc directly.
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await waitForCondition(() => !fakeCapture().isInitialized);
      // Parked: the camera is released and the session suspended.
      check(fakeCapture().isInitialized).isFalse();
      check(bloc.state).isA<CameraSuspended>();

      // Resuming (the legal chain back) re-enables frames; only now is
      // pumping safe again.
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expectCameraReady(tester);
      check(fakeCapture().isInitialized).isTrue();
      check(tester.takeException()).isNull();
    });

    testWidgets('7. no camera: unavailable view (no shutter, no retry, no '
        'settings); the gallery fallback still reaches analyzing', (
      tester,
    ) async {
      await pumpApp(tester);
      fakeCapture().mode = FakeCaptureMode.noCamera;
      await goHomeAsGuest(tester);
      await openCamera(tester);

      // The no-camera view offers exactly one escape: the gallery.
      check(
        find.byKey(const ValueKey('camera-shutter')).evaluate(),
      ).isEmpty();
      check(
        find.byKey(const ValueKey('camera-permission-retry')).evaluate(),
      ).isEmpty();
      check(
        find.byKey(const ValueKey('camera-open-settings')).evaluate(),
      ).isEmpty();

      await tapKey(tester, 'camera-gallery-fallback');
      expectOnAnalyzing(tester);
      check(tester.takeException()).isNull();
    });

    testWidgets('8. gallery denied: rationale + retry visible; retrying while '
        'denied stays; retrying after the grant reaches analyzing', (
      tester,
    ) async {
      await pumpApp(tester);
      fakeCapture().mode = FakeCaptureMode.galleryDenied;
      await goHomeAsGuest(tester);
      await openCamera(tester);
      expectCameraReady(tester);

      await tapKey(tester, 'camera-gallery');

      final retry = find.byKey(const ValueKey('camera-permission-retry'));
      check(retry.evaluate()).length.equals(1);
      check(
        find.byKey(const ValueKey('camera-shutter')).evaluate(),
      ).isEmpty();

      // Retrying while still denied re-dispatches the pick and keeps the
      // rationale on screen.
      await tapKey(tester, 'camera-permission-retry');
      check(retry.evaluate()).length.equals(1);

      // Once granted (the user answered the system dialog), the same retry
      // picks an image and hands off to analyzing.
      fakeCapture().mode = FakeCaptureMode.ready;
      await tapKey(tester, 'camera-permission-retry');
      expectOnAnalyzing(tester);
      check(tester.takeException()).isNull();
    });

    testWidgets('9. gallery permanently denied: Open Settings reaches the '
        'system settings (counted by the fake)', (tester) async {
      await pumpApp(tester);
      fakeCapture().mode = FakeCaptureMode.galleryPermanentlyDenied;
      await goHomeAsGuest(tester);
      await openCamera(tester);

      await tapKey(tester, 'camera-gallery');

      check(
        find.byKey(const ValueKey('camera-permission-retry')).evaluate(),
      ).isEmpty();
      await tapKey(tester, 'camera-open-settings');

      check(fakeCapture().openSystemSettingsCount).equals(1);
      check(tester.takeException()).isNull();
    });

    testWidgets('10. capture error: SnackBar failure, camera back to ready; '
        'the very next shutter succeeds (one-shot failure)', (tester) async {
      await pumpApp(tester);
      fakeCapture().mode = FakeCaptureMode.captureError;
      await goHomeAsGuest(tester);
      await openCamera(tester);
      expectCameraReady(tester);

      await tapKey(tester, 'camera-shutter');

      // The one-shot failure surfaces as a SnackBar over a ready camera.
      final l10n = tester.element(find.byType(CameraView)).l10n;
      check(
        find
            .descendant(
              of: find.byType(SnackBar),
              matching: find.text(l10n.cameraCaptureFailed),
            )
            .evaluate(),
      ).length.equals(1);
      expectCameraReady(tester);
      check(find.byType(PlaceholderPage).evaluate()).isEmpty();

      // Dismiss the toast so it cannot intercept the next shutter tap.
      ScaffoldMessenger.of(
        tester.element(find.byType(CameraView)),
      ).hideCurrentSnackBar();
      await tester.pumpAndSettle();
      check(find.byType(SnackBar).evaluate()).isEmpty();

      // One-shot: with the fault cleared, the same shutter succeeds.
      fakeCapture().mode = FakeCaptureMode.ready;
      await tapKey(tester, 'camera-shutter');
      expectOnAnalyzing(tester);
      check(tester.takeException()).isNull();
    });

    testWidgets('11. gallery cancelled: silently restores the ready camera '
        '(no error UI, still on the capture screen)', (tester) async {
      await pumpApp(tester);
      fakeCapture().mode = FakeCaptureMode.galleryCancelled;
      await goHomeAsGuest(tester);
      await openCamera(tester);
      expectCameraReady(tester);

      await tapKey(tester, 'camera-gallery');

      // Silent restore: ready camera, no toast, no rationale, no navigation.
      check(find.byType(CameraView).evaluate()).length.equals(1);
      expectCameraReady(tester);
      check(find.byType(SnackBar).evaluate()).isEmpty();
      check(
        find.byKey(const ValueKey('camera-permission-retry')).evaluate(),
      ).isEmpty();
      check(find.byType(PlaceholderPage).evaluate()).isEmpty();
      check(tester.takeException()).isNull();
    });
  });
}
