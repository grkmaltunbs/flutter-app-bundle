import 'package:checks/checks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:okey_acar_mi/app.dart';
import 'package:okey_acar_mi/core/di/injection.dart';
import 'package:okey_acar_mi/core/extensions/context_extensions.dart';
import 'package:okey_acar_mi/core/game/indicator.dart';
import 'package:okey_acar_mi/core/game/tile_color.dart';
import 'package:okey_acar_mi/core/widgets/app_buttons.dart';
import 'package:okey_acar_mi/core/widgets/placeholder_page.dart';
import 'package:okey_acar_mi/core/widgets/tile_slot.dart';
import 'package:okey_acar_mi/features/capture/data/fakes/fake_capture_service.dart';
import 'package:okey_acar_mi/features/capture/presentation/pages/camera_page.dart';
import 'package:okey_acar_mi/features/detection/data/fakes/fake_tile_detector.dart';
import 'package:okey_acar_mi/features/detection/presentation/pages/analyzing_page.dart';
import 'package:okey_acar_mi/features/home/presentation/pages/home_page.dart';
import 'package:okey_acar_mi/features/review/domain/entities/review_tile.dart';
import 'package:okey_acar_mi/features/review/presentation/blocs/review_bloc.dart';
import 'package:okey_acar_mi/features/review/presentation/pages/review_page.dart';
import 'package:okey_acar_mi/features/review/presentation/widgets/review_rack.dart';
import 'package:okey_acar_mi/features/review/presentation/widgets/tile_edit_panel.dart';
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

/// Detection finished and auto-advanced: the real review screen sits on top
/// while the analyzing page stays alive beneath it (its auto-pop fires only
/// when review pops, keeping the camera's push-future pending).
void expectLandedOnReview(WidgetTester tester) {
  check(
    find.byType(AnalyzingPage, skipOffstage: false).evaluate(),
  ).length.equals(1);
  check(find.byType(ReviewPage).evaluate()).length.equals(1);
}

/// Home → camera → photo shutter → review, on the current fake modes.
Future<void> captureToReview(WidgetTester tester) async {
  await goHomeAsGuest(tester);
  await openCamera(tester);
  await tapKey(tester, 'camera-shutter');
  expectLandedOnReview(tester);
}

/// The active review l10n (locale-safe text assertions).
AppLocalizations reviewL10n(WidgetTester tester) =>
    tester.element(find.byType(ReviewView)).l10n;

/// The screen-scoped review bloc (state assertions on the editable rack).
ReviewBloc reviewBloc(WidgetTester tester) =>
    BlocProvider.of<ReviewBloc>(tester.element(find.byType(ReviewView)));

/// The tappable rack cells in rack order (the only InkWells inside
/// [ReviewRack]); the seed order is deterministic, so indices are stable.
Finder rackCell(int index) => find
    .descendant(of: find.byType(ReviewRack), matching: find.byType(InkWell))
    .at(index);

Future<void> tapRackCell(WidgetTester tester, int index) async {
  await tester.ensureVisible(rackCell(index));
  await tester.pumpAndSettle();
  await tester.tap(rackCell(index));
  await tester.pumpAndSettle();
}

Finder inPanel(Finder matching) =>
    find.descendant(of: find.byType(TileEditPanel), matching: matching);

