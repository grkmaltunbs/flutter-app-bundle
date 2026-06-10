import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';
import 'package:okey_acar_mi/core/error/failure.dart';
import 'package:okey_acar_mi/features/auth/domain/entities/app_user.dart';
import 'package:okey_acar_mi/features/auth/domain/repositories/auth_repository.dart';

part 'auth_bloc.freezed.dart';
part 'auth_event.dart';
part 'auth_state.dart';

/// App-scoped session bloc: restores the persisted session at startup, then
/// mirrors the repository's auth stream into [AuthState].
///
/// Signed-out IS the guest state (D3): there is no separate "guest mode".
/// Holds a stream subscription, so [close] is overridden.
@lazySingleton
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  /// Creates an [AuthBloc].
  AuthBloc(this._repository) : super(const AuthState.unknown()) {
    on<AuthStarted>(_onStarted);
    on<AuthSignOutRequested>(_onSignOutRequested);
    on<AuthVerificationEmailResendRequested>(_onVerificationResendRequested);
    on<AuthSessionExpiredDismissed>(_onSessionExpiredDismissed);
    on<AuthSessionChanged>(_onSessionChanged);
  }

  final AuthRepository _repository;
  StreamSubscription<AppUser?>? _subscription;

  Future<void> _onStarted(AuthStarted event, Emitter<AuthState> emit) async {
    try {
      final user = await _repository.restoreSession();
      emit(
        user == null ? const AuthState.guest() : AuthState.authenticated(user),
      );
    } on SessionExpiredFailure {
      emit(const AuthState.guest(sessionExpired: true));
    } on Object {
      // Any other restore failure degrades to a plain guest (no banner).
      emit(const AuthState.guest());
    }
    await _subscription?.cancel();
    _subscription = _repository.authStateChanges().listen(
      (user) => add(AuthEvent.sessionChanged(user)),
    );
  }

  void _onSessionChanged(AuthSessionChanged event, Emitter<AuthState> emit) {
    final user = event.user;
    if (user == null) {
      // Skip when already guest so a startup-expired banner survives the
      // stream's immediate null; mid-session sign-outs never set the flag.
      if (state is! AuthGuest) emit(const AuthState.guest());
      return;
    }
    emit(AuthState.authenticated(user));
  }

  Future<void> _onSignOutRequested(
    AuthSignOutRequested event,
    Emitter<AuthState> emit,
  ) async {
    try {
      await _repository.signOut();
      // The auth stream emits null and sessionChanged moves us to guest.
    } on Object {
      // Even if the backend sign-out fails, the user asked to leave.
      emit(const AuthState.guest());
    }
  }

  Future<void> _onVerificationResendRequested(
    AuthVerificationEmailResendRequested event,
    Emitter<AuthState> emit,
  ) async {
    try {
      await _repository.sendEmailVerification();
    } on Object {
      // Fire-and-forget: a failed re-send changes no state.
    }
  }

  void _onSessionExpiredDismissed(
    AuthSessionExpiredDismissed event,
    Emitter<AuthState> emit,
  ) {
    if (state is AuthGuest) emit(const AuthState.guest());
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}
