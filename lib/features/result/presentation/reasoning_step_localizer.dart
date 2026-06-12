import 'package:okey_acar_mi/core/game/game_mode.dart';
import 'package:okey_acar_mi/core/game/game_tile.dart';
import 'package:okey_acar_mi/core/game/indicator.dart';
import 'package:okey_acar_mi/core/game/tile_color.dart';
import 'package:okey_acar_mi/features/result/presentation/models/result_arrangement.dart';
import 'package:okey_acar_mi/features/solver/domain/entities/reasoning_step.dart';
import 'package:okey_acar_mi/features/solver/domain/entities/solve_verdict.dart';
import 'package:okey_acar_mi/features/solver/domain/entities/solved_meld.dart';
import 'package:okey_acar_mi/l10n/app_localizations.dart';

/// The localized name of a tile color (joker → the joker label).
String tileColorLabel(AppLocalizations l10n, TileColor color) =>
    switch (color) {
      TileColor.red => l10n.tileColorRed,
      TileColor.black => l10n.tileColorBlack,
      TileColor.yellow => l10n.tileColorYellow,
      TileColor.blue => l10n.tileColorBlue,
      TileColor.joker => l10n.jokerSemantics,
    };

/// Formats a tile identity as user-facing text (e.g. "Kırmızı 7"; the joker
/// renders as its own label).
String formatTileLabel(AppLocalizations l10n, TileColor color, int? number) =>
    color == TileColor.joker || number == null
    ? l10n.jokerSemantics
    : l10n.tileSemantics(tileColorLabel(l10n, color), number);

/// Formats a [GameTile] as user-facing text.
String formatGameTile(AppLocalizations l10n, GameTile tile) =>
    formatTileLabel(l10n, tile.color, tile.number);

/// Formats an [Indicator] as user-facing text (always a numbered tile).
String formatIndicator(AppLocalizations l10n, Indicator indicator) =>
    l10n.tileSemantics(tileColorLabel(l10n, indicator.color), indicator.number);

/// The localized label of a display group kind (run / set / pair).
String resultGroupKindLabel(AppLocalizations l10n, ResultGroupKind kind) =>
    switch (kind) {
      ResultGroupKind.run => l10n.resultMeldRun,
      ResultGroupKind.set => l10n.resultMeldSet,
      ResultGroupKind.pair => l10n.resultPairLabel,
    };

/// The localized name of a game mode (for the rack-count reasoning step).
String gameModeLabel(AppLocalizations l10n, GameMode mode) => switch (mode) {
  GameMode.oneZeroOne => l10n.resultModeOneZeroOne,
  GameMode.okey => l10n.resultModeOkey,
};

/// Describes a meld for the reasoning list: kind plus its first/last
/// played-as identities (e.g. "Kırmızı 5–8 serisi", "5 kütü (3 renk)").
///
/// Presentation-only on purpose — the domain carries zero user-facing text.
String describeMeld(AppLocalizations l10n, SolvedMeld meld) {
  final first = meld.spots.first.playsAs;
  final last = meld.spots.last.playsAs;
  return switch (meld.kind) {
    MeldKind.run => l10n.resultMeldRunDescription(
      tileColorLabel(l10n, first.color),
      first.number!,
      last.number!,
    ),
    MeldKind.set => l10n.resultMeldSetDescription(
      first.number!,
      meld.spots.length,
    ),
  };
}

/// Localizes one [ReasoningStep] — exactly one arm per variant.
String reasoningStepText(AppLocalizations l10n, ReasoningStep step) =>
    switch (step) {
      OkeyDerivedStep(:final indicator, :final okeyTile) =>
        l10n.resultReasonOkeyDerived(
          formatIndicator(l10n, indicator),
          formatGameTile(l10n, okeyTile),
        ),
      WildsCountedStep(:final falseJokers, :final okeyCopies) =>
        l10n.resultReasonWildsCounted(falseJokers, okeyCopies),
      RackCountNotedStep(:final count, :final mode) =>
        l10n.resultReasonRackCountNoted(count, gameModeLabel(l10n, mode)),
      CountsClampedStep(:final kind, :final dropped) =>
        l10n.resultReasonCountsClamped(formatGameTile(l10n, kind), dropped),
      MeldFormedStep(:final meld, :final runningTotal) =>
        l10n.resultReasonMeldFormed(describeMeld(l10n, meld), runningTotal),
      ThresholdCheckedStep(:final total, :final threshold, :final opens) =>
        opens
            ? l10n.resultReasonThresholdOpens(total, threshold)
            : l10n.resultReasonThresholdShort(total, threshold),
      PairsCountedStep(:final pairCount, :final opens) =>
        opens
            ? l10n.resultReasonPairsCountedOpens(pairCount)
            : l10n.resultReasonPairsCounted(pairCount),
      PathChosenStep(:final via) => l10n.resultReasonPathChosen(
        via == OpenPath.melds ? l10n.resultPathMelds : l10n.resultPathPairs,
      ),
      OkeyTemplateChosenStep(:final via, :final matched, :final wildsUsed) =>
        l10n.resultReasonOkeyTemplateChosen(
          via == OkeyPath.meldsAndPair
              ? l10n.resultTemplateMeldsAndPair
              : l10n.resultTemplateSevenPairs,
          matched,
          wildsUsed,
        ),
      TilesNeededStep(:final needed) => l10n.resultReasonTilesNeeded(
        needed.map((tile) => formatGameTile(l10n, tile)).join(', '),
      ),
      DiscardSuggestedStep(:final tile) => l10n.resultReasonDiscardSuggested(
        formatGameTile(l10n, tile),
      ),
      TilesToWinComputedStep(:final tilesToWin) => l10n.resultReasonTilesToWin(
        tilesToWin,
      ),
    };
