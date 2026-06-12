import 'package:flutter/material.dart';
import 'package:okey_acar_mi/core/extensions/context_extensions.dart';
import 'package:okey_acar_mi/core/widgets/eyebrow.dart';
import 'package:okey_acar_mi/core/widgets/tile.dart';
import 'package:okey_acar_mi/features/result/presentation/reasoning_step_localizer.dart';
import 'package:okey_acar_mi/features/solver/domain/entities/solve_result.dart';

/// Okey-mode extras under the arrangement: the discard suggestion (15-tile
/// racks) and the tiles-still-needed summary. Renders nothing when neither
/// applies (every 101 result).
class ResultExtras extends StatelessWidget {
  /// Creates a [ResultExtras] for [result].
  const ResultExtras({
    required this.result,
    required this.neededCount,
    super.key,
  });

  /// The solver output (discard suggestion).
  final SolveResult result;

  /// How many tiles the arrangement still needs (from the display model).
  final int neededCount;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final palette = context.palette;
    final discard = result.discardSuggested;
    if (discard == null && neededCount == 0) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (discard != null) ...[
            Eyebrow(l10n.resultDiscardSuggestion),
            const SizedBox(height: 10),
            Row(
              children: [
                Tile(
                  color: discard.color,
                  number: discard.number,
                  size: TileSize.sm,
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    formatGameTile(l10n, discard),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.textTheme.bodyMedium?.copyWith(
                      color: palette.ink2,
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (neededCount > 0)
            Padding(
              padding: EdgeInsets.only(top: discard == null ? 0 : 10),
              child: Text(
                l10n.resultTilesNeeded(neededCount),
                style: context.textTheme.bodySmall?.copyWith(
                  color: palette.muted,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
