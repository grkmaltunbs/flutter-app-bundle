import 'package:okey_acar_mi/core/widgets/scan_card.dart';
import 'package:okey_acar_mi/core/widgets/tile_data.dart';
import 'package:okey_acar_mi/features/history/domain/entities/scan.dart';
import 'package:okey_acar_mi/features/history/domain/entities/scan_summary.dart';
import 'package:okey_acar_mi/l10n/app_localizations.dart';

/// Resolves the verdict pill for [summary]: label text + [ScanCardTone].
///
/// Shared by the history list rows and the home last-scan card so the
/// verdict mapping lives in exactly one place: 101 verdicts compose
/// `label · score`; okey verdicts show `Okey` (winning) or the
/// tiles-to-win count.
(String, ScanCardTone) scanVerdictPill(
  AppLocalizations l10n,
  ScanSummary summary,
) {
  return switch (summary.kind) {
    ScanVerdictKind.opens101 => (
      '${l10n.scanCardOpened} · ${summary.score}',
      ScanCardTone.good,
    ),
    ScanVerdictKind.doesNotOpen101 => (
      '${l10n.scanCardClosed} · ${summary.score}',
      ScanCardTone.bad,
    ),
    ScanVerdictKind.okeyOutcome => switch (summary.tilesToWin ?? 0) {
      0 => (l10n.scanCardOkeyWin, ScanCardTone.good),
      final tilesToWin => (
        l10n.scanCardTilesToWin(tilesToWin),
        ScanCardTone.neutral,
      ),
    },
  };
}

/// Maps a scan's tiles to the rack widget's [TileData] (a joker `GameTile`
/// carries the joker color + null number, which renders the joker glyph).
List<TileData> scanCardTiles(Scan scan) => [
  for (final tile in scan.tiles)
    TileData(color: tile.color, number: tile.number),
];
