import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:okey_acar_mi/core/extensions/context_extensions.dart';
import 'package:okey_acar_mi/core/theme/app_typography.dart';
import 'package:okey_acar_mi/core/widgets/app_buttons.dart';
import 'package:okey_acar_mi/features/review/presentation/blocs/review_bloc.dart';

/// The mono tile counter (`{count} / {min}–{max}`, warn-tinted while out of
/// range) and the add-tile action (enabled only below the mode's maximum).
class RackCountBar extends StatelessWidget {
  /// Creates a [RackCountBar].
  const RackCountBar({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ReviewBloc, ReviewState>(
      // canAdd and countValid both derive from the count (the mode is fixed
      // for the screen's lifetime).
      buildWhen: (a, b) => a.tileCount != b.tileCount,
      builder: (context, state) {
        final l10n = context.l10n;
        final palette = context.palette;
        return Row(
          children: [
            Expanded(
              child: Text(
                l10n.reviewCount(
                  state.tileCount,
                  state.gameMode.minTiles,
                  state.gameMode.maxTiles,
                ),
                style: AppTypography.monoStyle(
                  fontSize: 13,
                  color: state.countValid ? palette.muted : palette.warn,
                ),
              ),
            ),
            const SizedBox(width: 8),
            SecondaryButton(
              key: const ValueKey('review-add-tile'),
              label: l10n.reviewAddTile,
              icon: Icons.add,
              onPressed: state.canAdd
                  ? () => context.read<ReviewBloc>().add(
                      const ReviewEvent.tileAdded(),
                    )
                  : null,
            ),
          ],
        );
      },
    );
  }
}
