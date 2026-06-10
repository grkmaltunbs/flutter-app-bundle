import 'package:freezed_annotation/freezed_annotation.dart';

part 'failure.freezed.dart';

/// A sealed, typed application error.
///
/// Repository implementations map infrastructure errors (exceptions, platform
/// errors) into one of these variants so the domain and presentation layers
/// never see raw infrastructure types. Implements [Exception] because the
/// error contract is throw-based: repositories THROW typed failures.
@freezed
sealed class Failure with _$Failure implements Exception {
  /// A connectivity or transport-level failure.
  const factory Failure.network() = NetworkFailure;

  /// An unexpected, unclassified failure carrying a diagnostic [message].
  const factory Failure.unexpected(String message) = UnexpectedFailure;

  /// A requested resource could not be found.
  const factory Failure.notFound() = NotFoundFailure;

  /// The supplied credentials (email/password or provider credential) are
  /// wrong or refer to no account.
  const factory Failure.invalidCredentials() = InvalidCredentialsFailure;

  /// The email address is already registered to another account.
  const factory Failure.emailAlreadyInUse() = EmailAlreadyInUseFailure;

  /// The chosen password does not meet the minimum strength requirements.
  const factory Failure.weakPassword() = WeakPasswordFailure;

  /// The requested operation needs a recent sign-in (re-authentication).
  const factory Failure.requiresRecentLogin() = RequiresRecentLoginFailure;

  /// The stored session could not be refreshed and the user was signed out.
  const factory Failure.sessionExpired() = SessionExpiredFailure;

  /// The backend throttled the operation after too many attempts.
  const factory Failure.tooManyRequests() = TooManyRequestsFailure;
}
