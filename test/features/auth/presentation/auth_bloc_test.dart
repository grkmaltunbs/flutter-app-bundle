import 'package:bloc_test/bloc_test.dart';
import 'package:checks/checks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:okey_acar_mi/core/di/injection.dart';
import 'package:okey_acar_mi/features/auth/data/fakes/fake_auth_repository.dart';
import 'package:okey_acar_mi/features/auth/domain/entities/app_user.dart';
import 'package:okey_acar_mi/features/auth/domain/repositories/auth_repository.dart';
import 'package:okey_acar_mi/features/auth/presentation/blocs/auth_bloc.dart';

/// The verified seeded account ([FakeAuthRepository] seeds it as
/// `oyuncu@demo.app`). The bloc tests assert the bloc surfaces exactly this
/// user — not just "some" authenticated state.
const _oyuncu = AppUser(
  id: 'demo-oyuncu',
  email: 'oyuncu@demo.app',
  emailVerified: true,
  providers: [AuthProvider.password],
  displayName: 'Demo Oyuncu',
);

const _yeni = AppUser(
  id: 'demo-yeni',
  email: 'yeni@demo.app',
  emailVerified: false,
  providers: [AuthProvider.password],
);

void main() {
  setUp(() async => configureDependencies('demo'));
  tearDown(() async => getIt.reset());

  FakeAuthRepository fake() => getIt<AuthRepository>() as FakeAuthRepository;

  group('AuthBloc', () {
    test('initial state is AuthState.unknown', () {
      final bloc = getIt<AuthBloc>();
      addTearDown(bloc.close);

      check(bloc.state).equals(const AuthState.unknown());
    });

    group('started', () {
      blocTest<AuthBloc, AuthState>(
        'restores the seeded session into authenticated',
        setUp: () => fake().mode = FakeAuthMode.seededSignedIn,
        build: getIt.get<AuthBloc>,
        act: (bloc) => bloc.add(const AuthEvent.started()),
        expect: () => const <AuthState>[AuthState.authenticated(_oyuncu)],
      );

      blocTest<AuthBloc, AuthState>(
        'lands on plain guest when no session exists',
        build: getIt.get<AuthBloc>,
        act: (bloc) => bloc.add(const AuthEvent.started()),
        expect: () => const <AuthState>[AuthState.guest()],
      );

      blocTest<AuthBloc, AuthState>(
        'an expired session lands on guest with the sessionExpired flag '
        "(surviving the stream's immediate null replay)",
        setUp: () => fake().mode = FakeAuthMode.sessionExpired,
        build: getIt.get<AuthBloc>,
        act: (bloc) async {
          bloc.add(const AuthEvent.started());
          await pumpEventQueue();
        },
        expect: () => const <AuthState>[AuthState.guest(sessionExpired: true)],
      );
    });

    group('auth stream', () {
      blocTest<AuthBloc, AuthState>(
        'a sign-in after start moves guest → authenticated',
        build: getIt.get<AuthBloc>,
        act: (bloc) async {
          bloc.add(const AuthEvent.started());
          await pumpEventQueue();
          await fake().signInWithEmail(
            email: 'oyuncu@demo.app',
            password: 'okey1234',
          );
          await pumpEventQueue();
        },
        expect: () => const <AuthState>[
          AuthState.guest(),
          AuthState.authenticated(_oyuncu),
        ],
      );

      blocTest<AuthBloc, AuthState>(
        'a mid-session null moves authenticated → guest WITHOUT the '
        'sessionExpired flag',
        setUp: () => fake().mode = FakeAuthMode.seededSignedIn,
        build: getIt.get<AuthBloc>,
        act: (bloc) async {
          bloc.add(const AuthEvent.started());
          await pumpEventQueue();
          await fake().signOut();
          await pumpEventQueue();
        },
        expect: () => const <AuthState>[
          AuthState.authenticated(_oyuncu),
          AuthState.guest(),
        ],
      );
    });

    group('signOutRequested', () {
      blocTest<AuthBloc, AuthState>(
        'signs the session out back to plain guest',
        setUp: () => fake().mode = FakeAuthMode.seededSignedIn,
        build: getIt.get<AuthBloc>,
        act: (bloc) async {
          bloc.add(const AuthEvent.started());
          await pumpEventQueue();
          bloc.add(const AuthEvent.signOutRequested());
          await pumpEventQueue();
        },
        expect: () => const <AuthState>[
          AuthState.authenticated(_oyuncu),
          AuthState.guest(),
        ],
        verify: (_) => check(fake().currentUser).isNull(),
      );
    });

    group('verificationEmailResendRequested', () {
      blocTest<AuthBloc, AuthState>(
        're-sends the verification email without any state change',
        setUp: () => fake().mode = FakeAuthMode.seededUnverified,
        build: getIt.get<AuthBloc>,
        act: (bloc) async {
          bloc.add(const AuthEvent.started());
          await pumpEventQueue();
          bloc.add(const AuthEvent.verificationEmailResendRequested());
          await pumpEventQueue();
        },
        expect: () => const <AuthState>[AuthState.authenticated(_yeni)],
        verify: (_) => check(
          fake().verificationEmailsSentTo,
        ).deepEquals(['yeni@demo.app']),
      );
    });

    group('sessionExpiredDismissed', () {
      blocTest<AuthBloc, AuthState>(
        'clears the sessionExpired flag',
        setUp: () => fake().mode = FakeAuthMode.sessionExpired,
        build: getIt.get<AuthBloc>,
        act: (bloc) async {
          bloc.add(const AuthEvent.started());
          await pumpEventQueue();
          bloc.add(const AuthEvent.sessionExpiredDismissed());
        },
        expect: () => const <AuthState>[
          AuthState.guest(sessionExpired: true),
          AuthState.guest(),
        ],
      );
    });

    group('close', () {
      test('cancels the auth subscription (stream events after close are '
          'ignored)', () async {
        final bloc = getIt<AuthBloc>()..add(const AuthEvent.started());
        await pumpEventQueue();
        check(bloc.state).equals(const AuthState.guest());

        await bloc.close();

        // Were the subscription still alive, this emission would add an event
        // to a closed bloc and throw a StateError out of the listener.
        await fake().signInWithEmail(
          email: 'oyuncu@demo.app',
          password: 'okey1234',
        );
        await pumpEventQueue();

        check(bloc.state).equals(const AuthState.guest());
      });
    });
  });
}
