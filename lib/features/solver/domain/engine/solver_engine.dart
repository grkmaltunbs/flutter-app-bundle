import 'package:injectable/injectable.dart';
import 'package:okey_acar_mi/core/game/game_mode.dart';
import 'package:okey_acar_mi/core/game/game_tile.dart';
import 'package:okey_acar_mi/features/solver/domain/engine/meld_reconstructor.dart';
import 'package:okey_acar_mi/features/solver/domain/engine/meld_score_dp.dart';
import 'package:okey_acar_mi/features/solver/domain/engine/okey_reconstructor.dart';
import 'package:okey_acar_mi/features/solver/domain/engine/okey_win_dp.dart';
import 'package:okey_acar_mi/features/solver/domain/engine/pairs_evaluator.dart';
import 'package:okey_acar_mi/features/solver/domain/engine/rack_normalizer.dart';
import 'package:okey_acar_mi/features/solver/domain/entities/reasoning_step.dart';
import 'package:okey_acar_mi/features/solver/domain/entities/solve_request.dart';
import 'package:okey_acar_mi/features/solver/domain/entities/solve_result.dart';
import 'package:okey_acar_mi/features/solver/domain/entities/solve_verdict.dart';
import 'package:okey_acar_mi/features/solver/domain/entities/solved_meld.dart';
import 'package:okey_acar_mi/features/solver/domain/entities/solved_pair.dart';
import 'package:okey_acar_mi/features/solver/domain/entities/solved_spot.dart';

/// The solver: best legal arrangement + verdict for a rack.
abstract interface class SolverEngine {
  /// Solves [request] deterministically. Never throws on garbage input.
  SolveResult solve(SolveRequest request);
}

/// Exact DP implementation (§1–§3). Pure logic, identical in demo and
/// prod (no environment split). No per-solve mutable state — the only
/// shared state is `ColorTupleSpace`'s bounded deterministic static cache
/// of tuple spaces (rebuilt per isolate) ⇒ isolate-sendable.
@LazySingleton(as: SolverEngine)
class DpSolverEngine implements SolverEngine {
  /// Creates a [DpSolverEngine].
  const DpSolverEngine();

  static const int _openingThreshold = 101;
  static const int _openingPairs = 5;

  @override
  SolveResult solve(SolveRequest request) {
    const normalizer = RackNormalizer();
    final rack = normalizer.normalize(request.tiles, request.indicator);

    final reasoning = <ReasoningStep>[
      ReasoningStep.okeyDerived(
        indicator: request.indicator,
        okeyTile: rack.okeyTile,
      ),
      ReasoningStep.wildsCounted(
        falseJokers: rack.falseJokerCount,
        okeyCopies: rack.okeyCopyCount,
      ),
      ReasoningStep.rackCountNoted(
        count: request.tiles.length,
        mode: request.mode,
      ),
      for (final clamp in rack.clamped)
        ReasoningStep.countsClamped(kind: clamp.kind, dropped: clamp.dropped),
    ];

    final dpResult = const MeldScoreDp().run(rack);

    return switch (request.mode) {
      GameMode.oneZeroOne => _solve101(rack, dpResult, reasoning),
      GameMode.okey => _solveOkey(rack, dpResult, reasoning),
    };
  }

