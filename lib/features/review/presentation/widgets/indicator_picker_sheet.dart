import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:okey_acar_mi/core/extensions/context_extensions.dart';
import 'package:okey_acar_mi/core/game/indicator.dart';
import 'package:okey_acar_mi/core/theme/app_typography.dart';
import 'package:okey_acar_mi/core/widgets/app_buttons.dart';
import 'package:okey_acar_mi/core/widgets/eyebrow.dart';
import 'package:okey_acar_mi/core/widgets/tile.dart';
import 'package:okey_acar_mi/features/review/presentation/blocs/review_bloc.dart';
import 'package:okey_acar_mi/l10n/app_localizations.dart';

/// Opens the indicator picker bottom sheet, sharing the page's [bloc].
Future<void> showIndicatorPickerSheet(
  BuildContext context, {
  required ReviewBloc bloc,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => BlocProvider.value(
      value: bloc,
      child: const IndicatorPickerSheet(),
    ),
  );
}

/// The indicator picker body (assumes a [ReviewBloc] above it): the four
/// real colors (never the joker, D5), the 1–13 numerals, a live okey
/// preview, and a confirm action.
///
/// Selection is ephemeral local state; only confirm dispatches
/// `indicatorPicked` to the bloc.
class IndicatorPickerSheet extends StatefulWidget {
  /// Creates an [IndicatorPickerSheet].
  const IndicatorPickerSheet({super.key});

  @override
  State<IndicatorPickerSheet> createState() => _IndicatorPickerSheetState();
}

class _IndicatorPickerSheetState extends State<IndicatorPickerSheet> {
  TileColor? _color;
  int? _number;

  @override
  void initState() {
    super.initState();
    final current = context.read<ReviewBloc>().state.indicator;
    _color = current?.color;
    _number = current?.number;
  }

  Indicator? get _pending => _color == null || _number == null
      ? null
      : Indicator(color: _color!, number: _number!);

  void _confirm() {
    context.read<ReviewBloc>().add(
      ReviewEvent.indicatorPicked(_color!, _number!),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final palette = context.palette;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final pending = _pending;

    return SafeArea(
      child: SingleChildScrollView(
        key: const ValueKey('indicator-sheet'),
        padding: EdgeInsets.fromLTRB(24, 20, 24, 20 + bottomInset),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Eyebrow(l10n.reviewIndicatorTitle),
            const SizedBox(height: 8),
            Text(
              l10n.reviewIndicatorPick,
              style: AppTypography.serifStyle(fontSize: 28, color: palette.ink),
            ),
            const SizedBox(height: 16),
            Eyebrow(l10n.reviewEditColorLabel),
            const SizedBox(height: 8),
            Wrap(
              spacing: 2,
              runSpacing: 2,
              children: [
                // The indicator is a real tile — the joker is not offered.
                for (final color in const [
                  TileColor.red,
                  TileColor.black,
                  TileColor.yellow,
                  TileColor.blue,
                ])
                  _ColorButton(
                    color: color,
                    selected: _color == color,
                    onPressed: () => setState(() => _color = color),
                  ),
              ],
            ),
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
                    selected: _number == n,
                    onPressed: () => setState(() => _number = n),
                  ),
              ],
            ),
            if (pending != null) ...[
              const SizedBox(height: 16),
              _OkeyPreview(indicator: pending),
            ],
            const SizedBox(height: 20),
            PrimaryButton(
              key: const ValueKey('indicator-confirm'),
              label: l10n.reviewIndicatorPick,
              fullWidth: true,
              onPressed: pending == null ? null : _confirm,
            ),
          ],
        ),
      ),
    );
  }
}

/// Live preview of the okey the pending indicator derives, as one merged
/// semantics node.
class _OkeyPreview extends StatelessWidget {
  const _OkeyPreview({required this.indicator});

  final Indicator indicator;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final okey = indicator.okeyTile;
    final label = l10n.reviewOkeyLabel(
      _colorName(l10n, okey.color),
      okey.number!,
    );

    return Semantics(
      label: label,
      excludeSemantics: true,
      child: Row(
        children: [
          Tile(color: okey.color, number: okey.number, size: TileSize.sm),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              label,
              style: AppTypography.monoStyle(
                fontSize: 13,
                color: context.palette.ink2,
              ),
            ),
          ),
        ],
      ),
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

/// A 44pt color circle in a ≥48dp hit area (indicator semantics).
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
      label: l10n.indicatorColorSemantics(name),
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
            ),
          ),
        ),
      ),
    );
  }
}

/// A 44pt numeral chip in a ≥48dp hit area (indicator semantics).
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
      label: context.l10n.indicatorNumberSemantics(number),
      excludeSemantics: true,
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
