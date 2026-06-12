import 'package:checks/checks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:okey_acar_mi/core/game/game_mode.dart';
import 'package:okey_acar_mi/core/game/game_tile.dart';
import 'package:okey_acar_mi/core/game/indicator.dart';
import 'package:okey_acar_mi/core/game/tile_color.dart';
import 'package:okey_acar_mi/features/solver/domain/engine/solver_engine.dart';
import 'package:okey_acar_mi/features/solver/domain/entities/solve_request.dart';
import 'package:okey_acar_mi/features/solver/domain/entities/solve_verdict.dart';
import 'package:okey_acar_mi/features/solver/domain/usecases/solve_rack.dart';

GameTile _t(TileColor c, int n) => GameTile(color: c, number: n);
const _joker = GameTile(color: TileColor.joker);
const _engine = DpSolverEngine();

/// §5 worked example — ties everywhere (multiple optimal arrangements), so
/// any nondeterministic tie-break would surface here.
final _request101 = SolveRequest(
  tiles: [
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
  ],
  indicator: const Indicator(color: TileColor.blue, number: 3),
  mode: GameMode.oneZeroOne,
);

/// An okey rack with phantom padding + wild conversion — exercises the
/// canonical-padding and reconstruction tie-breaks.
final _requestOkey = SolveRequest(
  tiles: [
    _t(TileColor.red, 1),
    _t(TileColor.red, 2),
    _t(TileColor.red, 3),
    _t(TileColor.black, 7),
    _t(TileColor.black, 8),
    _t(TileColor.yellow, 11),
    _t(TileColor.yellow, 11),
    _t(TileColor.blue, 4),
    _t(TileColor.blue, 5),
    _t(TileColor.black, 2),
    _t(TileColor.yellow, 5),
    _t(TileColor.red, 9),
    _t(TileColor.blue, 13),
    _joker,
  ],
  indicator: const Indicator(color: TileColor.yellow, number: 9),
  mode: GameMode.okey,
);

void main() {
  group('solver determinism', () {
    test('50 repeated engine solves yield deeply equal results (101)', () {
      final reference = _engine.solve(_request101);
      for (var i = 0; i < 50; i++) {
        final result = _engine.solve(_request101);
        check(because: 'iteration $i', result).equals(reference);
        check(
          because: 'iteration $i reasoning',
          result.reasoning,
        ).deepEquals(reference.reasoning);
      }
    });

    test('50 repeated engine solves yield deeply equal results (okey)', () {
      final reference = _engine.solve(_requestOkey);
      check(reference.verdict).isA<OkeyOutcome>();
      for (var i = 0; i < 50; i++) {
        final result = _engine.solve(_requestOkey);
        check(because: 'iteration $i', result).equals(reference);
        check(
          because: 'iteration $i melds',
          result.melds,
        ).deepEquals(reference.melds);
        check(
          because: 'iteration $i leftovers',
          result.leftovers,
        ).deepEquals(reference.leftovers);
      }
    });

    test('results are identical across real Isolate.run executions', () async {
      final direct = _engine.solve(_request101);
      // Fresh usecases so the LRU(1) cache cannot mask the isolate path.
      final first = await SolveRack(_engine).call(_request101);
      final second = await SolveRack(_engine).call(_request101);
      check(first).equals(direct);
      check(second).equals(direct);
      check(first).equals(second);
    });
  });
}
