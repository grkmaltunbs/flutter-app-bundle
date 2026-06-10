import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:okey_acar_mi/core/extensions/context_extensions.dart';
import 'package:okey_acar_mi/features/capture/domain/entities/capture_mode.dart';
import 'package:okey_acar_mi/features/capture/presentation/blocs/camera_bloc.dart';

/// The photo / video / gallery mode pills above the shutter row.
class CameraModeToggle extends StatelessWidget {
  /// Creates a [CameraModeToggle].
  const CameraModeToggle({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return BlocSelector<CameraBloc, CameraState, CaptureMode?>(
      // Null while not in the live viewfinder: the pills render disabled.
      selector: (state) => switch (state) {
        CameraReady(:final mode) => mode,
        _ => null,
      },
      builder: (context, activeMode) {
        return Wrap(
          alignment: WrapAlignment.center,
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final (mode, icon, label) in [
              (
                CaptureMode.photo,
                Icons.photo_camera_outlined,
                l10n.cameraModePhoto,
              ),
              (
                CaptureMode.video,
                Icons.videocam_outlined,
                l10n.cameraModeVideo,
              ),
              (
                CaptureMode.gallery,
                Icons.image_outlined,
                l10n.cameraModeGallery,
              ),
            ])
              _ModePill(
                key: ValueKey('camera-mode-${mode.name}'),
                icon: icon,
                label: label,
                selected: mode == activeMode,
                onPressed: activeMode == null
                    ? null
                    : () => context.read<CameraBloc>().add(
                        CameraEvent.modeChanged(mode),
                      ),
              ),
          ],
        );
      },
    );
  }
}

/// One glass mode pill (white when selected, translucent otherwise).
class _ModePill extends StatelessWidget {
  const _ModePill({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onPressed,
    super.key,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? Colors.black : Colors.white;

    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(100),
        child: Padding(
          // The visual pill is ~36dp tall; this padding stretches the tap
          // target to ≥48dp while keeping the design's compact look.
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Container(
            constraints: const BoxConstraints(minHeight: 36, minWidth: 48),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: selected
                  ? const Color(0xF2FFFFFF)
                  : const Color(0x1FFFFFFF),
              borderRadius: BorderRadius.circular(100),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 14, color: foreground),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: context.textTheme.bodySmall?.copyWith(
                    color: foreground,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
