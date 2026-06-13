import 'package:checks/checks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:okey_acar_mi/app.dart';
import 'package:okey_acar_mi/core/db/app_database.dart';
import 'package:okey_acar_mi/core/di/injection.dart';
import 'package:okey_acar_mi/core/extensions/context_extensions.dart';
import 'package:okey_acar_mi/core/network/connectivity_service.dart';
import 'package:okey_acar_mi/features/auth/data/fakes/fake_auth_repository.dart';
import 'package:okey_acar_mi/features/auth/domain/repositories/auth_repository.dart';
import 'package:okey_acar_mi/features/auth/presentation/pages/login_page.dart';
import 'package:okey_acar_mi/features/capture/presentation/pages/camera_page.dart';
import 'package:okey_acar_mi/features/history/data/fakes/fake_scan_remote_data_source.dart';
import 'package:okey_acar_mi/features/history/presentation/pages/history_page.dart';
import 'package:okey_acar_mi/features/home/presentation/pages/home_page.dart';
import 'package:okey_acar_mi/features/result/presentation/pages/result_page.dart';
import 'package:okey_acar_mi/features/review/presentation/pages/review_page.dart';
import 'package:okey_acar_mi/features/settings/presentation/pages/settings_page.dart';
import 'package:okey_acar_mi/l10n/app_localizations.dart';

// ---------------------------------------------------------------------------
// Robot helpers
// ---------------------------------------------------------------------------

/// The demo fake behind the cloud scan store (registered as itself in demo).
FakeScanRemoteDataSource fakeRemote() => getIt<FakeScanRemoteDataSource>();

/// The demo fake behind connectivity.
FakeConnectivityService fakeConnectivity() =>
    getIt<ConnectivityService>() as FakeConnectivityService;

/// The demo fake behind auth (seeded `oyuncu@demo.app` / `okey1234`).
FakeAuthRepository fakeAuth() => getIt<AuthRepository>() as FakeAuthRepository;

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

Future<void> enterText(WidgetTester tester, String key, String text) async {
  final finder = find.byKey(ValueKey(key));
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.enterText(finder, text);
  await tester.pump();
}

/// Pumps real frames until [condition] holds, bounded by [timeout].
///
/// Drift writes run on a background isolate outside the frame scheduler, and
/// `syncNow` coalesces concurrent calls (a call during a running sync
/// returns immediately) — so a bare `pumpAndSettle` can return before the
/// persisted/pulled rows reach the UI. This awaits that real async boundary
/// through its visible outcome.
Future<void> pumpUntil(
  WidgetTester tester,
  bool Function() condition, {
  required String description,
  Duration timeout = const Duration(seconds: 10),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      fail('Timed out waiting for $description');
    }
    await tester.pump(const Duration(milliseconds: 100));
  }
  await tester.pumpAndSettle();
}

/// [pumpUntil] specialized to a [finder] matching at least one widget.
Future<void> pumpUntilFound(WidgetTester tester, Finder finder) => pumpUntil(
  tester,
  () => finder.evaluate().isNotEmpty,
  description: '$finder',
);

/// Splash → guest entry → Home.
Future<void> goHomeAsGuest(WidgetTester tester) async {
  await tapKey(tester, 'splash-guest');
  check(find.byType(HomePage).evaluate()).length.equals(1);
}

/// Seeded email sign-in from an open login screen → Home. The sign-in
/// awaits guest-data migration (drift, background isolate), so the landing
/// is awaited via [pumpUntilFound].
Future<void> submitSeededSignIn(WidgetTester tester) async {
  await enterText(tester, 'login-email', 'oyuncu@demo.app');
  await enterText(tester, 'login-password', 'okey1234');
  await tapKey(tester, 'login-submit');
  await pumpUntilFound(tester, find.byType(HomePage));
  check(find.byType(HomePage).evaluate()).length.equals(1);
}

/// Splash → "Devam et" → seeded email sign-in → the router redirect lands
/// Home.
Future<void> signInFromSplash(WidgetTester tester) async {
  await tapKey(tester, 'splash-continue');
  check(find.byType(LoginPage).evaluate()).length.equals(1);
  await submitSeededSignIn(tester);
}

