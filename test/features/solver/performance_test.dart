import 'package:checks/checks.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:okey_acar_mi/core/game/game_mode.dart';
import 'package:okey_acar_mi/core/game/game_tile.dart';
import 'package:okey_acar_mi/core/game/indicator.dart';
import 'package:okey_acar_mi/core/game/tile_color.dart';
import 'package:okey_acar_mi/features/solver/domain/engine/solver_engine.dart';
import 'package:okey_acar_mi/features/solver/domain/entities/solve_request.dart';
import 'package:okey_acar_mi/features/solver/domain/entities/solve_result.dart';
import 'package:okey_acar_mi/features/solver/domain/entities/solve_verdict.dart';

GameTile _t(TileColor c, int n) => GameTile(color: c, number: n);
const _joker = GameTile(color: TileColor.joker);
const _engine = DpSolverEngine();

/// Design §7.3 regression gate: every adversary must finish well inside the
/// solver's latency budget in a debug `flutter test` run. The bound is a
/// generous 2 s for CI safety; elapsed time is printed for trend-watching
/// (typical fixtures are expected far below 300 ms).
SolveResult _timed(String label, SolveRequest request) {
  final stopwatch = Stopwatch()..start();
  final result = _engine.solve(request);
  stopwatch.stop();
  debugPrint('[solver-perf] $label: ${stopwatch.elapsedMilliseconds} ms');
  check(
    because: '$label must stay under the 2 s debug budget',
    stopwatch.elapsedMilliseconds,
  ).isLessThan(2000);
  return result;
}

