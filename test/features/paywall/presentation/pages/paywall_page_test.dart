import 'package:checks/checks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:okey_acar_mi/core/payments/data/fakes/fake_purchase_repository.dart';
import 'package:okey_acar_mi/core/payments/subscription_bloc.dart';
import 'package:okey_acar_mi/core/router/app_router.dart';
import 'package:okey_acar_mi/core/theme/app_accent.dart';
import 'package:okey_acar_mi/core/theme/app_theme.dart';
import 'package:okey_acar_mi/core/theme/tile_style.dart';
import 'package:okey_acar_mi/core/time/clock.dart';
import 'package:okey_acar_mi/features/paywall/presentation/pages/paywall_page.dart';
import 'package:okey_acar_mi/features/paywall/presentation/widgets/paywall_error_view.dart';
import 'package:okey_acar_mi/features/paywall/presentation/widgets/paywall_plan_card.dart';
import 'package:okey_acar_mi/l10n/app_localizations.dart';

final AppLocalizations _l10n = lookupAppLocalizations(const Locale('en'));

/// Settles the paywall after an async flow (offering load, purchase, restore)
/// WITHOUT pumpAndSettle.
///
/// Two reasons pumpAndSettle can't be used: the loading/busy states render an
/// indeterminate `CircularProgressIndicator` whose ticker never settles, and
/// the app-scoped [SubscriptionBloc]'s repository work resolves on a real async
/// boundary (its entitlement stream parks the offering/purchase microtask past
/// the fake-async event queue). `runAsync` crosses that real boundary; the
/// surrounding pumps drive the page transition and the resolved-state rebuild.
Future<void> _settleAsync(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 50)),
  );
  await tester.pump();
  await tester.pump();
}

