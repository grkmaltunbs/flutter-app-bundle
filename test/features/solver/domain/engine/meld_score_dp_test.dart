import 'package:flutter_test/flutter_test.dart';
import 'package:okey_acar_mi/core/game/game_tile.dart';
import 'package:okey_acar_mi/core/game/indicator.dart';
import 'package:okey_acar_mi/core/game/tile_color.dart';
import 'package:okey_acar_mi/features/solver/domain/engine/meld_score_dp.dart';
import 'package:okey_acar_mi/features/solver/domain/engine/rack_normalizer.dart';

GameTile _t(TileColor c, int n) => GameTile(color: c, number: n);
const _joker = GameTile(color: TileColor.joker);

// Okey = Black 2; tests avoid Black 2 unless wilds are intended.
const _indicator = Indicator(color: TileColor.black, number: 1);

int _best(List<GameTile> tiles, [Indicator indicator = _indicator]) {
  final rack = const RackNormalizer().normalize(tiles, indicator);
  return const MeldScoreDp().run(rack).best;
}

void main() {
  group('MeldScoreDp', () {
    test('empty rack scores 0', () {
      expect(_best(const []), 0);
    });

    test('simple run scores its face sum', () {
      expect(
        _best([
          _t(TileColor.red, 5),
          _t(TileColor.red, 6),
          _t(TileColor.red, 7),
        ]),
        18,
      );
    });

    test('simple set scores number × size', () {
      expect(
        _best([
          _t(TileColor.red, 5),
          _t(TileColor.yellow, 5),
          _t(TileColor.blue, 5),
        ]),
        15,
      );
      expect(
        _best([for (final c in TileColor.values.sublist(0, 4)) _t(c, 9)]),
        36,
      );
    });

    test('no wrap: 12-13-1 and 13-1-2 never form a run', () {
      expect(
        _best([
          _t(TileColor.red, 12),
          _t(TileColor.red, 13),
          _t(TileColor.red, 1),
        ]),
        0,
      );
      expect(
        _best([
          _t(TileColor.red, 13),
          _t(TileColor.red, 1),
          _t(TileColor.red, 2),
        ]),
        0,
      );
    });

    test('full 1..13 run scores 91', () {
      expect(
        _best([for (var n = 1; n <= 13; n++) _t(TileColor.yellow, n)]),
        91,
      );
    });

    test('wild completes the most valuable extension', () {
      // Joker as Red 7 (5+6+7=18) beats Red 4 (15).
      expect(
        _best([_t(TileColor.red, 5), _t(TileColor.red, 6), _joker]),
        18,
      );
    });

    test('staggered runs share a column copy (composite close-reopen)', () {
      expect(
        _best([
          _t(TileColor.red, 1),
          _t(TileColor.red, 2),
          _t(TileColor.red, 3),
          _t(TileColor.red, 3),
          _t(TileColor.red, 4),
          _t(TileColor.red, 5),
        ]),
        18,
      );
    });

    test('three parallel same-color runs need the widened slots (§6)', () {
      // Optimum 102: 9-10-11 / 11-12-13 / ◦(Red 11)-12-13 — not 101.
      final best = _best([
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
      expect(best, 102);
    });

    test('pure-wild set forms in-sweep', () {
      // 3 wilds → set of three 13s (39) beats any run of 3 (max 36).
      expect(_best([_joker, _joker, _joker]), 39);
    });

    test('short runs are never paid for', () {
      expect(_best([_t(TileColor.red, 4), _t(TileColor.red, 5)]), 0);
    });
  });
}
