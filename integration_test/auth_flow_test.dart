import 'package:checks/checks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:okey_acar_mi/app.dart';
import 'package:okey_acar_mi/core/di/injection.dart';
import 'package:okey_acar_mi/core/widgets/app_buttons.dart';
import 'package:okey_acar_mi/features/auth/data/fakes/fake_auth_repository.dart';
import 'package:okey_acar_mi/features/auth/domain/repositories/auth_repository.dart';
import 'package:okey_acar_mi/features/auth/presentation/pages/login_page.dart';
import 'package:okey_acar_mi/features/home/presentation/pages/home_page.dart';
import 'package:okey_acar_mi/features/onboarding/presentation/pages/splash_page.dart';
import 'package:okey_acar_mi/features/settings/presentation/pages/settings_page.dart';

// ---------------------------------------------------------------------------
// Robot helpers
// ---------------------------------------------------------------------------

/// The demo fake driving every backend behavior in these flows.
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

/// Splash → "Devam et" → the login screen.
Future<void> goToLogin(WidgetTester tester) async {
  await tapKey(tester, 'splash-continue');
  check(find.byType(LoginPage).evaluate()).length.equals(1);
}

/// Signs in with a seeded email/password account from the login screen.
Future<void> signIn(
  WidgetTester tester, {
  String email = 'oyuncu@demo.app',
  String password = 'okey1234',
}) async {
  await goToLogin(tester);
  await enterText(tester, 'login-email', email);
  await enterText(tester, 'login-password', password);
  await tapKey(tester, 'login-submit');
}

Future<void> openSettingsTab(WidgetTester tester) async {
  await tapKey(tester, 'app-nav-2');
  check(find.byType(SettingsPage).evaluate()).length.equals(1);
}

/// The Settings list is lazy: scroll until [finder] is built and visible.
Future<void> showInSettings(WidgetTester tester, Finder finder) async {
  final scrollable = find
      .descendant(
        of: find.byType(SettingsPage),
        matching: find.byType(Scrollable),
      )
      .first;
  await tester.scrollUntilVisible(finder, 120, scrollable: scrollable);
  await tester.pumpAndSettle();
}

