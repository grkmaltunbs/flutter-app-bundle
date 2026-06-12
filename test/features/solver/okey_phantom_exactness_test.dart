import 'package:flutter_test/flutter_test.dart';
import 'package:okey_acar_mi/core/game/game_mode.dart';
import 'package:okey_acar_mi/core/game/game_tile.dart';
import 'package:okey_acar_mi/core/game/indicator.dart';
import 'package:okey_acar_mi/core/game/tile_color.dart';
import 'package:okey_acar_mi/features/solver/domain/engine/solver_engine.dart';
import 'package:okey_acar_mi/features/solver/domain/entities/solve_request.dart';
import 'package:okey_acar_mi/features/solver/domain/entities/solve_result.dart';
import 'package:okey_acar_mi/features/solver/domain/entities/solve_verdict.dart';
import 'package:okey_acar_mi/features/solver/domain/entities/solved_meld.dart';
import 'package:okey_acar_mi/features/solver/domain/entities/solved_spot.dart';

GameTile _t(TileColor c, int n) => GameTile(color: c, number: n);
const _engine = DpSolverEngine();

SolveResult _solveOkey(List<GameTile> tiles, Indicator indicator) =>
    _engine.solve(
      SolveRequest(tiles: tiles, indicator: indicator, mode: GameMode.okey),
    );

/// All [NeededSpot]s across melds and pairs of [result].
List<NeededSpot> _neededSpots(SolveResult result) => [
  ...result.melds.expand((m) => m.spots),
  for (final pair in result.pairs) ...[pair.first, pair.second],
].whereType<NeededSpot>().toList();

/// The run meld of [result] containing a real tile playing [anchor].
SolvedMeld _runContaining(SolveResult result, GameTile anchor) =>
    result.melds.firstWhere(
      (m) =>
          m.kind == MeldKind.run &&
          m.spots.any((s) => s is RackSpot && s.playsAs == anchor),
    );

