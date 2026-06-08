import 'package:checks/checks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:okey_acar_mi/app.dart';
import 'package:okey_acar_mi/core/di/injection.dart';
import 'package:okey_acar_mi/core/router/app_router.dart';
import 'package:okey_acar_mi/core/widgets/circle_icon_button.dart';
import 'package:okey_acar_mi/core/widgets/placeholder_page.dart';
import 'package:okey_acar_mi/features/history/presentation/pages/history_page.dart';
import 'package:okey_acar_mi/features/home/presentation/pages/home_page.dart';
import 'package:okey_acar_mi/features/onboarding/presentation/pages/splash_page.dart';
import 'package:okey_acar_mi/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:okey_acar_mi/features/settings/presentation/pages/settings_page.dart';
import 'package:okey_acar_mi/features/tutorial/presentation/pages/tutorial_page.dart';

/// Router + shell navigation, driven through the real [App] against the demo
/// fakes so it runs in `flutter test`. Covers `flow-onboard` entry, tab
/// switching, tutorial open/close, the continue→login path, deep-location
/// builds (no crash), and live TR/EN language switching.
void main() {
  group('App navigation (demo flavor)', () {
    setUp(() async => configureDependencies('demo'));
    tearDown(() async => getIt.reset());

    testWidgets('guest → Home, tabs switch, tutorial opens and closes', (
      tester,
    ) async {
      await tester.pumpWidget(const App());
      await tester.pumpAndSettle();
      check(find.byType(SplashPage).evaluate()).length.equals(1);

      await tester.tap(find.byKey(const ValueKey('splash-guest')));
      await tester.pumpAndSettle();
      check(find.byType(HomePage).evaluate()).length.equals(1);

      await tester.tap(find.byKey(const ValueKey('app-nav-1')));
      await tester.pumpAndSettle();
      check(find.byType(HistoryPage).evaluate()).length.equals(1);

      await tester.tap(find.byKey(const ValueKey('app-nav-2')));
      await tester.pumpAndSettle();
      check(find.byType(SettingsPage).evaluate()).length.equals(1);

      await tester.tap(find.byKey(const ValueKey('app-nav-0')));
      await tester.pumpAndSettle();
      check(find.byType(HomePage).evaluate()).length.equals(1);

      await tester.tap(find.byKey(const ValueKey('home-help')));
      await tester.pumpAndSettle();
      check(find.byType(TutorialPage).evaluate()).length.equals(1);

      final done = find.byKey(const ValueKey('tutorial-done'));
      await tester.ensureVisible(done);
      await tester.pumpAndSettle();
      await tester.tap(done);
      await tester.pumpAndSettle();
      check(find.byType(HomePage).evaluate()).length.equals(1);

      check(tester.takeException()).isNull();
    });

    testWidgets('continue → Login route, then pop returns to splash', (
      tester,
    ) async {
      await tester.pumpWidget(const App());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('splash-continue')));
      await tester.pumpAndSettle();
      check(find.byType(PlaceholderPage).evaluate()).length.equals(1);

      // Popping the pushed login returns to the splash beneath it.
      tester.element(find.byType(PlaceholderPage)).pop();
      await tester.pumpAndSettle();
      check(find.byType(SplashPage).evaluate()).length.equals(1);
      check(tester.takeException()).isNull();
    });

    testWidgets('deep locations build; stranded placeholder escapes home', (
      tester,
    ) async {
      await tester.pumpWidget(const App());
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('splash-guest')));
      await tester.pumpAndSettle();

      final router = getIt<AppRouter>().config;
      for (final location in const [
        AppRoutes.settings,
        AppRoutes.paywall,
        AppRoutes.result,
        AppRoutes.camera,
        AppRoutes.home,
      ]) {
        router.go(location);
        await tester.pumpAndSettle();
        check(tester.takeException()).isNull();
      }

      // A directly-addressed placeholder (empty back stack ⇒ cannot pop, and it
      // sits outside the bottom-nav shell) must still offer an escape to Home.
      router.go(AppRoutes.paywall);
      await tester.pumpAndSettle();
      check(find.byType(PlaceholderPage).evaluate()).length.equals(1);

      await tester.tap(find.byType(CircleIconButton));
      await tester.pumpAndSettle();
      check(find.byType(HomePage).evaluate()).length.equals(1);
      check(tester.takeException()).isNull();
    });

    testWidgets('language switch re-renders strings live (TR ⇄ EN)', (
      tester,
    ) async {
      await tester.pumpWidget(const App());
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('splash-guest')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('app-nav-2')));
      await tester.pumpAndSettle();

      SettingsCubit cubit() =>
          tester.element(find.byType(SettingsPage)).read<SettingsCubit>();
      String locale() => Localizations.localeOf(
        tester.element(find.byType(SettingsPage)),
      ).languageCode;

      final english = find.byKey(const ValueKey('settings-language-english'));
      await tester.ensureVisible(english);
      await tester.pumpAndSettle();
      await tester.tap(english);
      await tester.pumpAndSettle();
      check(cubit().state.language).equals(AppLanguage.english);
      check(locale()).equals('en');

      final turkish = find.byKey(const ValueKey('settings-language-turkish'));
      await tester.ensureVisible(turkish);
      await tester.pumpAndSettle();
      await tester.tap(turkish);
      await tester.pumpAndSettle();
      check(cubit().state.language).equals(AppLanguage.turkish);
      check(locale()).equals('tr');

      check(tester.takeException()).isNull();
    });
  });
}
