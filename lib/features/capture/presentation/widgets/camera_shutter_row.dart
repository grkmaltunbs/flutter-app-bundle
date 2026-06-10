import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:okey_acar_mi/core/extensions/context_extensions.dart';
import 'package:okey_acar_mi/features/capture/domain/entities/capture_mode.dart';
import 'package:okey_acar_mi/features/capture/presentation/blocs/camera_bloc.dart';

/// The recording red from the design's camera screen.
const Color _recordRed = Color(0xFFE53935);

/// What the shutter row reads from [CameraState] (record for cheap diffing).
typedef _ShutterView = ({CaptureMode? mode, bool busy, bool recording});

/// The capture screen's bottom action row: gallery (48dp), the 78dp shutter
/// ring, and the camera flip (48dp).
class CameraShutterRow extends StatelessWidget {
  /// Creates a [CameraShutterRow].
  const CameraShutterRow({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return BlocSelector<CameraBloc, CameraState, _ShutterView>(
      selector: (state) => switch (state) {
        CameraReady(:final mode) => (
          mode: mode,
          busy: false,
          recording: false,
        ),
        CameraRecording() => (mode: null, busy: false, recording: true),
        _ => (mode: null, busy: true, recording: false),
      },
      builder: (context, view) {
        final bloc = context.read<CameraBloc>();
        final idle = view.mode != null;

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _GlassSquareButton(
              key: const ValueKey('camera-gallery'),
              icon: Icons.image_outlined,
              semanticLabel: l10n.cameraGallerySemantics,
              onPressed: idle
                  ? () => bloc.add(const CameraEvent.galleryRequested())
                  : null,
            ),
            _ShutterButton(
              recording: view.recording,
              videoMode: view.mode == CaptureMode.video,
              semanticLabel: view.recording
                  ? l10n.cameraStopRecordingSemantics
                  : l10n.cameraShutterSemantics,
              onPressed: view.recording
                  ? () => bloc.add(const CameraEvent.recordingStopped())
                  : idle
                  ? () => bloc.add(const CameraEvent.shutterPressed())
                  : null,
            ),
            _GlassSquareButton(
              key: const ValueKey('camera-flip'),
              icon: Icons.cameraswitch_outlined,
              semanticLabel: l10n.cameraFlipSemantics,
              onPressed: idle
                  ? () => bloc.add(const CameraEvent.flipRequested())
                  : null,
            ),
          ],
        );
      },
    );
  }
}

/// The 78dp shutter ring: white inner circle for photo, red for video, and a
/// red rounded square while the burst is "recording".
class _ShutterButton extends StatelessWidget {
  const _ShutterButton({
    required this.recording,
    required this.videoMode,
    required this.semanticLabel,
    required this.onPressed,
  });

  final bool recording;
  final bool videoMode;
  final String semanticLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: InkWell(
        key: const ValueKey('camera-shutter'),
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: Container(
          width: 78,
          height: 78,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: onPressed == null ? Colors.white38 : Colors.white,
              width: 3,
            ),
          ),
          child: Center(
            child: recording
                ? Container(
                    width: 30,
                    height: 30,
                    decoration: const BoxDecoration(
                      color: _recordRed,
                      borderRadius: BorderRadius.all(Radius.circular(8)),
                    ),
                  )
                : Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: switch ((onPressed == null, videoMode)) {
                        (true, _) => Colors.white38,
                        (false, true) => _recordRed,
                        (false, false) => Colors.white,
                      },
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

/// A 48dp rounded-square glass icon button for the shutter row's sides.
class _GlassSquareButton extends StatelessWidget {
  const _GlassSquareButton({
    required this.icon,
    required this.semanticLabel,
    required this.onPressed,
    super.key,
  });

  final IconData icon;
  final String semanticLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 48,
          height: 48,
          decoration: const BoxDecoration(
            color: Color(0x26FFFFFF),
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
          child: Icon(
            icon,
            size: 20,
            color: onPressed == null ? Colors.white38 : Colors.white,
          ),
        ),
      ),
    );
  }
}
