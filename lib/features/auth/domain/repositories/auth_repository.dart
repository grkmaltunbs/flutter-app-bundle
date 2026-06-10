import 'package:okey_acar_mi/features/auth/domain/entities/app_user.dart';

/// How the user proves their identity again for sensitive operations.
enum ReauthMethod {
  /// Re-enter the account password.
  password,

  /// Re-run the Google Sign-In flow.
  google,

  /// Re-run the Sign in with Apple flow.
  apple,
}

/// Authentication and account-lifecycle access.
///
/// Implementations THROW typed `Failure`s (never raw infrastructure errors).
/// Provider sign-in cancellation is NOT a failure: cancelled flows resolve to
/// `null` (sign-in) or `false` (re-auth) so callers can silently return to
/// idle.
abstract class AuthRepository {
  /// Emits the current [AppUser] immediately on listen, then every change.
  /// `null` means guest (signed out).
  Stream<AppUser?> authStateChanges();

  /// The currently signed-in user, or `null` for guest.
  AppUser? get currentUser;

  /// Restores a persisted session at startup.
  ///
  /// Returns the restored [AppUser], or `null` when no session exists. Throws
  /// `Failure.sessionExpired` when the stored session can no longer be
  /// refreshed; a transient network error keeps the cached session.
  Future<AppUser?> restoreSession();

  /// Signs in with email + password.
  ///
  /// Throws `Failure.invalidCredentials`, `Failure.network`, or
  /// `Failure.tooManyRequests`.
  Future<AppUser> signInWithEmail({
    required String email,
    required String password,
  });

  /// Creates an account with email + password and sends a verification email.
  ///
  /// Throws `Failure.emailAlreadyInUse`, `Failure.weakPassword`, or
  /// `Failure.network`.
  Future<AppUser> signUpWithEmail({
    required String email,
    required String password,
  });

  /// Runs the Google Sign-In flow. Returns `null` when the user cancels.
  Future<AppUser?> signInWithGoogle();

  /// Runs the Sign in with Apple flow (iOS-only in v1). Returns `null` when
  /// the user cancels.
  Future<AppUser?> signInWithApple();

  /// Sends a password-reset email. Always succeeds for unknown emails (no
  /// account enumeration).
  Future<void> sendPasswordResetEmail(String email);

  /// (Re-)sends the verification email to the current user.
  Future<void> sendEmailVerification();

  /// Re-authenticates the current user via [method].
  ///
  /// Returns `false` when the user cancels a provider flow. Throws
  /// `Failure.invalidCredentials` on a wrong [password].
  Future<bool> reauthenticate(ReauthMethod method, {String? password});

  /// Permanently deletes the current account.
  ///
  /// Throws `Failure.requiresRecentLogin` when the session is too stale.
  Future<void> deleteAccount();

  /// Signs the current user out (back to guest).
  Future<void> signOut();
}
