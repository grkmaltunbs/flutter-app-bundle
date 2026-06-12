import 'package:flutter/material.dart';
import 'package:okey_acar_mi/core/extensions/context_extensions.dart';
import 'package:okey_acar_mi/core/theme/app_radii.dart';
import 'package:okey_acar_mi/core/theme/app_typography.dart';
import 'package:okey_acar_mi/core/widgets/app_pill.dart';
import 'package:okey_acar_mi/core/widgets/rack.dart';
import 'package:okey_acar_mi/core/widgets/tile.dart';
import 'package:okey_acar_mi/core/widgets/tile_data.dart';

/// The verdict tone of a [ScanCard]'s pill.
enum ScanCardTone {
  /// Opened / winning (good pill + check icon).
  good,

  /// Did not open (bad pill + close icon).
  bad,

  /// Neutral outcome, e.g. okey tiles-to-win (plain pill, no icon).
  neutral,
}

/// A tappable history/last-scan card: timestamp + mode header, a verdict
/// pill, and a mini two-row rack — ported from the design bundle's history
/// rows (`result_screens.jsx`) and the home recent-scan card
/// (`main_screens.jsx`).
///
/// Primitives-only on purpose: callers map their domain entities to strings,
/// a [ScanCardTone], and [TileData] so `core/` stays feature-free.
class ScanCard extends StatelessWidget {
  /// Creates a [ScanCard].
  const ScanCard({
    required this.timestamp,
    required this.modeLabel,
    required this.pillLabel,
    required this.tone,
    required this.tiles,
    required this.onTap,
    required this.semanticsLabel,
    super.key,
  });

  /// The formatted scan timestamp (`21:48`, `Bugün · 21:48`, `21 May`).
  final String timestamp;

  /// The game-mode name shown after the timestamp (`101 Okey` / `Okey`).
  final String modeLabel;

  /// The verdict pill text (e.g. `Açtı · 104`).
  final String pillLabel;

  /// The verdict pill tone.
  final ScanCardTone tone;

  /// The scanned tiles, in rack order (rendered as a mini rack).
  final List<TileData> tiles;

  /// Opens the scan (whole card is the tap target).
  final VoidCallback onTap;

  /// The composed accessibility label announced for the whole card.
  final String semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Semantics(
      button: true,
      label: semanticsLabel,
      // One announcement for the whole card — the inner timestamp/pill/tile
      // labels would be triple noise on top of the composed label.
      excludeSemantics: true,
      child: Material(
        color: palette.surface,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadii.lg),
          child: Container(
            constraints: const BoxConstraints(minHeight: 48),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadii.lg),
              border: Border.all(color: palette.line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _header(context),
                const SizedBox(height: 10),
                Rack(tiles: tiles, maxSize: TileSize.xs),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    final palette = context.palette;
    final (variant, icon) = switch (tone) {
      ScanCardTone.good => (PillVariant.good, Icons.check),
      ScanCardTone.bad => (PillVariant.bad, Icons.close),
      ScanCardTone.neutral => (PillVariant.neutral, null),
    };
    return Row(
      children: [
        Expanded(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: timestamp,
                  style: AppTypography.monoStyle(
                    fontSize: 11,
                    color: palette.muted,
                  ),
                ),
                TextSpan(
                  text: ' · $modeLabel',
                  style: AppTypography.monoStyle(
                    fontSize: 11,
                    color: palette.faint,
                  ),
                ),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        // scaleDown only: an oversized pill (long label at textScale 2 on a
        // narrow card) shrinks instead of overflowing the header row.
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: AppPill(label: pillLabel, variant: variant, icon: icon),
          ),
        ),
      ],
    );
  }
}
