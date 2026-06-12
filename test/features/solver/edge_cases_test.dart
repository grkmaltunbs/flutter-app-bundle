import 'package:checks/checks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:okey_acar_mi/core/game/game_mode.dart';
import 'package:okey_acar_mi/core/game/game_tile.dart';
import 'package:okey_acar_mi/core/game/indicator.dart';
import 'package:okey_acar_mi/core/game/tile_color.dart';
import 'package:okey_acar_mi/features/solver/domain/engine/meld_validator.dart';
import 'package:okey_acar_mi/features/solver/domain/engine/solver_engine.dart';
import 'package:okey_acar_mi/features/solver/domain/entities/reasoning_step.dart';
import 'package:okey_acar_mi/features/solver/domain/entities/solve_request.dart';
import 'package:okey_acar_mi/features/solver/domain/entities/solve_result.dart';
import 'package:okey_acar_mi/features/solver/domain/entities/solve_verdict.dart';
import 'package:okey_acar_mi/features/solver/domain/entities/solved_spot.dart';

GameTile _t(TileColor c, int n) => GameTile(color: c, number: n);
const _joker = GameTile(color: TileColor.joker);
const _engine = DpSolverEngine();
const _noWildIndicator = Indicator(color: TileColor.blue, number: 1);

SolveResult _solve101(List<GameTile> tiles, {Indicator? indicator}) =>
    _engine.solve(
      SolveRequest(
        tiles: tiles,
        indicator: indicator ?? _noWildIndicator,
        mode: GameMode.oneZeroOne,
      ),
    );

SolveResult _solveOkey(List<GameTile> tiles, {Indicator? indicator}) =>
    _engine.solve(
      SolveRequest(
        tiles: tiles,
        indicator: indicator ?? _noWildIndicator,
        mode: GameMode.okey,
      ),
    );

void _checkMeldsLegal(SolveResult result) {
  const validator = MeldValidator();
  for (final meld in result.melds) {
    check(validator.isValidMeld(meld)).isTrue();
  }
  for (final pair in result.pairs) {
    check(validator.isValidPair(pair)).isTrue();
  }
}

int _okeyCells(SolveResult result) =>
    result.melds.fold<int>(0, (s, m) => s + m.spots.length) +
    result.pairs.length * 2;

