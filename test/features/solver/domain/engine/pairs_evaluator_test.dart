import 'package:flutter_test/flutter_test.dart';
import 'package:okey_acar_mi/core/game/game_tile.dart';
import 'package:okey_acar_mi/core/game/indicator.dart';
import 'package:okey_acar_mi/core/game/tile_color.dart';
import 'package:okey_acar_mi/features/solver/domain/engine/meld_validator.dart';
import 'package:okey_acar_mi/features/solver/domain/engine/pairs_evaluator.dart';
import 'package:okey_acar_mi/features/solver/domain/engine/rack_normalizer.dart';
import 'package:okey_acar_mi/features/solver/domain/entities/solved_spot.dart';

GameTile _t(TileColor c, int n) => GameTile(color: c, number: n);
const _joker = GameTile(color: TileColor.joker);
const _indicator = Indicator(color: TileColor.black, number: 1);

void main() {
  const normalizer = RackNormalizer();
  const evaluator = PairsEvaluator();
  const validator = MeldValidator();

  group('evaluateFivePairs', () {
    test('counts natural pairs, wild-completed singles and wild+wild', () {
      // 3 natural pairs + 2 singles + 3 wilds (okey = Black 2).
      final tiles = <GameTile>[
        _t(TileColor.red, 5),
        _t(TileColor.red, 5),
        _t(TileColor.blue, 9),
        _t(TileColor.blue, 9),
        _t(TileColor.yellow, 13),
        _t(TileColor.yellow, 13),
        _t(TileColor.red, 1),
        _t(TileColor.black, 7),
        _joker,
        _joker,
        _t(TileColor.black, 2),
      ];
      final rack = normalizer.normalize(tiles, _indicator);
      final eval = evaluator.evaluateFivePairs(rack);
      // P=3, s=2, W=3 → 3 + min(3,2) + ⌊1/2⌋ = 5.
      expect(eval.pairCount, 5);
      expect(eval.pairs, hasLength(5));
      for (final pair in eval.pairs) {
        expect(validator.isValidPair(pair), isTrue);
      }
      expect(eval.usedRackIndices, hasLength(10));
    });

    test('two leftover wilds pair as the okey identity', () {
      final rack = normalizer.normalize([_joker, _joker], _indicator);
      final eval = evaluator.evaluateFivePairs(rack);
      expect(eval.pairCount, 1);
      expect(eval.pairs.single.identity, _t(TileColor.black, 2));
      expect(eval.pairs.single.first, isA<WildSpot>());
    });

    test('empty rack yields zero pairs', () {
      final rack = normalizer.normalize(const [], _indicator);
      final eval = evaluator.evaluateFivePairs(rack);
      expect(eval.pairCount, 0);
      expect(eval.pairs, isEmpty);
    });
  });

  group('evaluateSevenPairs', () {
    test('prefers real pairs, then supplied singles, then phantoms', () {
      final tiles = <GameTile>[
        _t(TileColor.red, 5), _t(TileColor.red, 5),
        _t(TileColor.blue, 9), _t(TileColor.blue, 9),
        _t(TileColor.yellow, 3), // single, budget 1 → phantom partner
        _t(TileColor.black, 7), _t(TileColor.black, 7), _t(TileColor.black, 7),
      ];
      final rack = normalizer.normalize(tiles, _indicator);
      final plan = evaluator.evaluateSevenPairs(rack);
      expect(plan.pairs, hasLength(7));
      // 3 real pairs (4,7,7 black… red, blue, black) = 6 matched;
      // Y3 single + phantom = 1; B7 leftover single has budget 0 → skipped.
      expect(plan.matched, 7);
      final neededCells = plan.pairs
          .expand((p) => [p.first, p.second])
          .whereType<NeededSpot>()
          .length;
      expect(neededCells, 7);
      for (final pair in plan.pairs) {
        expect(validator.isValidPair(pair), isTrue);
      }
    });

    test('empty rack fills 7 phantom pairs without crashing', () {
      final rack = normalizer.normalize(const [], _indicator);
      final plan = evaluator.evaluateSevenPairs(rack);
      expect(plan.matched, 0);
      expect(plan.pairs, hasLength(7));
      expect(plan.usedRackIndices, isEmpty);
    });

    test('seven real pairs match 14', () {
      final tiles = <GameTile>[
        for (var n = 1; n <= 7; n++) ...[
          _t(TileColor.red, n),
          _t(TileColor.red, n),
        ],
      ];
      final rack = normalizer.normalize(tiles, _indicator);
      final plan = evaluator.evaluateSevenPairs(rack);
      expect(plan.matched, 14);
      expect(plan.usedRackIndices, hasLength(14));
    });
  });
}
