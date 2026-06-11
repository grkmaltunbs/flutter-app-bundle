import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:okey_acar_mi/core/extensions/context_extensions.dart';
import 'package:okey_acar_mi/core/theme/app_radii.dart';
import 'package:okey_acar_mi/core/widgets/app_buttons.dart';
import 'package:okey_acar_mi/features/review/presentation/blocs/review_bloc.dart';

/// Warn banner shown when the overall detection confidence is low: suggests
/// a retake (pops back toward the camera) but never blocks solving (D2).
///
/// Collapses to nothing when confidence is fine, so the page can include it
/// unconditionally.
class ReviewLowConfidenceBanner extends StatelessWidget {
  /// Creates a [ReviewLowConfidenceBanner].
  const ReviewLowConfidenceBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocSelector<ReviewBloc, ReviewState, bool>(
      selector: (state) => state.lowOverallConfidence,
      builder: (context, low) {
        if (!low) return const SizedBox.shrink();
        final l10n = context.l10n;
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: _WarnCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _WarnLine(text: l10n.reviewLowOverallBanner),
                const SizedBox(height: 4),
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: GhostButton(
                    key: const ValueKey('review-retake'),
                    label: l10n.reviewRetakeCta,
                    icon: Icons.photo_camera_outlined,
                    // Popping review pops the analyzing page beneath it too
                    // (its auto-pop), landing back on the camera.
                    onPressed: () => context.pop(),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Warn banner shown while the tile count is outside the mode's legal range,
/// with mode-specific copy for too few vs too many tiles.
///
/// Collapses to nothing while the count is valid.
class ReviewWrongCountBanner extends StatelessWidget {
  /// Creates a [ReviewWrongCountBanner].
  const ReviewWrongCountBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ReviewBloc, ReviewState>(
      buildWhen: (a, b) => a.tileCount != b.tileCount,
      builder: (context, state) {
        if (state.countValid) return const SizedBox.shrink();
        final l10n = context.l10n;
        final message = state.tileCount < state.gameMode.minTiles
            ? l10n.reviewWrongCountFew(state.gameMode.minTiles)
            : l10n.reviewWrongCountMany(state.gameMode.maxTiles);
        return Padding(
          padding: const EdgeInsets.only(top: 12),
          child: _WarnCard(child: _WarnLine(text: message)),
        );
      },
    );
  }
}

/// Soft warn surface shared by the review banners.
class _WarnCard extends StatelessWidget {
  const _WarnCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final warn = context.palette.warn;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: warn.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: warn.withValues(alpha: 0.35)),
      ),
      child: child,
    );
  }
}

/// Icon + flexing text row (icon + text, never color alone).
class _WarnLine extends StatelessWidget {
  const _WarnLine({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.warning_amber_rounded,
          size: 18,
          color: context.palette.warn,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: context.textTheme.bodySmall?.copyWith(
              color: context.palette.ink2,
            ),
          ),
        ),
      ],
    );
  }
}
