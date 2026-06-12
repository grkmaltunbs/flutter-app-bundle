import 'package:okey_acar_mi/core/game/game_tile.dart';
import 'package:okey_acar_mi/core/game/tile_color.dart';
import 'package:okey_acar_mi/features/solver/domain/engine/rack_normalizer.dart';
import 'package:okey_acar_mi/features/solver/domain/entities/solved_pair.dart';
import 'package:okey_acar_mi/features/solver/domain/entities/solved_spot.dart';

/// Outcome of the 101-mode 5-pairs evaluation (§3a).
class PairsEvaluation {
  /// Creates a [PairsEvaluation].
  const PairsEvaluation({
    required this.pairCount,
    required this.pairs,
    required this.usedRackIndices,
  });

  /// Maximum achievable pairs: `P + min(W, s) + ⌊max(0, W − s) / 2⌋`.
  final int pairCount;

  /// Canonical pair arrangement realizing [pairCount].
  final List<SolvedPair> pairs;

  /// Rack indices consumed by [pairs] (for leftover computation).
  final Set<int> usedRackIndices;
}

/// Outcome of the okey-mode seven-pairs greedy (§3b).
class SevenPairsPlan {
  /// Creates a [SevenPairsPlan].
  const SevenPairsPlan({
    required this.matched,
    required this.pairs,
    required this.usedRackIndices,
  });

  /// Real rack tiles placed in the 7 pair slots (wilds excluded).
  final int matched;

  /// The 7 pair slots; incomplete cells are [NeededSpot]s.
  final List<SolvedPair> pairs;

  /// Rack indices consumed by [pairs].
  final Set<int> usedRackIndices;
}

/// Exact pair-path evaluators: 5-pairs (101 opening) and 7-pairs (okey win).
class PairsEvaluator {
  /// Creates a [PairsEvaluator].
  const PairsEvaluator();

  /// 101-mode 5-pairs count + canonical arrangement.
  ///
  /// Exact by exchange: breaking a natural pair never helps; a wild's best
  /// use is completing one pair; two leftover wilds pair as the okey
  /// identity.
  PairsEvaluation evaluateFivePairs(NormalizedRack rack) {
    final pairs = <SolvedPair>[];
    final used = <int>{};
    final singleKinds = <(int, int)>[];

    for (var c = 0; c < 4; c++) {
      for (var n = 1; n <= 13; n++) {
        final queue = rack.instanceQueues[c][n];
        final count = rack.counts[c][n];
        final identity = GameTile(color: TileColor.values[c], number: n);
        var taken = 0;
        while (count - taken >= 2) {
          pairs.add(
            SolvedPair(
              identity: identity,
              first: _rackSpot(rack, queue[taken], identity),
              second: _rackSpot(rack, queue[taken + 1], identity),
            ),
          );
          used
            ..add(queue[taken])
            ..add(queue[taken + 1]);
          taken += 2;
        }
        if (count - taken == 1) singleKinds.add((c, n));
      }
    }

    var wildAt = 0;
    for (final (c, n) in singleKinds) {
      if (wildAt >= rack.wildQueue.length) break;
      final identity = GameTile(color: TileColor.values[c], number: n);
      final queue = rack.instanceQueues[c][n];
      final singleIndex = queue[rack.counts[c][n] - 1];
      final wildIndex = rack.wildQueue[wildAt++];
      pairs.add(
        SolvedPair(
          identity: identity,
          first: _rackSpot(rack, singleIndex, identity),
          second: _wildSpot(rack, wildIndex, identity),
        ),
      );
      used
        ..add(singleIndex)
        ..add(wildIndex);
    }

    while (rack.wildQueue.length - wildAt >= 2) {
      final a = rack.wildQueue[wildAt];
      final b = rack.wildQueue[wildAt + 1];
      wildAt += 2;
      pairs.add(
        SolvedPair(
          identity: rack.okeyTile,
          first: _wildSpot(rack, a, rack.okeyTile),
          second: _wildSpot(rack, b, rack.okeyTile),
        ),
      );
      used
        ..add(a)
        ..add(b);
    }

    return PairsEvaluation(
      pairCount: pairs.length,
      pairs: pairs,
      usedRackIndices: used,
    );
  }

  /// Okey-mode 7-pairs greedy — exact because pair slots are independent.
  ///
  /// Fills 7 slots by descending matched: real pairs (2), single + phantom
  /// partner where the pool can still supply one (1), phantom pairs (0).
  SevenPairsPlan evaluateSevenPairs(NormalizedRack rack) {
    final pairs = <SolvedPair>[];
    final used = <int>{};
    var matched = 0;

    // Phase 1: real pairs.
    for (var c = 0; c < 4 && pairs.length < 7; c++) {
      for (var n = 1; n <= 13 && pairs.length < 7; n++) {
        final queue = rack.instanceQueues[c][n];
        final identity = GameTile(color: TileColor.values[c], number: n);
        var taken = 0;
        while (rack.counts[c][n] - taken >= 2 && pairs.length < 7) {
          pairs.add(
            SolvedPair(
              identity: identity,
              first: _rackSpot(rack, queue[taken], identity),
              second: _rackSpot(rack, queue[taken + 1], identity),
            ),
          );
          used
            ..add(queue[taken])
            ..add(queue[taken + 1]);
          taken += 2;
          matched += 2;
        }
      }
    }

    // Phase 2: lone singles + a drawable phantom partner (count == 1 only;
    // a leftover single of a triple has no pool supply left).
    for (var c = 0; c < 4 && pairs.length < 7; c++) {
      for (var n = 1; n <= 13 && pairs.length < 7; n++) {
        if (rack.counts[c][n] != 1) continue;
        final identity = GameTile(color: TileColor.values[c], number: n);
        final index = rack.instanceQueues[c][n].first;
        pairs.add(
          SolvedPair(
            identity: identity,
            first: _rackSpot(rack, index, identity),
            second: SolvedSpot.needed(playsAs: identity),
          ),
        );
        used.add(index);
        matched += 1;
      }
    }

    // Phase 3: pure-phantom pairs over kinds with budget ≥ 2; degenerate
    // racks fall back to the lowest kind — never crash.
    var fallback = 0;
    while (pairs.length < 7) {
      GameTile? identity;
      for (var c = 0; c < 4 && identity == null; c++) {
        for (var n = 1; n <= 13; n++) {
          final kind = GameTile(color: TileColor.values[c], number: n);
          if (rack.phantomBudget(c, n) >= 2 &&
              !pairs.any((p) => p.identity == kind)) {
            identity = kind;
            break;
          }
        }
      }
      identity ??= GameTile(
        color: TileColor.values[fallback ~/ 13],
        number: fallback % 13 + 1,
      );
      if (fallback < 51) fallback++;
      pairs.add(
        SolvedPair(
          identity: identity,
          first: SolvedSpot.needed(playsAs: identity),
          second: SolvedSpot.needed(playsAs: identity),
        ),
      );
    }

    return SevenPairsPlan(
      matched: matched,
      pairs: pairs,
      usedRackIndices: used,
    );
  }

  SolvedSpot _rackSpot(NormalizedRack rack, int index, GameTile playsAs) =>
      SolvedSpot.rackTile(
        physical: rack.tiles[index],
        rackIndex: index,
        playsAs: playsAs,
      );

  SolvedSpot _wildSpot(NormalizedRack rack, int index, GameTile playsAs) =>
      SolvedSpot.wild(
        physical: rack.tiles[index],
        rackIndex: index,
        playsAs: playsAs,
      );
}