  SolveResult _solve101(
    NormalizedRack rack,
    MeldScoreDpResult dpResult,
    List<ReasoningStep> reasoning,
  ) {
    final arrangement = const MeldReconstructor().reconstruct(rack, dpResult);
    var runningTotal = 0;
    for (final meld in arrangement.melds) {
      runningTotal += meld.points;
      reasoning.add(
        ReasoningStep.meldFormed(meld: meld, runningTotal: runningTotal),
      );
    }
    final opensViaMelds = dpResult.best >= _openingThreshold;
    reasoning.add(
      ReasoningStep.thresholdChecked(
        total: dpResult.best,
        threshold: _openingThreshold,
        opens: opensViaMelds,
      ),
    );

    final pairsEval = const PairsEvaluator().evaluateFivePairs(rack);
    final opensViaPairs = pairsEval.pairCount >= _openingPairs;
    reasoning.add(
      ReasoningStep.pairsCounted(
        pairCount: pairsEval.pairCount,
        opens: opensViaPairs,
      ),
    );

    if (opensViaMelds || opensViaPairs) {
      final via = opensViaMelds ? OpenPath.melds : OpenPath.pairs;
      reasoning.add(ReasoningStep.pathChosen(via: via));
      final useMelds = via == OpenPath.melds;
      return SolveResult(
        melds: useMelds ? arrangement.melds : const [],
        pairs: useMelds ? const [] : pairsEval.pairs,
        leftovers: _leftovers(
          rack,
          useMelds ? arrangement.usedRackIndices : pairsEval.usedRackIndices,
        ),
        totalScore: dpResult.best,
        verdict: SolveVerdict.opens101(score: dpResult.best, via: via),
        reasoning: reasoning,
      );
    }
    return SolveResult(
      melds: arrangement.melds,
      pairs: const [],
      leftovers: _leftovers(rack, arrangement.usedRackIndices),
      totalScore: dpResult.best,
      verdict: SolveVerdict.doesNotOpen101(
        score: dpResult.best,
        pointsShort: _openingThreshold - dpResult.best,
      ),
      reasoning: reasoning,
    );
  }

  SolveResult _solveOkey(
    NormalizedRack rack,
    MeldScoreDpResult dpResult,
    List<ReasoningStep> reasoning,
  ) {
    final okeyResult = const OkeyWinDp().run(rack);
    final template = const OkeyReconstructor().reconstruct(rack, okeyResult);
    final sevenPairs = const PairsEvaluator().evaluateSevenPairs(rack);

    final keptMeld = _kept(template.matched, rack.wildCount);
    final keptSeven = _kept(sevenPairs.matched, rack.wildCount);
    // Tie → meldsAndPair.
    final via = keptMeld >= keptSeven
        ? OkeyPath.meldsAndPair
        : OkeyPath.sevenPairs;
    final tilesToWin = 14 - (keptMeld >= keptSeven ? keptMeld : keptSeven);

    final useMelds = via == OkeyPath.meldsAndPair;
    final conversion = _convertPhantoms(
      rack,
      melds: useMelds ? template.melds : const [],
      pairs: useMelds
          ? [if (template.pair != null) template.pair!]
          : sevenPairs.pairs,
    );
    final used = {
      ...(useMelds ? template.usedRackIndices : sevenPairs.usedRackIndices),
      ...conversion.wildIndicesUsed,
    };
    assert(
      conversion.stillNeeded.length == tilesToWin,
      'unconverted phantoms must equal tilesToWin',
    );

    reasoning.add(
      ReasoningStep.okeyTemplateChosen(
        via: via,
        matched: useMelds ? template.matched : sevenPairs.matched,
        wildsUsed: conversion.wildsUsed,
      ),
    );
    var runningTotal = 0;
    for (final meld in conversion.melds) {
      runningTotal += meld.points;
      reasoning.add(
        ReasoningStep.meldFormed(meld: meld, runningTotal: runningTotal),
      );
    }
    if (conversion.stillNeeded.isNotEmpty) {
      reasoning.add(ReasoningStep.tilesNeeded(needed: conversion.stillNeeded));
    }

    final leftovers = _leftovers(rack, used);
    final discard = _suggestDiscard(rack, leftovers);
    if (discard != null) {
      reasoning.add(
        ReasoningStep.discardSuggested(
          tile: discard.physical,
          rackIndex: discard.rackIndex,
        ),
      );
    }
    reasoning.add(ReasoningStep.tilesToWinComputed(tilesToWin: tilesToWin));

    return SolveResult(
      melds: conversion.melds,
      pairs: conversion.pairs,
      leftovers: leftovers,
      totalScore: dpResult.best,
      verdict: SolveVerdict.okeyOutcome(tilesToWin: tilesToWin, via: via),
      reasoning: reasoning,
      discardSuggested: discard?.physical,
      discardRackIndex: discard?.rackIndex,
    );
  }

