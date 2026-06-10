part of 'login_bloc.dart';

/// Whether the form signs into an existing account or creates one.
enum LoginMode {
  /// Sign in to an existing account.
  signIn,

  /// Create a new account.
  signUp,
}

/// Which (single) login operation is currently in flight.
enum LoginInFlight {
  /// Idle.
  none,

  /// Email sign-in / sign-up.
  email,

  /// Google provider flow.
  google,

  /// Apple provider flow.
  apple,

  /// Password-reset email send.
  reset,
}

/// Inline validation errors for the email field.
enum EmailFieldError {
  /// The field is empty.
  empty,

  /// The value does not look like an email address.
  invalid,

  /// Sign-up: the address is already registered.
  alreadyInUse,
}

/// Inline validation errors for the password field.
enum PasswordFieldError {
  /// The field is empty.
  empty,

  /// Sign-up: shorter than 6 characters.
  tooShort,
}

/// Form state for [LoginBloc]: mode, in-flight operation, inline field
/// errors, the banner [failure], and the password-reset receipt.
@freezed
abstract class LoginState with _$LoginState {
  /// Creates a [LoginState]. Defaults to an idle sign-in form.
  const factory LoginState({
    @Default(LoginMode.signIn) LoginMode mode,
    @Default(LoginInFlight.none) LoginInFlight inFlight,
    EmailFieldError? emailError,
    PasswordFieldError? passwordError,
    Failure? failure,
    @Default(false) bool resetEmailSent,
  }) = _LoginState;
}
