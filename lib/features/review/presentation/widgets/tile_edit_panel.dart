import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:okey_acar_mi/core/extensions/context_extensions.dart';
import 'package:okey_acar_mi/core/theme/app_typography.dart';
import 'package:okey_acar_mi/core/widgets/app_buttons.dart';
import 'package:okey_acar_mi/core/widgets/app_card.dart';
import 'package:okey_acar_mi/core/widgets/eyebrow.dart';
import 'package:okey_acar_mi/core/widgets/tile.dart';
import 'package:okey_acar_mi/features/review/presentation/blocs/review_bloc.dart';

/// The inline edit panel for the tile being edited: color circles (the four
/// colors + joker), the 1–13 numeral grid (hidden while the joker is
/// selected), and the remove action (enabled only above the mode's minimum
/// rack size).
class TileEditPanel extends StatelessWidget {
  /// Creates a [TileEditPanel].
  const TileEditPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ReviewBloc, ReviewState>(
      buildWhen: (a, b) =>
          a.editingIndex != b.editingIndex || a.tiles != b.tiles,
      builder: (context, state) {
        final index = state.editingIndex;
        final tile = state.editingTile;
        if (index == null || tile == null) return const SizedBox.shrink();

        final l10n = context.l10n;
        final bloc = context.read<ReviewBloc>();
        return AppCard(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Eyebrow(l10n.reviewEditTileTitle(index + 1)),
                  ),
                  _CloseButton(
                    onPressed: () => bloc.add(const ReviewEvent.editClosed()),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Eyebrow(l10n.reviewEditColorLabel),
              const SizedBox(height: 8),
              Wrap(
                spacing: 2,
                runSpacing: 2,
                children: [
                  for (final color in TileColor.values)
                    _ColorButton(
                      color: color,
                      selected: tile.color == color,
                      onPressed: () =>
                          bloc.add(ReviewEvent.tileColorChanged(color)),
                    ),
                ],
              ),
              if (tile.color != TileColor.joker) ...[
                const SizedBox(height: 14),
                Eyebrow(l10n.reviewEditNumberLabel),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 2,
                  runSpacing: 2,
                  children: [
                    for (var n = 1; n <= 13; n++)
                      _NumberButton(
                        number: n,
                        selected: tile.number == n,
                        onPressed: () =>
                            bloc.add(ReviewEvent.tileNumberChanged(n)),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 14),
              GhostButton(
                key: const ValueKey('review-remove-tile'),
                label: l10n.reviewRemoveTile,
                icon: Icons.delete_outline,
                foregroundColor: context.palette.bad,
                onPressed: state.canRemove
                    ? () => bloc.add(const ReviewEvent.tileRemoved())
                    : null,
              ),
            ],
          ),
        );
      },
    );
  }
}

/// The panel's icon-only close button (≥48dp target).
class _CloseButton extends StatelessWidget {
  const _CloseButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: context.l10n.reviewEditCloseSemantics,
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 48,
          height: 48,
          child: Icon(Icons.close, size: 18, color: context.palette.muted),
        ),
      ),
    );
  }
}

/// A 44pt color circle (joker shows the glyph on a surface chip) in a ≥48dp
/// hit area.
class _ColorButton extends StatelessWidget {
  const _ColorButton({
    required this.color,
    required this.selected,
    required this.onPressed,
  });

  final TileColor color;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final l10n = context.l10n;
    final fill = switch (color) {
      TileColor.red => palette.tileRed,
      TileColor.black => palette.tileBlack,
      TileColor.yellow => palette.tileYellow,
      TileColor.blue => palette.tileBlue,
      TileColor.joker => palette.surface2,
    };
    final name = switch (color) {
      TileColor.red => l10n.tileColorRed,
      TileColor.black => l10n.tileColorBlack,
      TileColor.yellow => l10n.tileColorYellow,
      TileColor.blue => l10n.tileColorBlue,
      TileColor.joker => l10n.jokerSemantics,
    };

    return Semantics(
      button: true,
      selected: selected,
      label: name,
      excludeSemantics: true,
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 48,
          height: 48,
          child: Center(
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: fill,
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? palette.ink : Colors.transparent,
                  width: 2,
                ),
              ),
              child: color == TileColor.joker
                  ? Center(
                      child: CustomPaint(
                        size: const Size.square(20),
                        painter: JokerGlyph(color: palette.ink),
                      ),
                    )
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}

/// A 44pt numeral chip in a ≥48dp hit area.
class _NumberButton extends StatelessWidget {
  const _NumberButton({
    required this.number,
    required this.selected,
    required this.onPressed,
  });

  final int number;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 48,
          height: 48,
          child: Center(
            child: Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? palette.ink : palette.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: selected ? palette.ink : palette.line,
                ),
              ),
              child: Text(
                '$number',
                style: AppTypography.monoStyle(
                  color: selected ? palette.surface : palette.ink,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
