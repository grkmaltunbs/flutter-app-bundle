import 'package:flutter_test/flutter_test.dart';
import 'package:okey_acar_mi/core/game/game_tile.dart';
import 'package:okey_acar_mi/core/game/tile_color.dart';
import 'package:okey_acar_mi/features/solver/domain/engine/meld_validator.dart';
import 'package:okey_acar_mi/features/solver/domain/entities/solved_meld.dart';
import 'package:okey_acar_mi/features/solver/domain/entities/solved_pair.dart';
import 'package:okey_acar_mi/features/solver/domain/entities/solved_spot.dart';

SolvedSpot _spot(TileColor color, int number) => SolvedSpot.rackTile(
  physical: GameTile(color: color, number: number),
  rackIndex: 0,
  playsAs: GameTile(color: color, number: number),
);

SolvedMeld _run(TileColor color, List<int> numbers) => SolvedMeld(
  kind: MeldKind.run,
  spots: [for (final n in numbers) _spot(color, n)],
  points: 0,
);

SolvedMeld _set(int number, List<TileColor> colors) => SolvedMeld(
  kind: MeldKind.set,
  spots: [for (final c in colors) _spot(c, number)],
  points: 0,
);

void main() {
  const validator = MeldValidator();

  group('MeldValidator runs', () {
    test('accepts 3+ consecutive same color', () {
      expect(validator.isValidMeld(_run(TileColor.red, [9, 10, 11])), isTrue);
      expect(
        validator.isValidMeld(_run(TileColor.blue, [11, 12, 13])),
        isTrue,
      );
      final full = List.generate(13, (i) => i + 1);
      expect(validator.isValidMeld(_run(TileColor.yellow, full)), isTrue);
    });

    test('rejects wrap, short, gapped and mixed-color runs', () {
      expect(validator.isValidMeld(_run(TileColor.red, [12, 13, 1])), isFalse);
      expect(validator.isValidMeld(_run(TileColor.red, [13, 1, 2])), isFalse);
      expect(validator.isValidMeld(_run(TileColor.red, [4, 5])), isFalse);
      expect(validator.isValidMeld(_run(TileColor.red, [4, 6, 7])), isFalse);
      final mixed = SolvedMeld(
        kind: MeldKind.run,
        spots: [
          _spot(TileColor.red, 4),
          _spot(TileColor.black, 5),
          _spot(TileColor.red, 6),
        ],
        points: 0,
      );
      expect(validator.isValidMeld(mixed), isFalse);
    });
  });

  group('MeldValidator sets', () {
    test('accepts 3- and 4-color sets', () {
      expect(
        validator.isValidMeld(
          _set(5, [TileColor.black, TileColor.yellow, TileColor.blue]),
        ),
        isTrue,
      );
      expect(
        validator.isValidMeld(_set(13, TileColor.values.sublist(0, 4))),
        isTrue,
      );
    });

    test('rejects duplicate colors, wrong sizes, mixed numbers', () {
      expect(
        validator.isValidMeld(
          _set(5, [TileColor.red, TileColor.red, TileColor.blue]),
        ),
        isFalse,
      );
      expect(
        validator.isValidMeld(_set(5, [TileColor.red, TileColor.blue])),
        isFalse,
      );
      final mixed = SolvedMeld(
        kind: MeldKind.set,
        spots: [
          _spot(TileColor.red, 5),
          _spot(TileColor.black, 5),
          _spot(TileColor.blue, 6),
        ],
        points: 0,
      );
      expect(validator.isValidMeld(mixed), isFalse);
    });

    test('judges playsAs, not physical (wild substitution)', () {
      const wild = SolvedSpot.wild(
        physical: GameTile(color: TileColor.joker),
        rackIndex: 3,
        playsAs: GameTile(color: TileColor.yellow, number: 5),
      );
      final meld = SolvedMeld(
        kind: MeldKind.set,
        spots: [_spot(TileColor.red, 5), _spot(TileColor.black, 5), wild],
        points: 0,
      );
      expect(validator.isValidMeld(meld), isTrue);
    });
  });

  group('MeldValidator pairs', () {
    test('accepts identical identities, rejects mismatches', () {
      const identity = GameTile(color: TileColor.red, number: 9);
      final ok = SolvedPair(
        identity: identity,
        first: _spot(TileColor.red, 9),
        second: _spot(TileColor.red, 9),
      );
      expect(validator.isValidPair(ok), isTrue);
      final bad = SolvedPair(
        identity: identity,
        first: _spot(TileColor.red, 9),
        second: _spot(TileColor.red, 8),
      );
      expect(validator.isValidPair(bad), isFalse);
    });
  });
}
