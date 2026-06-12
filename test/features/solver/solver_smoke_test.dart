import 'package:flutter_test/flutter_test.dart';
import 'package:okey_acar_mi/core/game/game_mode.dart';
import 'package:okey_acar_mi/core/game/game_tile.dart';
import 'package:okey_acar_mi/core/game/indicator.dart';
import 'package:okey_acar_mi/core/game/tile_color.dart';
import 'package:okey_acar_mi/features/solver/domain/engine/meld_validator.dart';
import 'package:okey_acar_mi/features/solver/domain/engine/solver_engine.dart';
import 'package:okey_acar_mi/features/solver/domain/entities/reasoning_step.dart';
import 'package:okey_acar_mi/features/solver/domain/entities/solve_request.dart';
import 'package:okey_acar_mi/features/solver/domain/entities/solve_verdict.dart';
import 'package:okey_acar_mi/features/solver/domain/entities/solved_spot.dart';

GameTile _t(TileColor c, int n) => GameTile(color: c, number: n);
const _joker = GameTile(color: TileColor.joker);
const _engine = DpSolverEngine();

/// Design §5 worked example: indicator Blue 3 → okey Blue 4, W = 2.
final _workedExampleTiles = <GameTile>[
  _t(TileColor.red, 9),
  _t(TileColor.red, 10),
  _t(TileColor.red, 11),
  _t(TileColor.red, 12),
  _t(TileColor.red, 13),
  _t(TileColor.black, 5),
  _t(TileColor.yellow, 5),
  _t(TileColor.blue, 5),
  _t(TileColor.yellow, 1),
  _t(TileColor.yellow, 2),
  _t(TileColor.yellow, 3),
  _t(TileColor.black, 11),
  _t(TileColor.yellow, 11),
  _t(TileColor.black, 13),
  _t(TileColor.blue, 13),
  _t(TileColor.blue, 9),
  _t(TileColor.black, 2),
  _t(TileColor.red, 2),
  _t(TileColor.yellow, 8),
  _joker,
  _joker,
];

/// Okey-mode {3,3,3,3,2} winner: four 1-2-3 runs plus a final Red 9 pair.
final _finalPairRequest = SolveRequest(
  tiles: [
    for (final c in TileColor.values.sublist(0, 4)) ...[
      _t(c, 1),
      _t(c, 2),
      _t(c, 3),
    ],
    _t(TileColor.red, 9),
    _t(TileColor.red, 9),
  ],
  indicator: const Indicator(color: TileColor.black, number: 7),
  mode: GameMode.okey,
);

/// Okey-mode {3,3,3,3,2} winner where every meld is a forced run (all
/// numbers distinct), so the arrangement is exactly 4 melds + 1 pair.
final _fourRunsPairRequest = SolveRequest(
  tiles: [
    for (var n = 1; n <= 3; n++) _t(TileColor.red, n),
    for (var n = 4; n <= 6; n++) _t(TileColor.black, n),
    for (var n = 7; n <= 9; n++) _t(TileColor.yellow, n),
    for (var n = 10; n <= 12; n++) _t(TileColor.blue, n),
    _t(TileColor.red, 13),
    _t(TileColor.red, 13),
  ],
  indicator: const Indicator(color: TileColor.black, number: 1),
  mode: GameMode.okey,
);

