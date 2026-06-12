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

/// §6 three-parallel-runs rack — opens 101 with exactly 102.
final _request101 = SolveRequest(
  tiles: [
    for (final n in [9, 10, 11, 11, 12, 12, 13, 13]) _t(TileColor.red, n),
    _joker,
  ],
  indicator: const Indicator(color: TileColor.black, number: 1),
  mode: GameMode.oneZeroOne,
);

/// A 14-tile okey rack with phantom padding + wild conversion.
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
  group('SolveRack usecase contract', () {
    test('LRU(1) hit: a structurally equal request returns the identical '
        'cached result', () async {
      final usecase = SolveRack(_engine);
      final first = await usecase(_request101);
      final second = await usecase(
        SolveRequest(
          tiles: List.of(_request101.tiles),
          indicator: _request101.indicator,
          mode: _request101.mode,
        ),
      );
      check(identical(first, second)).isTrue();
      check(
        first.verdict,
      ).equals(const SolveVerdict.opens101(score: 102, via: OpenPath.melds));
    });

    test('A/B/A: the single-entry cache never serves a stale result', () async {
      final usecase = SolveRack(_engine);
      final directA = _engine.solve(_request101);
      final directB = _engine.solve(_requestOkey);
      final first = await usecase(_request101);
      final second = await usecase(_requestOkey);
      final third = await usecase(_request101);
      check(first).equals(directA);
      check(second).equals(directB);
      check(third).equals(directA);
      // B evicted A, so the third call recomputed off-isolate.
      check(identical(first, third)).isFalse();
    });

    test('mode is part of the cache key', () async {
      final usecase = SolveRack(_engine);
      final as101Request = _requestOkey.copyWith(mode: GameMode.oneZeroOne);
      final as101 = await usecase(as101Request);
      final asOkey = await usecase(_requestOkey);
      check(identical(as101, asOkey)).isFalse();
      check(as101).equals(_engine.solve(as101Request));
      check(asOkey).equals(_engine.solve(_requestOkey));
      check(as101.verdict).isA<DoesNotOpen101>();
      check(asOkey.verdict).isA<OkeyOutcome>();
    });

    test(
      'two concurrent solves with different requests do not interfere',
      () async {
        final direct101 = _engine.solve(_request101);
        final directOkey = _engine.solve(_requestOkey);
        final usecase = SolveRack(_engine);
        final results = await Future.wait([
          usecase(_request101),
          usecase(_requestOkey),
        ]);
        check(results[0]).equals(direct101);
        check(results[1]).equals(directOkey);
      },
    );
  });
}