  /// §3b reduction: `kept = min(14, matched + W)`.
  int _kept(int matched, int wilds) =>
      matched + wilds > 14 ? 14 : matched + wilds;

  /// Converts the first `min(W, #phantoms)` [NeededSpot]s to wild-filled
  /// spots in canonical meld order (melds first, then pairs; left to
  /// right within each).
  _PhantomConversion _convertPhantoms(
    NormalizedRack rack, {
    required List<SolvedMeld> melds,
    required List<SolvedPair> pairs,
  }) {
    var wildPos = 0;
    final wildIndices = <int>{};
    final stillNeeded = <GameTile>[];

    SolvedSpot convert(SolvedSpot spot) {
      if (spot is! NeededSpot) return spot;
      if (wildPos < rack.wildQueue.length) {
        final index = rack.wildQueue[wildPos++];
        wildIndices.add(index);
        return SolvedSpot.wild(
          physical: rack.tiles[index],
          rackIndex: index,
          playsAs: spot.playsAs,
        );
      }
      stillNeeded.add(spot.playsAs);
      return spot;
    }

    final newMelds = [
      for (final meld in melds)
        meld.copyWith(spots: [for (final s in meld.spots) convert(s)]),
    ];
    final newPairs = [
      for (final pair in pairs)
        pair.copyWith(first: convert(pair.first), second: convert(pair.second)),
    ];
    return _PhantomConversion(
      melds: newMelds,
      pairs: newPairs,
      stillNeeded: stillNeeded,
      wildIndicesUsed: wildIndices,
      wildsUsed: wildPos,
    );
  }

  /// Unbound rack tiles in rack order; forced clamped leftovers included.
  List<SolvedSpot> _leftovers(NormalizedRack rack, Set<int> used) {
    final spots = <SolvedSpot>[];
    for (var i = 0; i < rack.tiles.length; i++) {
      if (used.contains(i)) continue;
      final tile = rack.tiles[i];
      final isWild = tile.isJoker || tile == rack.okeyTile;
      spots.add(
        isWild
            ? SolvedSpot.wild(physical: tile, rackIndex: i, playsAs: tile)
            : SolvedSpot.rackTile(physical: tile, rackIndex: i, playsAs: tile),
      );
    }
    return spots;
  }

  /// Discard rule (15+-tile okey racks): lowest-face non-wild leftover,
  /// tie → lowest rack index; all-wild leftovers → lowest rack index.
  ({GameTile physical, int rackIndex})? _suggestDiscard(
    NormalizedRack rack,
    List<SolvedSpot> leftovers,
  ) {
    if (rack.tiles.length < 15 || leftovers.isEmpty) return null;
    RackSpot? best;
    for (final spot in leftovers) {
      if (spot is! RackSpot) continue;
      if (best == null ||
          (spot.physical.number ?? 14) < (best.physical.number ?? 14)) {
        best = spot;
      }
    }
    if (best != null) {
      return (physical: best.physical, rackIndex: best.rackIndex);
    }
    // Leftovers hold only RackSpot/WildSpot; all-wild → lowest rack index.
    final fallback = leftovers.first as WildSpot;
    return (physical: fallback.physical, rackIndex: fallback.rackIndex);
  }
}

class _PhantomConversion {
  const _PhantomConversion({
    required this.melds,
    required this.pairs,
    required this.stillNeeded,
    required this.wildIndicesUsed,
    required this.wildsUsed,
  });

  final List<SolvedMeld> melds;
  final List<SolvedPair> pairs;
  final List<GameTile> stillNeeded;
  final Set<int> wildIndicesUsed;
  final int wildsUsed;
}