void main() {
  group('no wrap-around runs', () {
    test('12-13-1 alone scores 0 (wrap would score 26)', () {
      final result = _solve101(
        [_t(TileColor.red, 12), _t(TileColor.red, 13), _t(TileColor.red, 1)],
      );
      check(
        result.verdict,
      ).equals(const SolveVerdict.doesNotOpen101(score: 0, pointsShort: 101));
      check(result.melds).isEmpty();
    });

    test('13-1-2 alone scores 0 (wrap would score 16)', () {
      final result = _solve101(
        [_t(TileColor.red, 13), _t(TileColor.red, 1), _t(TileColor.red, 2)],
      );
      check(result.totalScore).equals(0);
    });

    test('11-12-13-1: the legal 11-12-13 run forms, the 1 stays leftover', () {
      final result = _solve101([
        _t(TileColor.red, 11),
        _t(TileColor.red, 12),
        _t(TileColor.red, 13),
        _t(TileColor.red, 1),
      ]);
      check(result.totalScore).equals(36);
      check(result.melds).length.equals(1);
      check(result.leftovers).length.equals(1);
      check(result.leftovers.first.playsAs).equals(_t(TileColor.red, 1));
      _checkMeldsLegal(result);
    });
  });

  group('run length extremes', () {
    test('full 1..13 single color melds every tile for 91', () {
      final result = _solve101(
        [for (var n = 1; n <= 13; n++) _t(TileColor.yellow, n)],
      );
      check(result.verdict).equals(
        const SolveVerdict.doesNotOpen101(score: 91, pointsShort: 10),
      );
      // The arrangement on ties may split the run (e.g. 1-2-3 + 4..13);
      // pin the invariants: all 13 tiles melded, points sum to 91.
      check(result.leftovers).isEmpty();
      check(
        result.melds.fold<int>(0, (s, m) => s + m.spots.length),
      ).equals(13);
      check(result.melds.fold<int>(0, (s, m) => s + m.points)).equals(91);
      _checkMeldsLegal(result);
    });
  });

  group('okey derivation and wilds', () {
    test('indicator 13 wraps: 1s of that color are wild', () {
      // Indicator Yellow 13 → okey Yellow 1; two Y1 copies are wilds.
      final result = _solve101(
        [
          _t(TileColor.yellow, 1),
          _t(TileColor.yellow, 1),
          _t(TileColor.red, 5),
          _t(TileColor.black, 5),
        ],
        indicator: const Indicator(color: TileColor.yellow, number: 13),
      );
      check(result.reasoning.first).isA<OkeyDerivedStep>();
      check(
        (result.reasoning.first as OkeyDerivedStep).okeyTile,
      ).equals(_t(TileColor.yellow, 1));
      check(result.reasoning.whereType<WildsCountedStep>().single).equals(
        const ReasoningStep.wildsCounted(falseJokers: 0, okeyCopies: 2)
            as WildsCountedStep,
      );
      // Best: 4-set {R5 B5 ◦5 ◦5}? No — distinct colors, so {R5 B5 ◦Y5 ◦Bl5}.
      check(result.totalScore).equals(20);
      _checkMeldsLegal(result);
    });

    test('wild plays the okey identity itself at face value', () {
      // Indicator Red 4 → okey Red 5; the joker completes 3-4-◦5.
      final result = _solve101(
        [_t(TileColor.red, 3), _t(TileColor.red, 4), _joker],
        indicator: const Indicator(color: TileColor.red, number: 4),
      );
      check(result.totalScore).equals(12);
      final wildSpot = result.melds
          .expand((m) => m.spots)
          .whereType<WildSpot>()
          .single;
      check(wildSpot.playsAs).equals(_t(TileColor.red, 5));
      _checkMeldsLegal(result);
    });
  });

  group('101 five-pairs path', () {
    test('opens with 3 naturals + wild+single + wild+wild', () {
      final result = _solve101([
        _t(TileColor.red, 1), _t(TileColor.red, 1),
        _t(TileColor.black, 3), _t(TileColor.black, 3),
        _t(TileColor.yellow, 5), _t(TileColor.yellow, 5),
        _t(TileColor.red, 7), // single → wild partner
        _joker, _joker, _joker,
      ]);
      check(result.verdict).isA<Opens101>();
      check((result.verdict as Opens101).via).equals(OpenPath.pairs);
      check(result.pairs).length.equals(5);
      check(result.melds).isEmpty();
      // The wild+wild pair stands as the okey identity (Blue 2).
      check(
        result.pairs.map((p) => p.identity),
      ).contains(_t(TileColor.blue, 2));
      check(result.pairs.map((p) => p.identity)).contains(_t(TileColor.red, 7));
      _checkMeldsLegal(result);
    });

    test('exactly 4 pairs does not open', () {
      final result = _solve101([
        _t(TileColor.red, 1),
        _t(TileColor.red, 1),
        _t(TileColor.black, 3),
        _t(TileColor.black, 3),
        _t(TileColor.yellow, 5),
        _t(TileColor.yellow, 5),
        _t(TileColor.blue, 7),
        _t(TileColor.blue, 7),
      ]);
      check(result.verdict).isA<DoesNotOpen101>();
      final pairsStep = result.reasoning.whereType<PairsCountedStep>().single;
      check(pairsStep.pairCount).equals(4);
      check(pairsStep.opens).isFalse();
    });

    test('exactly 5 natural pairs opens via pairs', () {
      final result = _solve101([
        for (final (c, n) in [
          (TileColor.red, 1),
          (TileColor.black, 3),
          (TileColor.yellow, 5),
          (TileColor.blue, 7),
          (TileColor.red, 10),
        ]) ...[_t(c, n), _t(c, n)],
      ]);
      check(result.verdict).isA<Opens101>();
      check((result.verdict as Opens101).via).equals(OpenPath.pairs);
      check(result.pairs).length.equals(5);
    });
  });

  group('101 threshold boundary', () {
    test('exactly 101 opens (55 + 46)', () {
      final result = _solve101([
        for (var n = 9; n <= 13; n++) _t(TileColor.red, n),
        for (var n = 10; n <= 13; n++) _t(TileColor.black, n),
      ]);
      check(result.verdict).equals(
        const SolveVerdict.opens101(score: 101, via: OpenPath.melds),
      );
    });

    test('exactly 100 is short by exactly 1', () {
      final result = _solve101([
        for (var n = 9; n <= 13; n++) _t(TileColor.red, n), // 55
        for (var n = 10; n <= 12; n++) _t(TileColor.black, n), // 33
        for (var n = 3; n <= 5; n++) _t(TileColor.yellow, n), // 12
      ]);
      check(result.verdict).equals(
        const SolveVerdict.doesNotOpen101(score: 100, pointsShort: 1),
      );
    });
  });

  group('okey winning shapes', () {
    test('3+3+3+5 hand wins now', () {
      final result = _solveOkey([
        for (final c in [TileColor.red, TileColor.black, TileColor.yellow])
          for (var n = 1; n <= 3; n++) _t(c, n),
        for (var n = 5; n <= 9; n++) _t(TileColor.blue, n),
      ]);
      check(result.verdict).equals(
        const SolveVerdict.okeyOutcome(
          tilesToWin: 0,
          via: OkeyPath.meldsAndPair,
        ),
      );
      check(_okeyCells(result)).equals(14);
      check(result.leftovers).isEmpty();
      _checkMeldsLegal(result);
    });

    test('seven natural pairs win now via sevenPairs', () {
      final result = _solveOkey([
        for (final (c, n) in [
          (TileColor.red, 1),
          (TileColor.red, 4),
          (TileColor.red, 7),
          (TileColor.black, 2),
          (TileColor.black, 5),
          (TileColor.yellow, 3),
          (TileColor.blue, 9),
        ]) ...[_t(c, n), _t(c, n)],
      ]);
      check(result.verdict).equals(
        const SolveVerdict.okeyOutcome(
          tilesToWin: 0,
          via: OkeyPath.sevenPairs,
        ),
      );
      check(result.pairs).length.equals(7);
      check(_okeyCells(result)).equals(14);
      _checkMeldsLegal(result);
    });

    test('15th tile is implicitly discarded and suggested', () {
      final result = _solveOkey([
        for (var n = 1; n <= 3; n++) _t(TileColor.red, n),
        for (var n = 1; n <= 3; n++) _t(TileColor.black, n),
        for (var n = 5; n <= 8; n++) _t(TileColor.yellow, n),
        for (var n = 9; n <= 12; n++) _t(TileColor.blue, n),
        _t(TileColor.black, 13), // 15th tile — the discard
      ]);
      check(result.verdict).equals(
        const SolveVerdict.okeyOutcome(
          tilesToWin: 0,
          via: OkeyPath.meldsAndPair,
        ),
      );
      final discard = result.reasoning.whereType<DiscardSuggestedStep>().single;
      check(discard.tile).equals(_t(TileColor.black, 13));
      check(result.leftovers).length.equals(1);
    });

    test('trailing pad: a run anchored at 1 takes a phantom 3rd cell', () {
      // R1-R2 can only complete forward (◦3) — nothing exists below 1.
      final result = _solveOkey([_t(TileColor.red, 1), _t(TileColor.red, 2)]);
      check(result.verdict).isA<OkeyOutcome>();
      check((result.verdict as OkeyOutcome).tilesToWin).equals(12);
      check(_okeyCells(result)).equals(14);
      _checkMeldsLegal(result);
    });

    test('leading pad: a run anchored at 13 takes phantoms below', () {
      final result = _solveOkey(
        [_t(TileColor.red, 12), _t(TileColor.red, 13)],
      );
      check((result.verdict as OkeyOutcome).tilesToWin).equals(12);
      check(_okeyCells(result)).equals(14);
      _checkMeldsLegal(result);
    });
  });

  group('degenerate inputs', () {
    test('empty rack (101): doesNotOpen101(0, 101)', () {
      final result = _solve101(const []);
      check(result.verdict).equals(
        const SolveVerdict.doesNotOpen101(score: 0, pointsShort: 101),
      );
      check(result.melds).isEmpty();
      check(result.leftovers).isEmpty();
    });

    test('empty rack (okey): tilesToWin 14, tie prefers meldsAndPair', () {
      final result = _solveOkey(const []);
      check(result.verdict).equals(
        const SolveVerdict.okeyOutcome(
          tilesToWin: 14,
          via: OkeyPath.meldsAndPair,
        ),
      );
      check(_okeyCells(result)).equals(14);
      _checkMeldsLegal(result);
    });

    test('5 copies of one tile are clamped with a reasoning step', () {
      final result = _solve101([
        for (var i = 0; i < 5; i++) _t(TileColor.red, 7),
        _t(TileColor.red, 8),
        _t(TileColor.red, 9),
      ]);
      final clamp = result.reasoning.whereType<CountsClampedStep>().single;
      check(clamp.kind).equals(_t(TileColor.red, 7));
      check(clamp.dropped).equals(1);
      // Best meld: 7-8-9; four surplus red 7s (3 unmelded + 1 clamped)
      // are leftovers.
      check(result.totalScore).equals(24);
      check(result.leftovers).length.equals(4);
      _checkMeldsLegal(result);
    });
  });

  group('reasoning steps are typed and ordered', () {
    test('101 reasoning starts with okeyDerived and checks the threshold', () {
      final result = _solve101([
        for (var n = 9; n <= 13; n++) _t(TileColor.red, n),
        for (var n = 10; n <= 13; n++) _t(TileColor.black, n),
      ]);
      check(result.reasoning.first).isA<OkeyDerivedStep>();
      final threshold = result.reasoning
          .whereType<ThresholdCheckedStep>()
          .single;
      check(threshold.total).equals(101);
      check(threshold.threshold).equals(101);
      check(threshold.opens).isTrue();
      check(
        result.reasoning.whereType<PathChosenStep>().single.via,
      ).equals(OpenPath.melds);
      check(
        result.reasoning.whereType<MeldFormedStep>().length,
      ).equals(result.melds.length);
    });

    test('okey reasoning starts with okeyDerived and computes tilesToWin', () {
      final result = _solveOkey([_t(TileColor.red, 1), _t(TileColor.red, 2)]);
      check(result.reasoning.first).isA<OkeyDerivedStep>();
      final computed = result.reasoning
          .whereType<TilesToWinComputedStep>()
          .single;
      check(computed.tilesToWin).equals(12);
      check(
        result.reasoning.whereType<TilesNeededStep>().single.needed,
      ).length.equals(12);
    });
  });
}
