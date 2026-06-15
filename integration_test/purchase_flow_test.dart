import 'package:checks/checks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:okey_acar_mi/app.dart';
import 'package:okey_acar_mi/core/ads/presentation/ad_banner.dart';
import 'package:okey_acar_mi/core/di/injection.dart';
import 'package:okey_acar_mi/core/extensions/context_extensions.dart';
import 'package:okey_acar_mi/core/payments/data/fakes/fake_purchase_repository.dart';
import 'package:okey_acar_mi/core/payments/domain/repositories/purchase_repository.dart';
import 'package:okey_acar_mi/features/history/presentation/pages/history_page.dart';
import 'package:okey_acar_mi/features/home/presentation/pages/home_page.dart';
import 'package:okey_acar_mi/features/paywall/presentation/pages/paywall_page.dart';
import 'package:okey_acar_mi/features/settings/presentation/pages/settings_page.dart';

/// The demo purchase fake (registered as the [PurchaseRepository] interface).
FakePurchaseRepository fakePurchases() =>
    getIt<PurchaseRepository>() as FakePurchaseRepository;

Future<void> tapKey(WidgetTester tester, String key) async {
  final finder = find.byKey(ValueKey(key));
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> pumpUntilFound(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 100 && finder.evaluate().isEmpty; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> goHomeAsGuest(WidgetTester tester) async {
  await tester.pumpWidget(const App());
  await tester.pumpAndSettle();
  await tapKey(tester, 'splash-guest');
  check(find.byType(HomePage).evaluate()).length.equals(1);
}

Future<void> openSettings(WidgetTester tester) async {
  await tapKey(tester, 'app-nav-2');
  check(find.byType(SettingsPage).evaluate()).length.equals(1);
}

/// Scrolls the lazy settings list until [key] materializes.
Future<void> scrollToSettingsKey(WidgetTester tester, String key) async {
  final scrollable = find
      .descendant(
        of: find.byType(SettingsPage),
        matching: find.byType(Scrollable),
      )
      .first;
  await tester.scrollUntilVisible(
    find.byKey(ValueKey(key)),
    120,
    scrollable: scrollable,
  );
  await tester.pumpAndSettle();
}

/// End-to-end remove-ads purchase flow on the demo flavor (no store, no
/// screenshots). Run with:
///
/// ```bash
/// flutter test integration_test/purchase_flow_test.dart \
///   --dart-define=APP_ENV=demo -d <device>
/// ```
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Purchase flow end-to-end (demo flavor)', () {
    setUp(() async => configureDependencies('demo'));
    tearDown(() async {
      fakePurchases().reset();
      await getIt.reset();
    });

    testWidgets('Settings → paywall → subscribe → premium removes the banner '
        'on History; restore re-applies; expiry + resume returns ads', (
      tester,
    ) async {
      await goHomeAsGuest(tester);

      // The History tab mounts the ad banner for a free user.
      await tapKey(tester, 'app-nav-1');
      check(find.byType(HistoryPage).evaluate()).length.equals(1);
      check(find.byType(AdBanner).evaluate()).isNotEmpty();
      final l10n = tester.element(find.byType(HistoryPage)).l10n;
      check(find.text(l10n.adPlaceholderLabel).evaluate()).length.equals(1);

      // Settings → remove ads → the paywall.
      await openSettings(tester);
      await scrollToSettingsKey(tester, 'settings-remove-ads');
      await tapKey(tester, 'settings-remove-ads');
      check(find.byType(PaywallPage).evaluate()).length.equals(1);

      // The offering loads off a real async boundary; wait for the plan cards.
      await pumpUntilFound(
        tester,
        find.byKey(const ValueKey('paywall-plan-annual')),
      );
      check(
        find.byKey(const ValueKey('paywall-plan-annual')).evaluate(),
      ).length.equals(1);

      // Subscribe → the fake grants premium and pops the paywall.
      await tapKey(tester, 'paywall-subscribe');
      await pumpUntilFound(tester, find.byType(SettingsPage));
      check(find.byType(PaywallPage).evaluate()).isEmpty();

      // Premium now: the settings purchases section shows the active indicator
      // and the remove-ads CTA is gone.
      await scrollToSettingsKey(tester, 'settings-restore-purchases');
      check(
        find.text(l10n.settingsPremiumActive).evaluate(),
      ).length.equals(1);
      check(
        find.byKey(const ValueKey('settings-remove-ads')).evaluate(),
      ).isEmpty();

      // The banner is gone on History (entitlement read live).
      await tapKey(tester, 'app-nav-1');
      check(find.text(l10n.adPlaceholderLabel).evaluate()).isEmpty();

      // Restore re-applies premium (success SnackBar).
      await openSettings(tester);
      await scrollToSettingsKey(tester, 'settings-restore-purchases');
      await tapKey(tester, 'settings-restore-purchases');
      check(
        find
            .descendant(
              of: find.byType(SnackBar),
              matching: find.text(l10n.restoreSuccess),
            )
            .evaluate(),
      ).length.equals(1);
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();

      // Expiry while backgrounded: the resume-time refresh re-reads it and the
      // banner returns. The lifecycle walks inactive→hidden→paused→…→resumed
      // (never pumping while paused).
      fakePurchases().setMode(FakePurchaseMode.expired);
      tester.binding
        ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
        ..handleAppLifecycleStateChanged(AppLifecycleState.hidden)
        ..handleAppLifecycleStateChanged(AppLifecycleState.paused)
        ..handleAppLifecycleStateChanged(AppLifecycleState.hidden)
        ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
        ..handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      await tapKey(tester, 'app-nav-1');
      check(find.byType(HistoryPage).evaluate()).length.equals(1);
      check(find.text(l10n.adPlaceholderLabel).evaluate()).length.equals(1);
      check(tester.takeException()).isNull();
    });

    testWidgets('paywall close returns to Settings without subscribing '
        '(still free)', (tester) async {
      await goHomeAsGuest(tester);
      await openSettings(tester);
      await scrollToSettingsKey(tester, 'settings-remove-ads');
      await tapKey(tester, 'settings-remove-ads');
      check(find.byType(PaywallPage).evaluate()).length.equals(1);

      await tapKey(tester, 'paywall-close');
      check(find.byType(PaywallPage).evaluate()).isEmpty();
      check(find.byType(SettingsPage).evaluate()).length.equals(1);

      // Still free: the remove-ads CTA is back.
      await scrollToSettingsKey(tester, 'settings-remove-ads');
      check(
        find.byKey(const ValueKey('settings-remove-ads')).evaluate(),
      ).length.equals(1);
      check(tester.takeException()).isNull();
    });
  });
}