Future<void> tapInSettings(WidgetTester tester, String key) async {
  final finder = find.byKey(ValueKey(key));
  await showInSettings(tester, finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// Settings → delete account sheet → confirm → password re-auth → done →
/// back to the guest variant of the account section.
Future<void> deleteAccountViaSettings(WidgetTester tester) async {
  await openSettingsTab(tester);
  await tapInSettings(tester, 'settings-delete-account');
  check(find.byKey(const ValueKey('delete-sheet')).evaluate()).length.equals(1);

  await tapKey(tester, 'delete-confirm');
  await enterText(tester, 'delete-password', 'okey1234');
  await tapKey(tester, 'delete-reauth-submit');
  check(find.byKey(const ValueKey('delete-done')).evaluate()).length.equals(1);

  await tapKey(tester, 'delete-done');
  check(find.byKey(const ValueKey('delete-sheet')).evaluate()).isEmpty();

  final signUpCta = find.byKey(const ValueKey('settings-signup'));
  await showInSettings(tester, signUpCta);
  check(signUpCta.evaluate()).length.equals(1);
  check(fakeAuth().currentUser).isNull();
}

// ---------------------------------------------------------------------------
// Scenarios
// ---------------------------------------------------------------------------

/// End-to-end auth & account lifecycle on the demo flavor. Run with:
///
/// ```bash
/// flutter test integration_test/auth_flow_test.dart \
///   --dart-define=APP_ENV=demo -d <device>
/// ```
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Auth flows end-to-end (demo flavor)', () {
    setUp(() async => configureDependencies('demo'));
    tearDown(() async => getIt.reset());

    testWidgets('1. email sign-in lands Home; Settings shows the account; '
        'sign-out returns to guest', (tester) async {
      await pumpApp(tester);
      await signIn(tester);

      // The router redirect (not the login screen) moves us to Home.
      check(find.byType(HomePage).evaluate()).length.equals(1);

      await openSettingsTab(tester);
      final email = find.text('oyuncu@demo.app');
      await showInSettings(tester, email);
      check(email.evaluate()).length.equals(1);

      await tapInSettings(tester, 'settings-signout');
      final signUpCta = find.byKey(const ValueKey('settings-signup'));
      await showInSettings(tester, signUpCta);
      check(signUpCta.evaluate()).length.equals(1);
      check(tester.takeException()).isNull();
    });

    testWidgets('2. sign-up creates an unverified account; resend flips to '
        'sent', (tester) async {
      await pumpApp(tester);
      await goToLogin(tester);
      await tapKey(tester, 'login-mode-toggle');
      await enterText(tester, 'login-email', 'taze@demo.app');
      await enterText(tester, 'login-password', 'parola12');
      await tapKey(tester, 'login-submit');

      check(find.byType(HomePage).evaluate()).length.equals(1);
      check(fakeAuth().verificationEmailsSentTo).deepEquals(['taze@demo.app']);

      await openSettingsTab(tester);
      final resend = find.byKey(const ValueKey('settings-resend-verification'));
      await showInSettings(tester, resend);
      check(resend.evaluate()).length.equals(1);

      await tester.tap(resend);
      await tester.pumpAndSettle();
      check(
        fakeAuth().verificationEmailsSentTo,
      ).deepEquals(['taze@demo.app', 'taze@demo.app']);
      check(tester.widget<TextButton>(resend).onPressed).isNull();
      check(tester.takeException()).isNull();
    });

    testWidgets('3. invalid credentials show the banner and leave the form '
        'usable', (tester) async {
      await pumpApp(tester);
      await signIn(tester, password: 'yanlis-parola');

      check(find.byType(LoginPage).evaluate()).length.equals(1);
      check(
        find.byKey(const ValueKey('login-error-banner')).evaluate(),
      ).length.equals(1);
      final submit = tester.widget<PrimaryButton>(
        find.byKey(const ValueKey('login-submit')),
      );
      check(submit.loading).isFalse();
      check(submit.onPressed).isNotNull();
      check(tester.takeException()).isNull();
    });

    testWidgets('4. a cancelled Google flow silently returns to idle', (
      tester,
    ) async {
      await pumpApp(tester);
      fakeAuth().mode = FakeAuthMode.providerCancelled;
      await goToLogin(tester);

      await tapKey(tester, 'login-google');

      check(find.byType(LoginPage).evaluate()).length.equals(1);
      check(
        find.byKey(const ValueKey('login-error-banner')).evaluate(),
      ).isEmpty();
      final google = tester.widget<SecondaryButton>(
        find.byKey(const ValueKey('login-google')),
      );
      check(google.loading).isFalse();
      check(google.onPressed).isNotNull();
      check(fakeAuth().currentUser).isNull();
      check(tester.takeException()).isNull();
    });

    testWidgets('5. a network error surfaces the failure banner', (
      tester,
    ) async {
      await pumpApp(tester);
      fakeAuth().mode = FakeAuthMode.networkError;
      await signIn(tester);

      check(find.byType(LoginPage).evaluate()).length.equals(1);
      check(
        find.byKey(const ValueKey('login-error-banner')).evaluate(),
      ).length.equals(1);
      check(tester.takeException()).isNull();
    });

    testWidgets('6. forgot password: sheet → submit → sent → close', (
      tester,
    ) async {
      await pumpApp(tester);
      await goToLogin(tester);

      await tapKey(tester, 'login-forgot');
      check(
        find.byKey(const ValueKey('forgot-sheet')).evaluate(),
      ).length.equals(1);

      await enterText(tester, 'forgot-email', 'oyuncu@demo.app');
      await tapKey(tester, 'forgot-submit');
      check(
        fakeAuth().passwordResetEmailsSentTo,
      ).deepEquals(['oyuncu@demo.app']);
      check(
        find.byKey(const ValueKey('forgot-done')).evaluate(),
      ).length.equals(1);

      await tapKey(tester, 'forgot-done');
      check(find.byKey(const ValueKey('forgot-sheet')).evaluate()).isEmpty();
      check(tester.takeException()).isNull();
    });

    testWidgets('7. a persisted session cold-starts straight to Home', (
      tester,
    ) async {
      fakeAuth().mode = FakeAuthMode.seededSignedIn;
      await pumpApp(tester);

      check(find.byType(HomePage).evaluate()).length.equals(1);
      check(find.byType(SplashPage).evaluate()).isEmpty();
      check(find.byKey(const ValueKey('splash-continue')).evaluate()).isEmpty();
      check(find.byKey(const ValueKey('splash-guest')).evaluate()).isEmpty();
      check(tester.takeException()).isNull();
    });

    testWidgets('8. an expired session shows the banner; sign-in reaches '
        'login; dismiss clears it', (tester) async {
      fakeAuth().mode = FakeAuthMode.sessionExpired;
      await pumpApp(tester);
      await tapKey(tester, 'splash-guest');

      final banner = find.byKey(const ValueKey('session-expired-banner'));
      check(find.byType(HomePage).evaluate()).length.equals(1);
      check(banner.evaluate()).length.equals(1);

      // The banner's sign-in action pushes the login screen.
      await tester.tap(
        find.descendant(of: banner, matching: find.byType(TextButton)),
      );
      await tester.pumpAndSettle();
      check(find.byType(LoginPage).evaluate()).length.equals(1);

      // Back: the banner survives until explicitly dismissed.
      await tapKey(tester, 'login-back');
      check(banner.evaluate()).length.equals(1);

      await tester.tap(
        find.descendant(of: banner, matching: find.byIcon(Icons.close)),
      );
      await tester.pumpAndSettle();
      check(banner.evaluate()).isEmpty();
      check(tester.takeException()).isNull();
    });

    testWidgets('9a. delete account: confirm → password re-auth → done → '
        'guest', (tester) async {
      await pumpApp(tester);
      await signIn(tester);
      check(find.byType(HomePage).evaluate()).length.equals(1);

      await deleteAccountViaSettings(tester);
      check(tester.takeException()).isNull();
    });

    testWidgets('9b. delete account under requiresRecentLogin: the re-auth '
        'satisfies the gate', (tester) async {
      await pumpApp(tester);
      fakeAuth().mode = FakeAuthMode.requiresRecentLogin;
      await signIn(tester);
      check(find.byType(HomePage).evaluate()).length.equals(1);

      await deleteAccountViaSettings(tester);
      check(tester.takeException()).isNull();
    });
  });
}
