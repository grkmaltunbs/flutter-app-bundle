import 'package:flutter_test/flutter_test.dart';
import 'package:okey_acar_mi/core/game/game_tile.dart';
import 'package:okey_acar_mi/core/game/indicator.dart';
import 'package:okey_acar_mi/core/game/tile_color.dart';
import 'package:okey_acar_mi/features/solver/domain/engine/okey_reconstructor.dart';
import 'package:okey_acar_mi/features/solver/domain/engine/okey_win_dp.dart';
import 'package:okey_acar_mi/features/solver/domain/engine/rack_normalizer.dart';
import 'package:okey_acar_mi/features/solver/domain/entities/solved_spot.dart';

GameTile _t(TileColor c, int n) => GameTile(color: c, number: n);

(OkeyWinDpResult, OkeyArrangement) _solve(
  List<GameTile> tiles,
  Indicator indicator,
) {
  final rack = const RackNormalizer().normalize(tiles, indicator);
  final result = const OkeyWinDp().run(rack);
  final arrangement = const OkeyReconstructor().reconstruct(rack, result);
  expect(arrangement.matched, result.bestMatched);
  final cells =
      arrangement.melds.fold<int>(0, (s, m) => s + m.spots.length) +
      (arrangement.pair == null ? 0 : 2);
  expect(cells, 14);
  return (result, arrangement);
}

void main() {
  group('OkeyWinDp', () {
    test('3+3+4+4 winning hand matches all 14', () {
      final tiles = <GameTile>[
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
      ];
      const indicator = Indicator(color: TileColor.red, number: 12);
      final (result, arrangement) = _solve(tiles, indicator);
      expect(result.bestMatched, 14);
      expect(arrangement.melds, hasLength(4));
      expect(arrangement.pair, isNull);
      expect(
        arrangement.melds.expand((m) => m.spots).whereType<NeededSpot>(),
        isEmpty,
      );
    });

    test('3+3+3+3+2 final-pair hand matches all 14', () {
      final tiles = <GameTile>[
        for (final c in TileColor.values.sublist(0, 4)) ...[
          _t(c, 1),
          _t(c, 2),
          _t(c, 3),
        ],
        _t(TileColor.red, 9),
        _t(TileColor.red, 9),
      ];
      const indicator = Indicator(color: TileColor.black, number: 7);
      final (result, arrangement) = _solve(tiles, indicator);
      expect(result.bestMatched, 14);
      expect(arrangement.pair, isNotNull);
      expect(arrangement.pair!.identity, _t(TileColor.red, 9));
      // 4 runs of 3, or equivalently 3 sets of 4 — both are optimal.
      expect(arrangement.melds.length, inInclusiveRange(3, 4));
    });

    test('one tile short yields matched 13 and one needed spot', () {
      final tiles = <GameTile>[
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
        _t(TileColor.blue, 13),
      ];
      const indicator = Indicator(color: TileColor.red, number: 12);
      final (result, arrangement) = _solve(tiles, indicator);
      expect(result.bestMatched, 13);
      final needed = [
        ...arrangement.melds.expand((m) => m.spots),
        if (arrangement.pair != null) ...[
          arrangement.pair!.first,
          arrangement.pair!.second,
        ],
      ].whereType<NeededSpot>();
      expect(needed, hasLength(1));
    });

    test('phantom supply cap: a third copy is never demanded', () {
      // 3 × Red 5: pair (2) + one more cell via phantoms of other kinds.
      final tiles = [
        _t(TileColor.red, 5),
        _t(TileColor.red, 5),
        _t(TileColor.red, 5),
      ];
      const indicator = Indicator(color: TileColor.black, number: 1);
      final (result, _) = _solve(tiles, indicator);
      expect(result.bestMatched, 3);
    });

    test('empty rack pads 14 phantom cells without crashing', () {
      const indicator = Indicator(color: TileColor.black, number: 1);
      final (result, arrangement) = _solve(const [], indicator);
      expect(result.bestMatched, 0);
      final needed = [
        ...arrangement.melds.expand((m) => m.spots),
        if (arrangement.pair != null) ...[
          arrangement.pair!.first,
          arrangement.pair!.second,
        ],
      ].whereType<NeededSpot>();
      expect(needed, hasLength(14));
      expect(arrangement.usedRackIndices, isEmpty);
    });

    test('15-tile rack keeps at most 14 (implicit discard)', () {
      final tiles = <GameTile>[
        _t(TileColor.red, 1), _t(TileColor.red, 2), _t(TileColor.red, 3),
        _t(TileColor.black, 1), _t(TileColor.black, 2), _t(TileColor.black, 3),
        _t(TileColor.yellow, 5), _t(TileColor.yellow, 6),
        _t(TileColor.yellow, 7), _t(TileColor.yellow, 8),
        _t(TileColor.blue, 9), _t(TileColor.blue, 10),
        _t(TileColor.blue, 11), _t(TileColor.blue, 12),
        _t(TileColor.black, 13), // 15th tile
      ];
      const indicator = Indicator(color: TileColor.red, number: 12);
      final (result, arrangement) = _solve(tiles, indicator);
      expect(result.bestMatched, 14);
      expect(arrangement.usedRackIndices, hasLength(14));
    });
  });
}
