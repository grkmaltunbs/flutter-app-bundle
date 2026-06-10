import 'dart:async';

import 'package:injectable/injectable.dart';
import 'package:okey_acar_mi/core/error/failure.dart';
import 'package:okey_acar_mi/features/auth/domain/entities/app_user.dart';
import 'package:okey_acar_mi/features/auth/domain/repositories/auth_repository.dart';

/// The auth states the demo fake can be driven into, so every flow (restore,
/// expiry, cancellation, errors, deletion re-auth) is reachable on a
/// simulator without a backend.
enum FakeAuthMode {
  /// No session: the app boots as guest (default).
  signedOut,

  /// Restores the verified seeded account (`oyuncu@demo.app`).
  seededSignedIn,

  /// Restores the unverified seeded account (`yeni@demo.app`).
  seededUnverified,

  /// Session restore fails with `Failure.sessionExpired`.
  sessionExpired,

  /// Network-dependent operations throw `Failure.network`.
  networkError,

  /// Provider (Google/Apple) flows resolve as user-cancelled.
  providerCancelled,

  /// Account deletion requires re-authentication first.
  requiresRecentLogin,
}

/// Closes the [FakeAuthRepository]'s stream controller when the DI container
/// resets (`getIt.reset()`).
///
/// A top-level adapter (instead of `@disposeMethod`) because the fake is
/// registered as [AuthRepository], and the generated dispose callback is
/// typed against that interface.
void disposeFakeAuthRepository(AuthRepository instance) =>
    (instance as FakeAuthRepository).dispose();

/// In-memory, seeded [AuthRepository] for the demo flavor.
///
/// Deterministic, offline, instant — no artificial delays, no Firebase. Flip
/// [mode] (it is a `demo`-scoped singleton, so tests resolve it from the DI
/// container and set the mode) to drive expiry, error, and cancellation
/// paths. [verificationEmailsSentTo] / [passwordResetEmailsSentTo] record the
/// emails the fake "sent" so tests can assert on them.
@Environment('demo')
@LazySingleton(as: AuthRepository, dispose: disposeFakeAuthRepository)
class FakeAuthRepository implements AuthRepository {
  /// Creates a [FakeAuthRepository] in the [FakeAuthMode.signedOut] state.
  FakeAuthRepository();

  /// Controls the behavior of every operation. Defaults to
  /// [FakeAuthMode.signedOut].
  FakeAuthMode mode = FakeAuthMode.signedOut;

  /// Every address a verification email was "sent" to, in order.
  final List<String> verificationEmailsSentTo = <String>[];

  /// Every address a password-reset email was "sent" to, in order.
  final List<String> passwordResetEmailsSentTo = <String>[];

  static const AppUser _oyuncu = AppUser(
    id: 'demo-oyuncu',
    email: 'oyuncu@demo.app',
    emailVerified: true,
    providers: [AuthProvider.password],
    displayName: 'Demo Oyuncu',
  );

  static const AppUser _yeni = AppUser(
    id: 'demo-yeni',
    email: 'yeni@demo.app',
    emailVerified: false,
    providers: [AuthProvider.password],
  );

  static const AppUser _google = AppUser(
    id: 'demo-google',
    email: 'google@demo.app',
    emailVerified: true,
    providers: [AuthProvider.google],
    displayName: 'Google Oyuncu',
  );

  static const AppUser _apple = AppUser(
    id: 'demo-apple',
    email: 'apple@demo.app',
    emailVerified: true,
    providers: [AuthProvider.apple],
    displayName: 'Apple Oyuncu',
  );

  static const String _seedPassword = 'okey1234';

  /// email → (password, user) for the email/password accounts. Sign-up adds
  /// to it so freshly created demo accounts can sign back in.
  final Map<String, ({String password, AppUser user})> _passwordAccounts = {
    _oyuncu.email: (password: _seedPassword, user: _oyuncu),
    _yeni.email: (password: _seedPassword, user: _yeni),
  };

  final StreamController<AppUser?> _controller =
      StreamController<AppUser?>.broadcast();

  AppUser? _current;
  bool _recentlyAuthenticated = false;
  int _newUserCounter = 0;

  /// Restores the fake to its defaults (signed out, seeded accounts only).
  void reset() {
    mode = FakeAuthMode.signedOut;
    verificationEmailsSentTo.clear();
    passwordResetEmailsSentTo.clear();
    _passwordAccounts
      ..clear()
      ..[_oyuncu.email] = (password: _seedPassword, user: _oyuncu)
      ..[_yeni.email] = (password: _seedPassword, user: _yeni);
    _recentlyAuthenticated = false;
    _newUserCounter = 0;
    _setCurrent(null);
  }

