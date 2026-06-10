part of 'login_bloc.dart';

/// Intent events for [LoginBloc] (past-tense, no `BuildContext`).
@freezed
sealed class LoginEvent with _$LoginEvent {
  /// The user toggled between sign-in and sign-up.
  const factory LoginEvent.modeToggled() = LoginModeToggled;

  /// The user submitted the email + password form.
  const factory LoginEvent.emailSubmitted({
    required String email,
    required String password,
  }) = LoginEmailSubmitted;

  /// The user tapped "Continue with Google".
  const factory LoginEvent.googleRequested() = LoginGoogleRequested;

  /// The user tapped "Continue with Apple".
  const factory LoginEvent.appleRequested() = LoginAppleRequested;

  /// The user requested a password-reset email for [email].
  const factory LoginEvent.passwordResetRequested({required String email}) =
      LoginPasswordResetRequested;

  /// The user edited a field (clears inline errors and the reset receipt).
  const factory LoginEvent.fieldsEdited() = LoginFieldsEdited;
}
