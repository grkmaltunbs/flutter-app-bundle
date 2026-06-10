import 'package:firebase_auth/firebase_auth.dart';
import 'package:okey_acar_mi/core/error/failure.dart';

/// Maps a [FirebaseAuthException] into a typed [Failure].
///
/// Credential-ish codes (wrong password, unknown user, malformed email…) all
/// collapse into [Failure.invalidCredentials] so the UI never leaks whether
/// an account exists.
Failure mapFirebaseAuthError(FirebaseAuthException exception) {
  return switch (exception.code) {
    'invalid-credential' ||
    'wrong-password' ||
    'user-not-found' ||
    'invalid-email' ||
    'user-mismatch' ||
    // firebase_auth lowercases server codes; the uppercase arm stays as
    // belt-and-braces for SDKs that pass the raw server code through.
    'invalid-login-credentials' ||
    'INVALID_LOGIN_CREDENTIALS' => const Failure.invalidCredentials(),
    'email-already-in-use' ||
    'credential-already-in-use' ||
    'account-exists-with-different-credential' =>
      const Failure.emailAlreadyInUse(),
    'weak-password' => const Failure.weakPassword(),
    'requires-recent-login' => const Failure.requiresRecentLogin(),
    'user-token-expired' ||
    'invalid-user-token' ||
    'user-disabled' => const Failure.sessionExpired(),
    'network-request-failed' => const Failure.network(),
    'too-many-requests' => const Failure.tooManyRequests(),
    final code => Failure.unexpected(code),
  };
}
