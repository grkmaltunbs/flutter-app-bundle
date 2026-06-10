import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:injectable/injectable.dart';
import 'package:okey_acar_mi/core/error/failure.dart';
import 'package:okey_acar_mi/features/auth/data/repositories/auth_error_mapper.dart';
import 'package:okey_acar_mi/features/auth/domain/entities/app_user.dart';
import 'package:okey_acar_mi/features/auth/domain/repositories/auth_repository.dart';

/// The web OAuth client id (`client_type: 3` in
/// `android/app/google-services.json`), required by Google Sign-In v7 on
/// Android to mint an idToken Firebase accepts.
const String _googleServerClientId =
    '187450447184-0qvu82i768r88jouqomlj3dqoasla3pv.apps.googleusercontent.com';

/// Firebase Auth codes that mean a Sign in with Apple flow was cancelled.
const Set<String> _appleCancelledCodes = {
  'canceled',
  'web-context-canceled',
  'user-cancelled',
};

/// Firebase Auth codes that mean the persisted session is gone for good.
const Set<String> _deadSessionCodes = {
  'user-token-expired',
  'invalid-user-token',
  'user-disabled',
  'user-not-found',
};

/// Production [AuthRepository] backed by Firebase Auth + Google Sign-In v7 +
/// Sign in with Apple (via `FirebaseAuth.signInWithProvider`).
///
/// All infrastructure errors are mapped to typed `Failure`s; user-cancelled
/// provider flows resolve to `null` / `false`, never a failure.
@Environment('prod')
@LazySingleton(as: AuthRepository)
class FirebaseAuthRepository implements AuthRepository {
  /// Creates a [FirebaseAuthRepository] on the default Firebase app.
  FirebaseAuthRepository()
    : _auth = FirebaseAuth.instance,
      _googleSignIn = GoogleSignIn.instance;

  /// Creates a [FirebaseAuthRepository] with injected SDKs, for tests.
  @visibleForTesting
  FirebaseAuthRepository.withAuth(this._auth, this._googleSignIn);

  final FirebaseAuth _auth;
  final GoogleSignIn _googleSignIn;

  /// Shared one-shot initialization future: concurrent callers await the same
  /// in-flight `initialize()` instead of racing a boolean flag.
  Future<void>? _googleInit;

  AppUser _mapUser(User user) {
    final providers = <AuthProvider>[
      for (final info in user.providerData)
        ...switch (info.providerId) {
          'password' => const [AuthProvider.password],
          'google.com' => const [AuthProvider.google],
          'apple.com' => const [AuthProvider.apple],
          // Unknown linked providers are ignored.
          _ => const <AuthProvider>[],
        },
    ];
    return AppUser(
      id: user.uid,
      email: user.email ?? '',
      emailVerified: user.emailVerified,
      providers: providers,
      displayName: user.displayName,
    );
  }

  @override
  Stream<AppUser?> authStateChanges() =>
      _auth.userChanges().map((user) => user == null ? null : _mapUser(user));

  @override
  AppUser? get currentUser {
    final user = _auth.currentUser;
    return user == null ? null : _mapUser(user);
  }

