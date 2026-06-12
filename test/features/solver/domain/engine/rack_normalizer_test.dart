import 'package:flutter_test/flutter_test.dart';
import 'package:okey_acar_mi/core/game/game_tile.dart';
import 'package:okey_acar_mi/core/game/indicator.dart';
import 'package:okey_acar_mi/core/game/tile_color.dart';
import 'package:okey_acar_mi/features/solver/domain/engine/rack_normalizer.dart';

GameTile _t(TileColor c, int n) => GameTile(color: c, number: n);
const _joker = GameTile(color: TileColor.joker);

void main() {
  const normalizer = RackNormalizer();

  test('counts kinds, wilds, queues and slots deterministically', () {
    const indicator = Indicator(color: TileColor.blue, number: 3);
    final tiles = <GameTile>[
      _t(TileColor.red, 9),
      _joker,
      _t(TileColor.blue, 4), // okey copy → wild
      _t(TileColor.red, 9),
      _joker,
    ];
    final rack = normalizer.normalize(tiles, indicator);

    expect(rack.okeyTile, _t(TileColor.blue, 4));
    expect(rack.counts[TileColor.red.index][9], 2);
    expect(rack.counts[TileColor.blue.index][4], 0);
    expect(rack.wildCount, 3);
    expect(rack.falseJokerCount, 2);
    expect(rack.okeyCopyCount, 1);
    // False jokers first (rack order), then okey copies.
    expect(rack.wildQueue, [1, 4, 2]);
    expect(rack.instanceQueues[TileColor.red.index][9], [0, 3]);
    // T_red = 2, W = 3 → min(max(2, ⌊5/3⌋), T_red) = 2; colors with no
    // real tiles get 0 slots (W < 5 → no pure-wild-run slot anywhere).
    expect(rack.scoreSlots, [2, 0, 0, 0]);
    expect(rack.okeySlots, [2, 2, 2, 2]);
    expect(rack.clamped, isEmpty);
    expect(rack.forcedLeftoverIndices, isEmpty);
  });

  test('indicator 13 wraps: okey is number 1 of the same color', () {
    const indicator = Indicator(color: TileColor.red, number: 13);
    final rack = normalizer.normalize([_t(TileColor.red, 1)], indicator);
    expect(rack.okeyTile, _t(TileColor.red, 1));
    expect(rack.wildCount, 1);
    expect(rack.counts[TileColor.red.index][1], 0);
  });

  test('clamps 5th+ copies of a kind to forced leftovers', () {
    const indicator = Indicator(color: TileColor.black, number: 1);
    final tiles = List<GameTile>.filled(6, _t(TileColor.yellow, 7));
    final rack = normalizer.normalize(tiles, indicator);
    expect(rack.counts[TileColor.yellow.index][7], 4);
    expect(rack.forcedLeftoverIndices, [4, 5]);
    expect(rack.clamped, hasLength(1));
    expect(rack.clamped.single.kind, _t(TileColor.yellow, 7));
    expect(rack.clamped.single.dropped, 2);
    // 4 copies of one kind widen the okey slots.
    expect(rack.okeySlots[TileColor.yellow.index], 4);
  });

  test('slots widen with wilds and cap for overflow safety', () {
    const indicator = Indicator(color: TileColor.black, number: 1);
    // Three-parallel-runs shape: T_red = 8 + 1 wild → slots(red) = 3.
    final tiles = <GameTile>[
      for (final n in [9, 10, 11, 11, 12, 12, 13, 13]) _t(TileColor.red, n),
      _joker,
    ];
    final rack = normalizer.normalize(tiles, indicator);
    expect(rack.scoreSlots[TileColor.red.index], 3);

    // All-wild garbage: wilds alone never widen slots — only the
    // designated color keeps 1 slot for the (single possible) pure-wild
    // run once W ≥ 5.
    final garbage = List<GameTile>.filled(40, _joker);
    final wide = normalizer.normalize(garbage, indicator);
    expect(wide.scoreSlots, [1, 0, 0, 0]);
    expect(wide.wildCount, 40);

    // Real-tile garbage: the disjoint-cells arm caps at maxSlots.
    final dense = <GameTile>[
      for (var copy = 0; copy < 4; copy++)
        for (var n = 1; n <= 13; n++) _t(TileColor.red, n),
    ];
    final capped = normalizer.normalize(dense, indicator);
    expect(capped.scoreSlots[TileColor.red.index], RackNormalizer.maxSlots);
  });

  test('designated color gains the pure-wild run slot only at W ≥ 5', () {
    const indicator = Indicator(color: TileColor.black, number: 1);
    final four = normalizer.normalize(List.filled(4, _joker), indicator);
    expect(four.scoreSlots, [0, 0, 0, 0]);
    final five = normalizer.normalize(List.filled(5, _joker), indicator);
    expect(five.scoreSlots, [1, 0, 0, 0]);
    // Real tiles in the designated color stack on top of the bonus slot
    // only up to the disjoint-cells bound.
    final mixed = normalizer.normalize(
      [_t(TileColor.red, 13), ...List.filled(5, _joker)],
      indicator,
    );
    // Red: min(max(2, ⌊6/3⌋), 1 + 1) = 2.
    expect(mixed.scoreSlots, [2, 0, 0, 0]);
  });

  test('phantom budget reflects the 106-tile supply', () {
    const indicator = Indicator(color: TileColor.black, number: 1);
    final rack = normalizer.normalize(
      [_t(TileColor.red, 5), _t(TileColor.red, 5), _t(TileColor.blue, 9)],
      indicator,
    );
    expect(rack.phantomBudget(TileColor.red.index, 5), 0);
    expect(rack.phantomBudget(TileColor.blue.index, 9), 1);
    expect(rack.phantomBudget(TileColor.yellow.index, 2), 2);
  });

  test('phantom budget counts physical okey copies held as wilds', () {
    // Okey = Black 2; held copies are wilds (not rackCopies) yet deplete
    // the 106-tile pool, so the okey identity's budget must shrink.
    const indicator = Indicator(color: TileColor.black, number: 1);
    final one = normalizer.normalize([_t(TileColor.black, 2)], indicator);
    expect(one.okeyCopyCount, 1);
    expect(one.phantomBudget(TileColor.black.index, 2), 1);
    final both = normalizer.normalize(
      [_t(TileColor.black, 2), _t(TileColor.black, 2)],
      indicator,
    );
    expect(both.okeyCopyCount, 2);
    expect(both.phantomBudget(TileColor.black.index, 2), 0);
  });
}
