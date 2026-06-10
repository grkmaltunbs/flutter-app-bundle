import 'package:checks/checks.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:okey_acar_mi/core/error/failure.dart';
import 'package:okey_acar_mi/features/auth/data/repositories/auth_error_mapper.dart';

/// The full FirebaseAuthException code → [Failure] table. Credential-ish
/// codes collapse into invalidCredentials so the UI never leaks whether an
/// account exists.
const _table = <String, Failure>{
  'invalid-credential': Failure.invalidCredentials(),
  'wrong-password': Failure.invalidCredentials(),
  'user-not-found': Failure.invalidCredentials(),
  'invalid-email': Failure.invalidCredentials(),
  'user-mismatch': Failure.invalidCredentials(),
  'INVALID_LOGIN_CREDENTIALS': Failure.invalidCredentials(),
  'email-already-in-use': Failure.emailAlreadyInUse(),
  'credential-already-in-use': Failure.emailAlreadyInUse(),
  'account-exists-with-different-credential': Failure.emailAlreadyInUse(),
  'weak-password': Failure.weakPassword(),
  'requires-recent-login': Failure.requiresRecentLogin(),
  'user-token-expired': Failure.sessionExpired(),
  'invalid-user-token': Failure.sessionExpired(),
  'user-disabled': Failure.sessionExpired(),
  'network-request-failed': Failure.network(),
  'too-many-requests': Failure.tooManyRequests(),
};

void main() {
  group('mapFirebaseAuthError', () {
    for (final entry in _table.entries) {
      test('maps ${entry.key} → ${entry.value}', () {
        final failure = mapFirebaseAuthError(
          FirebaseAuthException(code: entry.key),
        );

        check(failure).equals(entry.value);
      });
    }

    test('maps an unknown code → unexpected carrying the code', () {
      final failure = mapFirebaseAuthError(
        FirebaseAuthException(code: 'something-novel'),
      );

      check(failure).equals(const Failure.unexpected('something-novel'));
    });
  });
}
