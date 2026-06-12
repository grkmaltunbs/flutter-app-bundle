import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:okey_acar_mi/core/extensions/context_extensions.dart';
import 'package:okey_acar_mi/core/theme/app_palette.dart';
import 'package:okey_acar_mi/core/theme/app_typography.dart';
import 'package:okey_acar_mi/core/widgets/eyebrow.dart';
import 'package:okey_acar_mi/core/widgets/rack.dart';
import 'package:okey_acar_mi/core/widgets/tile.dart';
import 'package:okey_acar_mi/features/result/presentation/models/result_arrangement.dart';
import 'package:okey_acar_mi/features/result/presentation/reasoning_step_localizer.dart';
import 'package:okey_acar_mi/l10n/app_localizations.dart';

/// Resolves the ring color for [groupIndex] from the design cycle
/// (accent → blue → red → warn), at render time so theme changes apply.
Color resultGroupRingColor(AppPalette palette, int groupIndex) {
  final cycle = [
    palette.accent,
    palette.tileBlue,
    palette.tileRed,
    palette.warn,
  ];
  return cycle[groupIndex % cycle.length];
}

/// "EN İYİ DİZİLİŞ": the arranged two-row rack on the istaka chrome with
/// per-tile group rings, plus the group legend below it.
///
/// The rack shows cells in **arranged** order (groups first, leftovers last)
/// — never the physical rack order. Tile width math mirrors the core [Rack]
/// (padding + border + gaps subtracted, floored, clamped), minus a slack
/// inset per row so the −3 ring overlays and corner badges are never
/// clipped; each row sits in a `FittedBox(scaleDown)` as the final
/// zero-overflow guarantee.
class ResultRackLayout extends StatelessWidget {
  /// Creates a [ResultRackLayout] for [arrangement].
  const ResultRackLayout({required this.arrangement, super.key});

  /// The arranged display model.
  final ResultArrangement arrangement;

  /// Horizontal gap between tiles, in logical pixels (matches [Rack]).
  static const double _gap = 3;

  /// Slack inside each row so rings/badges that extend past the tile bounds
  /// are not clipped (mirrors the review rack's slack padding).
  static const double _slack = 4;

  @override
  Widget build(BuildContext context) {
    final cells = arrangement.allCells;
    final splitAt = (cells.length / 2).ceil();
    final row1 = cells.sublist(0, splitAt);
    final row2 = cells.sublist(splitAt);
    final perRow = math.max(row1.length, row2.length);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Eyebrow(context.l10n.resultBestArrangement),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, constraints) {
            // Mirrors [RackFrame]'s default padding; the width math below
            // must subtract the same insets the frame applies.
            const pad = EdgeInsets.fromLTRB(12, 14, 12, 10);
            final available =
                constraints.maxWidth -
                pad.horizontal -
                RackFrame.borderWidth * 2 -
                _slack * 2 -
                math.max(0, perRow - 1) * _gap;
            final rawWidth = perRow == 0
                ? TileSize.sm.width
                : (available / perRow).clamp(14.0, TileSize.sm.width);
            final tileWidth = rawWidth.floorToDouble().clamp(
              14.0,
              TileSize.sm.width,
            );

            return RackFrame(
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
        ),
        const SizedBox(height: 16),
        _ArrangementLegend(arrangement: arrangement),
      ],
    );
  }

  Widget _row(List<ResultCell> row, double tileWidth) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: AlignmentDirectional.centerStart,
      child: Padding(
        // Slack so the −3 ring overlays and −4 corner badges survive.
        padding: const EdgeInsets.all(_slack),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < row.length; i++) ...[
              if (i > 0) const SizedBox(width: _gap),
              _ArrangedRackCell(
                cell: row[i],
                width: tileWidth,
                arrangement: arrangement,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// One rack cell with its group ring and semantics composed from its group.
class _ArrangedRackCell extends StatelessWidget {
  const _ArrangedRackCell({
    required this.cell,
    required this.width,
    required this.arrangement,
  });

  final ResultCell cell;
  final double width;
  final ResultArrangement arrangement;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final palette = context.palette;
    return ResultTileCell(
      cell: cell,
      width: width,
      ringColor: cell.groupIndex >= 0
          ? resultGroupRingColor(palette, cell.groupIndex)
          : null,
      groupLabel: cell.groupIndex >= 0
          ? l10n.resultGroupSemantics(
              resultGroupKindLabel(
                l10n,
                arrangement.groups[cell.groupIndex].kind,
              ),
              cell.groupIndex + 1,
            )
          : null,
    );
  }
}

/// A single result tile cell: the playsAs tile plus the group ring, the
/// dashed needed-ring, the wild/discard corner badges, and one merged
/// semantics node. Shared by the rack and list layouts.
class ResultTileCell extends StatelessWidget {
  /// Creates a [ResultTileCell].
  const ResultTileCell({
    required this.cell,
    required this.width,
    this.ringColor,
    this.groupLabel,
    super.key,
  });

  /// The display cell.
  final ResultCell cell;

  /// The tile render width (the rack passes its fitted width; the list
  /// passes [TileSize.sm]'s).
  final double width;

  /// Solid ring color, or null for no group ring (list layout / leftovers).
  /// A needed cell always draws the dashed faint ring instead.
  final Color? ringColor;

  /// Group description appended to the semantics label (rack layout only).
  final String? groupLabel;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final ringRadius = width * 0.13 + 3;
    final faded = cell.isNeeded || cell.groupIndex == -1;

    return Semantics(
      label: _label(context.l10n),
      // One composed announcement per cell, not the inner tile's own label.
      excludeSemantics: true,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Tile(
            color: cell.tile.color,
            number: cell.tile.number,
            widthOverride: width,
            faded: faded,
          ),
          if (cell.isNeeded)
            Positioned(
              left: -3,
              top: -3,
              right: -3,
              bottom: -3,
              child: IgnorePointer(
                child: CustomPaint(
                  painter: DashedRRectPainter(
                    color: palette.faint,
                    radius: ringRadius,
                  ),
                ),
              ),
            )
          else if (ringColor != null)
            Positioned(
              left: -3,
              top: -3,
              right: -3,
              bottom: -3,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(ringRadius),
                    border: Border.all(color: ringColor!, width: 1.5),
                  ),
                ),
              ),
            ),
          if (cell.isWild)
            const Positioned(bottom: -4, right: -4, child: _WildBadge()),
          if (cell.isDiscard)
            const Positioned(top: -4, right: -4, child: _DiscardBadge()),
        ],
      ),
    );
  }

  String _label(AppLocalizations l10n) {
    final tileText = formatTileLabel(l10n, cell.tile.color, cell.tile.number);
    final base = cell.isDiscard
        ? l10n.resultDiscardTileSemantics(tileText)
        : cell.isNeeded
        ? l10n.resultNeededTileSemantics(tileText)
        : cell.isWild
        ? l10n.resultWildTileSemantics(tileText)
        : tileText;
    final group = groupLabel;
    return group == null ? base : l10n.resultCellSemantics(base, group);
  }
}

