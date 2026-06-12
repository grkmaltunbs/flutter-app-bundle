import 'package:checks/checks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:okey_acar_mi/app.dart';
import 'package:okey_acar_mi/core/di/injection.dart';
import 'package:okey_acar_mi/core/extensions/context_extensions.dart';
import 'package:okey_acar_mi/features/capture/data/fakes/fake_capture_service.dart';
import 'package:okey_acar_mi/features/capture/presentation/pages/camera_page.dart';
import 'package:okey_acar_mi/features/detection/data/fakes/fake_tile_detector.dart';
import 'package:okey_acar_mi/features/home/presentation/pages/home_page.dart';
import 'package:okey_acar_mi/features/result/presentation/pages/result_page.dart';
import 'package:okey_acar_mi/features/review/presentation/pages/review_page.dart';
import 'package:okey_acar_mi/features/settings/presentation/pages/settings_page.dart';
import 'package:okey_acar_mi/l10n/app_localizations.dart';

// ---------------------------------------------------------------------------
// Robot helpers
// ---------------------------------------------------------------------------

/// The demo fake driving capture (registered as itself in demo).
FakeCaptureService fakeCapture() => getIt<FakeCaptureService>();

/// The demo fake driving detection (registered as itself in demo).
FakeTileDetector fakeDetector() => getIt<FakeTileDetector>();

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

/// Splash → guest entry → Home.
Future<void> goHomeAsGuest(WidgetTester tester) async {
  await tapKey(tester, 'splash-guest');
  check(find.byType(HomePage).evaluate()).length.equals(1);
}

/// Taps the Home scan CTA and lands on the capture screen.
Future<void> openCamera(WidgetTester tester) async {
  final cta = find.byIcon(Icons.photo_camera_outlined);
  await tester.ensureVisible(cta);
  await tester.pumpAndSettle();
  await tester.tap(cta);
  await tester.pumpAndSettle();
  check(find.byType(CameraView).evaluate()).length.equals(1);
}

/// The live capture chrome: shutter visible and ready.
void expectCameraReady(WidgetTester tester) {
  check(
    find.byKey(const ValueKey('camera-shutter')).evaluate(),
  ).length.equals(1);
}

/// Camera → photo shutter → the review screen, on the current fake modes.
Future<void> captureToReview(WidgetTester tester) async {
  await openCamera(tester);
  await tapKey(tester, 'camera-shutter');
  check(find.byType(ReviewPage).evaluate()).length.equals(1);
}

/// Opens the indicator sheet and confirms a pick. Sheet InkWell order:
/// the colors red(0) / black(1) / yellow(2) / blue(3) — never the joker —
/// then the 13 numerals, then the confirm button.
Future<void> pickIndicator(
  WidgetTester tester, {
  required int colorIndex,
  required int number,
}) async {
  await tapKey(tester, 'review-pick-indicator');
  final sheet = find.byKey(const ValueKey('indicator-sheet'));
  check(sheet.evaluate()).length.equals(1);

  await tester.tap(
    find.descendant(of: sheet, matching: find.byType(InkWell)).at(colorIndex),
  );
  await tester.pumpAndSettle();
  final numberChip = find.descendant(of: sheet, matching: find.text('$number'));
  await tester.ensureVisible(numberChip);
  await tester.pumpAndSettle();
  await tester.tap(numberChip);
  await tester.pumpAndSettle();
  await tapKey(tester, 'indicator-confirm');
  check(sheet.evaluate()).isEmpty();
}

/// Review → indicator pick → Hesapla → the real result screen. The solve
/// resolves inside the closing `pumpAndSettle`, so the verdict is already
/// rendered when this returns.
Future<void> calculateToResult(
  WidgetTester tester, {
  required int colorIndex,
  required int number,
}) async {
  await pickIndicator(tester, colorIndex: colorIndex, number: number);
  await tapKey(tester, 'review-calculate');
  check(find.byType(ResultView).evaluate()).length.equals(1);
}

/// The active result l10n (locale-safe text assertions).
AppLocalizations resultL10n(WidgetTester tester) =>
    tester.element(find.byType(ResultView)).l10n;

// ---------------------------------------------------------------------------
// Scenarios
// ---------------------------------------------------------------------------

