import 'package:checks/checks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:okey_acar_mi/app.dart';
import 'package:okey_acar_mi/core/di/injection.dart';
import 'package:okey_acar_mi/features/auth/data/fakes/fake_auth_repository.dart';
import 'package:okey_acar_mi/features/auth/domain/repositories/auth_repository.dart';
import 'package:okey_acar_mi/features/auth/presentation/pages/login_page.dart';
import 'package:okey_acar_mi/features/home/presentation/pages/home_page.dart';
import 'package:okey_acar_mi/features/settings/presentation/pages/settings_page.dart';

/// Success-navigation off the login screen, driven through the real [App]
/// (real router + demo fakes) so both navigation owners are exercised: the
/// router's refresh redirect (guarded-base case: splash) and the LoginPage
/// listener fallback (login pushed imperatively over an unguarded base:
/// Settings sign-up CTA, session-expired banner on Home).
void main() {
  group('Login success navigation (demo flavor)', () {
    setUp(() async => configureDependencies('demo'));
    tearDown(() async => getIt.reset());

    Future<void> tapKey(WidgetTester tester, String key) async {
      final finder = find.byKey(ValueKey(key));
      await tester.ensureVisible(finder);
      await tester.pumpAndSettle();
      await tester.tap(finder);
      await tester.pumpAndSettle();
    }

    /// The Settings list is lazy: scroll until [key] is built, then tap it.
    Future<void> tapInSettings(WidgetTester tester, String key) async {
      final scrollable = find
          .descendant(
            of: find.byType(SettingsPage),
            matching: find.byType(Scrollable),
          )
          .first;
      final finder = find.byKey(ValueKey(key));
      await tester.scrollUntilVisible(finder, 120, scrollable: scrollable);
      await tester.pumpAndSettle();
      await tester.tap(finder);
      await tester.pumpAndSettle();
    }

    /// Boots the app as guest and pushes /login from the Settings sign-up
    /// CTA — the imperative path whose base location (/settings) the auth
    /// redirect does not guard.
    Future<void> pushLoginFromSettings(WidgetTester tester) async {
      await tester.pumpWidget(const App());
      await tester.pumpAndSettle();
      await tapKey(tester, 'splash-guest');
      check(find.byType(HomePage).evaluate()).length.equals(1);
      await tapKey(tester, 'app-nav-2');
      check(find.byType(SettingsPage).evaluate()).length.equals(1);
      await tapInSettings(tester, 'settings-signup');
      check(find.byType(LoginPage).evaluate()).length.equals(1);
    }

    /// Signs in as the seeded demo account (`oyuncu@demo.app` / `okey1234`).
    Future<void> submitSeededCredentials(WidgetTester tester) async {
      await tester.enterText(
        find.byKey(const ValueKey('login-email')),
        'oyuncu@demo.app',
      );
      await tester.enterText(
        find.byKey(const ValueKey('login-password')),
        'okey1234',
      );
      await tapKey(tester, 'login-submit');
    }

    testWidgets('signing in on a login pushed over Settings lands on Home', (
      tester,
    ) async {
      await pushLoginFromSettings(tester);
      await submitSeededCredentials(tester);

      check(find.byType(HomePage).evaluate()).length.equals(1);
      check(find.byType(LoginPage).evaluate()).isEmpty();
      check(tester.takeException()).isNull();
    });

    testWidgets('cancelling a login pushed over Settings returns to Settings '
        '(back button and system back)', (tester) async {
      await pushLoginFromSettings(tester);
      await tapKey(tester, 'login-back');
      check(find.byType(SettingsPage).evaluate()).length.equals(1);
      check(find.byType(LoginPage).evaluate()).isEmpty();

      // Same cancel via the system (Android) back.
      await tapInSettings(tester, 'settings-signup');
      check(find.byType(LoginPage).evaluate()).length.equals(1);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      check(find.byType(SettingsPage).evaluate()).length.equals(1);
      check(find.byType(LoginPage).evaluate()).isEmpty();
      check(tester.takeException()).isNull();
    });

    testWidgets('signing in from the splash login still lands on Home '
        '(guarded-base refresh redirect)', (tester) async {
      await tester.pumpWidget(const App());
      await tester.pumpAndSettle();
      await tapKey(tester, 'splash-continue');
      check(find.byType(LoginPage).evaluate()).length.equals(1);

      await submitSeededCredentials(tester);

      check(find.byType(HomePage).evaluate()).length.equals(1);
      check(find.byType(LoginPage).evaluate()).isEmpty();
      check(tester.takeException()).isNull();
    });

    testWidgets('signing in on a login pushed by the session-expired banner '
        '(over Home) lands on Home', (tester) async {
      (getIt<AuthRepository>() as FakeAuthRepository).mode =
          FakeAuthMode.sessionExpired;
      await tester.pumpWidget(const App());
      await tester.pumpAndSettle();
      await tapKey(tester, 'splash-guest');

      final banner = find.byKey(const ValueKey('session-expired-banner'));
      check(banner.evaluate()).length.equals(1);
      await tester.tap(
        find.descendant(of: banner, matching: find.byType(TextButton)),
      );
      await tester.pumpAndSettle();
      check(find.byType(LoginPage).evaluate()).length.equals(1);

      await submitSeededCredentials(tester);

      check(find.byType(HomePage).evaluate()).length.equals(1);
      check(find.byType(LoginPage).evaluate()).isEmpty();
      check(tester.takeException()).isNull();
    });
  });
}
