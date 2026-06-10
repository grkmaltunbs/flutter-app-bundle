import 'package:okey_acar_mi/core/error/failure.dart';
import 'package:okey_acar_mi/l10n/app_localizations.dart';

/// Maps a [Failure] to its user-facing auth error message.
///
/// Field-level failures (already-in-use, weak password) surface as inline
/// field errors instead and never reach this banner text.
String failureText(AppLocalizations l10n, Failure failure) {
  return switch (failure) {
    InvalidCredentialsFailure() => l10n.authErrorInvalidCredentials,
    NetworkFailure() => l10n.authErrorNetwork,
    TooManyRequestsFailure() => l10n.authErrorTooManyRequests,
    RequiresRecentLoginFailure() => l10n.authErrorRequiresRecentLogin,
    SessionExpiredFailure() => l10n.authErrorSessionExpired,
    _ => l10n.authErrorUnexpected,
  };
}
