import 'package:checks/checks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:okey_acar_mi/core/error/failure.dart';
import 'package:okey_acar_mi/features/auth/domain/entities/app_user.dart';
import 'package:okey_acar_mi/features/auth/domain/repositories/auth_repository.dart';
import 'package:okey_acar_mi/features/auth/domain/services/guest_data_migrator.dart';
import 'package:okey_acar_mi/features/auth/domain/usecases/sign_in_with_apple.dart';
import 'package:okey_acar_mi/features/auth/domain/usecases/sign_in_with_email.dart';
import 'package:okey_acar_mi/features/auth/domain/usecases/sign_in_with_google.dart';
import 'package:okey_acar_mi/features/auth/domain/usecases/sign_up_with_email.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

class _MockGuestDataMigrator extends Mock implements GuestDataMigrator {}

const _user = AppUser(
  id: 'user-1',
  email: 'user@example.com',
  emailVerified: true,
  providers: [AuthProvider.password],
);

void main() {
  late _MockAuthRepository repository;
  late _MockGuestDataMigrator migrator;

  setUp(() {
    repository = _MockAuthRepository();
    migrator = _MockGuestDataMigrator();
    when(
      () => migrator.migrateGuestData(toUserId: any(named: 'toUserId')),
    ).thenAnswer((_) async {});
  });

  void verifyNoMigration() => verifyNever(
    () => migrator.migrateGuestData(toUserId: any(named: 'toUserId')),
  );

  group('SignInWithEmail', () {
    test(
      'success returns the user and migrates guest data to user.id',
      () async {
        when(
          () => repository.signInWithEmail(
            email: 'user@example.com',
            password: 'parola12',
          ),
        ).thenAnswer((_) async => _user);
        final useCase = SignInWithEmail(repository, migrator);

        final result = await useCase(
          email: 'user@example.com',
          password: 'parola12',
        );

        check(result).equals(_user);
        verify(() => migrator.migrateGuestData(toUserId: 'user-1')).called(1);
      },
    );

    test('a repository failure propagates and migration never runs', () async {
      when(
        () => repository.signInWithEmail(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenThrow(const Failure.invalidCredentials());
      final useCase = SignInWithEmail(repository, migrator);

      await check(
        useCase(email: 'user@example.com', password: 'yanlis'),
      ).throws<InvalidCredentialsFailure>();

      verifyNoMigration();
    });

    test('a migrator crash is swallowed; sign-in still succeeds', () async {
      when(
        () => repository.signInWithEmail(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenAnswer((_) async => _user);
      when(
        () => migrator.migrateGuestData(toUserId: any(named: 'toUserId')),
      ).thenThrow(Exception('migration boom'));
      final useCase = SignInWithEmail(repository, migrator);

      final result = await useCase(
        email: 'user@example.com',
        password: 'parola12',
      );

      check(result).equals(_user);
    });
  });

  group('SignUpWithEmail', () {
    test(
      'success returns the user and migrates guest data to user.id',
      () async {
        when(
          () => repository.signUpWithEmail(
            email: 'user@example.com',
            password: 'parola12',
          ),
        ).thenAnswer((_) async => _user);
        final useCase = SignUpWithEmail(repository, migrator);

        final result = await useCase(
          email: 'user@example.com',
          password: 'parola12',
        );

        check(result).equals(_user);
        verify(() => migrator.migrateGuestData(toUserId: 'user-1')).called(1);
      },
    );

    test('a repository failure propagates and migration never runs', () async {
      when(
        () => repository.signUpWithEmail(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenThrow(const Failure.emailAlreadyInUse());
      final useCase = SignUpWithEmail(repository, migrator);

      await check(
        useCase(email: 'user@example.com', password: 'parola12'),
      ).throws<EmailAlreadyInUseFailure>();

      verifyNoMigration();
    });

    test('a migrator crash is swallowed; sign-up still succeeds', () async {
      when(
        () => repository.signUpWithEmail(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenAnswer((_) async => _user);
      when(
        () => migrator.migrateGuestData(toUserId: any(named: 'toUserId')),
      ).thenThrow(Exception('migration boom'));
      final useCase = SignUpWithEmail(repository, migrator);

      final result = await useCase(
        email: 'user@example.com',
        password: 'parola12',
      );

      check(result).equals(_user);
    });
  });

  group('SignInWithGoogle', () {
    test('success returns the user and migrates guest data', () async {
      when(repository.signInWithGoogle).thenAnswer((_) async => _user);
      final useCase = SignInWithGoogle(repository, migrator);

      final result = await useCase();

      check(result).equals(_user);
      verify(() => migrator.migrateGuestData(toUserId: 'user-1')).called(1);
    });

    test('cancellation (null) returns null and skips migration', () async {
      when(repository.signInWithGoogle).thenAnswer((_) async => null);
      final useCase = SignInWithGoogle(repository, migrator);

      final result = await useCase();

      check(result).isNull();
      verifyNoMigration();
    });

    test('a repository failure propagates and migration never runs', () async {
      when(repository.signInWithGoogle).thenThrow(const Failure.network());
      final useCase = SignInWithGoogle(repository, migrator);

      await check(useCase()).throws<NetworkFailure>();

      verifyNoMigration();
    });

    test('a migrator crash is swallowed; sign-in still succeeds', () async {
      when(repository.signInWithGoogle).thenAnswer((_) async => _user);
      when(
        () => migrator.migrateGuestData(toUserId: any(named: 'toUserId')),
      ).thenThrow(Exception('migration boom'));
      final useCase = SignInWithGoogle(repository, migrator);

      check(await useCase()).equals(_user);
    });
  });

  group('SignInWithApple', () {
    test('success returns the user and migrates guest data', () async {
      when(repository.signInWithApple).thenAnswer((_) async => _user);
      final useCase = SignInWithApple(repository, migrator);

      final result = await useCase();

      check(result).equals(_user);
      verify(() => migrator.migrateGuestData(toUserId: 'user-1')).called(1);
    });

    test('cancellation (null) returns null and skips migration', () async {
      when(repository.signInWithApple).thenAnswer((_) async => null);
      final useCase = SignInWithApple(repository, migrator);

      final result = await useCase();

      check(result).isNull();
      verifyNoMigration();
    });

    test('a repository failure propagates and migration never runs', () async {
      when(repository.signInWithApple).thenThrow(const Failure.network());
      final useCase = SignInWithApple(repository, migrator);

      await check(useCase()).throws<NetworkFailure>();

      verifyNoMigration();
    });

    test('a migrator crash is swallowed; sign-in still succeeds', () async {
      when(repository.signInWithApple).thenAnswer((_) async => _user);
      when(
        () => migrator.migrateGuestData(toUserId: any(named: 'toUserId')),
      ).thenThrow(Exception('migration boom'));
      final useCase = SignInWithApple(repository, migrator);

      check(await useCase()).equals(_user);
    });
  });
}
