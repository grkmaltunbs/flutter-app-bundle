import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:okey_acar_mi/core/extensions/context_extensions.dart';
import 'package:okey_acar_mi/core/theme/app_typography.dart';
import 'package:okey_acar_mi/core/widgets/app_buttons.dart';
import 'package:okey_acar_mi/core/widgets/app_card.dart';
import 'package:okey_acar_mi/core/widgets/eyebrow.dart';
import 'package:okey_acar_mi/features/result/presentation/blocs/result_bloc.dart';
import 'package:okey_acar_mi/features/result/presentation/reasoning_step_localizer.dart';
import 'package:okey_acar_mi/features/solver/domain/entities/reasoning_step.dart';

/// "NEDEN BÖYLE?": the step-by-step reasoning — a locked teaser card until
/// unlocked, then the numbered localized steps.
class ResultDetailSection extends StatelessWidget {
  /// Creates a [ResultDetailSection] for [steps].
  const ResultDetailSection({required this.steps, super.key});

  /// The solver's typed reasoning steps, in order.
  final List<ReasoningStep> steps;

  @override
  Widget build(BuildContext context) {
    return BlocSelector<ResultBloc, ResultState, bool>(
      selector: (state) => state.detailUnlocked,
      builder: (context, unlocked) =>
          unlocked ? _ReasoningList(steps: steps) : const _LockedCard(),
    );
  }
}

/// The locked teaser: lock icon, copy, and the unlock CTA stub.
class _LockedCard extends StatelessWidget {
  const _LockedCard();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final palette = context.palette;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.lock_outline, size: 20, color: palette.muted),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.resultDetailLockedTitle,
                      style: context.textTheme.titleSmall?.copyWith(
                        color: palette.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l10n.resultDetailLockedBody,
                      style: context.textTheme.bodySmall?.copyWith(
                        color: palette.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SecondaryButton(
            key: const ValueKey('result-detail-unlock'),
            label: l10n.resultDetailUnlockCta,
            icon: Icons.lock_open_outlined,
            fullWidth: true,
            // TODO(step-11): replace with the SubscriptionBloc / rewarded-ad
            // gate; for now the CTA grants the unlock directly.
            onPressed: () => context.read<ResultBloc>().add(
              const ResultEvent.detailUnlockGranted(),
            ),
          ),
        ],
      ),
    );
  }
}

/// The unlocked numbered reasoning list with hairline separators.
class _ReasoningList extends StatelessWidget {
  const _ReasoningList({required this.steps});

  final List<ReasoningStep> steps;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final palette = context.palette;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Eyebrow(l10n.resultWhyThis),
        const SizedBox(height: 10),
        AppCard(
          child: Column(
            children: [
              for (var i = 0; i < steps.length; i++)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: i < steps.length - 1
                      ? BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: palette.line),
                          ),
                        )
                      : null,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 24,
                        child: Text(
                          '${i + 1}'.padLeft(2, '0'),
                          style: AppTypography.monoStyle(
                            fontSize: 11,
                            color: palette.accent,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          reasoningStepText(l10n, steps[i]),
                          style: context.textTheme.bodySmall?.copyWith(
                            color: palette.ink,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
