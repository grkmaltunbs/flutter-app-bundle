import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:okey_acar_mi/core/game/game_mode.dart';
import 'package:okey_acar_mi/core/game/game_tile.dart';
import 'package:okey_acar_mi/core/game/indicator.dart';
import 'package:okey_acar_mi/features/solver/domain/entities/solve_verdict.dart';
import 'package:okey_acar_mi/features/solver/domain/entities/solved_meld.dart';

part 'reasoning_step.freezed.dart';

/// A typed, presentation-agnostic explanation step. Zero user-facing
/// strings live in the domain; the UI localizes each variant.
@freezed
sealed class ReasoningStep with _$ReasoningStep {
  /// The okey tile was derived from the indicator.
  const factory ReasoningStep.okeyDerived({
    required Indicator indicator,
    required GameTile okeyTile,
  }) = OkeyDerivedStep;

  /// Wilds on the rack were counted (false jokers + physical okey copies).
  const factory ReasoningStep.wildsCounted({
    required int falseJokers,
    required int okeyCopies,
  }) = WildsCountedStep;

  /// The rack size was noted against the mode's legal range.
  const factory ReasoningStep.rackCountNoted({
    required int count,
    required GameMode mode,
  }) = RackCountNotedStep;

  /// Excess copies of one kind were dropped (degenerate edits only).
  const factory ReasoningStep.countsClamped({
    required GameTile kind,
    required int dropped,
  }) = CountsClampedStep;

  /// A meld was formed; [runningTotal] is the score so far.
  const factory ReasoningStep.meldFormed({
    required SolvedMeld meld,
    required int runningTotal,
  }) = MeldFormedStep;

  /// The meld total was checked against the opening threshold.
  const factory ReasoningStep.thresholdChecked({
    required int total,
    required int threshold,
    required bool opens,
  }) = ThresholdCheckedStep;

  /// Achievable pairs were counted against the 5-pairs opening.
  const factory ReasoningStep.pairsCounted({
    required int pairCount,
    required bool opens,
  }) = PairsCountedStep;

  /// Which 101 opening path the verdict uses.
  const factory ReasoningStep.pathChosen({
    required OpenPath via,
  }) = PathChosenStep;

  /// Which okey winning template was chosen and how it fills.
  const factory ReasoningStep.okeyTemplateChosen({
    required OkeyPath via,
    required int matched,
    required int wildsUsed,
  }) = OkeyTemplateChosenStep;

  /// The exact tiles still needed to complete the okey template.
  const factory ReasoningStep.tilesNeeded({
    required List<GameTile> needed,
  }) = TilesNeededStep;

  /// Suggested discard for a 15-tile okey rack.
  const factory ReasoningStep.discardSuggested({
    required GameTile tile,
    required int rackIndex,
  }) = DiscardSuggestedStep;

  /// The final tiles-to-win figure.
  const factory ReasoningStep.tilesToWinComputed({
    required int tilesToWin,
  }) = TilesToWinComputedStep;
}
