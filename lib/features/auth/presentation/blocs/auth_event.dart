part of 'auth_bloc.dart';

/// Intent events for [AuthBloc] (past-tense, no `BuildContext`).
@freezed
sealed class AuthEvent with _$AuthEvent {
  /// App start: restore the session, then follow the auth stream.
  const factory AuthEvent.started() = AuthStarted;

  /// The user asked to sign out.
  const factory AuthEvent.signOutRequested() = AuthSignOutRequested;

  /// The user asked to re-send the verification email.
  const factory AuthEvent.verificationEmailResendRequested() =
      AuthVerificationEmailResendRequested;

  /// The user dismissed the session-expired banner.
  const factory AuthEvent.sessionExpiredDismissed() =
      AuthSessionExpiredDismissed;

  /// Internal: the repository's auth stream emitted [user] (null = guest).
  const factory AuthEvent.sessionChanged(AppUser? user) = AuthSessionChanged;
}