/// Small joker-glyph badge marking a wild standing in for a tile.
class _WildBadge extends StatelessWidget {
  const _WildBadge();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        color: palette.surface2,
        shape: BoxShape.circle,
        border: Border.all(color: palette.line2),
      ),
      child: Center(
        child: CustomPaint(
          size: const Size.square(9),
          painter: JokerGlyph(color: palette.ink),
        ),
      ),
    );
  }
}

/// Small down-arrow badge marking the suggested discard.
class _DiscardBadge extends StatelessWidget {
  const _DiscardBadge();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        color: palette.surface2,
        shape: BoxShape.circle,
        border: Border.all(color: palette.warn),
      ),
      child: Icon(Icons.arrow_downward, size: 10, color: palette.warn),
    );
  }
}

/// Paints a dashed rounded-rect outline (needed rings, dashed swatches, the
/// leftover card border).
class DashedRRectPainter extends CustomPainter {
  /// Creates a [DashedRRectPainter].
  const DashedRRectPainter({
    required this.color,
    required this.radius,
    this.strokeWidth = 1.5,
    this.dashLength = 4,
    this.gapLength = 3,
  });

  /// Stroke color.
  final Color color;

  /// Corner radius of the outlined rounded rect.
  final double radius;

  /// Stroke width.
  final double strokeWidth;

  /// Length of each dash segment.
  final double dashLength;

  /// Gap between dash segments.
  final double gapLength;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)),
      );
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        canvas.drawPath(
          metric.extractPath(
            distance,
            math.min(distance + dashLength, metric.length),
          ),
          paint,
        );
        distance += dashLength + gapLength;
      }
    }
  }

  @override
  bool shouldRepaint(DashedRRectPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.radius != radius ||
      oldDelegate.strokeWidth != strokeWidth ||
      oldDelegate.dashLength != dashLength ||
      oldDelegate.gapLength != gapLength;
}

/// The legend under the rack: one row per group (swatch, label, tile count,
/// points) and a leftover row above a hairline.
class _ArrangementLegend extends StatelessWidget {
  const _ArrangementLegend({required this.arrangement});

  final ResultArrangement arrangement;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final palette = context.palette;
    final groups = arrangement.groups;

    return Column(
      children: [
        for (var i = 0; i < groups.length; i++)
          Padding(
            padding: EdgeInsets.only(top: i == 0 ? 0 : 10),
            child: _LegendRow(group: groups[i], index: i),
          ),
        if (arrangement.leftovers.isNotEmpty)
          Container(
            margin: EdgeInsets.only(top: groups.isEmpty ? 0 : 10),
            padding: EdgeInsets.only(top: groups.isEmpty ? 0 : 8),
            decoration: groups.isEmpty
                ? null
                : BoxDecoration(
                    border: Border(top: BorderSide(color: palette.line)),
                  ),
            child: Row(
              children: [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CustomPaint(
                    painter: DashedRRectPainter(
                      color: palette.faint,
                      radius: 4,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    l10n.resultLeftover(arrangement.leftovers.length),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.textTheme.bodyMedium?.copyWith(
                      color: palette.muted,
                    ),
                  ),
                ),
                Text(
                  '—',
                  style: AppTypography.monoStyle(color: palette.muted),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// One legend row: colored swatch, group label + tile count, mono points.
class _LegendRow extends StatelessWidget {
  const _LegendRow({required this.group, required this.index});

  final ResultGroup group;
  final int index;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final palette = context.palette;
    final points = group.points;

    return Row(
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: resultGroupRingColor(palette, index),
              width: 1.5,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text.rich(
            TextSpan(
              text: resultGroupKindLabel(l10n, group.kind),
              style: context.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
                color: palette.ink,
              ),
              children: [
                TextSpan(
                  text: ' · ${l10n.resultLegendTileCount(group.cells.length)}',
                  style: context.textTheme.bodySmall?.copyWith(
                    color: palette.muted,
                  ),
                ),
              ],
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Text(
          points == null ? '—' : '+$points',
          style: AppTypography.monoStyle(
            color: points == null ? palette.muted : palette.accent,
          ),
        ),
      ],
    );
  }
}
