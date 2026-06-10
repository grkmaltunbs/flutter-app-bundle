import 'package:checks/checks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:okey_acar_mi/core/error/failure.dart';
import 'package:okey_acar_mi/features/auth/data/fakes/fake_auth_repository.dart';
import 'package:okey_acar_mi/features/auth/domain/entities/app_user.dart';
import 'package:okey_acar_mi/features/auth/domain/repositories/auth_repository.dart';

/// The demo fake is the backend for every simulator verification run, so its
/// seeded accounts, mode behaviors, and recorded side effects are asserted
/// exhaustively here.
void main() {
  late FakeAuthRepository fake;

  setUp(() => fake = FakeAuthRepository());

  group('seeded credentials', () {
    test('oyuncu@demo.app/okey1234 signs in as the verified account', () async {
      final user = await fake.signInWithEmail(
        email: 'oyuncu@demo.app',
        password: 'okey1234',
      );

      check(user.id).equals('demo-oyuncu');
      check(user.email).equals('oyuncu@demo.app');
      check(user.emailVerified).isTrue();
      check(user.providers).deepEquals([AuthProvider.password]);
      check(user.displayName).equals('Demo Oyuncu');
      check(fake.currentUser).equals(user);
    });

    test('yeni@demo.app/okey1234 signs in as the unverified account', () async {
      final user = await fake.signInWithEmail(
        email: 'yeni@demo.app',
        password: 'okey1234',
      );

      check(user.id).equals('demo-yeni');
      check(user.emailVerified).isFalse();
      check(user.providers).deepEquals([AuthProvider.password]);
      check(fake.currentUser).equals(user);
    });

    test(
      'a wrong password throws invalidCredentials and stays guest',
      () async {
        await check(
          fake.signInWithEmail(email: 'oyuncu@demo.app', password: 'yanlis'),
        ).throws<InvalidCredentialsFailure>();

        check(fake.currentUser).isNull();
      },
    );

    test(
      'an unknown email throws invalidCredentials (no enumeration)',
      () async {
        await check(
          fake.signInWithEmail(email: 'kimse@demo.app', password: 'okey1234'),
        ).throws<InvalidCredentialsFailure>();

        check(fake.currentUser).isNull();
      },
    );

    test('the Google flow signs in google@demo.app', () async {
      final user = await fake.signInWithGoogle();

      check(user).isNotNull();
      check(user!.email).equals('google@demo.app');
      check(user.providers).deepEquals([AuthProvider.google]);
      check(fake.currentUser).equals(user);
    });

    test('the Apple flow signs in apple@demo.app', () async {
      final user = await fake.signInWithApple();

      check(user).isNotNull();
      check(user!.email).equals('apple@demo.app');
      check(user.providers).deepEquals([AuthProvider.apple]);
      check(fake.currentUser).equals(user);
    });
  });

  group('sign-up', () {
    test(
      'a duplicate password-account email throws emailAlreadyInUse',
      () async {
        await check(
          fake.signUpWithEmail(email: 'oyuncu@demo.app', password: 'parola12'),
        ).throws<EmailAlreadyInUseFailure>();
      },
    );

    test(
      'a duplicate provider-account email throws emailAlreadyInUse',
      () async {
        await check(
          fake.signUpWithEmail(email: 'google@demo.app', password: 'parola12'),
        ).throws<EmailAlreadyInUseFailure>();
      },
    );

    test('a password shorter than 6 characters throws weakPassword', () async {
      await check(
        fake.signUpWithEmail(email: 'taze@demo.app', password: 'abc'),
      ).throws<WeakPasswordFailure>();

      check(fake.currentUser).isNull();
    });

    test('success creates an unverified session and records the verification '
        'email', () async {
      final user = await fake.signUpWithEmail(
        email: 'taze@demo.app',
        password: 'parola12',
      );

      check(user.email).equals('taze@demo.app');
      check(user.emailVerified).isFalse();
      check(user.providers).deepEquals([AuthProvider.password]);
      check(fake.currentUser).equals(user);
      check(fake.verificationEmailsSentTo).deepEquals(['taze@demo.app']);
    });

    test('a freshly created account can sign back in', () async {
      await fake.signUpWithEmail(email: 'taze@demo.app', password: 'parola12');
      await fake.signOut();
      check(fake.currentUser).isNull();

      final user = await fake.signInWithEmail(
        email: 'taze@demo.app',
        password: 'parola12',
      );

      check(user.email).equals('taze@demo.app');
    });
  });

  group('emails', () {
    test('sendPasswordResetEmail records every address in order', () async {
      await fake.sendPasswordResetEmail('oyuncu@demo.app');
      await fake.sendPasswordResetEmail('kimse@demo.app');

      check(
        fake.passwordResetEmailsSentTo,
      ).deepEquals(['oyuncu@demo.app', 'kimse@demo.app']);
    });

    test('sendEmailVerification records the signed-in address', () async {
      await fake.signInWithEmail(email: 'yeni@demo.app', password: 'okey1234');

      await fake.sendEmailVerification();

      check(fake.verificationEmailsSentTo).deepEquals(['yeni@demo.app']);
    });

    test('sendEmailVerification is a no-op for a guest', () async {
      await fake.sendEmailVerification();

      check(fake.verificationEmailsSentTo).isEmpty();
    });
  });

  group('restoreSession per mode', () {
    test('signedOut restores no session', () async {
      check(await fake.restoreSession()).isNull();
      check(fake.currentUser).isNull();
    });

    test('seededSignedIn restores the verified seeded account', () async {
      fake.mode = FakeAuthMode.seededSignedIn;

      final user = await fake.restoreSession();

      check(user).isNotNull();
      check(user!.email).equals('oyuncu@demo.app');
      check(user.emailVerified).isTrue();
      check(fake.currentUser).equals(user);
    });

    test('seededUnverified restores the unverified seeded account', () async {
      fake.mode = FakeAuthMode.seededUnverified;

      final user = await fake.restoreSession();

      check(user).isNotNull();
      check(user!.email).equals('yeni@demo.app');
      check(user.emailVerified).isFalse();
    });

    test('sessionExpired throws sessionExpired', () async {
      fake.mode = FakeAuthMode.sessionExpired;

      await check(fake.restoreSession()).throws<SessionExpiredFailure>();
    });

    test('networkError / providerCancelled / requiresRecentLogin restore '
        'nothing', () async {
      for (final mode in [
        FakeAuthMode.networkError,
        FakeAuthMode.providerCancelled,
        FakeAuthMode.requiresRecentLogin,
      ]) {
        fake.mode = mode;
        check(await fake.restoreSession()).isNull();
      }
    });
  });

  group('networkError mode', () {
    setUp(() => fake.mode = FakeAuthMode.networkError);

    test('email sign-in throws network', () async {
      await check(
        fake.signInWithEmail(email: 'oyuncu@demo.app', password: 'okey1234'),
      ).throws<NetworkFailure>();
    });

    test('sign-up throws network', () async {
      await check(
        fake.signUpWithEmail(email: 'taze@demo.app', password: 'parola12'),
      ).throws<NetworkFailure>();
    });

    test('Google and Apple sign-in throw network', () async {
      await check(fake.signInWithGoogle()).throws<NetworkFailure>();
      await check(fake.signInWithApple()).throws<NetworkFailure>();
    });

    test('password reset throws network and records nothing', () async {
      await check(
        fake.sendPasswordResetEmail('oyuncu@demo.app'),
      ).throws<NetworkFailure>();

      check(fake.passwordResetEmailsSentTo).isEmpty();
    });

    test('deleteAccount throws network', () async {
      await check(fake.deleteAccount()).throws<NetworkFailure>();
    });
  });

  group('providerCancelled mode', () {
    setUp(() => fake.mode = FakeAuthMode.providerCancelled);

    test('Google and Apple sign-in resolve to null (no failure)', () async {
      check(await fake.signInWithGoogle()).isNull();
      check(await fake.signInWithApple()).isNull();
      check(fake.currentUser).isNull();
    });

    test('provider re-auth resolves to false (cancelled)', () async {
      check(await fake.reauthenticate(ReauthMethod.google)).isFalse();
      check(await fake.reauthenticate(ReauthMethod.apple)).isFalse();
    });

    test('password re-auth is unaffected by the mode', () async {
      fake.mode = FakeAuthMode.signedOut;
      await fake.signInWithEmail(
        email: 'oyuncu@demo.app',
        password: 'okey1234',
      );
      fake.mode = FakeAuthMode.providerCancelled;

      check(
        await fake.reauthenticate(ReauthMethod.password, password: 'okey1234'),
      ).isTrue();
    });
  });

  group('requiresRecentLogin mode', () {
    test('deleteAccount is gated until a successful re-auth', () async {
      await fake.signInWithEmail(
        email: 'oyuncu@demo.app',
        password: 'okey1234',
      );
      fake.mode = FakeAuthMode.requiresRecentLogin;

      await check(fake.deleteAccount()).throws<RequiresRecentLoginFailure>();
      check(fake.currentUser).isNotNull();

      check(
        await fake.reauthenticate(ReauthMethod.password, password: 'okey1234'),
      ).isTrue();

      await fake.deleteAccount();
      check(fake.currentUser).isNull();
    });

    test('a wrong re-auth password throws invalidCredentials and keeps the '
        'gate', () async {
      await fake.signInWithEmail(
        email: 'oyuncu@demo.app',
        password: 'okey1234',
      );
      fake.mode = FakeAuthMode.requiresRecentLogin;

      await check(
        fake.reauthenticate(ReauthMethod.password, password: 'yanlis'),
      ).throws<InvalidCredentialsFailure>();
      await check(fake.deleteAccount()).throws<RequiresRecentLoginFailure>();
    });

    test('signOut resets the recent-authentication flag', () async {
      await fake.signInWithEmail(
        email: 'oyuncu@demo.app',
        password: 'okey1234',
      );
      fake.mode = FakeAuthMode.requiresRecentLogin;
      await fake.reauthenticate(ReauthMethod.password, password: 'okey1234');

      await fake.signOut();
      await fake.signInWithEmail(
        email: 'oyuncu@demo.app',
        password: 'okey1234',
      );

      await check(fake.deleteAccount()).throws<RequiresRecentLoginFailure>();
    });
  });

  group('deleteAccount', () {
    test(
      'removes the account: the deleted user can no longer sign in',
      () async {
        await fake.signInWithEmail(
          email: 'oyuncu@demo.app',
          password: 'okey1234',
        );

        await fake.deleteAccount();

        check(fake.currentUser).isNull();
        await check(
          fake.signInWithEmail(email: 'oyuncu@demo.app', password: 'okey1234'),
        ).throws<InvalidCredentialsFailure>();
      },
    );

    test('resets the recent-authentication gate', () async {
      await fake.signInWithEmail(
        email: 'oyuncu@demo.app',
        password: 'okey1234',
      );
      await fake.reauthenticate(ReauthMethod.password, password: 'okey1234');
      await fake.deleteAccount();

      // A later session must re-authenticate again before deleting.
      fake.mode = FakeAuthMode.requiresRecentLogin;
      await fake.signInWithEmail(email: 'yeni@demo.app', password: 'okey1234');

      await check(fake.deleteAccount()).throws<RequiresRecentLoginFailure>();
    });
  });

  group('authStateChanges', () {
    test('replays the current value on listen, then emits changes', () async {
      await fake.signInWithEmail(
        email: 'oyuncu@demo.app',
        password: 'okey1234',
      );

      final emissions = <AppUser?>[];
      final subscription = fake.authStateChanges().listen(emissions.add);
      addTearDown(subscription.cancel);

      await pumpEventQueue();
      check(emissions).length.equals(1);
      check(emissions.single?.email).equals('oyuncu@demo.app');

      await fake.signOut();
      await pumpEventQueue();
      check(emissions).length.equals(2);
      check(emissions.last).isNull();
    });

    test('does not drop an emission landing in the listen microtask window '
        '(no subscribe gap)', () async {
      final emissions = <AppUser?>[];
      final subscription = fake.authStateChanges().listen(emissions.add);
      addTearDown(subscription.cancel);

      // No event-loop turn between listen and the change: the fake mutates
      // its state synchronously, so this emission lands in the microtask
      // window a generator-based stream would still be subscribing in.
      await fake.signInWithEmail(
        email: 'oyuncu@demo.app',
        password: 'okey1234',
      );
      await pumpEventQueue();

      check(emissions).length.equals(2);
      check(emissions.first).isNull();
      check(emissions.last?.email).equals('oyuncu@demo.app');
    });

    test('replays null for a guest, then follows a sign-in', () async {
      final emissions = <AppUser?>[];
      final subscription = fake.authStateChanges().listen(emissions.add);
      addTearDown(subscription.cancel);

      await pumpEventQueue();
      check(emissions).deepEquals([null]);

      await fake.signInWithEmail(
        email: 'oyuncu@demo.app',
        password: 'okey1234',
      );
      await pumpEventQueue();
      check(emissions).length.equals(2);
      check(emissions.last?.email).equals('oyuncu@demo.app');
    });
  });

  group('reset', () {
    test('restores the defaults: mode, seeds, records, and session', () async {
      fake.mode = FakeAuthMode.requiresRecentLogin;
      await fake.signUpWithEmail(email: 'taze@demo.app', password: 'parola12');
      await fake.sendPasswordResetEmail('oyuncu@demo.app');

      fake.reset();

      check(fake.mode).equals(FakeAuthMode.signedOut);
      check(fake.currentUser).isNull();
      check(fake.verificationEmailsSentTo).isEmpty();
      check(fake.passwordResetEmailsSentTo).isEmpty();

      // The signed-up account is gone; the seeded accounts survive.
      await check(
        fake.signInWithEmail(email: 'taze@demo.app', password: 'parola12'),
      ).throws<InvalidCredentialsFailure>();
      final user = await fake.signInWithEmail(
        email: 'oyuncu@demo.app',
        password: 'okey1234',
      );
      check(user.email).equals('oyuncu@demo.app');
    });
  });
}
