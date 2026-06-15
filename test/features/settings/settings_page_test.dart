import 'package:checks/checks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:okey_acar_mi/core/app_info/app_info.dart';
import 'package:okey_acar_mi/core/di/injection.dart';
import 'package:okey_acar_mi/core/payments/data/fakes/fake_purchase_repository.dart';
import 'package:okey_acar_mi/core/payments/domain/repositories/purchase_repository.dart';
import 'package:okey_acar_mi/core/payments/subscription_bloc.dart';
import 'package:okey_acar_mi/core/router/app_router.dart';
import 'package:okey_acar_mi/core/theme/app_accent.dart';
import 'package:okey_acar_mi/core/theme/app_theme.dart';
import 'package:okey_acar_mi/core/theme/tile_style.dart';
import 'package:okey_acar_mi/features/auth/presentation/blocs/auth_bloc.dart';
import 'package:okey_acar_mi/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:okey_acar_mi/features/settings/presentation/pages/settings_page.dart';
import 'package:okey_acar_mi/l10n/app_localizations.dart';

final AppLocalizations _l10n = lookupAppLocalizations(const Locale('en'));

/// Pumps the real [SettingsPage] above demo-DI blocs (the account section
/// reads the app-scoped [AuthBloc]; the purchases section reads the app-scoped
/// [SubscriptionBloc]; the version row reads `getIt<AppInfo>`), inside a router
/// exposing a stub /paywall so the "remove ads" push is observable.
Widget _harness() {
  final router = GoRouter(
    initialLocation: AppRoutes.settings,
    routes: [
      GoRoute(
        path: AppRoutes.settings,
        builder: (context, state) => const SettingsPage(),
      ),
      GoRoute(
        path: AppRoutes.paywall,
        builder: (context, state) =>
            const Scaffold(body: Center(child: Text('paywall-stub'))),
      ),
    ],
  );
  return MaterialApp.router(
    theme: AppTheme.light(AppAccent.sage, TileStyle.classic),
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: const [Locale('tr'), Locale('en')],
    routerConfig: router,
    builder: (context, child) => MultiBlocProvider(
      providers: [
        BlocProvider<SettingsCubit>(create: (_) => SettingsCubit()),
        BlocProvider<AuthBloc>(
          create: (_) => getIt<AuthBloc>()..add(const AuthEvent.started()),
        ),
        BlocProvider<SubscriptionBloc>(
          create: (_) =>
              getIt<SubscriptionBloc>()..add(const SubscriptionEvent.started()),
        ),
      ],
      child: child!,
    ),
  );
}

/// Seeds the demo purchase fake to [mode] before the harness is pumped so the
/// app-scoped [SubscriptionBloc] starts on the matching entitlement.
void _seedMode(FakePurchaseMode mode) =>
    (getIt<PurchaseRepository>() as FakePurchaseRepository).setMode(mode);

