import 'dart:math' as math;

import 'package:okey_acar_mi/core/game/game_tile.dart';
import 'package:okey_acar_mi/core/game/indicator.dart';
import 'package:okey_acar_mi/core/game/tile_color.dart';

/// An independent brute-force solver derived purely from the game semantics
/// in `PRODUCT_SPEC.md` — written without reference to the engine internals,
/// as a differential-testing oracle.
///
/// Semantics encoded here:
/// - Tiles 1–13 × {red, black, yellow, blue}; wilds = rack tiles equal to
///   `indicator.okeyTile` plus unnumbered jokers; wilds are fully wild and
///   take the value + identity of the tile they substitute.
/// - Set: 3–4 tiles, same number, all-distinct colors. Run: 3+ consecutive,
///   same color, 1 low only (no 12-13-1 / 13-1-2 wrap), max length 13.
/// - Meld score = sum of substituted face values.
/// - 101 pairs: pair = two identical color+number tiles; a wild may stand
///   for one or both members; two wilds pair as the okey identity.
/// - Okey: win = 14 cells as melds(≥3) + at most one pair, or seven pairs;
///   `tilesToWin = 14 − min(14, bestMatchedReals + wilds)` where a template
///   may not demand more real copies of a kind than the 106-tile set can
///   still supply: `phantom(c, n) ≤ max(0, 2 − rackCopies(c, n))`.
///
/// Exhaustive for racks ≤ ~11 tiles (101) and ≤ ~8 tiles (okey).
class BruteForceOracle {
  BruteForceOracle();

  /// All legal meld templates as lists of kind codes (`color * 13 + n - 1`).
  /// Runs: every color × start 1..11 × length 3..13 (no wrap). Sets: every
  /// number × every color subset of size 3 or 4.
  late final List<List<int>> _templates = _buildTemplates();

  static List<List<int>> _buildTemplates() {
    final templates = <List<int>>[];
    for (var c = 0; c < 4; c++) {
      for (var start = 1; start <= 11; start++) {
        for (var len = 3; start + len - 1 <= 13; len++) {
          templates.add([
            for (var n = start; n < start + len; n++) c * 13 + n - 1,
          ]);
        }
      }
    }
    const colorSubsets = <List<int>>[
      [0, 1, 2],
      [0, 1, 3],
      [0, 2, 3],
      [1, 2, 3],
      [0, 1, 2, 3],
    ];
    for (var n = 1; n <= 13; n++) {
      for (final subset in colorSubsets) {
        templates.add([for (final c in subset) c * 13 + n - 1]);
      }
    }
    return templates;
  }

  ({List<int> counts, int wilds}) _normalize(
    List<GameTile> tiles,
    Indicator indicator,
  ) {
    final counts = List<int>.filled(52, 0);
    var wilds = 0;
    final okey = indicator.okeyTile;
    for (final tile in tiles) {
      if (tile.isJoker || tile == okey) {
        wilds++;
        continue;
      }
      counts[tile.color.index * 13 + tile.number! - 1]++;
    }
    return (counts: counts, wilds: wilds);
  }

  /// Exact maximum total meld score (101 mode) by exhaustive enumeration of
  /// meld covers with every real/wild cell assignment.
  int maxMeldScore(List<GameTile> tiles, Indicator indicator) {
    final (:counts, :wilds) = _normalize(tiles, indicator);
    var realLeft = counts.fold<int>(0, (s, c) => s + c);
    var best = 0;

    void dfs(int templateIndex, int wildsLeft, int score) {
      if (score > best) best = score;
      // Sound upper bound: every further cell scores at most 13.
      if (score + (realLeft + wildsLeft) * 13 <= best) return;
      for (var t = templateIndex; t < _templates.length; t++) {
        final template = _templates[t];
        // Enumerate every real/wild assignment for this template's cells.
        void cells(int cellIndex, int wildsRemaining, int gained) {
          if (cellIndex == template.length) {
            dfs(t, wildsRemaining, score + gained);
            return;
          }
          final kind = template[cellIndex];
          final value = kind % 13 + 1;
          if (counts[kind] > 0) {
            counts[kind]--;
            realLeft--;
            cells(cellIndex + 1, wildsRemaining, gained + value);
            counts[kind]++;
            realLeft++;
          }
          if (wildsRemaining > 0) {
            cells(cellIndex + 1, wildsRemaining - 1, gained + value);
          }
        }

        cells(0, wildsLeft, 0);
      }
    }

    dfs(0, wilds, 0);
    return best;
  }

  /// Maximum achievable pair count (101 five-pairs path).
  ///
  /// Exact by exchange: breaking a natural pair never helps; a wild's best
  /// use is completing a single; two leftover wilds pair as the okey
  /// identity.
  int maxPairCount(List<GameTile> tiles, Indicator indicator) {
    final (:counts, :wilds) = _normalize(tiles, indicator);
    var natural = 0;
    var singles = 0;
    for (final count in counts) {
      natural += count ~/ 2;
      singles += count % 2;
    }
    final wildOnSingle = math.min(wilds, singles);
    return natural + wildOnSingle + (wilds - wildOnSingle) ~/ 2;
  }

