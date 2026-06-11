import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:okey_acar_mi/core/error/failure.dart';
import 'package:okey_acar_mi/core/extensions/context_extensions.dart';
import 'package:okey_acar_mi/features/detection/presentation/blocs/detection_bloc.dart';
import 'package:okey_acar_mi/features/detection/presentation/widgets/detection_failure_l10n.dart';

/// Full-screen explanation + escapes for a failed detection run, on the
/// analyzing screen's dark chrome. Never a dead-end:
///
/// - **no tiles** → lighting/framing tips, primary *Retake* (pop back to the
///   camera) and secondary *Try again* (re-run detection);
/// - **pipeline error** → primary *Try again* and secondary *Back*.
class DetectionFailureView extends StatelessWidget {
  /// Creates a [DetectionFailureView] for [failure].
  const DetectionFailureView({required this.failure, super.key});

  /// The terminal failure to explain.
  final Failure failure;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final bloc = context.read<DetectionBloc>();
    final copy = detectionFailureCopy(l10n, failure);
    final noTiles = failure is NoTilesDetectedFailure;

    void retry() => bloc.add(const DetectionEvent.retryRequested());
    void leave() => context.pop();

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(32, 96, 32, 64),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                noTiles ? Icons.grid_off_outlined : Icons.error_outline_rounded,
                size: 44,
                color: Colors.white70,
              ),
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
              if (noTiles) ...[
                _PrimaryAction(
                  key: const ValueKey('analyzing-retake'),
                  label: l10n.analyzingRetake,
                  onPressed: leave,
                ),
                const SizedBox(height: 10),
                _SecondaryAction(
                  key: const ValueKey('analyzing-retry'),
                  label: l10n.analyzingRetry,
                  onPressed: retry,
                ),
              ] else ...[
                _PrimaryAction(
                  key: const ValueKey('analyzing-retry'),
                  label: l10n.analyzingRetry,
                  onPressed: retry,
                ),
                const SizedBox(height: 10),
                _SecondaryAction(
                  key: const ValueKey('analyzing-back'),
                  label: l10n.commonBack,
                  onPressed: leave,
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

/// Outlined full-width secondary action on the dark chrome.
class _SecondaryAction extends StatelessWidget {
  const _SecondaryAction({
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
