import 'package:okey_acar_mi/core/error/failure.dart';
import 'package:okey_acar_mi/l10n/app_localizations.dart';

/// Maps a [Failure] surfaced on the analyzing screen to its localized copy
/// (mirrors the capture feature's `camera_failure_l10n`).
({String title, String body}) detectionFailureCopy(
  AppLocalizations l10n,
  Failure failure,
) {
  return switch (failure) {
    NoTilesDetectedFailure() => (
      title: l10n.analyzingNoTilesTitle,
      body: l10n.analyzingNoTilesBody,
    ),
    _ => (
      title: l10n.analyzingErrorTitle,
      body: l10n.analyzingErrorBody,
    ),
  };
}
