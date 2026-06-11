import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:okey_acar_mi/core/extensions/context_extensions.dart';
import 'package:okey_acar_mi/core/game/indicator.dart';
import 'package:okey_acar_mi/core/theme/app_typography.dart';
import 'package:okey_acar_mi/core/widgets/app_buttons.dart';
import 'package:okey_acar_mi/core/widgets/app_card.dart';
import 'package:okey_acar_mi/core/widgets/eyebrow.dart';
import 'package:okey_acar_mi/core/widgets/tile.dart';
import 'package:okey_acar_mi/features/review/presentation/blocs/review_bloc.dart';
import 'package:okey_acar_mi/features/review/presentation/widgets/indicator_picker_sheet.dart';
import 'package:okey_acar_mi/l10n/app_localizations.dart';

/// The indicator (gösterge) card: a pick CTA while unset; once set, the
/// indicator tile, the derived okey tile, the okey label, and the
/// false-joker note, plus a change action.
class IndicatorSection extends StatelessWidget {
  /// Creates an [IndicatorSection].
  const IndicatorSection({super.key});

  void _openPicker(BuildContext context) {
    unawaited(
      showIndicatorPickerSheet(context, bloc: context.read<ReviewBloc>()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocSelector<ReviewBloc, ReviewState, Indicator?>(
      selector: (state) => state.indicator,
      builder: (context, indicator) {
        final l10n = context.l10n;
        return AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Eyebrow(l10n.reviewIndicatorTitle),
              const SizedBox(height: 12),
              if (indicator == null)
                SecondaryButton(
                  key: const ValueKey('review-pick-indicator'),
                  label: l10n.reviewIndicatorPick,
                  icon: Icons.touch_app_outlined,
                  fullWidth: true,
                  onPressed: () => _openPicker(context),
                )
              else
                _PickedIndicator(
                  indicator: indicator,
                  onChange: () => _openPicker(context),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// The set-state body: indicator → okey tiles, labels, and the change action.
class _PickedIndicator extends StatelessWidget {
  const _PickedIndicator({required this.indicator, required this.onChange});

  final Indicator indicator;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final palette = context.palette;
    final okey = indicator.okeyTile;
    final okeyColorName = _colorName(l10n, okey.color);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Tile(
              color: indicator.color,
              number: indicator.number,
              size: TileSize.sm,
            ),
            const SizedBox(width: 10),
            Icon(Icons.arrow_forward, size: 16, color: palette.muted),
            const SizedBox(width: 10),
            Tile(color: okey.color, number: okey.number, size: TileSize.sm),
            Expanded(
              child: Align(
                alignment: AlignmentDirectional.centerEnd,
                child: GhostButton(
                  key: const ValueKey('review-change-indicator'),
                  label: l10n.reviewIndicatorChange,
                  onPressed: onChange,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          l10n.reviewOkeyLabel(okeyColorName, okey.number!),
          style: AppTypography.monoStyle(fontSize: 13, color: palette.ink2),
        ),
        const SizedBox(height: 4),
        Text(
          l10n.reviewFalseJokerNote(okeyColorName, okey.number!),
          style: context.textTheme.bodySmall?.copyWith(color: palette.muted),
        ),
      ],
    );
  }

  String _colorName(AppLocalizations l10n, TileColor color) => switch (color) {
    TileColor.red => l10n.tileColorRed,
    TileColor.black => l10n.tileColorBlack,
    TileColor.yellow => l10n.tileColorYellow,
    TileColor.blue => l10n.tileColorBlue,
    TileColor.joker => l10n.jokerSemantics,
  };
}