  /// Exact okey-mode tiles-to-win:
  /// `14 − min(14, max(meldTemplates, sevenPairs) + wilds)`.
  ///
  /// Reduction (documented): pure-phantom padding melds/pairs are assumed
  /// suppliable, which holds for every rack this oracle is used on (≤ 8
  /// tiles ⇒ ≥ 36 kinds remain untouched with full budget 2).
  int okeyTilesToWin(List<GameTile> tiles, Indicator indicator) {
    final (:counts, :wilds) = _normalize(tiles, indicator);
    final budget = List<int>.generate(
      52,
      (k) => math.max(0, 2 - counts[k]),
    );
    final matched = math.max(
      _bestMatchedMeldsAndPair(counts, budget),
      _sevenPairsMatched(counts, budget),
    );
    return 14 - math.min(14, matched + wilds);
  }

  /// Max real rack tiles placeable in a melds(≥3)+at-most-one-pair template
  /// of exactly 14 cells, under the phantom supply cap.
  int _bestMatchedMeldsAndPair(List<int> counts, List<int> budget) {
    var realLeft = counts.fold<int>(0, (s, c) => s + c);
    var best = 0;

    bool padFeasible(int remaining, {required bool pairUsed}) =>
        remaining == 0 || remaining >= 3 || (remaining == 2 && !pairUsed);

    void dfs(
      int templateIndex,
      int cells,
      int matched, {
      required bool pairUsed,
    }) {
      if (padFeasible(14 - cells, pairUsed: pairUsed) && matched > best) {
        best = matched;
      }
      if (matched + math.min(realLeft, 14 - cells) <= best) return;
      for (var t = templateIndex; t < _templates.length; t++) {
        final template = _templates[t];
        if (cells + template.length > 14) continue;
        // Enumerate real/phantom per cell; require at least one real
        // (pure-phantom melds are padding, handled by padFeasible).
        void cellsEnum(int cellIndex, int reals) {
          if (cellIndex == template.length) {
            if (reals > 0) {
              dfs(
                t,
                cells + template.length,
                matched + reals,
                pairUsed: pairUsed,
              );
            }
            return;
          }
          final kind = template[cellIndex];
          if (counts[kind] > 0) {
            counts[kind]--;
            realLeft--;
            cellsEnum(cellIndex + 1, reals + 1);
            counts[kind]++;
            realLeft++;
          }
          if (budget[kind] > 0) {
            budget[kind]--;
            cellsEnum(cellIndex + 1, reals);
            budget[kind]++;
          }
        }

        cellsEnum(0, 0);
      }
    }

    // Pair commutes with melds: enumerate the pair choice up front.
    dfs(0, 0, 0, pairUsed: false);
    for (var kind = 0; kind < 52; kind++) {
      if (counts[kind] >= 2) {
        counts[kind] -= 2;
        realLeft -= 2;
        dfs(0, 2, 2, pairUsed: true);
        counts[kind] += 2;
        realLeft += 2;
      }
      if (counts[kind] >= 1 && budget[kind] >= 1) {
        counts[kind]--;
        realLeft--;
        budget[kind]--;
        dfs(0, 2, 1, pairUsed: true);
        counts[kind]++;
        realLeft++;
        budget[kind]++;
      }
    }
    return best;
  }

  /// Max real rack tiles placeable in seven pair slots. Slots are
  /// independent: each kind contributes ⌊count/2⌋ real pairs (2 matched) and
  /// a phantom-partnered single (1 matched) only while the outside supply
  /// has a copy left (`budget ≥ 1` ⇔ rack count ≤ 1).
  int _sevenPairsMatched(List<int> counts, List<int> budget) {
    final contributions = <int>[];
    for (var kind = 0; kind < 52; kind++) {
      for (var i = 0; i < counts[kind] ~/ 2; i++) {
        contributions.add(2);
      }
      if (counts[kind].isOdd && budget[kind] >= 1) contributions.add(1);
    }
    contributions.sort((a, b) => b.compareTo(a));
    var matched = 0;
    for (var i = 0; i < math.min(7, contributions.length); i++) {
      matched += contributions[i];
    }
    return matched;
  }
}

/// Draws [size] tiles from a shuffled full 106-tile pool (2 copies of every
/// kind + 2 jokers) — deterministic for a seeded [rng].
List<GameTile> drawRack(math.Random rng, int size) {
  final pool = <GameTile>[
    for (var copy = 0; copy < 2; copy++) ...[
      for (final color in TileColor.values)
        if (color != TileColor.joker)
          for (var n = 1; n <= 13; n++) GameTile(color: color, number: n),
      const GameTile(color: TileColor.joker),
    ],
  ]..shuffle(rng);
  return pool.take(size).toList();
}

/// A deterministic random indicator.
Indicator drawIndicator(math.Random rng) => Indicator(
  color: TileColor.values[rng.nextInt(4)],
  number: rng.nextInt(13) + 1,
);
