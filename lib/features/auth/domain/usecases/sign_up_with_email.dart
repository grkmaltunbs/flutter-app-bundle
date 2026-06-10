import 'package:injectable/injectable.dart';
import 'package:okey_acar_mi/features/auth/domain/entities/app_user.dart';
import 'package:okey_acar_mi/features/auth/domain/repositories/auth_repository.dart';
import 'package:okey_acar_mi/features/auth/domain/services/guest_data_migrator.dart';

/// Creates an email + password account, then migrates guest data onto it.
@injectable
class SignUpWithEmail {
  /// Creates a [SignUpWithEmail].
  const SignUpWithEmail(this._repository, this._migrator);

  final AuthRepository _repository;
  final GuestDataMigrator _migrator;

  /// Executes the use case. Throws a `Failure` when sign-up fails.
  Future<AppUser> call({
    required String email,
    required String password,
  }) async {
    final user = await _repository.signUpWithEmail(
      email: email,
      password: password,
    );
    try {
      await _migrator.migrateGuestData(toUserId: user.id);
    } on Object {
      // A migration failure must never fail the sign-up itself; the user is
      // authenticated either way. Swallow silently (Step 9 adds real
      // migration with logging).
    }
    return user;
  }
}
