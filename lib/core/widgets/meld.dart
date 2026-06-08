import 'package:flutter/material.dart';
import 'package:okey_acar_mi/core/extensions/context_extensions.dart';
import 'package:okey_acar_mi/core/theme/app_typography.dart';
import 'package:okey_acar_mi/core/theme/tile_style.dart';
import 'package:okey_acar_mi/core/widgets/eyebrow.dart';
import 'package:okey_acar_mi/core/widgets/tile.dart';
import 'package:okey_acar_mi/core/widgets/tile_data.dart';

/// A labeled group of tiles (a set or run) with an optional score.
///
/// Ported from the `Meld` component in the design bundle's `tiles.jsx`: an
/// eyebrow label with `+score` on the right, then the tiles inside an
/// accent-soft rounded container. Uses a [Wrap] so the tiles never overflow.
class Meld extends StatelessWidget {
  /// Creates a [Meld].
  const Meld({
    required this.tiles,
    required this.label,
    this.score,
    this.style,
    this.size = TileSize.sm,
    super.key,
  });

  /// The tiles in this meld.
  final List<TileData> tiles;

  /// The eyebrow label (e.g. "Run", "Set").
  final String label;

  /// Optional score, rendered as `+score` in the accent color.
  final int? score;

  /// Tile render style; defaults to the active `palette.tileStyle`.
  final TileStyle? style;

  /// The tile size within the meld.
  final TileSize size;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Flexible(
              child: Eyebrow(label),
            ),
            if (score != null) ...[
              const SizedBox(width: 8),
              Text(
                '+$score',
                style: AppTypography.monoStyle(
                  fontSize: 11,
                  color: palette.accent,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: palette.accentSoft,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Wrap(
            spacing: 3,
            runSpacing: 3,
            children: [
              for (final t in tiles)
                Tile(
                  number: t.number,
                  color: t.color,
                  size: size,
                  style: style,
                ),
            ],
          ),
        ),
      ],
    );
  }
}
