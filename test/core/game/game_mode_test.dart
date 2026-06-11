import 'package:checks/checks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:okey_acar_mi/core/game/game_mode.dart';

void main() {
  group('GameMode rack limits', () {
    test('101 mode allows 20-21 tiles', () {
      check(GameMode.oneZeroOne.minTiles).equals(20);
      check(GameMode.oneZeroOne.maxTiles).equals(21);
    });

    test('okey mode allows 14-15 tiles', () {
      check(GameMode.okey.minTiles).equals(14);
      check(GameMode.okey.maxTiles).equals(15);
    });
  });
}
