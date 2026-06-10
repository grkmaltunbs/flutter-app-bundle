import 'package:injectable/injectable.dart';
import 'package:okey_acar_mi/features/auth/domain/entities/app_user.dart';
import 'package:okey_acar_mi/features/auth/domain/repositories/auth_repository.dart';
import 'package:okey_acar_mi/features/auth/domain/services/guest_data_migrator.dart';

/// Runs the Sign in with Apple flow, then migrates guest data to the account.
@injectable
class SignInWithApple {
  /// Creates a [SignInWithApple].
  const SignInWithApple(this._repository, this._migrator);

  final AuthRepository _repository;
  final GuestDataMigrator _migrator;

  /// Executes the use case. Returns `null` when the user cancels (no
  /// migration runs). Throws a `Failure` when sign-in fails.
  Future<AppUser?> call() async {
    final user = await _repository.signInWithApple();
    if (user == null) return null;
    try {
      await _migrator.migrateGuestData(toUserId: user.id);
    } on Object {
      // A migration failure must never fail the sign-in itself; the user is
      // authenticated either way. Swallow silently (Step 9 adds real
      // migration with logging).
    }
    return user;
  }
}