void main() {
  setUp(() async => configureDependencies('demo'));
  tearDown(() async => getIt.reset());

  Finder pageScrollable() => find
      .descendant(
        of: find.byType(SettingsPage),
        matching: find.byType(Scrollable),
      )
      .first;

  Future<void> scrollTo(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(finder, 120, scrollable: pageScrollable());
    await tester.pumpAndSettle();
  }

  /// Lets the open SnackBar time out and animate away, so the test ends with
  /// no pending timers.
  Future<void> dismissSnackBar(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  }

  group('SettingsPage purchases section — free', () {
    testWidgets('shows remove-ads + restore (no premium row / manage); '
        'tapping remove-ads pushes the paywall', (tester) async {
      await tester.pumpWidget(_harness());
      await tester.pumpAndSettle();

      final removeAds = find.byKey(const ValueKey('settings-remove-ads'));
      final restore = find.byKey(const ValueKey('settings-restore-purchases'));
      await scrollTo(tester, removeAds);

      check(removeAds.evaluate()).length.equals(1);
      check(restore.evaluate()).length.equals(1);
      // The premium-only affordances are absent for a free user.
      check(
        find.byKey(const ValueKey('settings-manage-subscription')).evaluate(),
      ).isEmpty();
      check(find.text(_l10n.settingsPremiumActive).evaluate()).isEmpty();

      await tester.tap(removeAds);
      await tester.pumpAndSettle();
      check(find.text('paywall-stub').evaluate()).length.equals(1);
      check(tester.takeException()).isNull();
    });

    testWidgets('tapping restore with nothing to restore surfaces the '
        '"no purchases" SnackBar', (tester) async {
      (getIt<PurchaseRepository>() as FakePurchaseRepository).nothingToRestore =
          true;
      await tester.pumpWidget(_harness());
      await tester.pumpAndSettle();

      final restore = find.byKey(const ValueKey('settings-restore-purchases'));
      await scrollTo(tester, restore);
      await tester.tap(restore);
      await tester.pumpAndSettle();

      check(
        find
            .descendant(
              of: find.byType(SnackBar),
              matching: find.text(_l10n.restoreNothingToRestore),
            )
            .evaluate(),
      ).length.equals(1);
      await dismissSnackBar(tester);
      check(tester.takeException()).isNull();
    });

    testWidgets('tapping restore that re-applies a purchase surfaces the '
        'restore-success SnackBar', (tester) async {
      await tester.pumpWidget(_harness());
      await tester.pumpAndSettle();

      final restore = find.byKey(const ValueKey('settings-restore-purchases'));
      await scrollTo(tester, restore);
      await tester.tap(restore);
      await tester.pumpAndSettle();

      check(
        find
            .descendant(
              of: find.byType(SnackBar),
              matching: find.text(_l10n.restoreSuccess),
            )
            .evaluate(),
      ).length.equals(1);
      await dismissSnackBar(tester);
      check(tester.takeException()).isNull();
    });
  });

  group('SettingsPage purchases section — premium', () {
    testWidgets('shows the premium-active indicator + manage + restore, '
        'never remove-ads', (tester) async {
      _seedMode(FakePurchaseMode.premium);
      await tester.pumpWidget(_harness());
      await tester.pumpAndSettle();

      final premiumRow = find.text(_l10n.settingsPremiumActive);
      await scrollTo(tester, premiumRow);

      check(premiumRow.evaluate()).length.equals(1);
      check(
        find.byKey(const ValueKey('settings-manage-subscription')).evaluate(),
      ).length.equals(1);
      check(
        find.byKey(const ValueKey('settings-restore-purchases')).evaluate(),
      ).length.equals(1);
      // The "remove ads" CTA is hidden once premium is active.
      check(
        find.byKey(const ValueKey('settings-remove-ads')).evaluate(),
      ).isEmpty();
      check(tester.takeException()).isNull();
    });
  });

  group('SettingsPage about section', () {
    testWidgets('lists the legal links and the AppInfo version label', (
      tester,
    ) async {
      await tester.pumpWidget(_harness());
      await tester.pumpAndSettle();

      final terms = find.byKey(const ValueKey('settings-terms-of-use'));
      await scrollTo(tester, terms);

      // Presence only — tapping would invoke url_launcher (no host platform
      // channel; the real launch path is exercised manually via HUMAN_SETUP).
      check(
        find.byKey(const ValueKey('settings-privacy-policy')).evaluate(),
      ).length.equals(1);
      check(terms.evaluate()).length.equals(1);

      // The version row renders the DI-provided AppInfo label (the host
      // fallback is '0.0.0 (0)' — asserted through the same source the page
      // reads, so this also holds on-device).
      check(find.text('Version').evaluate()).length.equals(1);
      check(find.text(getIt<AppInfo>().label).evaluate()).length.equals(1);
      check(getIt<AppInfo>().label).equals('0.0.0 (0)');

      check(tester.takeException()).isNull();
    });
  });
}
