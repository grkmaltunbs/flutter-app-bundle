import 'package:checks/checks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:okey_acar_mi/app.dart';
import 'package:okey_acar_mi/core/di/injection.dart';
import 'package:okey_acar_mi/core/extensions/context_extensions.dart';
import 'package:okey_acar_mi/core/game/tile_color.dart';
import 'package:okey_acar_mi/core/widgets/placeholder_page.dart';
import 'package:okey_acar_mi/features/capture/data/fakes/fake_capture_service.dart';
import 'package:okey_acar_mi/features/capture/presentation/pages/camera_page.dart';
import 'package:okey_acar_mi/features/detection/data/fakes/fake_tile_detector.dart';
import 'package:okey_acar_mi/features/detection/domain/entities/detected_tile.dart';
import 'package:okey_acar_mi/features/detection/presentation/pages/analyzing_page.dart';
import 'package:okey_acar_mi/features/home/presentation/pages/home_page.dart';

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

/// Awaits [condition] with real async waits — **no frame pumping** (safe
/// while frames are not being produced; the caller's `check` fails loudly on
/// timeout).
Future<void> waitForCondition(
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 5),
}) async {
  final stopwatch = Stopwatch()..start();
  while (!condition() && stopwatch.elapsed < timeout) {
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
}

/// Pumps frames until [finder] matches (bounded poll on a real async
/// boundary). Used instead of `pumpAndSettle` while the analyzing screen's
/// scan line animates forever — settling is impossible mid-detection.
Future<void> pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 10),
}) async {
  final stopwatch = Stopwatch()..start();
  while (finder.evaluate().isEmpty && stopwatch.elapsed < timeout) {
    await tester.pump(const Duration(milliseconds: 100));
  }
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

/// Detection finished and auto-advanced: the review placeholder sits on top
/// while the analyzing page stays alive beneath it (its auto-pop fires only
/// when review pops, keeping the camera's push-future pending).
void expectLandedOnReview(WidgetTester tester) {
  check(
    find.byType(AnalyzingPage, skipOffstage: false).evaluate(),
  ).length.equals(1);
  final page = tester.widget<PlaceholderPage>(find.byType(PlaceholderPage));
  check(page.screen).equals(PlaceholderScreen.review);
}

/// The analyzing failure view is on screen with the given escape keys.
void expectFailureEscapes(
  WidgetTester tester, {
  required List<String> present,
  required List<String> absent,
}) {
  for (final key in present) {
    check(
      because: '$key must be offered',
      find.byKey(ValueKey(key)).evaluate(),
    ).length.equals(1);
  }
  for (final key in absent) {
    check(
      because: '$key must not be offered',
      find.byKey(ValueKey(key)).evaluate(),
    ).isEmpty();
  }
}

// ---------------------------------------------------------------------------
// Scenarios
// ---------------------------------------------------------------------------

/// End-to-end detection flows on the demo flavor (no hardware, no
/// screenshots). Run with:
///
/// ```bash
/// flutter test integration_test/detection_flow_test.dart \
///   --dart-define=APP_ENV=demo -d <device>
/// ```
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Detection flows end-to-end (demo flavor)', () {
    setUp(() async => configureDependencies('demo'));
    tearDown(() async {
      // Restore the fakes' defaults before the container reset rebuilds them.
      fakeCapture().reset();
      fakeDetector().reset();
      await getIt.reset();
    });

    testWidgets('1. happy still: capture → analyzing reveal → review; the '
        'recorded result is the legal 21-tile 101 rack with confidences', (
      tester,
    ) async {
      await pumpApp(tester);
      await goHomeAsGuest(tester);
      await openCamera(tester);

      await tapKey(tester, 'camera-shutter');
      expectLandedOnReview(tester);

      final result = fakeDetector().lastResult;
      check(result).isNotNull();
      final tiles = result!.tiles;
      check(tiles.length).equals(21);
      check(result.frameCount).equals(1);
      check(
        tiles
            .where((t) => t.color == TileColor.joker && t.number == null)
            .length,
      ).equals(1);
      for (final tile in tiles) {
        check(
          because: 'every tile carries a usable confidence',
          tile.confidence,
        ).isGreaterThan(0);
        check(tile.confidence).isLessOrEqual(1);
      }
      check(result.overallConfidence).isGreaterThan(0);
      check(result.overallConfidence).isLessOrEqual(1);
      check(tester.takeException()).isNull();
    });

    testWidgets('2. video burst: multi-frame aggregation lands on review '
        'with frameCount > 1 and the disagreeing positions flagged '
        'low-confidence', (tester) async {
      await pumpApp(tester);
      await goHomeAsGuest(tester);
      await openCamera(tester);

      await tapKey(tester, 'camera-mode-video');
      await tapKey(tester, 'camera-shutter');
      expectLandedOnReview(tester);

      final result = fakeDetector().lastResult;
      check(result).isNotNull();
      check(result!.frameCount).isGreaterThan(1);

      DetectedTile at(int row, int index) => result.tiles.singleWhere(
        (t) => t.position == TilePosition(row: row, index: index),
      );
      check(
        because: 'frames disagreed at row 0 index 3',
        at(0, 3).confidence,
      ).isLessThan(kLowConfidenceThreshold);
      check(
        because: 'frames disagreed at row 1 index 9',
        at(1, 9).confidence,
      ).isLessThan(kLowConfidenceThreshold);
      check(tester.takeException()).isNull();
    });

    testWidgets('3. no tiles found: failure view with tips; Retake returns '
        'to a ready camera and the next capture reaches review', (
      tester,
    ) async {
      await pumpApp(tester);
      fakeDetector().mode = FakeDetectionMode.noTiles;
      await goHomeAsGuest(tester);
      await openCamera(tester);

      await tapKey(tester, 'camera-shutter');

      // The no-tiles failure: tips + Retake (primary) + Try again, no Back.
      final l10n = tester.element(find.byType(AnalyzingView)).l10n;
      check(
        find.text(l10n.analyzingNoTilesTitle).evaluate(),
      ).length.equals(1);
      check(find.text(l10n.analyzingNoTilesBody).evaluate()).length.equals(1);
      expectFailureEscapes(
        tester,
        present: const ['analyzing-retake', 'analyzing-retry'],
        absent: const ['analyzing-back'],
      );
      check(find.byType(PlaceholderPage).evaluate()).isEmpty();

      // Retake pops back to the camera, which re-acquires into ready.
      await tapKey(tester, 'analyzing-retake');
      expectCameraReady(tester);

      // With the fault cleared, the same shutter reaches review.
      fakeDetector().mode = FakeDetectionMode.fromFixture;
      await tapKey(tester, 'camera-shutter');
      expectLandedOnReview(tester);
      check(tester.takeException()).isNull();
    });

    testWidgets('4. detection error: failure view with Try again; the retry '
        'after the fault clears reaches review without leaving the screen', (
      tester,
    ) async {
      await pumpApp(tester);
      fakeDetector().mode = FakeDetectionMode.error;
      await goHomeAsGuest(tester);
      await openCamera(tester);

      await tapKey(tester, 'camera-shutter');

      final l10n = tester.element(find.byType(AnalyzingView)).l10n;
      check(find.text(l10n.analyzingErrorTitle).evaluate()).length.equals(1);
      expectFailureEscapes(
        tester,
        present: const ['analyzing-retry', 'analyzing-back'],
        absent: const ['analyzing-retake'],
      );

      // The user fixed nothing — but the pipeline fault was transient.
      fakeDetector().mode = FakeDetectionMode.fromFixture;
      await tapKey(tester, 'analyzing-retry');
      expectLandedOnReview(tester);
      check(tester.takeException()).isNull();
    });

    testWidgets('5. cancelling mid-analysis aborts the run and returns to a '
        'ready camera with no errors', (tester) async {
      await pumpApp(tester);
      // Pin the run in flight: the worker stalls before its first tile
      // reveal, so the cancel always lands mid-detection.
      fakeDetector().revealPause = const Duration(minutes: 1);
      await goHomeAsGuest(tester);
      await openCamera(tester);

      // The scan line animates forever while processing, so settling is
      // impossible — drive the navigation with bounded pump polls instead.
      await tester.tap(find.byKey(const ValueKey('camera-shutter')));
      await pumpUntilFound(
        tester,
        find.byKey(const ValueKey('analyzing-cancel')),
      );
      check(
        find.byKey(const ValueKey('analyzing-cancel')).evaluate(),
      ).length.equals(1);
      check(fakeDetector().lastResult).isNull();

      // Back = cancel: disposes the bloc, cancels the run, kills the worker.
      await tester.tap(find.byKey(const ValueKey('analyzing-cancel')));
      await pumpUntilFound(
        tester,
        find.byKey(const ValueKey('camera-shutter')),
      );
      await waitForCondition(() => fakeCapture().isInitialized);
      await tester.pumpAndSettle();

      expectCameraReady(tester);
      check(
        find.byType(AnalyzingPage, skipOffstage: false).evaluate(),
      ).isEmpty();
      // The aborted run never completed — nothing was recorded.
      check(fakeDetector().lastResult).isNull();
      check(tester.takeException()).isNull();
    });

    testWidgets('6. back from review auto-pops the analyzing page and '
        're-acquires the camera (the push/auto-pop chain)', (tester) async {
      await pumpApp(tester);
      await goHomeAsGuest(tester);
      await openCamera(tester);

      await tapKey(tester, 'camera-shutter');
      expectLandedOnReview(tester);

      // Popping review unwinds analyzing too; the camera's push-future
      // completes and its returnedFromCapture re-acquisition fires.
      await tester.tap(
        find.descendant(
          of: find.byType(PlaceholderPage),
          matching: find.byIcon(Icons.arrow_back),
        ),
      );
      await tester.pumpAndSettle();

      expectCameraReady(tester);
      check(
        find.byType(AnalyzingPage, skipOffstage: false).evaluate(),
      ).isEmpty();
      check(find.byType(PlaceholderPage).evaluate()).isEmpty();
      check(fakeCapture().isInitialized).isTrue();
      check(tester.takeException()).isNull();
    });
  });
}