void main() {
  group('okey DP phantom exactness (trailing-pad regression)', () {
    test(
      'left-anchored run with one trailing phantom: tilesToWin exactly 1',
      () {
        // Red 1-2-3 anchored at column 1: no leading room, no len<3 split.
        // The single trailing phantom [Red 4] is the ONLY way to reach 14
        // cells at matched 13. The old within-2-ahead guard blocked it
        // (no real red at 5 or 6) and overstated tilesToWin as 2.
        final tiles = <GameTile>[
          _t(TileColor.red, 1),
          _t(TileColor.red, 2),
          _t(TileColor.red, 3),
          _t(TileColor.yellow, 7),
          _t(TileColor.black, 7),
          _t(TileColor.blue, 7),
          _t(TileColor.red, 7),
          _t(TileColor.yellow, 11),
          _t(TileColor.black, 11),
          _t(TileColor.blue, 11),
          _t(TileColor.red, 11),
          _t(TileColor.black, 13),
          _t(TileColor.black, 13),
          _t(TileColor.yellow, 1),
        ];
        // Okey = Blue 2, absent from the rack: W = 0.
        const indicator = Indicator(color: TileColor.blue, number: 1);
        final result = _solveOkey(tiles, indicator);

        final verdict = result.verdict as OkeyOutcome;
        expect(verdict.tilesToWin, 1);

        final needed = _neededSpots(result);
        expect(needed, hasLength(1));
        expect(needed.single.playsAs, _t(TileColor.red, 4));

        final run = _runContaining(result, _t(TileColor.red, 1));
        expect(
          run.spots.map((s) => s.playsAs).toList(),
          [for (var n = 1; n <= 4; n++) _t(TileColor.red, n)],
        );
        expect(run.spots.whereType<NeededSpot>(), hasLength(1));
      },
    );

    test(
      'right-anchored run with one leading phantom: tilesToWin exactly 1',
      () {
        // Mirror case: Red 11-12-13 needs the leading [Red 10]. The leading
        // open path already passed the old guard — pinned for symmetry.
        final tiles = <GameTile>[
          _t(TileColor.red, 11),
          _t(TileColor.red, 12),
          _t(TileColor.red, 13),
          _t(TileColor.yellow, 7),
          _t(TileColor.black, 7),
          _t(TileColor.blue, 7),
          _t(TileColor.red, 7),
          _t(TileColor.yellow, 5),
          _t(TileColor.black, 5),
          _t(TileColor.blue, 5),
          _t(TileColor.red, 5),
          _t(TileColor.black, 13),
          _t(TileColor.black, 13),
          _t(TileColor.yellow, 1),
        ];
        // Okey = Blue 2, absent from the rack: W = 0.
        const indicator = Indicator(color: TileColor.blue, number: 1);
        final result = _solveOkey(tiles, indicator);

        final verdict = result.verdict as OkeyOutcome;
        expect(verdict.tilesToWin, 1);

        final needed = _neededSpots(result);
        expect(needed, hasLength(1));
        expect(needed.single.playsAs, _t(TileColor.red, 10));

        final run = _runContaining(result, _t(TileColor.red, 11));
        expect(
          run.spots.map((s) => s.playsAs).toList(),
          [for (var n = 10; n <= 13; n++) _t(TileColor.red, n)],
        );
      },
    );

    test(
      'left-anchored run with two trailing phantoms is the chosen optimum',
      () {
        // 12 reals, 2 phantoms. All melds are 3-sets or the 1s 4-set, the
        // pair is real, and every alternative phantom sink sits at columns
        // summing below 4 + 5 = 9, so the composite objective
        // (matched, then score) uniquely selects Red 1-2-3-[4]-[5].
        final tiles = <GameTile>[
          _t(TileColor.red, 1),
          _t(TileColor.red, 1),
          _t(TileColor.red, 2),
          _t(TileColor.red, 3),
          _t(TileColor.yellow, 1),
          _t(TileColor.yellow, 2),
          _t(TileColor.yellow, 2),
          _t(TileColor.yellow, 3),
          _t(TileColor.black, 1),
          _t(TileColor.black, 3),
          _t(TileColor.blue, 1),
          _t(TileColor.blue, 3),
        ];
        // Okey = Blue 5, absent from the rack: W = 0.
        const indicator = Indicator(color: TileColor.blue, number: 4);
        final result = _solveOkey(tiles, indicator);

        final verdict = result.verdict as OkeyOutcome;
        expect(verdict.tilesToWin, 2);

        final run = _runContaining(result, _t(TileColor.red, 2));
        expect(
          run.spots.map((s) => s.playsAs).toList(),
          [for (var n = 1; n <= 5; n++) _t(TileColor.red, n)],
        );
        expect(run.spots.whereType<NeededSpot>(), hasLength(2));
        expect(_neededSpots(result), hasLength(2));
      },
    );
  });

  group('okey phantom budget counts held okey copies (display fix)', () {
    test('seven-pairs phantom pair never names the held okey identity', () {
      // Okey = Red 1; BOTH copies sit on the rack as wilds, so zero Red 1s
      // remain in the 106-tile pool. Six scattered singles force the
      // seven-pairs path; its 7th slot is a pure-phantom pair over the
      // lowest kind with supply — which must NOT be Red 1.
      final tiles = <GameTile>[
        _t(TileColor.red, 1), // okey copy -> wild
        _t(TileColor.red, 1), // okey copy -> wild
        _t(TileColor.black, 5),
        _t(TileColor.yellow, 9),
        _t(TileColor.blue, 3),
        _t(TileColor.black, 11),
        _t(TileColor.yellow, 4),
        _t(TileColor.blue, 7),
      ];
      const indicator = Indicator(color: TileColor.red, number: 13);
      final result = _solveOkey(tiles, indicator);

      final verdict = result.verdict as OkeyOutcome;
      expect(verdict.via, OkeyPath.sevenPairs);
      expect(verdict.tilesToWin, 6);

      // Every displayed needed tile must still be drawable: needed copies
      // of a kind + physical rack copies of that kind (okey copies held as
      // wilds included) can never exceed the pool's 2.
      final needed = _neededSpots(result);
      expect(
        needed.map((s) => s.playsAs),
        isNot(contains(_t(TileColor.red, 1))),
      );
      for (final spot in needed) {
        final kind = spot.playsAs;
        final onRack = tiles.where((t) => t == kind).length;
        final demanded = needed.where((s) => s.playsAs == kind).length;
        expect(
          demanded + onRack,
          lessThanOrEqualTo(2),
          reason: 'needed $kind must remain drawable from the pool',
        );
      }
    });
  });
}