/// Taps a color circle in the edit panel. InkWell order inside the panel:
/// 0 = close, then the colors red(1) / black(2) / yellow(3) / blue(4) /
/// joker(5), then the 13 numerals, then the remove action.
Future<void> tapPanelColor(WidgetTester tester, int colorIndex) async {
  final target = inPanel(find.byType(InkWell)).at(1 + colorIndex);
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

/// Taps a numeral chip in the edit panel (numeral text is unique within it).
Future<void> tapPanelNumber(WidgetTester tester, int number) async {
  final target = inPanel(find.text('$number'));
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Future<void> closePanel(WidgetTester tester) async {
  final target = inPanel(find.byIcon(Icons.close));
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
  check(find.byType(TileEditPanel).evaluate()).isEmpty();
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

bool calculateEnabled(WidgetTester tester) =>
    tester
        .widget<PrimaryButton>(find.byKey(const ValueKey('review-calculate')))
        .onPressed !=
    null;

void expectOnResultPlaceholder(WidgetTester tester) {
  final page = tester.widget<PlaceholderPage>(find.byType(PlaceholderPage));
  check(page.screen).equals(PlaceholderScreen.result);
}

// ---------------------------------------------------------------------------
// Scenarios
// ---------------------------------------------------------------------------

/// End-to-end review & indicator flows on the demo flavor (no hardware, no
/// screenshots). Run with:
///
/// ```bash
/// flutter test integration_test/review_flow_test.dart \
///   --dart-define=APP_ENV=demo -d <device>
/// ```
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Review flows end-to-end (demo flavor)', () {
    setUp(() async => configureDependencies('demo'));
    tearDown(() async {
      // Restore the fakes' defaults before the container reset rebuilds them.
      fakeCapture().reset();
      fakeDetector().reset();
      await getIt.reset();
    });

    testWidgets('1. happy 101 review: fix a low-confidence tile, remove and '
        're-add a tile, pick indicator 13 (okey wraps to 1), calculate lands '
        'on /result, and back returns to the live review', (tester) async {
      await pumpApp(tester);
      await captureToReview(tester);

      final l10n = reviewL10n(tester);
      final bloc = reviewBloc(tester);

      // The seeded 101 rack: 21 tiles, two flagged low-confidence.
      check(bloc.state.tileCount).equals(21);
      check(
        find.text(l10n.reviewCount(21, 20, 21)).evaluate(),
      ).length.equals(1);
      check(
        find.text(l10n.reviewLowConfidenceLegend).evaluate(),
      ).length.equals(1);

      // Fix the low-confidence yellow 5 (seed index 9): confirm its numeral.
      await tapRackCell(tester, 9);
      check(find.byType(TileEditPanel).evaluate()).length.equals(1);
      await tapPanelNumber(tester, 5);
      check(bloc.state.tiles[9]).equals(
        const ReviewTile(color: TileColor.yellow, number: 5),
      );

      // Remove the last tile (21 → 20) through its editor.
      await tapRackCell(tester, 20);
      await tapKey(tester, 'review-remove-tile');
      check(bloc.state.tileCount).equals(20);
      check(find.byType(TileEditPanel).evaluate()).isEmpty();
      check(
        find.text(l10n.reviewCount(20, 20, 21)).evaluate(),
      ).length.equals(1);

      // Add one back: a dashed slot appears with its editor open; define it.
      await tapKey(tester, 'review-add-tile');
      check(find.byType(TileSlot).evaluate()).length.equals(1);
      check(find.byType(TileEditPanel).evaluate()).length.equals(1);
      await tapPanelColor(tester, 0); // red
      await tapPanelNumber(tester, 9);
      check(bloc.state.tiles[20]).equals(
        const ReviewTile(color: TileColor.red, number: 9),
      );
      check(find.byType(TileSlot).evaluate()).isEmpty();
      await closePanel(tester);

      // Everything is complete — only the indicator still blocks.
      check(find.text(l10n.reviewBlockerIndicator).evaluate()).length.equals(1);
      check(calculateEnabled(tester)).isFalse();

      // Indicator yellow 13 → the okey wraps to yellow 1.
      await pickIndicator(tester, colorIndex: 2, number: 13);
      check(bloc.state.indicator).equals(
        const Indicator(color: TileColor.yellow, number: 13),
      );
      check(
        find.text(l10n.reviewOkeyLabel(l10n.tileColorYellow, 1)).evaluate(),
      ).length.equals(1);
      check(calculateEnabled(tester)).isTrue();

      // Calculate → the /result placeholder (Step 8 owns the real screen).
      await tapKey(tester, 'review-calculate');
      expectOnResultPlaceholder(tester);

      // Back from result returns to the live review, edits intact.
      await tester.tap(
        find.descendant(
          of: find.byType(PlaceholderPage),
          matching: find.byIcon(Icons.arrow_back),
        ),
      );
      await tester.pumpAndSettle();
      check(find.byType(ReviewView).evaluate()).length.equals(1);
      check(
        find.text(l10n.reviewOkeyLabel(l10n.tileColorYellow, 1)).evaluate(),
      ).length.equals(1);
      check(tester.takeException()).isNull();
    });

    testWidgets('2. wrong-count seed: the warning is shown and calculate is '
        'blocked; adding + defining the missing tile and picking the '
        'indicator unblocks it', (tester) async {
      await pumpApp(tester);
      fakeDetector().mode = FakeDetectionMode.wrongCount;
      await captureToReview(tester);

      final l10n = reviewL10n(tester);
      final bloc = reviewBloc(tester);

      // 19 tiles: too few for 101 — warning + count blocker, no calculate.
      check(bloc.state.tileCount).equals(19);
      check(
        find.text(l10n.reviewWrongCountFew(20)).evaluate(),
      ).length.equals(1);
      check(find.text(l10n.reviewBlockerCount).evaluate()).length.equals(1);
      check(calculateEnabled(tester)).isFalse();

      // Add the missing tile: the warning clears, the blocker moves on to
      // the still-undefined placeholder.
      await tapKey(tester, 'review-add-tile');
      check(find.text(l10n.reviewWrongCountFew(20)).evaluate()).isEmpty();
      check(
        find.text(l10n.reviewBlockerIncomplete).evaluate(),
      ).length.equals(1);
      check(calculateEnabled(tester)).isFalse();

      // Define it (blue 6); the blocker moves on to the indicator.
      await tapPanelColor(tester, 3); // blue
      await tapPanelNumber(tester, 6);
      check(bloc.state.tiles[19]).equals(
        const ReviewTile(color: TileColor.blue, number: 6),
      );
      check(find.text(l10n.reviewBlockerIndicator).evaluate()).length.equals(1);

      // Red 5 → okey red 6 (the non-wrap case); calculate unblocks.
      await pickIndicator(tester, colorIndex: 0, number: 5);
      check(
        find.text(l10n.reviewOkeyLabel(l10n.tileColorRed, 6)).evaluate(),
      ).length.equals(1);
      check(calculateEnabled(tester)).isTrue();

      await tapKey(tester, 'review-calculate');
      expectOnResultPlaceholder(tester);
      check(tester.takeException()).isNull();
    });

    testWidgets('3. low-confidence seed: the retake banner is shown and '
        'Retake unwinds review + analyzing back to a ready camera', (
      tester,
    ) async {
      await pumpApp(tester);
      fakeDetector().mode = FakeDetectionMode.lowConfidence;
      await captureToReview(tester);

      final l10n = reviewL10n(tester);
      check(find.text(l10n.reviewLowOverallBanner).evaluate()).length.equals(1);
      check(
        find.text(l10n.reviewLowConfidenceLegend).evaluate(),
      ).length.equals(1);

      await tapKey(tester, 'review-retake');
      expectCameraReady(tester);
      check(find.byType(ReviewPage).evaluate()).isEmpty();
      check(
        find.byType(AnalyzingPage, skipOffstage: false).evaluate(),
      ).isEmpty();
      check(tester.takeException()).isNull();
    });

    testWidgets('4. back from review pops to a ready camera (the analyzing '
        'page auto-pops with it)', (tester) async {
      await pumpApp(tester);
      await captureToReview(tester);

      await tapKey(tester, 'review-back');
      expectCameraReady(tester);
      check(find.byType(ReviewPage).evaluate()).isEmpty();
      check(
        find.byType(AnalyzingPage, skipOffstage: false).evaluate(),
      ).isEmpty();
      check(fakeCapture().isInitialized).isTrue();
      check(tester.takeException()).isNull();
    });
  });
}
