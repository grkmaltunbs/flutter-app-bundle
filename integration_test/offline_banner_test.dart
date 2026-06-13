import 'package:checks/checks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:okey_acar_mi/app.dart';
import 'package:okey_acar_mi/core/di/injection.dart';
import 'package:okey_acar_mi/core/extensions/context_extensions.dart';
import 'package:okey_acar_mi/core/network/connectivity_service.dart';
import 'package:okey_acar_mi/features/history/presentation/pages/history_page.dart';
import 'package:okey_acar_mi/features/home/presentation/pages/home_page.dart';
import 'package:okey_acar_mi/features/settings/presentation/pages/settings_page.dart';

// ---------------------------------------------------------------------------
// Robot helpers
// ---------------------------------------------------------------------------

/// The demo fake behind connectivity.
FakeConnectivityService fakeConnectivity() =>
    getIt<ConnectivityService>() as FakeConnectivityService;

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

// ---------------------------------------------------------------------------
// Scenario
// ---------------------------------------------------------------------------

/// The shell-level offline banner end-to-end on the demo flavor: appears on
/// every tab while the fake transport is down, clears when it returns. Run
/// with:
///
/// ```bash
/// flutter test integration_test/offline_banner_test.dart \
///   --dart-define=APP_ENV=demo -d <device>
/// ```
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Offline banner end-to-end (demo flavor)', () {
    setUp(() async {
      await configureDependencies('demo');
      fakeConnectivity().reset();
    });

    tearDown(() async => getIt.reset());

    testWidgets('going offline raises the banner on every tab; back online '
        'clears it', (tester) async {
      await pumpApp(tester);
      await goHomeAsGuest(tester);

      final banner = find.byKey(const ValueKey('offline-banner'));
      check(banner.evaluate()).isEmpty();

      // Drop the transport: the banner lands on Home…
      fakeConnectivity().setOnline(online: false);
      await tester.pumpAndSettle();
      check(banner.evaluate()).length.equals(1);
      final l10n = tester.element(find.byType(HomePage)).l10n;
      check(find.text(l10n.offlineBanner).evaluate()).length.equals(1);

      // …persists across the History tab…
      await tapKey(tester, 'app-nav-1');
      check(find.byType(HistoryPage).evaluate()).length.equals(1);
      check(banner.evaluate()).length.equals(1);

      // …and the Settings tab (it is shell-scoped, not per-screen).
      await tapKey(tester, 'app-nav-2');
      check(find.byType(SettingsPage).evaluate()).length.equals(1);
      check(banner.evaluate()).length.equals(1);

      // Transport back: the banner clears wherever the user is.
      fakeConnectivity().setOnline(online: true);
      await tester.pumpAndSettle();
      check(banner.evaluate()).isEmpty();

      check(tester.takeException()).isNull();
    });
  });
}
