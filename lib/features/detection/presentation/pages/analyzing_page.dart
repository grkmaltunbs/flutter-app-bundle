import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:okey_acar_mi/core/di/injection.dart';
import 'package:okey_acar_mi/core/extensions/context_extensions.dart';
import 'package:okey_acar_mi/core/router/app_router.dart';
import 'package:okey_acar_mi/core/widgets/eyebrow.dart';
import 'package:okey_acar_mi/features/capture/domain/entities/capture_payload.dart';
import 'package:okey_acar_mi/features/detection/domain/entities/detected_tile.dart';
import 'package:okey_acar_mi/features/detection/domain/entities/detection_result.dart';
import 'package:okey_acar_mi/features/detection/domain/entities/detection_stage.dart';
import 'package:okey_acar_mi/features/detection/presentation/blocs/detection_bloc.dart';
import 'package:okey_acar_mi/features/detection/presentation/widgets/analyzing_progress_panel.dart';
import 'package:okey_acar_mi/features/detection/presentation/widgets/detection_failure_view.dart';
import 'package:okey_acar_mi/features/detection/presentation/widgets/detection_overlay.dart';
import 'package:okey_acar_mi/features/detection/presentation/widgets/revealed_rack.dart';

/// The analyzing screen: owns the screen-scoped [DetectionBloc] (created for
/// this capture's payload) and starts the run immediately.
class AnalyzingPage extends StatelessWidget {
  /// Creates an [AnalyzingPage] for [payload].
  const AnalyzingPage({required this.payload, super.key});

  /// The capture under analysis (route `extra`, guarded by the router
  /// redirect).
  final CapturePayload payload;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<DetectionBloc>(
      create: (_) =>
          getIt<DetectionBloc>(param1: payload)
            ..add(const DetectionEvent.started()),
      child: AnalyzingView(payload: payload),
    );
  }
}

/// The analyzing screen view (assumes a [DetectionBloc] is provided above
/// it): staged progress, the per-tile rack reveal over the captured image,
/// and the failure escapes.
class AnalyzingView extends StatelessWidget {
  /// Creates an [AnalyzingView] for [payload].
  const AnalyzingView({required this.payload, super.key});

  /// The capture under analysis (its image backs the overlay).
  final CapturePayload payload;

  /// The representative image behind the bounding-box overlay.
  String get _imagePath => switch (payload) {
    StillCapture(:final imagePath) => imagePath,
    FramesCapture(:final framePaths) => framePaths.firstOrNull ?? '',
  };

  void _onStateChanged(BuildContext context, DetectionState state) {
    if (state is! DetectionSuccess) return;
    unawaited(_handoff(context, state.result));
  }

  /// Push + auto-pop (deliberately NOT `pushReplacement`): review runs on
  /// top of this page; when it pops, this page pops itself too, completing
  /// the camera page's `push(analyzing).then(...)` future so its
  /// `returnedFromCapture` re-acquisition fires correctly.
  Future<void> _handoff(BuildContext context, DetectionResult result) async {
    await context.push<void>(AppRoutes.review, extra: result);
    if (context.mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<DetectionBloc, DetectionState>(
      listener: _onStateChanged,
      child: Scaffold(
        backgroundColor: const Color(0xFF0A0A0A),
        body: SafeArea(
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: _AnalyzingTopBar(),
              ),
              Expanded(
                child: BlocBuilder<DetectionBloc, DetectionState>(
                  builder: (context, state) => switch (state) {
                    DetectionProcessing(
                      :final stage,
                      :final revealed,
                      :final totalTiles,
                    ) =>
                      _AnalyzingBody(
                        imagePath: _imagePath,
                        tiles: revealed,
                        stage: stage,
                        totalTiles: totalTiles,
                        scanning: true,
                      ),
                    DetectionSuccess(:final result) => _AnalyzingBody(
                      imagePath: _imagePath,
                      tiles: result.tiles,
                      stage: DetectionStage.finalizing,
                      totalTiles: result.tiles.length,
                      scanning: false,
                      completed: true,
                    ),
                    DetectionFailure(:final failure) => DetectionFailureView(
                      failure: failure,
                    ),
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Back/cancel glass button + the eyebrow screen title on the dark chrome.
class _AnalyzingTopBar extends StatelessWidget {
  const _AnalyzingTopBar();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final canPop = context.canPop();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          _GlassCircleButton(
            key: const ValueKey('analyzing-cancel'),
            icon: canPop ? Icons.arrow_back : Icons.home_outlined,
            semanticLabel: l10n.analyzingCancelSemantics,
            // Popping disposes the bloc, which cancels the run and kills the
            // worker isolate (the cancellation chain on DetectionBloc).
            onPressed: () =>
                canPop ? context.pop() : context.go(AppRoutes.home),
          ),
          Expanded(
            child: Center(
              child: Eyebrow(l10n.screenAnalyzingTitle, color: Colors.white54),
            ),
          ),
          // Balance the leading button so the eyebrow stays centered.
          const SizedBox(width: 48),
        ],
      ),
    );
  }
}

/// The processing/success layout: overlay (flexes), rack reveal, progress.
class _AnalyzingBody extends StatelessWidget {
  const _AnalyzingBody({
    required this.imagePath,
    required this.tiles,
    required this.stage,
    required this.totalTiles,
    required this.scanning,
    this.completed = false,
  });

  final String imagePath;
  final List<DetectedTile> tiles;
  final DetectionStage stage;
  final int? totalTiles;
  final bool scanning;
  final bool completed;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: DetectionOverlay(
                imagePath: imagePath,
                bounds: [
                  for (final tile in tiles)
                    if (tile.bounds != null) tile.bounds!,
                ],
                scanning: scanning,
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: RevealedRack(tiles: tiles),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 28),
          child: AnalyzingProgressPanel(
            stage: stage,
            revealedCount: tiles.length,
            totalTiles: totalTiles,
            completed: completed,
          ),
        ),
      ],
    );
  }
}

/// A 44pt circular glass icon button (≥48dp tap target) on the dark chrome.
class _GlassCircleButton extends StatelessWidget {
  const _GlassCircleButton({
    required this.icon,
    required this.semanticLabel,
    required this.onPressed,
    super.key,
  });

  final IconData icon;
  final String semanticLabel;
  final VoidCallback onPressed;

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
              child: Icon(icon, size: 20, color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}