  @override
  Future<AppUser?> restoreSession() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    try {
      await user.getIdToken();
      return _mapUser(_auth.currentUser ?? user);
    } on FirebaseAuthException catch (exception) {
      if (_deadSessionCodes.contains(exception.code)) {
        await _auth.signOut();
        throw const Failure.sessionExpired();
      }
      if (exception.code == 'network-request-failed') {
        // Transient network trouble keeps the cached session alive.
        return _mapUser(user);
      }
      throw mapFirebaseAuthError(exception);
    }
  }

  @override
  Future<AppUser> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return _mapUser(credential.user!);
    } on FirebaseAuthException catch (exception) {
      throw mapFirebaseAuthError(exception);
    }
  }

  @override
  Future<AppUser> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = credential.user!;
      try {
        await user.sendEmailVerification();
      } on Object {
        // A failed verification send must not fail the sign-up; the user can
        // re-send from Settings.
      }
      return _mapUser(user);
    } on FirebaseAuthException catch (exception) {
      throw mapFirebaseAuthError(exception);
    }
  }

  Future<void> _ensureGoogleInitialized() async {
    _googleInit ??= _googleSignIn.initialize(
      serverClientId: _googleServerClientId,
    );
    await _googleInit;
  }

  @override
  Future<AppUser?> signInWithGoogle() async {
    try {
      await _ensureGoogleInitialized();
      final account = await _googleSignIn.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null) {
        throw const Failure.unexpected('google-sign-in/no-id-token');
      }
      final credential = GoogleAuthProvider.credential(idToken: idToken);
      final userCredential = await _auth.signInWithCredential(credential);
      return _mapUser(userCredential.user!);
    } on GoogleSignInException catch (exception) {
      if (exception.code == GoogleSignInExceptionCode.canceled) return null;
      throw Failure.unexpected(
        'google-sign-in/${exception.code.name}: ${exception.description}',
      );
    } on FirebaseAuthException catch (exception) {
      throw mapFirebaseAuthError(exception);
    }
  }

  @override
  Future<AppUser?> signInWithApple() async {
    try {
      final provider = AppleAuthProvider()
        ..addScope('email')
        ..addScope('name');
      final credential = await _auth.signInWithProvider(provider);
      return _mapUser(credential.user!);
    } on FirebaseAuthException catch (exception) {
      if (_appleCancelledCodes.contains(exception.code)) return null;
      throw mapFirebaseAuthError(exception);
    }
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (exception) {
      // Unknown emails must look like success (no account enumeration).
      if (exception.code == 'user-not-found') return;
      throw mapFirebaseAuthError(exception);
    }
  }

  @override
  Future<void> sendEmailVerification() async {
    final user = _auth.currentUser;
    if (user == null) return;
    try {
      await user.sendEmailVerification();
    } on FirebaseAuthException catch (exception) {
      throw mapFirebaseAuthError(exception);
    }
  }

  @override
  Future<bool> reauthenticate(ReauthMethod method, {String? password}) async {
    final user = _auth.currentUser;
    if (user == null) throw const Failure.sessionExpired();
    try {
      switch (method) {
        case ReauthMethod.password:
          await user.reauthenticateWithCredential(
            EmailAuthProvider.credential(
              email: user.email!,
              password: password!,
            ),
          );
          return true;
        case ReauthMethod.google:
          await _ensureGoogleInitialized();
          final GoogleSignInAccount account;
          try {
            account = await _googleSignIn.authenticate();
          } on GoogleSignInException catch (exception) {
            if (exception.code == GoogleSignInExceptionCode.canceled) {
              return false;
            }
            throw Failure.unexpected(
              'google-sign-in/${exception.code.name}: '
              '${exception.description}',
            );
          }
          final idToken = account.authentication.idToken;
          if (idToken == null) {
            throw const Failure.unexpected('google-sign-in/no-id-token');
          }
          await user.reauthenticateWithCredential(
            GoogleAuthProvider.credential(idToken: idToken),
          );
          return true;
        case ReauthMethod.apple:
          await user.reauthenticateWithProvider(AppleAuthProvider());
          return true;
      }
    } on FirebaseAuthException catch (exception) {
      if (method == ReauthMethod.apple &&
          _appleCancelledCodes.contains(exception.code)) {
        return false;
      }
      throw mapFirebaseAuthError(exception);
    }
  }

  @override
  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) return;
    try {
      // Step 9+: delete owner-scoped Firestore docs in a WriteBatch before
      // auth delete.
      await user.delete();
    } on FirebaseAuthException catch (exception) {
      throw mapFirebaseAuthError(exception);
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } on FirebaseAuthException catch (exception) {
      throw mapFirebaseAuthError(exception);
    }
  }
}
