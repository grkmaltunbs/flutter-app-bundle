import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:okey_acar_mi/core/game/game_tile.dart';
import 'package:okey_acar_mi/features/solver/domain/entities/reasoning_step.dart';
import 'package:okey_acar_mi/features/solver/domain/entities/solve_verdict.dart';
import 'package:okey_acar_mi/features/solver/domain/entities/solved_meld.dart';
import 'package:okey_acar_mi/features/solver/domain/entities/solved_pair.dart';
import 'package:okey_acar_mi/features/solver/domain/entities/solved_spot.dart';

part 'solve_result.freezed.dart';

/// Aggregate solver output.
///
/// Consumers must switch on [verdict] — the sealed discriminant — to know
/// which fields the chosen arrangement populates:
///
/// - [Opens101] via [OpenPath.melds] → [melds] populated, [pairs] empty.
/// - [Opens101] via [OpenPath.pairs] → [pairs] populated, [melds] empty.
/// - [DoesNotOpen101] → [melds] carries the best meld arrangement anyway
///   (possibly empty when nothing melds), [pairs] empty.
/// - [OkeyOutcome] via [OkeyPath.meldsAndPair] → **both** [melds] and
///   [pairs] populated: the melds plus the final pair (when the winning
///   template uses one) in [pairs]. Not an XOR.
/// - [OkeyOutcome] via [OkeyPath.sevenPairs] → [pairs] holds the 7 pair
///   slots, [melds] empty.
///
/// [totalScore] is the best meld-DP total in every case. All list orders
/// below are deterministic: equal [reasoning]/field content for equal
/// requests, always.
@freezed
abstract class SolveResult with _$SolveResult {
  /// Creates a [SolveResult].
  const factory SolveResult({
    /// Chosen melds in formation order (DP column ascending; within a
    /// column runs flush before sets, colors ascending). Stable across
    /// solves of equal requests.
    required List<SolvedMeld> melds,

    /// Chosen pairs: natural pairs by color then number, then wild- or
    /// phantom-completed pairs. Okey `meldsAndPair` puts the single final
    /// pair here. Deterministic order.
    required List<SolvedPair> pairs,

    /// Unused rack tiles in rack order (ascending `rackIndex`); only
    /// [RackSpot] / [WildSpot], never [NeededSpot].
    required List<SolvedSpot> leftovers,

    /// Best meld-DP total — populated for every verdict.
    required int totalScore,

    /// The sealed discriminant; see the class doc for the field contract.
    required SolveVerdict verdict,

    /// Typed explanation steps in a fixed per-mode sequence:
    /// normalization steps first ([OkeyDerivedStep], [WildsCountedStep],
    /// [RackCountNotedStep], any [CountsClampedStep]s), then the
    /// mode-specific steps in emission order.
    required List<ReasoningStep> reasoning,

    /// Suggested discard tile — okey-mode 15-tile racks only, else null.
    /// Mirrors the [DiscardSuggestedStep] in [reasoning].
    GameTile? discardSuggested,

    /// Rack index of [discardSuggested]; null exactly when it is null.
    int? discardRackIndex,
  }) = _SolveResult;
}
