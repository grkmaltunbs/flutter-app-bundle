import 'dart:math' as math;

import 'package:checks/checks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:okey_acar_mi/core/game/game_mode.dart';
import 'package:okey_acar_mi/core/game/game_tile.dart';
import 'package:okey_acar_mi/core/game/indicator.dart';
import 'package:okey_acar_mi/core/game/tile_color.dart';
import 'package:okey_acar_mi/features/solver/domain/engine/meld_validator.dart';
import 'package:okey_acar_mi/features/solver/domain/engine/solver_engine.dart';
import 'package:okey_acar_mi/features/solver/domain/entities/solve_request.dart';
import 'package:okey_acar_mi/features/solver/domain/entities/solve_result.dart';
import 'package:okey_acar_mi/features/solver/domain/entities/solve_verdict.dart';
import 'package:okey_acar_mi/features/solver/domain/entities/solved_pair.dart';
import 'package:okey_acar_mi/features/solver/domain/entities/solved_spot.dart';

import 'oracle/brute_force_oracle.dart';

GameTile _t(TileColor c, int n) => GameTile(color: c, number: n);
const _joker = GameTile(color: TileColor.joker);
const _engine = DpSolverEngine();
final _oracle = BruteForceOracle();

/// Structural invariants every engine result must satisfy, independent of
/// the exact arrangement chosen on ties.
void _checkStructure(SolveResult result, List<GameTile> tiles, String label) {
  const validator = MeldValidator();
  for (final meld in result.melds) {
    check(because: '$label: legal meld', validator.isValidMeld(meld)).isTrue();
    final faceSum = meld.spots.fold<int>(0, (s, x) => s + x.playsAs.number!);
    check(because: '$label: meld points', meld.points).equals(faceSum);
  }
  for (final pair in result.pairs) {
    check(because: '$label: legal pair', validator.isValidPair(pair)).isTrue();
  }
  // Every physical rack tile is bound at most once across melds, pairs and
  // leftovers, and nothing is lost.
  final indices = <int>[];
  void collect(SolvedSpot spot) {
    if (spot is RackSpot) indices.add(spot.rackIndex);
    if (spot is WildSpot) indices.add(spot.rackIndex);
  }

  result.melds.expand((m) => m.spots).forEach(collect);
  for (final SolvedPair(:first, :second) in result.pairs) {
    collect(first);
    collect(second);
  }
  result.leftovers.forEach(collect);
  check(
    because: '$label: indices unique',
    indices.toSet().length,
  ).equals(indices.length);
  check(
    because: '$label: tile conservation',
    indices.length,
  ).equals(tiles.length);
}

void _checkOkeyCells(SolveResult result, String label) {
  final cells =
      result.melds.fold<int>(0, (s, m) => s + m.spots.length) +
      result.pairs.length * 2;
  check(because: '$label: okey template is 14 cells', cells).equals(14);
}

void _check101AgainstOracle(
  List<GameTile> tiles,
  Indicator indicator,
  String label, {
  int? pinnedScore,
}) {
  final result = _engine.solve(
    SolveRequest(tiles: tiles, indicator: indicator, mode: GameMode.oneZeroOne),
  );
  final expected = _oracle.maxMeldScore(tiles, indicator);
  if (pinnedScore != null) {
    check(
      because: '$label: hand-computed optimum',
      expected,
    ).equals(pinnedScore);
  }
  check(
    because: '$label: engine vs oracle score',
    result.totalScore,
  ).equals(expected);
  final oraclePairs = _oracle.maxPairCount(tiles, indicator);
  final shouldOpen = expected >= 101 || oraclePairs >= 5;
  switch (result.verdict) {
    case Opens101(:final score, :final via):
      check(because: '$label: opens', shouldOpen).isTrue();
      check(because: '$label: verdict score', score).equals(expected);
      check(
        because: '$label: via',
        via,
      ).equals(expected >= 101 ? OpenPath.melds : OpenPath.pairs);
    case DoesNotOpen101(:final score, :final pointsShort):
      check(because: '$label: does not open', shouldOpen).isFalse();
      check(because: '$label: verdict score', score).equals(expected);
      check(
        because: '$label: points short',
        pointsShort,
      ).equals(101 - expected);
    case OkeyOutcome():
      fail('$label: okey verdict in 101 mode');
  }
  _checkStructure(result, tiles, label);
}

