part of 'auth_bloc.dart';

/// Sealed session state for [AuthBloc].
@freezed
sealed class AuthState with _$AuthState {
  /// Boot: the session has not been restored yet.
  const factory AuthState.unknown() = AuthUnknown;

  /// Signed out — the user is a guest. [sessionExpired] is true only when a
  /// persisted session failed to restore at startup (drives the banner).
  const factory AuthState.guest({@Default(false) bool sessionExpired}) =
      AuthGuest;

  /// Signed in as [user].
  const factory AuthState.authenticated(AppUser user) = AuthAuthenticated;
}
