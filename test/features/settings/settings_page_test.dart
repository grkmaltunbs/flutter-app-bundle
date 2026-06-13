import 'package:checks/checks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:okey_acar_mi/core/app_info/app_info.dart';
import 'package:okey_acar_mi/core/di/injection.dart';
import 'package:okey_acar_mi/core/theme/app_accent.dart';
import 'package:okey_acar_mi/core/theme/app_theme.dart';
import 'package:okey_acar_mi/core/theme/tile_style.dart';
import 'package:okey_acar_mi/features/auth/presentation/blocs/auth_bloc.dart';
import 'package:okey_acar_mi/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:okey_acar_mi/features/settings/presentation/pages/settings_page.dart';
import 'package:okey_acar_mi/l10n/app_localizations.dart';

/// Pumps the real [SettingsPage] above demo-DI blocs (the account section
/// reads the app-scoped [AuthBloc]; the version row reads `getIt<AppInfo>`).
Widget _harness() {
  return MaterialApp(
    theme: AppTheme.light(AppAccent.sage, TileStyle.classic),
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: const [Locale('tr'), Locale('en')],
    home: MultiBlocProvider(
      providers: [
        BlocProvider<SettingsCubit>(create: (_) => SettingsCubit()),
        BlocProvider<AuthBloc>(
          create: (_) => getIt<AuthBloc>()..add(const AuthEvent.started()),
        ),
      ],
      child: const SettingsPage(),
    ),
  );
}

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

  group('SettingsPage purchases section', () {
    testWidgets('restore + manage rows are present; tapping each shows the '
        'coming-soon SnackBar', (tester) async {
      await tester.pumpWidget(_harness());
      await tester.pumpAndSettle();

      final restore = find.byKey(const ValueKey('settings-restore-purchases'));
      final manage = find.byKey(const ValueKey('settings-manage-subscription'));
      await scrollTo(tester, restore);
      check(restore.evaluate()).length.equals(1);
      check(manage.evaluate()).length.equals(1);
      check(find.text('Coming soon').evaluate()).isEmpty();

      await tester.tap(restore);
      await tester.pumpAndSettle();
      check(
        find
            .descendant(
              of: find.byType(SnackBar),
              matching: find.text('Coming soon'),
            )
            .evaluate(),
      ).length.equals(1);
      await dismissSnackBar(tester);

      await tester.tap(manage);
      await tester.pumpAndSettle();
      check(
        find
            .descendant(
              of: find.byType(SnackBar),
              matching: find.text('Coming soon'),
            )
            .evaluate(),
      ).length.equals(1);
      await dismissSnackBar(tester);

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
