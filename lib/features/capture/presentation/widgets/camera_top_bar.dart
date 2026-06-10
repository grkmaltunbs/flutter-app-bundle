import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:okey_acar_mi/core/extensions/context_extensions.dart';
import 'package:okey_acar_mi/core/router/app_router.dart';
import 'package:okey_acar_mi/core/theme/app_typography.dart';
import 'package:okey_acar_mi/features/capture/presentation/blocs/camera_bloc.dart';

/// What the top bar reads from [CameraState] (record for cheap diffing).
typedef _TopBarView = ({
  bool showFlash,
  bool flashOn,
  int? framesCaptured,
  int? frameTarget,
});

/// The capture screen's top chrome: back glass button, the framing-hint pill
/// (burst progress while recording), and the flash toggle.
class CameraTopBar extends StatelessWidget {
  /// Creates a [CameraTopBar].
  const CameraTopBar({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final canPop = context.canPop();

    return BlocSelector<CameraBloc, CameraState, _TopBarView>(
      selector: (state) => switch (state) {
        CameraReady(:final flashAvailable, :final flashOn) => (
          showFlash: flashAvailable,
          flashOn: flashOn,
          framesCaptured: null,
          frameTarget: null,
        ),
        CameraRecording(:final framesCaptured, :final frameTarget) => (
          showFlash: false,
          flashOn: false,
          framesCaptured: framesCaptured,
          frameTarget: frameTarget,
        ),
        _ => (
          showFlash: false,
          flashOn: false,
          framesCaptured: null,
          frameTarget: null,
        ),
      },
      builder: (context, view) {
        final recording = view.framesCaptured != null;
        final pillText = recording
            ? l10n.cameraRecordingProgress(
                view.framesCaptured!,
                view.frameTarget!,
              )
            : l10n.cameraFrameHint;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: [
              _GlassCircleButton(
                key: const ValueKey('camera-back'),
                icon: canPop ? Icons.arrow_back : Icons.home_outlined,
                semanticLabel: canPop ? l10n.commonBack : l10n.navHome,
                onPressed: () =>
                    canPop ? context.pop() : context.go(AppRoutes.home),
              ),
              Expanded(
                child: Center(
                  child: _HintPill(
                    key: const ValueKey('camera-frame-hint'),
                    text: pillText,
                  ),
                ),
              ),
              if (view.showFlash)
                _GlassCircleButton(
                  key: const ValueKey('camera-flash'),
                  icon: view.flashOn
                      ? Icons.flash_on_rounded
                      : Icons.flash_off_rounded,
                  iconColor: view.flashOn ? context.palette.accent : null,
                  semanticLabel: view.flashOn
                      ? l10n.cameraFlashOnSemantics
                      : l10n.cameraFlashOffSemantics,
                  onPressed: () => context.read<CameraBloc>().add(
                    const CameraEvent.flashToggled(),
                  ),
                )
              else
                // Keep the pill centered when the flash toggle is hidden.
                const SizedBox(width: 48),
            ],
          ),
        );
      },
    );
  }
}

/// The mono uppercase hint pill on glass, from the design's camera header.
class _HintPill extends StatelessWidget {
  const _HintPill({required this.text, super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: const BoxDecoration(
        color: Color(0x59000000),
        borderRadius: BorderRadius.all(Radius.circular(100)),
      ),
      // Long translations / large text scales shrink instead of overflowing.
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          text,
          maxLines: 1,
          style: AppTypography.monoStyle(
            fontSize: 11,
            color: Colors.white,
            letterSpacing: 0.88,
          ),
        ),
      ),
    );
  }
}

/// A 44pt circular glass icon button (≥48dp tap target) for the dark camera
/// chrome.
class _GlassCircleButton extends StatelessWidget {
  const _GlassCircleButton({
    required this.icon,
    required this.semanticLabel,
    required this.onPressed,
    this.iconColor,
    super.key,
  });

  final IconData icon;
  final String semanticLabel;
  final VoidCallback onPressed;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 48,
          height: 48,
          child: Center(
            child: Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: Color(0x59000000),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 20, color: iconColor ?? Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}
