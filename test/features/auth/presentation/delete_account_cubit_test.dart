import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:checks/checks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:okey_acar_mi/core/di/injection.dart';
import 'package:okey_acar_mi/core/error/failure.dart';
import 'package:okey_acar_mi/features/auth/data/fakes/fake_auth_repository.dart';
import 'package:okey_acar_mi/features/auth/domain/repositories/auth_repository.dart';
import 'package:okey_acar_mi/features/auth/presentation/blocs/delete_account_cubit.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  setUp(() async => configureDependencies('demo'));
  tearDown(() async => getIt.reset());

  FakeAuthRepository fake() => getIt<AuthRepository>() as FakeAuthRepository;

  Future<void> signInSeeded() => fake().signInWithEmail(
    email: 'oyuncu@demo.app',
    password: 'okey1234',
  );

  group('DeleteAccountCubit', () {
    test('initial state is the confirm step', () {
      final cubit = getIt<DeleteAccountCubit>();
      addTearDown(cubit.close);

      check(cubit.state).equals(const DeleteAccountState.confirm());
    });

    blocTest<DeleteAccountCubit, DeleteAccountState>(
      'confirmRequested moves confirm → reauth',
      build: getIt.get<DeleteAccountCubit>,
      act: (cubit) => cubit.confirmRequested(),
      expect: () => const <DeleteAccountState>[DeleteAccountState.reauth()],
    );

    blocTest<DeleteAccountCubit, DeleteAccountState>(
      'a correct password re-auth deletes the account: reauth(inFlight) → '
      'deleting → done',
      setUp: signInSeeded,
      build: getIt.get<DeleteAccountCubit>,
      seed: () => const DeleteAccountState.reauth(),
      act: (cubit) => cubit.reauthWithPassword('okey1234'),
      expect: () => const <DeleteAccountState>[
        DeleteAccountState.reauth(inFlight: true),
        DeleteAccountState.deleting(),
        DeleteAccountState.done(),
      ],
      verify: (_) => check(fake().currentUser).isNull(),
    );

    blocTest<DeleteAccountCubit, DeleteAccountState>(
      'a wrong password flags the field and keeps the account',
      setUp: signInSeeded,
      build: getIt.get<DeleteAccountCubit>,
      seed: () => const DeleteAccountState.reauth(),
      act: (cubit) => cubit.reauthWithPassword('yanlis'),
      expect: () => const <DeleteAccountState>[
        DeleteAccountState.reauth(inFlight: true),
        DeleteAccountState.reauth(wrongPassword: true),
      ],
      verify: (_) => check(fake().currentUser).isNotNull(),
    );

    blocTest<DeleteAccountCubit, DeleteAccountState>(
      'a cancelled provider re-auth silently returns to the reauth step '
      '(no failure, no wrongPassword)',
      setUp: () async {
        await fake().signInWithGoogle();
        fake().mode = FakeAuthMode.providerCancelled;
      },
      build: getIt.get<DeleteAccountCubit>,
      seed: () => const DeleteAccountState.reauth(),
      act: (cubit) => cubit.reauthWithProvider(ReauthMethod.google),
      expect: () => const <DeleteAccountState>[
        DeleteAccountState.reauth(inFlight: true),
        DeleteAccountState.reauth(),
      ],
      verify: (_) => check(fake().currentUser?.email).equals('google@demo.app'),
    );

    blocTest<DeleteAccountCubit, DeleteAccountState>(
      'requiresRecentLogin mode: a successful re-auth satisfies the deletion '
      'gate end-to-end',
      setUp: () async {
        await signInSeeded();
        fake().mode = FakeAuthMode.requiresRecentLogin;
      },
      build: getIt.get<DeleteAccountCubit>,
      seed: () => const DeleteAccountState.reauth(),
      act: (cubit) => cubit.reauthWithPassword('okey1234'),
      expect: () => const <DeleteAccountState>[
        DeleteAccountState.reauth(inFlight: true),
        DeleteAccountState.deleting(),
        DeleteAccountState.done(),
      ],
      verify: (_) => check(fake().currentUser).isNull(),
    );

    blocTest<DeleteAccountCubit, DeleteAccountState>(
      'a stale-session deleteAccount surfaces requiresRecentLogin inline; '
      'the retried re-auth then deletes',
      // The fake's re-auth always satisfies its own gate, so a mock forces
      // the delete-after-reauth staleness Firebase can produce.
      build: () {
        final repository = _MockAuthRepository();
        when(
          () => repository.reauthenticate(
            ReauthMethod.password,
            password: any(named: 'password'),
          ),
        ).thenAnswer((_) async => true);
        var deleteCalls = 0;
        when(repository.deleteAccount).thenAnswer((_) async {
          deleteCalls++;
          if (deleteCalls == 1) throw const Failure.requiresRecentLogin();
        });
        return DeleteAccountCubit(repository);
      },
      seed: () => const DeleteAccountState.reauth(),
      act: (cubit) async {
        await cubit.reauthWithPassword('okey1234');
        await cubit.reauthWithPassword('okey1234');
      },
      expect: () => const <DeleteAccountState>[
        DeleteAccountState.reauth(inFlight: true),
        DeleteAccountState.deleting(),
        DeleteAccountState.reauth(failure: Failure.requiresRecentLogin()),
        DeleteAccountState.reauth(inFlight: true),
        DeleteAccountState.deleting(),
        DeleteAccountState.done(),
      ],
    );

    test('closing the cubit mid-re-auth neither throws nor deletes', () async {
      final repository = _MockAuthRepository();
      final reauthCompleter = Completer<bool>();
      when(
        () => repository.reauthenticate(
          ReauthMethod.password,
          password: any(named: 'password'),
        ),
      ).thenAnswer((_) => reauthCompleter.future);
      final cubit = DeleteAccountCubit(repository);

      final pending = cubit.reauthWithPassword('okey1234');
      await cubit.close();
      reauthCompleter.complete(true);
      // Must not throw an emit-after-close StateError.
      await pending;

      check(
        cubit.state,
      ).equals(const DeleteAccountState.reauth(inFlight: true));
      verifyNever(repository.deleteAccount);
    });

    blocTest<DeleteAccountCubit, DeleteAccountState>(
      'a network failure during deletion returns to reauth with the failure',
      setUp: () async {
        await signInSeeded();
        fake().mode = FakeAuthMode.networkError;
      },
      build: getIt.get<DeleteAccountCubit>,
      seed: () => const DeleteAccountState.reauth(),
      act: (cubit) => cubit.reauthWithPassword('okey1234'),
      expect: () => const <DeleteAccountState>[
        DeleteAccountState.reauth(inFlight: true),
        DeleteAccountState.deleting(),
        DeleteAccountState.reauth(failure: Failure.network()),
      ],
      verify: (_) => check(fake().currentUser).isNotNull(),
    );
  });
}
