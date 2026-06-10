import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:okey_acar_mi/core/extensions/context_extensions.dart';
import 'package:okey_acar_mi/features/capture/presentation/blocs/camera_bloc.dart';
import 'package:okey_acar_mi/l10n/app_localizations.dart';

/// Which blocked-capture state the view explains.
enum CameraPermissionVariant {
  /// Camera denied, re-promptable: Retry + gallery fallback.
  cameraDenied,

  /// Camera denied for good: Open Settings + gallery fallback.
  cameraPermanentlyDenied,

  /// No camera hardware: gallery fallback only.
  noCamera,

  /// Photo access denied, re-promptable: Retry.
  galleryDenied,

  /// Photo access denied for good: Open Settings.
  galleryPermanentlyDenied,
}

/// Full-screen explanation + actions for the camera-denied / no-camera /
/// gallery-denied states, on the capture screen's dark chrome.
///
/// Scrollable and centered, so it survives textScale 2.0 on the smallest
/// matrix size without overflowing.
class CameraPermissionView extends StatelessWidget {
  /// Creates a [CameraPermissionView] for [variant].
  const CameraPermissionView({required this.variant, super.key});

  /// The blocked state to explain.
  final CameraPermissionVariant variant;

  ({IconData icon, String title, String body}) _copy(AppLocalizations l10n) {
    return switch (variant) {
      CameraPermissionVariant.cameraDenied => (
        icon: Icons.no_photography_outlined,
        title: l10n.cameraDeniedTitle,
        body: l10n.cameraDeniedBody,
      ),
      CameraPermissionVariant.cameraPermanentlyDenied => (
        icon: Icons.no_photography_outlined,
        title: l10n.cameraDeniedTitle,
        body: l10n.cameraPermanentlyDeniedBody,
      ),
      CameraPermissionVariant.noCamera => (
        icon: Icons.videocam_off_outlined,
        title: l10n.cameraNoCameraTitle,
        body: l10n.cameraNoCameraBody,
      ),
      CameraPermissionVariant.galleryDenied => (
        icon: Icons.image_not_supported_outlined,
        title: l10n.cameraGalleryDeniedTitle,
        body: l10n.cameraGalleryDeniedBody,
      ),
      CameraPermissionVariant.galleryPermanentlyDenied => (
        icon: Icons.image_not_supported_outlined,
        title: l10n.cameraGalleryDeniedTitle,
        body: l10n.cameraGalleryPermanentlyDeniedBody,
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final bloc = context.read<CameraBloc>();
    final copy = _copy(l10n);

    final showRetryCamera = variant == CameraPermissionVariant.cameraDenied;
    final showRetryGallery = variant == CameraPermissionVariant.galleryDenied;
    final showSettings =
        variant == CameraPermissionVariant.cameraPermanentlyDenied ||
        variant == CameraPermissionVariant.galleryPermanentlyDenied;
    final showGalleryFallback =
        variant == CameraPermissionVariant.cameraDenied ||
        variant == CameraPermissionVariant.cameraPermanentlyDenied ||
        variant == CameraPermissionVariant.noCamera;

    return Center(
      child: SingleChildScrollView(
        // Generous vertical padding keeps the content clear of the top bar.
        padding: const EdgeInsets.fromLTRB(32, 96, 32, 64),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(copy.icon, size: 44, color: Colors.white70),
              const SizedBox(height: 16),
              Text(
                copy.title,
                textAlign: TextAlign.center,
                style: context.textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                copy.body,
                textAlign: TextAlign.center,
                style: context.textTheme.bodyMedium?.copyWith(
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: 24),
              if (showRetryCamera)
                _PrimaryAction(
                  key: const ValueKey('camera-permission-retry'),
                  label: l10n.cameraDeniedRetry,
                  onPressed: () => bloc.add(
                    const CameraEvent.permissionRetryRequested(),
                  ),
                ),
              if (showRetryGallery)
                _PrimaryAction(
                  key: const ValueKey('camera-permission-retry'),
                  label: l10n.cameraDeniedRetry,
                  onPressed: () =>
                      bloc.add(const CameraEvent.galleryRequested()),
                ),
              if (showSettings)
                _PrimaryAction(
                  key: const ValueKey('camera-open-settings'),
                  label: l10n.cameraOpenSettings,
                  onPressed: () => bloc.add(
                    const CameraEvent.openSettingsRequested(),
                  ),
                ),
              if (showGalleryFallback) ...[
                const SizedBox(height: 10),
                _GalleryFallbackAction(
                  key: const ValueKey('camera-gallery-fallback'),
                  primary: variant == CameraPermissionVariant.noCamera,
                  label: l10n.cameraGalleryFallback,
                  onPressed: () =>
                      bloc.add(const CameraEvent.galleryRequested()),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// White full-width filled action on the dark chrome.
class _PrimaryAction extends StatelessWidget {
  const _PrimaryAction({
    required this.label,
    required this.onPressed,
    super.key,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        onPressed: onPressed,
        child: Text(label),
      ),
    );
  }
}

/// The "import from gallery" escape: outlined normally, filled when it is
/// the only action (no-camera variant).
class _GalleryFallbackAction extends StatelessWidget {
  const _GalleryFallbackAction({
    required this.primary,
    required this.label,
    required this.onPressed,
    super.key,
  });

  final bool primary;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    if (primary) return _PrimaryAction(label: label, onPressed: onPressed);
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          side: const BorderSide(color: Colors.white38),
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        onPressed: onPressed,
        child: Text(label),
      ),
    );
  }
}
