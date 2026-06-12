import 'package:flutter_test/flutter_test.dart';
import 'package:okey_acar_mi/core/game/game_tile.dart';
import 'package:okey_acar_mi/core/game/indicator.dart';
import 'package:okey_acar_mi/core/game/tile_color.dart';
import 'package:okey_acar_mi/features/solver/domain/engine/meld_reconstructor.dart';
import 'package:okey_acar_mi/features/solver/domain/engine/meld_score_dp.dart';
import 'package:okey_acar_mi/features/solver/domain/engine/meld_validator.dart';
import 'package:okey_acar_mi/features/solver/domain/engine/rack_normalizer.dart';
import 'package:okey_acar_mi/features/solver/domain/entities/solved_meld.dart';
import 'package:okey_acar_mi/features/solver/domain/entities/solved_spot.dart';

GameTile _t(TileColor c, int n) => GameTile(color: c, number: n);
const _joker = GameTile(color: TileColor.joker);
const _indicator = Indicator(color: TileColor.black, number: 1);

MeldArrangement _arrange(List<GameTile> tiles) {
  final rack = const RackNormalizer().normalize(tiles, _indicator);
  final result = const MeldScoreDp().run(rack);
  final arrangement = const MeldReconstructor().reconstruct(rack, result);
  // Invariants pinned for every fixture.
  final sum = arrangement.melds.fold<int>(0, (s, m) => s + m.points);
  expect(sum, result.best);
  for (final meld in arrangement.melds) {
    expect(const MeldValidator().isValidMeld(meld), isTrue);
  }
  return arrangement;
}

void main() {
  test('empty rack reconstructs to no melds', () {
    final arrangement = _arrange(const []);
    expect(arrangement.melds, isEmpty);
    expect(arrangement.usedRackIndices, isEmpty);
  });

  test('single run binds rack indices in order', () {
    final arrangement = _arrange([
      _t(TileColor.red, 7),
      _t(TileColor.red, 5),
      _t(TileColor.red, 6),
    ]);
    final meld = arrangement.melds.single;
    expect(meld.kind, MeldKind.run);
    expect(meld.points, 18);
    expect(
      meld.spots.map((s) => s.playsAs.number),
      [5, 6, 7],
    );
    expect(arrangement.usedRackIndices, {0, 1, 2});
  });

  test('wild in a set plays the lowest-enum missing color', () {
    final arrangement = _arrange([
      _t(TileColor.black, 11),
      _t(TileColor.yellow, 11),
      _joker,
    ]);
    final meld = arrangement.melds.single;
    expect(meld.kind, MeldKind.set);
    expect(meld.points, 33);
    final wild = meld.spots.whereType<WildSpot>().single;
    expect(wild.playsAs, _t(TileColor.red, 11));
  });

  test('staggered runs split the duplicate column copy', () {
    final arrangement = _arrange([
      _t(TileColor.red, 1),
      _t(TileColor.red, 2),
      _t(TileColor.red, 3),
      _t(TileColor.red, 3),
      _t(TileColor.red, 4),
      _t(TileColor.red, 5),
    ]);
    expect(arrangement.melds, hasLength(2));
    expect(arrangement.usedRackIndices, hasLength(6));
  });

  test('three parallel red runs reconstruct the 102 optimum', () {
    final arrangement = _arrange([
      _t(TileColor.red, 9),
      _t(TileColor.red, 10),
      _t(TileColor.red, 11),
      _t(TileColor.red, 11),
      _t(TileColor.red, 12),
      _t(TileColor.red, 12),
      _t(TileColor.red, 13),
      _t(TileColor.red, 13),
      _joker,
    ]);
    expect(arrangement.melds, hasLength(3));
    expect(arrangement.usedRackIndices, hasLength(9));
    final wilds = arrangement.melds
        .expand((m) => m.spots)
        .whereType<WildSpot>();
    expect(wilds.single.playsAs.color, TileColor.red);
  });

  test('unmeldable tiles stay unused', () {
    final arrangement = _arrange([
      _t(TileColor.red, 5),
      _t(TileColor.red, 6),
      _t(TileColor.red, 7),
      _t(TileColor.blue, 2),
    ]);
    expect(arrangement.melds, hasLength(1));
    expect(arrangement.usedRackIndices, {0, 1, 2});
  });
}