void main() {
  group('solver performance adversaries (§7.3)', () {
    test('breadth adversary: 17 distinct kinds + 4 wilds, 21 tiles, 101', () {
      // Indicator Black 12 → okey Black 13; the two Black 13s are wilds.
      final tiles = <GameTile>[
        for (final n in [1, 3, 5, 7, 9, 11, 13]) _t(TileColor.red, n),
        for (final n in [2, 4, 6, 8, 10]) _t(TileColor.black, n),
        for (final n in [1, 4, 7, 10]) _t(TileColor.yellow, n),
        _t(TileColor.blue, 13),
        _t(TileColor.black, 13), // okey copy → wild
        _t(TileColor.black, 13), // okey copy → wild
        _joker,
        _joker,
      ];
      check(tiles).length.equals(21);
      final result = _timed(
        'breadth 21 tiles',
        SolveRequest(
          tiles: tiles,
          indicator: const Indicator(color: TileColor.black, number: 12),
          mode: GameMode.oneZeroOne,
        ),
      );
      check(result.verdict).isA<SolveVerdict>();
    });

    test('duplicate-heavy adversary: 2 × 8 consecutive kinds + 4 wilds', () {
      // Indicator Black 4 → okey Black 5; the two Black 5s are wilds.
      final tiles = <GameTile>[
        for (var copy = 0; copy < 2; copy++)
          for (var n = 3; n <= 10; n++) _t(TileColor.red, n),
        _t(TileColor.black, 5), // okey copy → wild
        _t(TileColor.black, 5), // okey copy → wild
        _joker,
        _joker,
      ];
      check(tiles).length.equals(20);
      final result = _timed(
        'duplicate-heavy 20 tiles',
        SolveRequest(
          tiles: tiles,
          indicator: const Indicator(color: TileColor.black, number: 4),
          mode: GameMode.oneZeroOne,
        ),
      );
      check(result.totalScore).isGreaterThan(0);
    });

    test('garbage 15-tile okey rack (no melds anywhere)', () {
      final tiles = <GameTile>[
        for (final n in [1, 4, 7, 10, 13]) _t(TileColor.red, n),
        for (final n in [2, 5, 8, 11]) _t(TileColor.black, n),
        for (final n in [3, 6, 9, 12]) _t(TileColor.yellow, n),
        _t(TileColor.blue, 1),
        _t(TileColor.blue, 13),
      ];
      check(tiles).length.equals(15);
      final result = _timed(
        'garbage 15-tile okey',
        SolveRequest(
          tiles: tiles,
          indicator: const Indicator(color: TileColor.blue, number: 5),
          mode: GameMode.okey,
        ),
      );
      check(result.verdict).isA<OkeyOutcome>();
    });

    test('all-wild 8-tile rack: every cell plays a 13', () {
      // 2 jokers + 6 okey copies: 8 wild cells split into two 13-sets of
      // 4 score 8 × 13 = 104.
      final tiles = <GameTile>[
        _joker,
        _joker,
        for (var i = 0; i < 6; i++) _t(TileColor.black, 2), // okey copies
      ];
      final result = _timed(
        'all-wild 8 tiles (101)',
        SolveRequest(
          tiles: tiles,
          indicator: const Indicator(color: TileColor.black, number: 1),
          mode: GameMode.oneZeroOne,
        ),
      );
      check(result.totalScore).equals(104);
    });

    test('all-wild 12-tile rack: three 13-sets, well inside budget', () {
      // Regression for the wild-driven slot blowup: wilds used to widen
      // `slots(c)` for EVERY color (W=12 → ~5 s, W=21 → > 13 min). Slots
      // are now bounded by real tiles per color (+1 designated pure-wild
      // run slot at W ≥ 5), so all-wild racks collapse to a tiny state
      // space. The exact optimum is unchanged: 12 × 13 = 156.
      final tiles = <GameTile>[
        _joker,
        _joker,
        for (var i = 0; i < 10; i++) _t(TileColor.black, 2), // okey copies
      ];
      final result = _timed(
        'all-wild 12 tiles (101)',
        SolveRequest(
          tiles: tiles,
          indicator: const Indicator(color: TileColor.black, number: 1),
          mode: GameMode.oneZeroOne,
        ),
      );
      check(result.totalScore).equals(156);
    });

    test('all-wild 21-joker rack: six pure-wild 13-sets', () {
      // The mode-legal worst case the design's perf guarantee covers
      // (> 13 min before the slot fix). 21 wilds close as six 13-sets
      // (sizes 4·3 + 3·3): 21 × 13 = 273.
      final tiles = List<GameTile>.filled(21, _joker);
      final result = _timed(
        'all-wild 21 jokers (101)',
        SolveRequest(
          tiles: tiles,
          indicator: const Indicator(color: TileColor.black, number: 1),
          mode: GameMode.oneZeroOne,
        ),
      );
      check(result.totalScore).equals(273);
    });

    test('mixed garbage: 10 wilds + 11 spread reals stays fast', () {
      // Wild-heavy AND real-bearing: every color keeps its real-bound
      // slots, so this exercises the widest post-fix state space.
      final tiles = <GameTile>[
        for (final n in [1, 4, 7, 10, 13]) _t(TileColor.red, n),
        for (final n in [2, 5, 8]) _t(TileColor.yellow, n),
        for (final n in [3, 6, 9]) _t(TileColor.blue, n),
        _joker,
        _joker,
        for (var i = 0; i < 8; i++) _t(TileColor.black, 2), // okey copies
      ];
      check(tiles).length.equals(21);
      final result = _timed(
        'mixed garbage 10 wilds + 11 reals (101)',
        SolveRequest(
          tiles: tiles,
          indicator: const Indicator(color: TileColor.black, number: 1),
          mode: GameMode.oneZeroOne,
        ),
      );
      check(result.totalScore).isGreaterThan(0);
    });

    test('typical 21-tile fixture (§5 worked example) is fast', () {
      final tiles = <GameTile>[
        for (final n in [9, 10, 11, 12, 13]) _t(TileColor.red, n),
        _t(TileColor.black, 5),
        _t(TileColor.yellow, 5),
        _t(TileColor.blue, 5),
        for (final n in [1, 2, 3]) _t(TileColor.yellow, n),
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
      check(tiles).length.equals(21);
      final result = _timed(
        'typical 21 tiles (target < 300 ms)',
        SolveRequest(
          tiles: tiles,
          indicator: const Indicator(color: TileColor.blue, number: 3),
          mode: GameMode.oneZeroOne,
        ),
      );
      check(result.totalScore).equals(153);
    });
  });
}