void main() {
  late FakePurchaseRepository repository;
  late SubscriptionBloc subscription;

  setUp(() {
    repository = FakePurchaseRepository(const _Clock());
    subscription = SubscriptionBloc(repository)
      ..add(const SubscriptionEvent.started());
  });

  tearDown(() async {
    await subscription.close();
    repository.dispose();
  });

  /// Pumps the paywall over [subscription], with a stub "home" route beneath
  /// it so a `context.pop()` after a successful purchase/restore has somewhere
  /// to land.
  Future<void> pumpPaywall(WidgetTester tester) async {
    final router = GoRouter(
      initialLocation: AppRoutes.home,
      routes: [
        GoRoute(
          path: AppRoutes.home,
          builder: (context, state) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => context.push(AppRoutes.paywall),
                child: const Text('open-paywall'),
              ),
            ),
          ),
        ),
        GoRoute(
          path: AppRoutes.paywall,
          builder: (context, state) => const PaywallPage(),
        ),
      ],
    );
    await tester.pumpWidget(
      BlocProvider<SubscriptionBloc>.value(
        value: subscription,
        child: MaterialApp.router(
          theme: AppTheme.light(AppAccent.sage, TileStyle.classic),
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: const [Locale('tr'), Locale('en')],
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
    // Push the paywall over the home route so context.pop() lands on home.
    // The paywall briefly shows an indeterminate `CircularProgressIndicator`
    // while the offering loads; pumping past it (rather than pumpAndSettle,
    // which spins on the indeterminate ticker) lands the loaded plan body.
    await tester.tap(find.text('open-paywall'));
    await _settleAsync(tester);
  }

  Finder key(String value) => find.byKey(ValueKey(value));

  /// Pumps frames after a purchase/restore tap, stopping while the SnackBar is
  /// still visible so the caller can assert on it.
  Future<void> settleFlow(WidgetTester tester) => _settleAsync(tester);

  /// Drains the SnackBar's auto-dismiss timer so the test ends with no pending
  /// timers (and no perpetual spinner to settle on).
  Future<void> drainSnackBar(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 4));
    await tester.pump(const Duration(milliseconds: 400));
  }

  group('PaywallPage rendering', () {
    testWidgets('renders both plan cards with the trial badge and the CTAs', (
      tester,
    ) async {
      await pumpPaywall(tester);

      check(find.byType(PaywallPlanCard).evaluate()).length.equals(2);
      check(key('paywall-plan-monthly').evaluate()).length.equals(1);
      check(key('paywall-plan-annual').evaluate()).length.equals(1);
      // Both seeded plans carry a 7-day trial badge.
      check(find.text(_l10n.paywallTrialBadge).evaluate()).length.equals(2);
      check(key('paywall-subscribe').evaluate()).length.equals(1);
      check(key('paywall-restore').evaluate()).length.equals(1);
      check(key('paywall-close').evaluate()).length.equals(1);
      check(tester.takeException()).isNull();
    });
  });

  group('purchase flow', () {
    testWidgets('subscribe dispatches purchaseRequested for the selected plan; '
        'success pops with a SnackBar and premium is active', (tester) async {
      await pumpPaywall(tester);

      // Select monthly, then subscribe.
      await tester.tap(key('paywall-plan-monthly'));
      await tester.pump();
      await tester.tap(key('paywall-subscribe'));
      await settleFlow(tester);
      // The purchase succeeded and premium became active; the listener popped
      // the paywall. Finish the (spinner-free) pop transition.
      await tester.pumpAndSettle();

      check(subscription.state.isPremium).isTrue();
      // Success pops back to home and surfaces the success SnackBar.
      check(find.text('open-paywall').evaluate()).length.equals(1);
      check(find.byType(PaywallPage).evaluate()).isEmpty();
      check(find.text(_l10n.paywallSuccess).evaluate()).length.equals(1);
      await drainSnackBar(tester);
      check(tester.takeException()).isNull();
    });

    testWidgets('a payment failure surfaces a SnackBar and keeps the paywall '
        'open (not premium)', (tester) async {
      repository.failNextPurchase = true;
      await pumpPaywall(tester);

      await tester.tap(key('paywall-subscribe'));
      await settleFlow(tester);

      check(subscription.state.isPremium).isFalse();
      check(find.byType(PaywallPage).evaluate()).length.equals(1);
      check(find.text(_l10n.paywallErrorPayment).evaluate()).length.equals(1);
      await drainSnackBar(tester);
      check(tester.takeException()).isNull();
    });
  });

  group('restore flow', () {
    testWidgets('restore dispatches restoreRequested; nothing-to-restore '
        'surfaces a SnackBar and stays open', (tester) async {
      repository.nothingToRestore = true;
      await pumpPaywall(tester);

      await tester.tap(key('paywall-restore'));
      await settleFlow(tester);

      check(find.byType(PaywallPage).evaluate()).length.equals(1);
      check(
        find.text(_l10n.restoreNothingToRestore).evaluate(),
      ).length.equals(1);
      await drainSnackBar(tester);
      check(tester.takeException()).isNull();
    });
  });

  group('offline flow', () {
    testWidgets('offline offerings show the retry view; retrying after coming '
        'online loads the plans', (tester) async {
      repository.offline = true;
      await pumpPaywall(tester);

      // The offering request failed offline: the retry view is shown.
      check(find.byType(PaywallErrorView).evaluate()).length.equals(1);
      check(find.byType(PaywallPlanCard).evaluate()).isEmpty();

      // Back online, retry loads the seeded plans.
      repository.offline = false;
      await tester.tap(key('paywall-retry'));
      await settleFlow(tester);
      check(find.byType(PaywallPlanCard).evaluate()).length.equals(2);
      check(tester.takeException()).isNull();
    });
  });

  group('close', () {
    testWidgets('the close button pops back to the caller', (tester) async {
      await pumpPaywall(tester);
      await tester.tap(key('paywall-close'));
      // The pop transition has no perpetual spinner (the loaded body popped),
      // so pumpAndSettle finishes the pop cleanly.
      await tester.pumpAndSettle();
      check(find.byType(PaywallPage).evaluate()).isEmpty();
      check(find.text('open-paywall').evaluate()).length.equals(1);
      check(tester.takeException()).isNull();
    });
  });
}

/// A deterministic clock for the fake repository (no demo DI needed here).
class _Clock implements Clock {
  const _Clock();
  @override
  DateTime now() => DateTime.utc(2026);
}
