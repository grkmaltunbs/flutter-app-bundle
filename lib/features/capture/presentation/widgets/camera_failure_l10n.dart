import 'package:okey_acar_mi/core/error/failure.dart';
import 'package:okey_acar_mi/l10n/app_localizations.dart';

/// Maps a [Failure] surfaced on the camera screen to its SnackBar message.
///
/// Permission and no-camera failures never reach this mapper — they render as
/// full `CameraPermissionView` states instead of toasts.
String cameraFailureText(AppLocalizations l10n, Failure failure) {
  return switch (failure) {
    // Every capture-surface failure today renders the same retryable copy;
    // the switch is the seam for more specific messages later.
    _ => l10n.cameraCaptureFailed,
  };
}
