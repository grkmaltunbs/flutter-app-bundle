import 'package:bloc_test/bloc_test.dart';
import 'package:checks/checks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:okey_acar_mi/core/di/injection.dart';
import 'package:okey_acar_mi/core/error/failure.dart';
import 'package:okey_acar_mi/features/auth/data/fakes/fake_auth_repository.dart';
import 'package:okey_acar_mi/features/auth/domain/repositories/auth_repository.dart';
import 'package:okey_acar_mi/features/auth/domain/usecases/sign_up_with_email.dart';
import 'package:okey_acar_mi/features/auth/presentation/blocs/login_bloc.dart';

class _MockSignUpWithEmail extends Mock implements SignUpWithEmail {}

/// Every [LoginBloc] path against the real demo fake (mocktail only where the
/// fake cannot produce the behavior). Each `expect:` pins the exact emitted
/// state list, so every terminal state is also asserted to be back at
/// `inFlight: none`.
void main() {
  setUp(() async => configureDependencies('demo'));
  tearDown(() async => getIt.reset());

  FakeAuthRepository fake() => getIt<AuthRepository>() as FakeAuthRepository;

  group('LoginBloc', () {
    test('initial state is an idle sign-in form', () {
      final bloc = getIt<LoginBloc>();
      addTearDown(bloc.close);

      check(bloc.state).equals(const LoginState());
    });

    group('email sign-in', () {
      blocTest<LoginBloc, LoginState>(
        'success passes through inFlight and ends idle with no failure',
        build: getIt.get<LoginBloc>,
        act: (bloc) => bloc.add(
          const LoginEvent.emailSubmitted(
            email: 'oyuncu@demo.app',
            password: 'okey1234',
          ),
        ),
        expect: () => const <LoginState>[
          LoginState(inFlight: LoginInFlight.email),
          LoginState(),
        ],
        verify: (_) =>
            check(fake().currentUser?.email).equals('oyuncu@demo.app'),
      );

      blocTest<LoginBloc, LoginState>(
        'invalid credentials surface as a failure banner, back to idle',
        build: getIt.get<LoginBloc>,
        act: (bloc) => bloc.add(
          const LoginEvent.emailSubmitted(
            email: 'oyuncu@demo.app',
            password: 'yanlis',
          ),
        ),
        expect: () => const <LoginState>[
          LoginState(inFlight: LoginInFlight.email),
          LoginState(failure: Failure.invalidCredentials()),
        ],
      );

      blocTest<LoginBloc, LoginState>(
        'a second emailSubmitted while in flight is ignored (re-entrancy)',
        build: getIt.get<LoginBloc>,
        seed: () => const LoginState(inFlight: LoginInFlight.email),
        act: (bloc) => bloc.add(
          const LoginEvent.emailSubmitted(
            email: 'oyuncu@demo.app',
            password: 'okey1234',
          ),
        ),
        expect: () => const <LoginState>[],
        verify: (_) => check(fake().currentUser).isNull(),
      );

      blocTest<LoginBloc, LoginState>(
        'an empty email is rejected inline without going in flight',
        build: getIt.get<LoginBloc>,
        act: (bloc) => bloc.add(
          const LoginEvent.emailSubmitted(email: '', password: 'okey1234'),
        ),
        expect: () => const <LoginState>[
          LoginState(emailError: EmailFieldError.empty),
        ],
      );

      blocTest<LoginBloc, LoginState>(
        'a malformed email is rejected inline without going in flight',
        build: getIt.get<LoginBloc>,
        act: (bloc) => bloc.add(
          const LoginEvent.emailSubmitted(
            email: 'not-an-email',
            password: 'okey1234',
          ),
        ),
        expect: () => const <LoginState>[
          LoginState(emailError: EmailFieldError.invalid),
        ],
      );
    });

    group('email sign-up', () {
      blocTest<LoginBloc, LoginState>(
        'a short password is rejected inline before the repository is hit',
        build: getIt.get<LoginBloc>,
        seed: () => const LoginState(mode: LoginMode.signUp),
        act: (bloc) => bloc.add(
          const LoginEvent.emailSubmitted(
            email: 'taze@demo.app',
            password: 'abc',
          ),
        ),
        expect: () => const <LoginState>[
          LoginState(
            mode: LoginMode.signUp,
            passwordError: PasswordFieldError.tooShort,
          ),
        ],
        verify: (_) => check(fake().currentUser).isNull(),
      );

      blocTest<LoginBloc, LoginState>(
        'a duplicate email lands on the email field as alreadyInUse',
        build: getIt.get<LoginBloc>,
        seed: () => const LoginState(mode: LoginMode.signUp),
        act: (bloc) => bloc.add(
          const LoginEvent.emailSubmitted(
            email: 'oyuncu@demo.app',
            password: 'parola12',
          ),
        ),
        expect: () => const <LoginState>[
          LoginState(mode: LoginMode.signUp, inFlight: LoginInFlight.email),
          LoginState(
            mode: LoginMode.signUp,
            emailError: EmailFieldError.alreadyInUse,
          ),
        ],
      );

      blocTest<LoginBloc, LoginState>(
        'a repository WeakPasswordFailure lands on the password field',
        build: () {
          // The fake's weak-password rule coincides with the submit
          // validation, so a mock forces the repository-side failure.
          final signUp = _MockSignUpWithEmail();
          when(
            () => signUp.call(
              email: any(named: 'email'),
              password: any(named: 'password'),
            ),
          ).thenThrow(const Failure.weakPassword());
          return LoginBloc(getIt(), signUp, getIt(), getIt(), getIt());
        },
        seed: () => const LoginState(mode: LoginMode.signUp),
        act: (bloc) => bloc.add(
          const LoginEvent.emailSubmitted(
            email: 'taze@demo.app',
            password: 'parola12',
          ),
        ),
        expect: () => const <LoginState>[
          LoginState(mode: LoginMode.signUp, inFlight: LoginInFlight.email),
          LoginState(
            mode: LoginMode.signUp,
            passwordError: PasswordFieldError.tooShort,
          ),
        ],
      );
    });

    group('Google sign-in', () {
      blocTest<LoginBloc, LoginState>(
        'success passes through inFlight and ends idle',
        build: getIt.get<LoginBloc>,
        act: (bloc) => bloc.add(const LoginEvent.googleRequested()),
        expect: () => const <LoginState>[
          LoginState(inFlight: LoginInFlight.google),
          LoginState(),
        ],
        verify: (_) =>
            check(fake().currentUser?.email).equals('google@demo.app'),
      );

      blocTest<LoginBloc, LoginState>(
        'cancellation silently returns to idle — no failure',
        setUp: () => fake().mode = FakeAuthMode.providerCancelled,
        build: getIt.get<LoginBloc>,
        act: (bloc) => bloc.add(const LoginEvent.googleRequested()),
        expect: () => const <LoginState>[
          LoginState(inFlight: LoginInFlight.google),
          LoginState(),
        ],
        verify: (_) => check(fake().currentUser).isNull(),
      );

      blocTest<LoginBloc, LoginState>(
        'a network error surfaces as a failure banner',
        setUp: () => fake().mode = FakeAuthMode.networkError,
        build: getIt.get<LoginBloc>,
        act: (bloc) => bloc.add(const LoginEvent.googleRequested()),
        expect: () => const <LoginState>[
          LoginState(inFlight: LoginInFlight.google),
          LoginState(failure: Failure.network()),
        ],
      );
    });

    group('Apple sign-in', () {
      blocTest<LoginBloc, LoginState>(
        'success passes through inFlight and ends idle',
        build: getIt.get<LoginBloc>,
        act: (bloc) => bloc.add(const LoginEvent.appleRequested()),
        expect: () => const <LoginState>[
          LoginState(inFlight: LoginInFlight.apple),
          LoginState(),
        ],
        verify: (_) =>
            check(fake().currentUser?.email).equals('apple@demo.app'),
      );

      blocTest<LoginBloc, LoginState>(
        'cancellation silently returns to idle — no failure',
        setUp: () => fake().mode = FakeAuthMode.providerCancelled,
        build: getIt.get<LoginBloc>,
        act: (bloc) => bloc.add(const LoginEvent.appleRequested()),
        expect: () => const <LoginState>[
          LoginState(inFlight: LoginInFlight.apple),
          LoginState(),
        ],
        verify: (_) => check(fake().currentUser).isNull(),
      );
    });

    group('password reset', () {
      blocTest<LoginBloc, LoginState>(
        'a valid email sends the reset and sets the receipt',
        build: getIt.get<LoginBloc>,
        act: (bloc) => bloc.add(
          const LoginEvent.passwordResetRequested(email: 'oyuncu@demo.app'),
        ),
        expect: () => const <LoginState>[
          LoginState(inFlight: LoginInFlight.reset),
          LoginState(resetEmailSent: true),
        ],
        verify: (_) => check(
          fake().passwordResetEmailsSentTo,
        ).deepEquals(['oyuncu@demo.app']),
      );

      blocTest<LoginBloc, LoginState>(
        'an invalid email is rejected inline without going in flight',
        build: getIt.get<LoginBloc>,
        act: (bloc) => bloc.add(
          const LoginEvent.passwordResetRequested(email: 'not-an-email'),
        ),
        expect: () => const <LoginState>[
          LoginState(emailError: EmailFieldError.invalid),
        ],
        verify: (_) => check(fake().passwordResetEmailsSentTo).isEmpty(),
      );

      blocTest<LoginBloc, LoginState>(
        'a network error surfaces as a failure banner',
        setUp: () => fake().mode = FakeAuthMode.networkError,
        build: getIt.get<LoginBloc>,
        act: (bloc) => bloc.add(
          const LoginEvent.passwordResetRequested(email: 'oyuncu@demo.app'),
        ),
        expect: () => const <LoginState>[
          LoginState(inFlight: LoginInFlight.reset),
          LoginState(failure: Failure.network()),
        ],
      );
    });

    group('mode + editing', () {
      blocTest<LoginBloc, LoginState>(
        'modeToggled flips signIn → signUp and resets every error',
        build: getIt.get<LoginBloc>,
        seed: () => const LoginState(
          emailError: EmailFieldError.invalid,
          failure: Failure.network(),
        ),
        act: (bloc) => bloc.add(const LoginEvent.modeToggled()),
        expect: () => const <LoginState>[LoginState(mode: LoginMode.signUp)],
      );

      blocTest<LoginBloc, LoginState>(
        'modeToggled flips signUp → signIn',
        build: getIt.get<LoginBloc>,
        seed: () => const LoginState(mode: LoginMode.signUp),
        act: (bloc) => bloc.add(const LoginEvent.modeToggled()),
        expect: () => const <LoginState>[LoginState()],
      );

      blocTest<LoginBloc, LoginState>(
        'fieldsEdited clears field errors, the failure, and the reset receipt',
        build: getIt.get<LoginBloc>,
        seed: () => const LoginState(
          emailError: EmailFieldError.empty,
          passwordError: PasswordFieldError.empty,
          failure: Failure.network(),
          resetEmailSent: true,
        ),
        act: (bloc) => bloc.add(const LoginEvent.fieldsEdited()),
        expect: () => const <LoginState>[LoginState()],
      );
    });
  });
}
