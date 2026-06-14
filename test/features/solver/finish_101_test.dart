import 'package:checks/checks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:okey_acar_mi/core/game/game_mode.dart';
import 'package:okey_acar_mi/core/game/game_tile.dart';
import 'package:okey_acar_mi/core/game/indicator.dart';
import 'package:okey_acar_mi/core/game/tile_color.dart';
import 'package:okey_acar_mi/features/solver/domain/engine/solver_engine.dart';
import 'package:okey_acar_mi/features/solver/domain/entities/solve_request.dart';
import 'package:okey_acar_mi/features/solver/domain/entities/solve_result.dart';
import 'package:okey_acar_mi/features/solver/domain/entities/solve_verdict.dart';

const _engine = DpSolverEngine();

GameTile _t(TileColor c, int n) => GameTile(color: c, number: n);
List<GameTile> _run(TileColor c, int lo, int hi) => [
  for (var n = lo; n <= hi; n++) _t(c, n),
];
List<GameTile> _set(int n, List<TileColor> colors) => [
  for (final c in colors) _t(c, n),
];

SolveResult _solve(
  List<GameTile> tiles, {
  Indicator? indicator,
  GameMode mode = GameMode.oneZeroOne,
}) => _engine.solve(
  SolveRequest(tiles: tiles, indicator: indicator, mode: mode),
);

void main() {
  // The indicator's okey is chosen absent from every rack below so no numbered
  // tile is silently treated as a wild (okey yellow 6 / blue 11).
  const yellow5 = Indicator(color: TileColor.yellow, number: 5);
  const blue10 = Indicator(color: TileColor.blue, number: 10);

  group('101 FINISHES verdict', () {
    test('22 tiles, all 21 meld with score ≥ 101 → FINISHES + discard', () {
      final tiles = <GameTile>[
        ..._run(TileColor.red, 1, 3),
        ..._run(TileColor.red, 4, 6),
        ..._run(TileColor.red, 7, 9),
        ..._run(TileColor.blue, 1, 3),
        ..._run(TileColor.blue, 4, 6),
        ..._run(TileColor.blue, 7, 9),
        ..._run(TileColor.black, 11, 13),
        // The lone discard → 22 tiles. Yellow 10 cannot meld (no yellow 9/11,
        // and no red/black 10 for a set), so coverage is exactly 21.
        _t(TileColor.yellow, 10),
      ];

      final result = _solve(tiles, indicator: yellow5);

      check(result.verdict).isA<Finishes101>();
      check((result.verdict as Finishes101).score).equals(126);
      check(result.leftovers.length).equals(1);
      check(result.discardSuggested).equals(_t(TileColor.yellow, 10));
      check(result.discardRackIndex).equals(21);
    });

    test('22 tiles, all 21 meld but score < 101 → still FINISHES', () {
      final tiles = <GameTile>[
        ..._run(TileColor.red, 1, 3),
        ..._run(TileColor.blue, 1, 3),
        ..._run(TileColor.black, 1, 3),
        ..._run(TileColor.yellow, 1, 3),
        ..._run(TileColor.red, 4, 6),
        ..._run(TileColor.blue, 4, 6),
        ..._run(TileColor.black, 4, 6),
        _t(TileColor.yellow, 9), // the lone discard → 22 tiles
      ];

      final result = _solve(tiles, indicator: blue10);

      // Using all 21 tiles finishes regardless of the meld total.
      check(result.verdict).isA<Finishes101>();
      check((result.verdict as Finishes101).score).isLessThan(101);
      check(result.leftovers.length).equals(1);
      check(result.discardSuggested).equals(_t(TileColor.yellow, 9));
    });

    test('21 tiles that all meld → OPENS (not FINISHES), no discard', () {
      final tiles = <GameTile>[
        ..._run(TileColor.red, 1, 3),
        ..._run(TileColor.red, 4, 6),
        ..._run(TileColor.red, 7, 9),
        ..._run(TileColor.blue, 1, 3),
        ..._run(TileColor.blue, 4, 6),
        ..._run(TileColor.blue, 7, 9),
        ..._run(TileColor.black, 11, 13),
      ]; // 21 tiles, no draw yet ⇒ cannot finish (no tile to discard)

      final result = _solve(tiles, indicator: yellow5);

      check(result.verdict).isA<Opens101>();
      check(result.discardSuggested).isNull();
      check(result.leftovers).isEmpty();
    });

    test('22 tiles that open ≥ 101 but cannot meld 21 → OPENS + discard', () {
      final tiles = <GameTile>[
        ..._set(13, const [
          TileColor.red,
          TileColor.blue,
          TileColor.yellow,
          TileColor.black,
        ]),
        ..._set(12, const [
          TileColor.red,
          TileColor.blue,
          TileColor.yellow,
          TileColor.black,
        ]),
        ..._set(11, const [
          TileColor.red,
          TileColor.blue,
          TileColor.yellow,
          TileColor.black,
        ]),
        // 10 dead tiles (only red/blue, ≤2 copies) — no set, no run.
        _t(TileColor.red, 1), _t(TileColor.red, 1),
        _t(TileColor.blue, 1), _t(TileColor.blue, 1),
        _t(TileColor.red, 2), _t(TileColor.red, 2),
        _t(TileColor.blue, 2), _t(TileColor.blue, 2),
        _t(TileColor.red, 4), _t(TileColor.red, 4),
      ]; // 12 melded + 10 dead = 22 tiles

      final result = _solve(tiles, indicator: yellow5);

      check(result.verdict).isA<Opens101>();
      check((result.verdict as Opens101).score).isGreaterOrEqual(101);
      check(result.discardSuggested).isNotNull();
    });
  });

  group('101 nullable indicator (face-down wild)', () {
    test('solves with a null indicator without crashing; wild melds', () {
      final tiles = <GameTile>[
        ..._run(TileColor.red, 1, 3),
        ..._run(TileColor.red, 4, 6),
        ..._run(TileColor.red, 7, 9),
        ..._run(TileColor.blue, 1, 3),
        ..._run(TileColor.blue, 4, 6),
        ..._run(TileColor.blue, 7, 9),
        _t(TileColor.black, 11),
        _t(TileColor.black, 12),
        // Face-down (blank okey) → wild → black 13. A sahte okey would need
        // the indicator, which is why the face-down is what makes solving
        // without one possible.
        const GameTile(color: TileColor.joker, faceDown: true),
      ]; // 21 tiles

      final result = _solve(tiles); // no indicator picked

      check(result.verdict).isA<Opens101>();
      check(result.melds).isNotEmpty();
    });
  });

  group('sahte okey (false joker) is not wild', () {
    test('a false joker plays only as the okey value, never a high wild', () {
      // okey = red 3. A wild here would complete blue 9-10-11-12-13 (+55); the
      // sahte okey can only be red 3 (a lone leftover), so the best is the blue
      // 9-10-11-12 run (+42). (This pins the reported bug: joker → blue 13.)
      final tiles = <GameTile>[
        _t(TileColor.blue, 9),
        _t(TileColor.blue, 10),
        _t(TileColor.blue, 11),
        _t(TileColor.blue, 12),
        const GameTile(color: TileColor.joker), // sahte okey → red 3
      ];

      final result = _solve(
        tiles,
        indicator: const Indicator(color: TileColor.red, number: 2),
      );

      check(result.totalScore).equals(42);
      final playsAs = [
        for (final m in result.melds) ...m.spots.map((s) => s.playsAs),
      ];
      check(
        playsAs.any((t) => t.color == TileColor.blue && t.number == 13),
      ).isFalse();
    });
  });
}
