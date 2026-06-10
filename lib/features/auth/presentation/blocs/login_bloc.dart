import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';
import 'package:okey_acar_mi/core/error/error_mapper.dart';
import 'package:okey_acar_mi/core/error/failure.dart';
import 'package:okey_acar_mi/features/auth/domain/repositories/auth_repository.dart';
import 'package:okey_acar_mi/features/auth/domain/usecases/sign_in_with_apple.dart';
import 'package:okey_acar_mi/features/auth/domain/usecases/sign_in_with_email.dart';
import 'package:okey_acar_mi/features/auth/domain/usecases/sign_in_with_google.dart';
import 'package:okey_acar_mi/features/auth/domain/usecases/sign_up_with_email.dart';

part 'login_bloc.freezed.dart';
part 'login_event.dart';
part 'login_state.dart';

/// Validates the email shape on submit (`^\S+@\S+\.\S+$`).
final RegExp _emailPattern = RegExp(r'^\S+@\S+\.\S+$');

/// Screen-scoped bloc for the sign-in / sign-up form.
///
/// Validation runs on submit only; editing any field clears the inline
/// errors. Cancelled provider flows (null from the use case) silently return
/// to idle — no failure, no toast (D2). Successful sign-in never navigates:
/// the router redirect does (D8). Holds no subscriptions, so [close] is not
/// overridden.
@injectable
class LoginBloc extends Bloc<LoginEvent, LoginState> {
  /// Creates a [LoginBloc].
  LoginBloc(
    this._signInWithEmail,
    this._signUpWithEmail,
    this._signInWithGoogle,
    this._signInWithApple,
    this._repository,
  ) : super(const LoginState()) {
    on<LoginModeToggled>(_onModeToggled);
    on<LoginEmailSubmitted>(_onEmailSubmitted);
    on<LoginGoogleRequested>(_onGoogleRequested);
    on<LoginAppleRequested>(_onAppleRequested);
    on<LoginPasswordResetRequested>(_onPasswordResetRequested);
    on<LoginFieldsEdited>(_onFieldsEdited);
  }

  final SignInWithEmail _signInWithEmail;
  final SignUpWithEmail _signUpWithEmail;
  final SignInWithGoogle _signInWithGoogle;
  final SignInWithApple _signInWithApple;
  final AuthRepository _repository;

  static EmailFieldError? _validateEmail(String email) {
    if (email.isEmpty) return EmailFieldError.empty;
    if (!_emailPattern.hasMatch(email)) return EmailFieldError.invalid;
    return null;
  }

  static PasswordFieldError? _validatePassword(
    String password,
    LoginMode mode,
  ) {
    if (password.isEmpty) return PasswordFieldError.empty;
    if (mode == LoginMode.signUp && password.length < 6) {
      return PasswordFieldError.tooShort;
    }
    return null;
  }

  void _onModeToggled(LoginModeToggled event, Emitter<LoginState> emit) {
    emit(
      LoginState(
        mode: state.mode == LoginMode.signIn
            ? LoginMode.signUp
            : LoginMode.signIn,
      ),
    );
  }

  void _onFieldsEdited(LoginFieldsEdited event, Emitter<LoginState> emit) {
    emit(
      state.copyWith(
        emailError: null,
        passwordError: null,
        failure: null,
        resetEmailSent: false,
      ),
    );
  }

  Future<void> _onEmailSubmitted(
    LoginEmailSubmitted event,
    Emitter<LoginState> emit,
  ) async {
    // Re-entrancy guard: ignore submits while another attempt is in flight.
    if (state.inFlight != LoginInFlight.none) return;
    final emailError = _validateEmail(event.email);
    final passwordError = _validatePassword(event.password, state.mode);
    if (emailError != null || passwordError != null) {
      // Validation failures never set inFlight.
      emit(
        state.copyWith(
          emailError: emailError,
          passwordError: passwordError,
          failure: null,
          resetEmailSent: false,
        ),
      );
      return;
    }
    emit(
      state.copyWith(
        inFlight: LoginInFlight.email,
        emailError: null,
        passwordError: null,
        failure: null,
        resetEmailSent: false,
      ),
    );
    try {
      if (state.mode == LoginMode.signIn) {
        await _signInWithEmail(email: event.email, password: event.password);
      } else {
        await _signUpWithEmail(email: event.email, password: event.password);
      }
      // Success: back to idle — the router redirect handles navigation.
      emit(state.copyWith(inFlight: LoginInFlight.none));
    } on EmailAlreadyInUseFailure {
      emit(
        state.copyWith(
          inFlight: LoginInFlight.none,
          emailError: EmailFieldError.alreadyInUse,
        ),
      );
    } on WeakPasswordFailure {
      emit(
        state.copyWith(
          inFlight: LoginInFlight.none,
          passwordError: PasswordFieldError.tooShort,
        ),
      );
    } on Failure catch (failure) {
      emit(state.copyWith(inFlight: LoginInFlight.none, failure: failure));
    } on Object catch (error) {
      emit(
        state.copyWith(
          inFlight: LoginInFlight.none,
          failure: mapToFailure(error),
        ),
      );
    }
  }

  Future<void> _onGoogleRequested(
    LoginGoogleRequested event,
    Emitter<LoginState> emit,
  ) => _onProviderRequested(LoginInFlight.google, _signInWithGoogle.call, emit);

  Future<void> _onAppleRequested(
    LoginAppleRequested event,
    Emitter<LoginState> emit,
  ) => _onProviderRequested(LoginInFlight.apple, _signInWithApple.call, emit);

  Future<void> _onProviderRequested(
    LoginInFlight inFlight,
    Future<Object?> Function() signIn,
    Emitter<LoginState> emit,
  ) async {
    // Re-entrancy guard: ignore requests while another attempt is in flight.
    if (state.inFlight != LoginInFlight.none) return;
    emit(
      state.copyWith(
        inFlight: inFlight,
        emailError: null,
        passwordError: null,
        failure: null,
        resetEmailSent: false,
      ),
    );
    try {
      // Null = cancelled: silently back to idle, no failure (D2). Success
      // also just returns to idle — the router redirect navigates.
      await signIn();
      emit(state.copyWith(inFlight: LoginInFlight.none));
    } on Failure catch (failure) {
      emit(state.copyWith(inFlight: LoginInFlight.none, failure: failure));
    } on Object catch (error) {
      emit(
        state.copyWith(
          inFlight: LoginInFlight.none,
          failure: mapToFailure(error),
        ),
      );
    }
  }

  Future<void> _onPasswordResetRequested(
    LoginPasswordResetRequested event,
    Emitter<LoginState> emit,
  ) async {
    // Re-entrancy guard: ignore requests while another attempt is in flight.
    if (state.inFlight != LoginInFlight.none) return;
    final emailError = _validateEmail(event.email);
    if (emailError != null) {
      emit(
        state.copyWith(
          emailError: emailError,
          failure: null,
          resetEmailSent: false,
        ),
      );
      return;
    }
    emit(
      state.copyWith(
        inFlight: LoginInFlight.reset,
        emailError: null,
        failure: null,
        resetEmailSent: false,
      ),
    );
    try {
      await _repository.sendPasswordResetEmail(event.email);
      emit(state.copyWith(inFlight: LoginInFlight.none, resetEmailSent: true));
    } on Failure catch (failure) {
      emit(state.copyWith(inFlight: LoginInFlight.none, failure: failure));
    } on Object catch (error) {
      emit(
        state.copyWith(
          inFlight: LoginInFlight.none,
          failure: mapToFailure(error),
        ),
      );
    }
  }
}