/// Settings tab → sign-up CTA (pushes the login over the shell) → seeded
/// email sign-in → the LoginView auth listener lands Home (the refresh
/// redirect never sees imperatively pushed routes).
Future<void> signInFromSettings(WidgetTester tester) async {
  await tapKey(tester, 'app-nav-2');
  check(find.byType(SettingsPage).evaluate()).length.equals(1);
  // The settings list is lazy: scroll until the CTA is built and visible.
  final scrollable = find
      .descendant(
        of: find.byType(SettingsPage),
        matching: find.byType(Scrollable),
      )
      .first;
  final cta = find.byKey(const ValueKey('settings-signup'));
  await tester.scrollUntilVisible(cta, 120, scrollable: scrollable);
  await tester.pumpAndSettle();
  await tester.tap(cta);
  await tester.pumpAndSettle();
  check(find.byType(LoginPage).evaluate()).length.equals(1);
  await submitSeededSignIn(tester);
}

/// Home → scan CTA → camera → photo shutter → review (fake capture +
/// detection).
Future<void> captureToReview(WidgetTester tester) async {
  final cta = find.byIcon(Icons.photo_camera_outlined);
  await tester.ensureVisible(cta);
  await tester.pumpAndSettle();
  await tester.tap(cta);
  await tester.pumpAndSettle();
  check(find.byType(CameraView).evaluate()).length.equals(1);
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

/// The full core loop: Home → camera → review → indicator yellow 13 →
/// Hesapla → solved result (the auto-save lands with the verdict).
Future<void> runScanLoopToResult(WidgetTester tester) async {
  await captureToReview(tester);
  await pickIndicator(tester, colorIndex: 2, number: 13);
  await tapKey(tester, 'review-calculate');
  check(find.byType(ResultView).evaluate()).length.equals(1);
}

Future<void> openHistoryTab(WidgetTester tester) async {
  await tapKey(tester, 'app-nav-1');
  check(find.byType(HistoryPage).evaluate()).length.equals(1);
}

/// The active history l10n (locale-safe text assertions).
AppLocalizations historyL10n(WidgetTester tester) =>
    tester.element(find.byType(HistoryView)).l10n;

/// Every materialized scan card (built slivers only unless [offstage]).
Finder scanCards({bool offstage = false}) => find.byWidgetPredicate((widget) {
  final key = widget.key;
  return key is ValueKey<String> && key.value.startsWith('scan-card-');
}, skipOffstage: !offstage);

/// The text [value] inside the filter chip with [chipKey].
Finder chipCount(String chipKey, String value) => find.descendant(
  of: find.byKey(ValueKey(chipKey)),
  matching: find.text(value),
);

/// The history list's scrollable (the CustomScrollView's position — first in
/// tree order, before the chips' horizontal scroller).
Finder historyScrollable() => find
    .descendant(
      of: find.byType(HistoryView),
      matching: find.byType(Scrollable),
    )
    .first;

// ---------------------------------------------------------------------------
// Scenarios
// ---------------------------------------------------------------------------

/// End-to-end history + persistence + sync flows on the demo flavor (real
/// drift file on the device, seeded in-memory cloud fake). Run with:
///
/// ```bash
/// flutter test integration_test/history_flow_test.dart \
///   --dart-define=APP_ENV=demo -d <device>
/// ```
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('History flows end-to-end (demo flavor)', () {
    setUp(() async {
      await configureDependencies('demo');
      // The demo drift FILE persists across runs on the device — start clean.
      await getIt<AppDatabase>().wipeScansForTest();
      fakeRemote().reset();
      fakeConnectivity().reset();
      fakeAuth().reset();
    });

    tearDown(() async {
      // Wipe the persisted rows before the container reset closes the db.
      await getIt<AppDatabase>().wipeScansForTest();
      await getIt.reset();
    });

    testWidgets('1. a guest with no scans sees the inviting empty history', (
      tester,
    ) async {
      await pumpApp(tester);
      await goHomeAsGuest(tester);

      await openHistoryTab(tester);
      final l10n = historyL10n(tester);

      check(find.text(l10n.historyEmptyTitle).evaluate()).length.equals(1);
      check(find.text(l10n.historyEmptyCta).evaluate()).length.equals(1);
      check(find.text(l10n.historyNoResultsTitle).evaluate()).isEmpty();
      check(scanCards().evaluate()).isEmpty();
      check(
        find.byKey(const ValueKey('offline-banner')).evaluate(),
      ).isEmpty();
      check(tester.takeException()).isNull();
    });

    testWidgets('2. the core loop auto-saves: verdict → Done → home last-scan '
        'card + stats → one history card; filtering it out shows the '
        'DISTINCT no-results view', (tester) async {
      await pumpApp(tester);
      await goHomeAsGuest(tester);

      // Scan → solve. The seeded 21-tile rack opens with yellow-13.
      await runScanLoopToResult(tester);
      final resultL10n = tester.element(find.byType(ResultView)).l10n;
      check(
        find.text(resultL10n.resultOpensVerdict).evaluate(),
      ).length.equals(1);

      // Done → Home now carries the live last-scan card + stats (total 1,
      // 100% open rate).
      await tapKey(tester, 'result-done');
      check(find.byType(HomePage).evaluate()).length.equals(1);
      final lastScan = find.byKey(const ValueKey('home-last-scan'));
      await tester.ensureVisible(lastScan);
      await tester.pumpAndSettle();
      check(lastScan.evaluate()).length.equals(1);
      final stats = find.byKey(const ValueKey('home-stats'));
      await tester.ensureVisible(stats);
      await tester.pumpAndSettle();
      check(
        find.descendant(of: stats, matching: find.text('1')).evaluate(),
      ).length.equals(1);
      check(
        find.descendant(of: stats, matching: find.text('100%')).evaluate(),
      ).length.equals(1);

      // History lists exactly that one scan.
      await openHistoryTab(tester);
      final l10n = historyL10n(tester);
      check(scanCards().evaluate()).length.equals(1);
      check(chipCount('history-filter-all', '1').evaluate()).length.equals(1);
      check(
        chipCount('history-filter-opened', '1').evaluate(),
      ).length.equals(1);
      check(
        chipCount('history-filter-closed', '0').evaluate(),
      ).length.equals(1);

      // The opened scan fails the "closed" filter → no-results (NOT empty).
      await tapKey(tester, 'history-filter-closed');
      check(find.text(l10n.historyNoResultsTitle).evaluate()).length.equals(1);
      check(find.text(l10n.historyEmptyTitle).evaluate()).isEmpty();
      check(scanCards().evaluate()).isEmpty();

      // Back to all: the card returns.
      await tapKey(tester, 'history-filter-all');
      check(scanCards().evaluate()).length.equals(1);
      check(tester.takeException()).isNull();
    });

    testWidgets('3. scans persist across an app restart (real drift file '
        'reopened by a fresh DI container)', (tester) async {
      await pumpApp(tester);
      await goHomeAsGuest(tester);
      await runScanLoopToResult(tester);
      await tapKey(tester, 'result-done');
      await openHistoryTab(tester);
      check(scanCards().evaluate()).length.equals(1);

      // "Restart": unmount the app first so no widget holds a bloc from the
      // old container, then reset DI and boot again. Explicit pumps — a
      // pumpAndSettle against the dead container can race lazy singleton
      // disposal.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 100));
      await getIt.reset();
      await configureDependencies('demo');
      await pumpApp(tester);
      await goHomeAsGuest(tester);

      // The home dashboard already reflects the persisted scan…
      final lastScan = find.byKey(const ValueKey('home-last-scan'));
      await tester.ensureVisible(lastScan);
      await tester.pumpAndSettle();
      check(lastScan.evaluate()).length.equals(1);

      // …and history still lists it: the row outlived the restart.
      await openHistoryTab(tester);
      check(scanCards().evaluate()).length.equals(1);
      check(chipCount('history-filter-all', '1').evaluate()).length.equals(1);
      check(tester.takeException()).isNull();
    });

    testWidgets('4. signing in adopts the guest scan, pulls the 26 seeded '
        'cloud scans, and uploads the adopted scan to the fake remote', (
      tester,
    ) async {
      await pumpApp(tester);
      await goHomeAsGuest(tester);
      await runScanLoopToResult(tester);
      await tapKey(tester, 'result-done');

      // Sign in through Settings → sign-up CTA: the login is pushed over
      // the shell tab and the LoginView auth listener lands the session on
      // Home (flow-auth-signin).
      await signInFromSettings(tester);

      // History now merges the adopted guest scan with the 26 pulled seeds:
      // 27 total, 17 opened (14×101 + 2 okey-wins + the guest scan), 10
      // closed. The pull lands via the coalesced background sync, so the
      // counts are awaited, not asserted on the first frame.
      await openHistoryTab(tester);
      await pumpUntilFound(tester, chipCount('history-filter-all', '27'));
      check(
        chipCount('history-filter-opened', '17').evaluate(),
      ).length.equals(1);
      check(
        chipCount('history-filter-closed', '10').evaluate(),
      ).length.equals(1);

      // "Signed-in writes go to Firestore (fake)": the adopted guest scan —
      // and only it — was uploaded, re-owned to the seeded uid (the push
      // follows the pull inside the same background sync pass).
      await pumpUntil(
        tester,
        () => fakeRemote().uploadedScans.isNotEmpty,
        description: 'the adopted guest scan upload',
      );
      final uploaded = fakeRemote().uploadedScans;
      check(uploaded.length).equals(1);
      check(uploaded.single.ownerId).equals('demo-oyuncu');
      check(uploaded.single.id.startsWith('seed-scan-')).isFalse();

      // The okey-mode seeded card renders its okey pill (seed 3, winning
      // now → "Okey"; pills render uppercase).
      final l10n = historyL10n(tester);
      final okeyCard = find.byKey(const ValueKey('scan-card-seed-scan-03'));
      await tester.scrollUntilVisible(
        okeyCard,
        200,
        scrollable: historyScrollable(),
      );
      await tester.pumpAndSettle();
      check(
        find
            .descendant(
              of: okeyCard,
              matching: find.text(l10n.scanCardOkeyWin.toUpperCase()),
            )
            .evaluate(),
      ).length.equals(1);
      check(tester.takeException()).isNull();
    });

    testWidgets('5. pagination materializes the second page; replaying a '
        'seeded card re-solves read-only (no duplicate row)', (tester) async {
      await pumpApp(tester);
      await signInFromSplash(tester);

      await openHistoryTab(tester);
      // The 26 seeds land via the coalesced background sync — awaited.
      await pumpUntilFound(tester, chipCount('history-filter-all', '26'));
      // The oldest seed sits beyond the first 20-row window.
      check(
        find
            .byKey(
              const ValueKey('scan-card-seed-scan-26'),
              skipOffstage: false,
            )
            .evaluate(),
      ).isEmpty();

      // Scroll to the bottom: the near-end notification grows the window and
      // the 21st+ cards materialize.
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('scan-card-seed-scan-26')),
        400,
        scrollable: historyScrollable(),
        maxScrolls: 80,
      );
      await tester.pumpAndSettle();
      check(
        find.byKey(const ValueKey('scan-card-seed-scan-26')).evaluate(),
      ).length.equals(1);

      // Replay the oldest seed (opens with 131): the stored scan re-solves
      // to its seeded verdict on the result screen.
      await tapKey(tester, 'scan-card-seed-scan-26');
      check(find.byType(ResultView).evaluate()).length.equals(1);
      final resultL10n = tester.element(find.byType(ResultView)).l10n;
      check(
        find.text(resultL10n.resultOpensVerdict).evaluate(),
      ).length.equals(1);
      check(find.text('131').evaluate()).length.equals(1);
      check(find.text(resultL10n.resultErrorTitle).evaluate()).isEmpty();

      // Close → home → back to history: a replay never saves, so the
      // counts are unchanged. The retained tab is still scrolled to the
      // bottom from the pagination above — drag back to the top where the
      // chips live before asserting. Were a duplicate row saved, the chip
      // would read 27 and this wait would time out.
      await tapKey(tester, 'result-close');
      check(find.byType(HomePage).evaluate()).length.equals(1);
      await openHistoryTab(tester);
      await tester.drag(historyScrollable(), const Offset(0, 6000));
      await tester.pumpAndSettle();
      await pumpUntilFound(tester, chipCount('history-filter-all', '26'));
      check(tester.takeException()).isNull();
    });

    testWidgets('6. going offline shows the shell-level offline banner over '
        'the still-populated list; back online clears it', (tester) async {
      await pumpApp(tester);
      await signInFromSplash(tester);
      await openHistoryTab(tester);
      // The pulled seeds land via the coalesced background sync — awaited.
      await pumpUntilFound(tester, scanCards());
      // The banner is shell-level now (above the active tab), so it renders
      // while the History tab is on screen.
      final banner = find.byKey(const ValueKey('offline-banner'));
      check(banner.evaluate()).isEmpty();
      check(scanCards().evaluate()).isNotEmpty();

      fakeConnectivity().setOnline(online: false);
      await tester.pumpAndSettle();
      check(banner.evaluate()).length.equals(1);
      final l10n = historyL10n(tester);
      check(find.text(l10n.offlineBanner).evaluate()).length.equals(1);
      // The local store keeps serving the list.
      check(scanCards().evaluate()).isNotEmpty();

      fakeConnectivity().setOnline(online: true);
      await tester.pumpAndSettle();
      check(banner.evaluate()).isEmpty();
      check(tester.takeException()).isNull();
    });
  });
}