void main() {
  // The design doc's §5 walkthrough claims 148, but its example arithmetic
  // is provably suboptimal: the following fully legal arrangement scores
  // 153 using each rack tile at most once and both wilds —
  //   set {R2  B2  Y2}        =  6
  //   set {B5  Y5  Bl5}       = 15
  //   set {R9  ◦B9  Bl9}      = 27   (wild plays Black 9)
  //   set {R11 B11 Y11}       = 33
  //   run  R10 ◦R11 R12       = 33   (wild plays the 2nd Red 11)
  //   set {R13 B13 Bl13}      = 39
  // Total 6+15+27+33+33+39 = 153; leftovers Yellow 1, 3, 8.
  // Cross-check: rack face sum 145 − leftovers 12 + wild identities
  // (9 + 11) = 153. The doc's 148 missed splitting the red run so that
  // Red 9/13 anchor the 9s/13s sets.
  test('§5 worked example opens with the true optimum 153 via melds', () {
    final result = _engine.solve(
      SolveRequest(
        tiles: _workedExampleTiles,
        indicator: const Indicator(color: TileColor.blue, number: 3),
        mode: GameMode.oneZeroOne,
      ),
    );
    expect(
      result.verdict,
      const SolveVerdict.opens101(score: 153, via: OpenPath.melds),
    );
    expect(result.totalScore, 153);
    expect(result.melds, hasLength(6));
    expect(
      result.melds.fold<int>(0, (s, m) => s + m.points),
      153,
    );
    for (final meld in result.melds) {
      expect(const MeldValidator().isValidMeld(meld), isTrue);
    }
    // Leftovers: Yellow 1, Yellow 3, Yellow 8.
    expect(result.leftovers, hasLength(3));
    expect(
      result.leftovers.map((s) => s.playsAs),
      containsAll([
        _t(TileColor.yellow, 1),
        _t(TileColor.yellow, 3),
        _t(TileColor.yellow, 8),
      ]),
    );
    // Both wilds are spent, playing Black 9 and Red 11.
    final wilds = result.melds
        .expand((m) => m.spots)
        .whereType<WildSpot>()
        .map((w) => w.playsAs);
    expect(
      wilds,
      containsAll([_t(TileColor.black, 9), _t(TileColor.red, 11)]),
    );
    // Discard suggestions are okey-mode only.
    expect(result.discardSuggested, isNull);
    expect(result.discardRackIndex, isNull);
  });

  test('§6 three-parallel-runs rack opens with exactly 102', () {
    final result = _engine.solve(
      SolveRequest(
        tiles: [
          for (final n in [9, 10, 11, 11, 12, 12, 13, 13]) _t(TileColor.red, n),
          _joker,
        ],
        indicator: const Indicator(color: TileColor.black, number: 1),
        mode: GameMode.oneZeroOne,
      ),
    );
    expect(
      result.verdict,
      const SolveVerdict.opens101(score: 102, via: OpenPath.melds),
    );
  });

  test('non-opening 20-tile rack reports the exact shortfall', () {
    final tiles = <GameTile>[
      for (final n in [1, 1, 2, 4, 5, 7, 8]) _t(TileColor.red, n),
      for (final n in [1, 2, 4, 5, 7, 8, 8]) _t(TileColor.black, n),
      for (final n in [10, 11, 13]) _t(TileColor.yellow, n),
      for (final n in [10, 11, 13]) _t(TileColor.blue, n),
    ];
    final result = _engine.solve(
      SolveRequest(
        tiles: tiles,
        indicator: const Indicator(color: TileColor.yellow, number: 5),
        mode: GameMode.oneZeroOne,
      ),
    );
    expect(
      result.verdict,
      const SolveVerdict.doesNotOpen101(score: 0, pointsShort: 101),
    );
    expect(result.melds, isEmpty);
    expect(result.leftovers, hasLength(20));
  });

  test('okey 3+3+4+4 hand wins now (tilesToWin 0)', () {
    final result = _engine.solve(
      SolveRequest(
        tiles: [
          _t(TileColor.red, 1),
          _t(TileColor.red, 2),
          _t(TileColor.red, 3),
          _t(TileColor.black, 1),
          _t(TileColor.black, 2),
          _t(TileColor.black, 3),
          _t(TileColor.yellow, 5),
          _t(TileColor.yellow, 6),
          _t(TileColor.yellow, 7),
          _t(TileColor.yellow, 8),
          _t(TileColor.blue, 9),
          _t(TileColor.blue, 10),
          _t(TileColor.blue, 11),
          _t(TileColor.blue, 12),
        ],
        indicator: const Indicator(color: TileColor.red, number: 12),
        mode: GameMode.okey,
      ),
    );
    expect(
      result.verdict,
      const SolveVerdict.okeyOutcome(
        tilesToWin: 0,
        via: OkeyPath.meldsAndPair,
      ),
    );
    expect(result.leftovers, isEmpty);
  });

  test('okey 3+3+3+3+2 final-pair hand wins now (tilesToWin 0)', () {
    final result = _engine.solve(_finalPairRequest);
    expect(
      result.verdict,
      const SolveVerdict.okeyOutcome(
        tilesToWin: 0,
        via: OkeyPath.meldsAndPair,
      ),
    );
  });

  test(
    'okey meldsAndPair populates BOTH melds and pairs (verdict contract)',
    () {
      // The SolveResult doc promises: switch on the verdict — a meldsAndPair
      // okey outcome fills melds AND puts the final pair in pairs (not XOR).
      final result = _engine.solve(_fourRunsPairRequest);
      expect(
        result.verdict,
        const SolveVerdict.okeyOutcome(
          tilesToWin: 0,
          via: OkeyPath.meldsAndPair,
        ),
      );
      expect(result.melds, hasLength(4));
      expect(result.pairs, hasLength(1));
      expect(result.pairs.single.identity, _t(TileColor.red, 13));
    },
  );

  test('okey reasoning emits meldFormed per meld after okeyTemplateChosen', () {
    final result = _engine.solve(_finalPairRequest);
    final template = result.reasoning.indexWhere(
      (s) => s is OkeyTemplateChosenStep,
    );
    expect(template, greaterThanOrEqualTo(0));
    final meldSteps = result.reasoning.sublist(
      template + 1,
      template + 1 + result.melds.length,
    );
    var runningTotal = 0;
    for (var i = 0; i < result.melds.length; i++) {
      runningTotal += result.melds[i].points;
      expect(
        meldSteps[i],
        ReasoningStep.meldFormed(
          meld: result.melds[i],
          runningTotal: runningTotal,
        ),
        reason: 'meld $i must follow okeyTemplateChosen in arrangement order',
      );
    }
    expect(result.reasoning.last, isA<TilesToWinComputedStep>());
  });

  test('okey 15-tile rack surfaces the discard as a first-class field', () {
    final result = _engine.solve(
      _finalPairRequest.copyWith(
        tiles: [..._finalPairRequest.tiles, _t(TileColor.yellow, 5)],
      ),
    );
    final step = result.reasoning.whereType<DiscardSuggestedStep>().single;
    expect(result.discardSuggested, isNotNull);
    expect(result.discardSuggested, step.tile);
    expect(result.discardRackIndex, step.rackIndex);
  });

  test('okey 14-tile rack suggests no discard (fields null)', () {
    final result = _engine.solve(_finalPairRequest);
    expect(result.reasoning.whereType<DiscardSuggestedStep>(), isEmpty);
    expect(result.discardSuggested, isNull);
    expect(result.discardRackIndex, isNull);
  });

  test('solving the same request twice is deterministic', () {
    final request = SolveRequest(
      tiles: _workedExampleTiles,
      indicator: const Indicator(color: TileColor.blue, number: 3),
      mode: GameMode.oneZeroOne,
    );
    final first = _engine.solve(request);
    final second = _engine.solve(request);
    expect(first, second);
  });
}
