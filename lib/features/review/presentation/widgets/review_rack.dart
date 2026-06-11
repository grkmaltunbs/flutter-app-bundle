import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:okey_acar_mi/core/extensions/context_extensions.dart';
import 'package:okey_acar_mi/core/game/game_tile.dart';
import 'package:okey_acar_mi/core/widgets/rack.dart';
import 'package:okey_acar_mi/core/widgets/tile.dart';
import 'package:okey_acar_mi/core/widgets/tile_slot.dart';
import 'package:okey_acar_mi/features/review/domain/entities/review_tile.dart';
import 'package:okey_acar_mi/features/review/presentation/blocs/review_bloc.dart';
import 'package:okey_acar_mi/l10n/app_localizations.dart';

/// The editable two-row rack on the review screen, plus the low-confidence
/// legend below it.
///
/// Tiles render at a fixed [TileSize.md] inside a horizontal scroll view (a
/// 21-tile rack scrolls on narrow screens instead of shrinking below tappable
/// size), centered when the rows are narrower than the viewport. Undefined
/// tiles render as dashed [TileSlot]s; once the indicator is set, false
/// jokers display as the okey tile with a joker-glyph corner badge (display
/// only — the underlying data stays joker, D4).
class ReviewRack extends StatefulWidget {
  /// Creates a [ReviewRack].
  const ReviewRack({super.key});

  @override
  State<ReviewRack> createState() => _ReviewRackState();
}

class _ReviewRackState extends State<ReviewRack> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ReviewBloc, ReviewState>(
      buildWhen: (a, b) =>
          a.tiles != b.tiles ||
          a.editingIndex != b.editingIndex ||
          a.indicator != b.indicator,
      builder: (context, state) {
        final hasLowConfidence = state.tiles.any((tile) => tile.lowConfidence);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RackFrame(
              child: LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  controller: _scrollController,
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    // Center the rows when they are narrower than the frame.
                    constraints: BoxConstraints(
                      minWidth: constraints.maxWidth,
                    ),
                    child: Padding(
                      // Slack so the selected-tile lift (−4) and the warn /
                      // joker badges (−4/−4) are not clipped by the scroll
                      // view.
                      padding: const EdgeInsets.fromLTRB(4, 6, 4, 0),
                      child: _TwoRowGrid(state: state),
                    ),
                  ),
                ),
              ),
            ),
            if (hasLowConfidence) ...[
              const SizedBox(height: 12),
              const _LowConfidenceLegend(),
            ],
          ],
        );
      },
    );
  }
}

/// The two centered rows of editable cells (split `(n / 2).ceil()`).
class _TwoRowGrid extends StatelessWidget {
  const _TwoRowGrid({required this.state});

  final ReviewState state;

  @override
  Widget build(BuildContext context) {
    final count = state.tiles.length;
    final splitAt = (count / 2).ceil();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _row(0, splitAt),
        if (splitAt < count) ...[
          const SizedBox(height: 6),
          _row(splitAt, count),
        ],
      ],
    );
  }

  Widget _row(int from, int to) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = from; i < to; i++) _RackCell(index: i, state: state),
      ],
    );
  }
}

/// One tappable rack cell: tile / slot visual, selection ring, warn dot,
/// false-joker badge, and a single merged semantics node.
class _RackCell extends StatelessWidget {
  const _RackCell({required this.index, required this.state});

  final int index;
  final ReviewState state;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tile = state.tiles[index];
    final selected = state.editingIndex == index;
    final okeyTile = state.okeyTile;
    final isFalseJoker = tile.color == TileColor.joker && okeyTile != null;

    return Semantics(
      button: true,
      selected: selected,
      label: _label(l10n, tile, okeyTile),
      // Announce the composed label once instead of the inner tile's own
      // semantics followed by it again.
      excludeSemantics: true,
      child: InkWell(
        onTap: () =>
            context.read<ReviewBloc>().add(ReviewEvent.tileTapped(index)),
        borderRadius: BorderRadius.circular(8),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          child: Center(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                _visual(tile, okeyTile, selected: selected),
                if (selected && !_rendersAsTile(tile))
                  const Positioned.fill(child: _SelectionRing()),
                if (tile.lowConfidence)
                  const Positioned(top: -4, right: -4, child: _WarnDot()),
                if (isFalseJoker)
                  const Positioned(
                    bottom: -4,
                    right: -4,
                    child: _JokerBadge(),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Whether the cell renders a real [Tile] (which carries its own selection
  /// ring) rather than a dashed slot.
  bool _rendersAsTile(ReviewTile tile) =>
      tile.color != null &&
      (tile.color == TileColor.joker || tile.number != null);

  Widget _visual(
    ReviewTile tile,
    GameTile? okeyTile, {
    required bool selected,
  }) {
    final color = tile.color;
    // Undefined placeholder, or a partial tile (real color, no number yet —
    // e.g. right after switching a joker to a color).
    if (!_rendersAsTile(tile)) return const TileSlot();
    if (color == TileColor.joker && okeyTile != null) {
      // False joker displays as the okey it stands in for (D4).
      return Tile(
        color: okeyTile.color,
        number: okeyTile.number,
        selected: selected,
      );
    }
    return Tile(color: color!, number: tile.number, selected: selected);
  }

  String _label(AppLocalizations l10n, ReviewTile tile, GameTile? okeyTile) {
    final color = tile.color;
    if (!_rendersAsTile(tile)) return l10n.reviewUndefinedTileSemantics;

    final String base;
    if (color == TileColor.joker && okeyTile != null) {
      base = l10n.reviewFalseJokerTileSemantics(
        _colorName(l10n, okeyTile.color),
        okeyTile.number!,
      );
    } else if (color == TileColor.joker) {
      base = l10n.jokerSemantics;
    } else {
      base = l10n.tileSemantics(_colorName(l10n, color!), tile.number!);
    }
    final positioned = l10n.reviewTileSemantics(
      base,
      index + 1,
      state.tiles.length,
    );
    return tile.lowConfidence
        ? '$positioned, ${l10n.reviewLowConfidenceLegend}'
        : positioned;
  }

  String _colorName(AppLocalizations l10n, TileColor color) => switch (color) {
    TileColor.red => l10n.tileColorRed,
    TileColor.black => l10n.tileColorBlack,
    TileColor.yellow => l10n.tileColorYellow,
    TileColor.blue => l10n.tileColorBlue,
    TileColor.joker => l10n.jokerSemantics,
  };
}

/// Accent ring drawn over a selected dashed slot (a real [Tile] paints its
/// own selection ring).
class _SelectionRing extends StatelessWidget {
  const _SelectionRing();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(38 * 0.13),
          border: Border.all(color: context.palette.accent, width: 1.5),
        ),
      ),
    );
  }
}

/// The low-confidence warn dot pinned to a cell's top-right corner.
class _WarnDot extends StatelessWidget {
  const _WarnDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        color: context.palette.warn,
        shape: BoxShape.circle,
        border: Border.all(
          color: Theme.of(context).scaffoldBackgroundColor,
          width: 2,
        ),
      ),
    );
  }
}

/// Small joker-glyph badge marking a false joker rendered as the okey tile.
class _JokerBadge extends StatelessWidget {
  const _JokerBadge();

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

/// Warn-dot legend row shown when any tile carries the low-confidence flag.
class _LowConfidenceLegend extends StatelessWidget {
  const _LowConfidenceLegend();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Row(
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(
            color: palette.warn,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            context.l10n.reviewLowConfidenceLegend,
            style: context.textTheme.bodySmall?.copyWith(
              color: palette.muted,
            ),
          ),
        ),
      ],
    );
  }
}