/// End-to-end result flows on the demo flavor (no hardware, no
/// screenshots). Run with:
///
/// ```bash
/// flutter test integration_test/result_flow_test.dart \
///   --dart-define=APP_ENV=demo -d <device>
/// ```
///
/// The solver-failure → retry path is covered at the widget level only
/// (`test/features/result/presentation/pages/result_page_test.dart`): the
/// solve engine is pure Dart with no fake seam, so it cannot be made to
/// fail through the demo fakes.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Result flows end-to-end (demo flavor)', () {
    setUp(() async => configureDependencies('demo'));
    tearDown(() async {
      // Restore the fakes' defaults before the container reset rebuilds them.
      fakeCapture().reset();
      fakeDetector().reset();
      await getIt.reset();
    });

    testWidgets('1. happy 101: calculate lands on the verdict with the '
        'arrangement legend and footer; unlocking reveals the reasoning; '
        'the list layout toggles; Tekrar re-scans and Bitir finishes home', (
      tester,
    ) async {
      await pumpApp(tester);
      await goHomeAsGuest(tester);
      await captureToReview(tester);

      // Indicator yellow 13 (okey wraps to yellow 1) → calculate. The
      // seeded 21-tile rack melds well past 101, so the verdict opens.
      await calculateToResult(tester, colorIndex: 2, number: 13);
      final l10n = resultL10n(tester);
      check(find.text(l10n.resultOpensVerdict).evaluate()).length.equals(1);
      check(find.text(l10n.resultOpensEyebrow).evaluate()).length.equals(1);
      check(find.text(l10n.resultClosesVerdict).evaluate()).isEmpty();
      check(find.text(l10n.resultScoreOutOf).evaluate()).length.equals(1);
      // The arranged rack with its legend, and the pinned footer.
      check(find.text(l10n.resultBestArrangement).evaluate()).length.equals(1);
      check(
        find.byKey(const ValueKey('result-again')).evaluate(),
      ).length.equals(1);
      check(
        find.byKey(const ValueKey('result-done')).evaluate(),
      ).length.equals(1);

      // The reasoning is locked behind the unlock CTA stub; tapping it
      // reveals the numbered steps.
      check(find.text(l10n.resultWhyThis).evaluate()).isEmpty();
      await tapKey(tester, 'result-detail-unlock');
      check(find.text(l10n.resultWhyThis).evaluate()).length.equals(1);
      check(
        find.byKey(const ValueKey('result-detail-unlock')).evaluate(),
      ).isEmpty();

      // Rack ⇄ list layout toggle.
      await tapKey(tester, 'result-layout-list');
      check(find.text(l10n.resultGroups).evaluate()).length.equals(1);
      await tapKey(tester, 'result-layout-rack');
      check(find.text(l10n.resultBestArrangement).evaluate()).length.equals(1);

      // "Tekrar" starts a new scan: back to a ready camera.
      await tapKey(tester, 'result-again');
      expectCameraReady(tester);
      check(find.byType(ResultView).evaluate()).isEmpty();

      // Redo the flow (red 5 → okey red 6) and finish with "Bitir".
      await tapKey(tester, 'camera-shutter');
      check(find.byType(ReviewPage).evaluate()).length.equals(1);
      await calculateToResult(tester, colorIndex: 0, number: 5);
      check(find.text(l10n.resultOpensVerdict).evaluate()).length.equals(1);

      await tapKey(tester, 'result-done');
      check(find.byType(HomePage).evaluate()).length.equals(1);
      check(find.byType(ResultView).evaluate()).isEmpty();
      check(tester.takeException()).isNull();
    });

    testWidgets('2. okey mode: switching the default mode and scanning the '
        'okey rack shows tiles-to-win — never Açar/Açmaz — and Bitir '
        'returns home', (tester) async {
      await pumpApp(tester);
      await goHomeAsGuest(tester);

      // Settings → default game mode Okey → back to the Home tab.
      await tapKey(tester, 'app-nav-2');
      check(find.byType(SettingsPage).evaluate()).length.equals(1);
      await tapKey(tester, 'settings-mode-okey');
      await tapKey(tester, 'app-nav-0');
      check(find.byType(HomePage).evaluate()).length.equals(1);

      // Capture the seeded 14-tile okey rack fixture.
      fakeCapture().fixture = FakeCaptureService.rackOkeyFixture;
      await captureToReview(tester);

      // Indicator yellow 9 → okey yellow 10 (not on the rack); calculate.
      await calculateToResult(tester, colorIndex: 2, number: 9);
      final l10n = resultL10n(tester);

      // Okey mode answers tiles-to-win; the 101 verdict words never appear.
      check(
        find.text(l10n.resultOkeyTilesToWinLabel).evaluate(),
      ).length.equals(1);
      check(find.text(l10n.resultOkeyEyebrow).evaluate()).length.equals(1);
      check(find.text(l10n.resultOpensVerdict).evaluate()).isEmpty();
      check(find.text(l10n.resultClosesVerdict).evaluate()).isEmpty();
      check(find.text(l10n.resultScoreOutOf).evaluate()).isEmpty();
      check(find.text(l10n.resultBestArrangement).evaluate()).length.equals(1);

      await tapKey(tester, 'result-done');
      check(find.byType(HomePage).evaluate()).length.equals(1);
      check(tester.takeException()).isNull();
    });
  });
}