  void _setCurrent(AppUser? user) {
    _current = user;
    _controller.add(user);
  }

  @override
  Stream<AppUser?> authStateChanges() {
    // Gap-free replay: `async*` would yield the current value and only then
    // subscribe to the broadcast controller, dropping any emission landing in
    // that microtask window. Stream.multi subscribes synchronously on listen.
    return Stream<AppUser?>.multi((listener) {
      listener
        ..add(_current)
        ..addStream(_controller.stream).ignore();
    });
  }

  @override
  AppUser? get currentUser => _current;

  @override
  Future<AppUser?> restoreSession() async {
    switch (mode) {
      case FakeAuthMode.seededSignedIn:
        _setCurrent(_oyuncu);
        return _oyuncu;
      case FakeAuthMode.seededUnverified:
        _setCurrent(_yeni);
        return _yeni;
      case FakeAuthMode.sessionExpired:
        throw const Failure.sessionExpired();
      case FakeAuthMode.signedOut:
      case FakeAuthMode.networkError:
      case FakeAuthMode.providerCancelled:
      case FakeAuthMode.requiresRecentLogin:
        return null;
    }
  }

  @override
  Future<AppUser> signInWithEmail({
    required String email,
    required String password,
  }) async {
    if (mode == FakeAuthMode.networkError) throw const Failure.network();
    final account = _passwordAccounts[email];
    if (account == null || account.password != password) {
      throw const Failure.invalidCredentials();
    }
    _setCurrent(account.user);
    return account.user;
  }

  @override
  Future<AppUser> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    if (mode == FakeAuthMode.networkError) throw const Failure.network();
    final existingEmails = {
      ..._passwordAccounts.keys,
      _google.email,
      _apple.email,
    };
    if (existingEmails.contains(email)) {
      throw const Failure.emailAlreadyInUse();
    }
    if (password.length < 6) throw const Failure.weakPassword();
    final user = AppUser(
      id: 'demo-new-${++_newUserCounter}',
      email: email,
      emailVerified: false,
      providers: const [AuthProvider.password],
    );
    _passwordAccounts[email] = (password: password, user: user);
    verificationEmailsSentTo.add(email);
    _setCurrent(user);
    return user;
  }

  @override
  Future<AppUser?> signInWithGoogle() async {
    if (mode == FakeAuthMode.providerCancelled) return null;
    if (mode == FakeAuthMode.networkError) throw const Failure.network();
    _setCurrent(_google);
    return _google;
  }

  @override
  Future<AppUser?> signInWithApple() async {
    if (mode == FakeAuthMode.providerCancelled) return null;
    if (mode == FakeAuthMode.networkError) throw const Failure.network();
    _setCurrent(_apple);
    return _apple;
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    if (mode == FakeAuthMode.networkError) throw const Failure.network();
    passwordResetEmailsSentTo.add(email);
  }

  @override
  Future<void> sendEmailVerification() async {
    final current = _current;
    if (current == null) return;
    verificationEmailsSentTo.add(current.email);
  }

  @override
  Future<bool> reauthenticate(ReauthMethod method, {String? password}) async {
    switch (method) {
      case ReauthMethod.password:
        final current = _current;
        if (current == null) return false;
        final stored = _passwordAccounts[current.email];
        if (stored == null || stored.password != password) {
          throw const Failure.invalidCredentials();
        }
        _recentlyAuthenticated = true;
        return true;
      case ReauthMethod.google:
      case ReauthMethod.apple:
        if (mode == FakeAuthMode.providerCancelled) return false;
        _recentlyAuthenticated = true;
        return true;
    }
  }

  @override
  Future<void> deleteAccount() async {
    if (mode == FakeAuthMode.requiresRecentLogin && !_recentlyAuthenticated) {
      throw const Failure.requiresRecentLogin();
    }
    if (mode == FakeAuthMode.networkError) throw const Failure.network();
    // Actually delete: the account can no longer sign back in.
    final current = _current;
    if (current != null) _passwordAccounts.remove(current.email);
    _recentlyAuthenticated = false;
    _setCurrent(null);
  }

  @override
  Future<void> signOut() async {
    _recentlyAuthenticated = false;
    _setCurrent(null);
  }

  /// Closes the auth-state controller; called via
  /// [disposeFakeAuthRepository] when the DI container resets.
  void dispose() => _controller.close();
}
