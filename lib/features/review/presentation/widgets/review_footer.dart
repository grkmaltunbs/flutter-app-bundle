import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:okey_acar_mi/core/extensions/context_extensions.dart';
import 'package:okey_acar_mi/core/router/app_router.dart';
import 'package:okey_acar_mi/core/widgets/app_buttons.dart';
import 'package:okey_acar_mi/features/review/presentation/blocs/review_bloc.dart';

/// The pinned bottom bar: a helper line naming the highest-priority blocker
/// (wrong count → incomplete tiles → indicator unset) and the full-width
/// "Hesapla" CTA, disabled until the rack is solvable (D2).
///
/// Navigation is a widget-side effect here — the bloc never navigates.
class ReviewFooter extends StatelessWidget {
  /// Creates a [ReviewFooter].
  const ReviewFooter({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).scaffoldBackgroundColor.withValues(alpha: 0.92),
        border: Border(top: BorderSide(color: palette.line)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: BlocBuilder<ReviewBloc, ReviewState>(
            buildWhen: (a, b) =>
                a.tiles != b.tiles || a.indicator != b.indicator,
            builder: (context, state) {
              final blocker = _blocker(context, state);
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (blocker != null) ...[
                    Text(
                      blocker,
                      key: const ValueKey('review-blocker'),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: context.textTheme.bodySmall?.copyWith(
                        color: palette.muted,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  PrimaryButton(
                    key: const ValueKey('review-calculate'),
                    label: context.l10n.reviewCalculateCta,
                    icon: Icons.arrow_forward,
                    fullWidth: true,
                    onPressed: state.canSolve
                        ? () => context.push(
                            AppRoutes.result,
                            extra: state.outcome(),
                          )
                        : null,
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  String? _blocker(BuildContext context, ReviewState state) {
    final l10n = context.l10n;
    if (!state.countValid) return l10n.reviewBlockerCount;
    if (!state.allTilesComplete) return l10n.reviewBlockerIncomplete;
    if (state.indicator == null) return l10n.reviewBlockerIndicator;
    return null;
  }
}
