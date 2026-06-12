import 'package:flutter/material.dart';
import 'package:okey_acar_mi/core/extensions/context_extensions.dart';
import 'package:okey_acar_mi/core/theme/app_radii.dart';
import 'package:okey_acar_mi/core/theme/app_typography.dart';
import 'package:okey_acar_mi/core/widgets/app_card.dart';
import 'package:okey_acar_mi/core/widgets/app_pill.dart';
import 'package:okey_acar_mi/core/widgets/eyebrow.dart';
import 'package:okey_acar_mi/core/widgets/tile.dart';
import 'package:okey_acar_mi/features/result/presentation/models/result_arrangement.dart';
import 'package:okey_acar_mi/features/result/presentation/reasoning_step_localizer.dart';
import 'package:okey_acar_mi/features/result/presentation/widgets/result_rack_layout.dart';

/// "GRUPLAR": one card per meld/pair (eyebrow label + points pill + the
/// tiles in a wrap), plus a dashed leftover card with faded tiles.
class ResultListLayout extends StatelessWidget {
  /// Creates a [ResultListLayout] for [arrangement].
  const ResultListLayout({required this.arrangement, super.key});

  /// The arranged display model.
  final ResultArrangement arrangement;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Eyebrow(l10n.resultGroups),
        const SizedBox(height: 10),
        for (final group in arrangement.groups)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _GroupCard(group: group),
          ),
        if (arrangement.leftovers.isNotEmpty)
          _LeftoverCard(leftovers: arrangement.leftovers),
      ],
    );
  }
}

/// One meld/pair card: label, points pill (melds only), and the tiles.
class _GroupCard extends StatelessWidget {
  const _GroupCard({required this.group});

  final ResultGroup group;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final palette = context.palette;
    final points = group.points;

    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Eyebrow(resultGroupKindLabel(l10n, group.kind))),
              if (points == null)
                Text(
                  '—',
                  style: AppTypography.monoStyle(
                    fontSize: 11,
                    color: palette.muted,
                  ),
                )
              else
                AppPill(label: '+$points', variant: PillVariant.accent),
            ],
          ),
          const SizedBox(height: 10),
          _CellWrap(cells: group.cells),
        ],
      ),
    );
  }
}

/// The unused tiles in a dashed-border card.
class _LeftoverCard extends StatelessWidget {
  const _LeftoverCard({required this.leftovers});

  final List<ResultCell> leftovers;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final palette = context.palette;

    return CustomPaint(
      painter: DashedRRectPainter(
        color: palette.line2,
        radius: AppRadii.lg,
        strokeWidth: 1,
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Eyebrow(l10n.resultLeftover(leftovers.length)),
                ),
                Text(
                  '—',
                  style: AppTypography.monoStyle(
                    fontSize: 11,
                    color: palette.muted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _CellWrap(cells: leftovers),
          ],
        ),
      ),
    );
  }
}

/// The cells of one card in a lazy-free wrap (≤ 13 tiles per group), with
/// slack so corner badges are not clipped.
class _CellWrap extends StatelessWidget {
  const _CellWrap({required this.cells});

  final List<ResultCell> cells;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, right: 4),
      child: Wrap(
        spacing: 4,
        runSpacing: 8,
        children: [
          for (final cell in cells)
            ResultTileCell(cell: cell, width: TileSize.sm.width),
        ],
      ),
    );
  }
}
