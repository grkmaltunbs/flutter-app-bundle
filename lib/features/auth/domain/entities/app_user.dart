import 'package:freezed_annotation/freezed_annotation.dart';

part 'app_user.freezed.dart';

/// An authenticated account. Absence of an [AppUser] (null) means guest.
@freezed
sealed class AppUser with _$AppUser {
  /// Creates an [AppUser].
  const factory AppUser({
    required String id,
    required String email,
    required bool emailVerified,
    required List<AuthProvider> providers,
    String? displayName,
  }) = _AppUser;
}

/// The sign-in providers linked to an [AppUser].
enum AuthProvider {
  /// Email + password.
  password,

  /// Google Sign-In.
  google,

  /// Sign in with Apple.
  apple,
}
