import 'package:checks/checks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:okey_acar_mi/core/game/game_tile.dart';
import 'package:okey_acar_mi/core/game/indicator.dart';
import 'package:okey_acar_mi/core/game/tile_color.dart';

void main() {
  group('Indicator.okeyNumber', () {
    test('derives one up for every numeral, wrapping 13 to 1', () {
      const expected = [2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 1];
      for (var n = 1; n <= 13; n++) {
        check(
          because: 'indicator $n',
          Indicator(color: TileColor.blue, number: n).okeyNumber,
        ).equals(expected[n - 1]);
      }
    });

    test('3 derives 4', () {
      check(
        const Indicator(color: TileColor.red, number: 3).okeyNumber,
      ).equals(4);
    });

    test('13 wraps to 1', () {
      check(
        const Indicator(color: TileColor.yellow, number: 13).okeyNumber,
      ).equals(1);
    });
  });

  group('Indicator.okeyTile', () {
    test('keeps the indicator color', () {
      for (final color in const [
        TileColor.red,
        TileColor.black,
        TileColor.yellow,
        TileColor.blue,
      ]) {
        final okey = Indicator(color: color, number: 7).okeyTile;
        check(okey).equals(GameTile(color: color, number: 8));
        check(okey.isJoker).isFalse();
      }
    });
  });

  group('Indicator invariants', () {
    test('rejects the joker color', () {
      expect(
        () => Indicator(color: TileColor.joker, number: 5),
        throwsA(isA<AssertionError>()),
      );
    });

    test('rejects out-of-range numbers', () {
      expect(
        () => Indicator(color: TileColor.red, number: 0),
        throwsA(isA<AssertionError>()),
      );
      expect(
        () => Indicator(color: TileColor.red, number: 14),
        throwsA(isA<AssertionError>()),
      );
    });
  });
}