void _checkOkeyAgainstOracle(
  List<GameTile> tiles,
  Indicator indicator,
  String label,
) {
  final result = _engine.solve(
    SolveRequest(tiles: tiles, indicator: indicator, mode: GameMode.okey),
  );
  final expected = _oracle.okeyTilesToWin(tiles, indicator);
  final verdict = result.verdict;
  check(because: '$label: okey verdict type', verdict).isA<OkeyOutcome>();
  check(
    because: '$label: engine vs oracle tilesToWin',
    (verdict as OkeyOutcome).tilesToWin,
  ).equals(expected);
  _checkStructure(result, tiles, label);
  _checkOkeyCells(result, label);
}

void main() {
  group('differential oracle — wild-heavy corner racks (101)', () {
    test('§6 three parallel same-color runs score exactly 102', () {
      _check101AgainstOracle(
        [
          for (final n in [9, 10, 11, 11, 12, 12, 13, 13]) _t(TileColor.red, n),
          _joker,
        ],
        const Indicator(color: TileColor.black, number: 1),
        'three-parallel-runs',
        pinnedScore: 102,
      );
    });

    test('three-runs variant centered lower (verdict-sensitive zone)', () {
      _check101AgainstOracle(
        [
          for (final n in [8, 9, 10, 10, 11, 11, 12, 12]) _t(TileColor.red, n),
          _joker,
        ],
        const Indicator(color: TileColor.black, number: 1),
        'three-runs-centered-10',
      );
    });

    test('both copies of a kind melded plus a wild as the 3rd copy', () {
      _check101AgainstOracle(
        [
          _t(TileColor.black, 7),
          _t(TileColor.black, 7),
          _t(TileColor.red, 7),
          _t(TileColor.yellow, 7),
          _t(TileColor.blue, 7),
          _joker,
        ],
        const Indicator(color: TileColor.red, number: 1),
        'wild-as-3rd-copy',
        pinnedScore: 42, // {B7 R7 Y7} + {B7 Bl7 ◦7} — all six cells play 7.
      );
    });

    test('staggered same-color runs share the duplicate kind', () {
      _check101AgainstOracle(
        [
          for (final n in [1, 2, 3, 3, 4, 5]) _t(TileColor.yellow, n),
        ],
        const Indicator(color: TileColor.red, number: 9),
        'staggered-runs',
        pinnedScore: 18, // 1-2-3 (6) + 3-4-5 (12).
      );
    });

    test('three jokers form a pure-wild set of 13s', () {
      _check101AgainstOracle(
        const [_joker, _joker, _joker],
        const Indicator(color: TileColor.black, number: 1),
        'three-jokers',
        pinnedScore: 39,
      );
    });

    test('four jokers form a pure-wild 4-set of 13s', () {
      _check101AgainstOracle(
        const [_joker, _joker, _joker, _joker],
        const Indicator(color: TileColor.black, number: 1),
        'four-jokers',
        pinnedScore: 52,
      );
    });

    test('W=5 all-wild: the unique pure-wild RUN optimum (9..13 = 55)', () {
      // Exactness pin for the designated pure-wild run slot: 5 is the one
      // wild total where no set partition reaches the run (4-set = 52,
      // 3-set + 2 dead = 39 < run 9-10-11-12-13 = 55). The naive slot
      // bound min(…, T_c) would make 55 unreachable, and random oracle
      // racks never draw 5 wilds — hence this explicit pin.
      _check101AgainstOracle(
        [
          _joker,
          _joker,
          _t(TileColor.black, 2), // okey copy → wild
          _t(TileColor.black, 2), // okey copy → wild
          _t(TileColor.black, 2), // okey copy → wild
        ],
        const Indicator(color: TileColor.black, number: 1),
        'five-wilds-pure-run',
        pinnedScore: 55,
      );
    });

    test('W=6 all-wild: two pure-wild 13-sets beat any run split', () {
      _check101AgainstOracle(
        List.filled(6, _joker),
        const Indicator(color: TileColor.black, number: 1),
        'six-jokers-two-13-sets',
        pinnedScore: 78,
      );
    });

    test('W=5 mixed rack: engine equals oracle with scattered reals', () {
      // 5 wilds alongside reals — exercises the designated-slot formula
      // when real-bound slots coexist with the pure-wild run option.
      _check101AgainstOracle(
        [
          _t(TileColor.red, 13),
          _t(TileColor.yellow, 5),
          _t(TileColor.blue, 9),
          _t(TileColor.black, 7),
          _joker,
          _joker,
          _t(TileColor.black, 2), // okey copy → wild
          _t(TileColor.black, 2), // okey copy → wild
          _t(TileColor.black, 2), // okey copy → wild
        ],
        const Indicator(color: TileColor.black, number: 1),
        'five-wilds-mixed',
      );
    });

    test('wild standing as the okey identity itself at face value', () {
      _check101AgainstOracle(
        [_t(TileColor.red, 3), _t(TileColor.red, 4), _joker],
        const Indicator(color: TileColor.red, number: 4), // okey = Red 5
        'wild-as-okey',
        pinnedScore: 12, // run 3-4-◦5.
      );
    });

    test('4 wilds (2 jokers + 2 okey copies) split across two 13-sets', () {
      _check101AgainstOracle(
        [
          _t(TileColor.red, 13),
          _t(TileColor.yellow, 13),
          _t(TileColor.black, 2), // okey copy → wild
          _t(TileColor.black, 2), // okey copy → wild
          _joker,
          _joker,
        ],
        const Indicator(color: TileColor.black, number: 1),
        'four-wilds-two-13-sets',
        pinnedScore: 78, // {R13 ◦ ◦} + {Y13 ◦ ◦} — all six cells play 13.
      );
    });
  });

  // Fuzz scale: the design (§7.1) asked for ≥ 10k random racks; the full
  // 10k busts the repo suite's wall-time budget (~3.5 min), so the accepted
  // deviation is 2,000 101-mode racks + 1,000 okey mini-hands = 3,000
  // oracle comparisons per run, spread over 8 fixed seeds each so coverage
  // still accumulates breadth across rack sizes and indicators.
  group('differential oracle — seeded random racks (101)', () {
    for (final seed in const [
      101,
      777001,
      90210,
      424242,
      31337,
      888333,
      246810,
      555777,
    ]) {
      test('engine equals brute force on 250 racks of 5–11 (seed $seed)', () {
        final rng = math.Random(seed);
        for (var i = 0; i < 250; i++) {
          final size = 5 + i % 7;
          final tiles = drawRack(rng, size);
          final indicator = drawIndicator(rng);
          _check101AgainstOracle(
            tiles,
            indicator,
            'random-101 seed=$seed #$i tiles=$tiles indicator=$indicator',
          );
        }
      });
    }
  });

  group('differential oracle — seeded random mini-hands (okey)', () {
    // Reduction: a full 14-tile okey oracle is too slow, so the oracle runs
    // on mini-hands (≤ 8 tiles). tilesToWin only depends on the maximum
    // matched reals over win templates, which mini-hands exercise fully
    // (melds, pair shapes, supply caps, wilds), while phantom padding to 14
    // cells stays trivially suppliable.
    for (final seed in const [
      1453,
      777001,
      90210,
      424242,
      31337,
      888333,
      246810,
      555777,
    ]) {
      test(
        'engine tilesToWin equals oracle on 125 mini-hands (seed $seed)',
        () {
          final rng = math.Random(seed);
          for (var i = 0; i < 125; i++) {
            final size = 4 + i % 5;
            final tiles = drawRack(rng, size);
            final indicator = drawIndicator(rng);
            _checkOkeyAgainstOracle(
              tiles,
              indicator,
              'random-okey seed=$seed #$i tiles=$tiles indicator=$indicator',
            );
          }
        },
      );
    }

    test('okey oracle corners: pair shapes and supply caps', () {
      // Two copies melded as a pair; third copy capped by supply.
      _checkOkeyAgainstOracle(
        [
          _t(TileColor.red, 5),
          _t(TileColor.red, 5),
          _t(TileColor.red, 5),
        ],
        const Indicator(color: TileColor.black, number: 1),
        'triple-copy-supply-cap',
      );
      // Wild-heavy mini-hand: 2 jokers + okey copy.
      _checkOkeyAgainstOracle(
        [
          _t(TileColor.blue, 2), // okey copy → wild
          _t(TileColor.yellow, 9),
          _t(TileColor.yellow, 10),
          _joker,
          _joker,
        ],
        const Indicator(color: TileColor.blue, number: 1),
        'okey-wild-heavy-mini',
      );
      // Singles only: seven-pairs path with phantom partners.
      _checkOkeyAgainstOracle(
        [
          _t(TileColor.red, 1),
          _t(TileColor.black, 4),
          _t(TileColor.yellow, 7),
          _t(TileColor.blue, 10),
          _t(TileColor.red, 13),
        ],
        const Indicator(color: TileColor.yellow, number: 2),
        'okey-singles-seven-pairs',
      );
    });
  });
}
