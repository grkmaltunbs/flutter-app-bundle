import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:okey_acar_mi/core/extensions/context_extensions.dart';
import 'package:okey_acar_mi/core/theme/tile_style.dart';
import 'package:okey_acar_mi/core/widgets/tile.dart';
import 'package:okey_acar_mi/core/widgets/tile_data.dart';

/// A physical-looking rack (istaka) holding 14–21 tiles across two rows.
///
/// Tile width is derived entirely from the incoming [BoxConstraints]: the
/// widest of the two rows determines `tileWidth`, clamped to `[14, sm]`. The
/// available width subtracts the inner padding, the inter-tile gaps **and** the
/// decoration border inset, so the sized row fits exactly. As a final
/// guarantee, each row is wrapped in a `FittedBox(scaleDown)`, so even an
/// unforeseen rounding/decoration change can only shrink a row, never overflow
/// it — at any matrix size, text scale, or device pixel ratio, including 21
/// tiles on a 320pt-wide screen.
class Rack extends StatelessWidget {
  /// Creates a [Rack].
  const Rack({
    required this.tiles,
    this.style,
    this.padding,
    super.key,
  });

  /// The tiles to display, in rack order (split across two rows).
  final List<TileData> tiles;

  /// The tile render style; defaults to the active `palette.tileStyle`.
  final TileStyle? style;

  /// Inner padding; defaults to the design bundle's `14/12/10`.
  final EdgeInsets? padding;

  /// Horizontal gap between tiles, in logical pixels.
  static const double _gap = 3;

  /// Width of the rack's decoration border (`Border.all`), per side. A
  /// `BoxDecoration` border insets the Container's child by this on every side,
  /// so the available-width math must subtract it from both horizontal edges.
  static const double _borderWidth = 1;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final pad = padding ?? const EdgeInsets.fromLTRB(12, 14, 12, 10);

    final splitAt = (tiles.length / 2).ceil();
    final row1 = tiles.take(splitAt).toList();
    final row2 = tiles.skip(splitAt).toList();
    final perRow = math.max(row1.length, row2.length);

    return LayoutBuilder(
      builder: (context, constraints) {
        final available =
            constraints.maxWidth -
            pad.horizontal -
            // The decoration border (below) insets the child by `_borderWidth`
            // on each side; account for both edges or tiles are sized 2px wide.
            _borderWidth * 2 -
            math.max(0, perRow - 1) * _gap;
        // Width per tile, never wider than `sm`, never narrower than 14.
        // Floor to whole pixels so `perRow * tileWidth + gaps` can never exceed
        // the available width by a sub-pixel rounding error (which would trip a
        // RenderFlex overflow). The clamp lower bound keeps tiles legible.
        final rawWidth = perRow == 0
            ? TileSize.sm.width
            : (available / perRow).clamp(14.0, TileSize.sm.width);
        final tileWidth = rawWidth.floorToDouble().clamp(
          14.0,
          TileSize.sm.width,
        );

        return Container(
          padding: pad,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [palette.rackTop, palette.rackBottom],
            ),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: palette.rackBorder,
              // The decoration border and the available-width math must
              // reference the same value, so `width` is stated explicitly even
              // though `_borderWidth` equals Border.all's default.
              // ignore: avoid_redundant_argument_values, the const link is intentional
              width: _borderWidth,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _row(row1, tileWidth),
              if (row2.isNotEmpty) ...[
                SizedBox(height: tileWidth * 0.2),
                _row(row2, tileWidth),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _row(List<TileData> row, double tileWidth) {
    // The `available` math already sizes tiles to fit exactly. The FittedBox
    // is a belt-and-braces guarantee: it receives a bounded width from the
    // padded Container's Column, and `BoxFit.scaleDown` only ever shrinks the
    // row, so a future decoration/rounding change can never overflow it.
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: AlignmentDirectional.centerStart,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < row.length; i++) ...[
            if (i > 0) const SizedBox(width: _gap),
            _RackTile(data: row[i], width: tileWidth, style: style),
          ],
        ],
      ),
    );
  }
}

/// A single tile inside a [Rack], with an optional low-confidence warn ring.
class _RackTile extends StatelessWidget {
  const _RackTile({required this.data, required this.width, this.style});

  final TileData data;
  final double width;
  final TileStyle? style;

  @override
  Widget build(BuildContext context) {
    final tile = Tile(
      number: data.number,
      color: data.color,
      widthOverride: width,
      style: style,
    );
    if (!data.lowConfidence) return tile;

    final radius = width * 0.13;
    return Stack(
      children: [
        tile,
        Positioned.fill(
          child: IgnorePointer(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(radius),
                border: Border.all(
                  color: context.palette.warn.withValues(alpha: 0.9),
                  width: 1.5,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
