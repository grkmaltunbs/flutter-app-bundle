import 'package:checks/checks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:okey_acar_mi/core/game/tile_color.dart';
import 'package:okey_acar_mi/features/detection/domain/entities/detected_tile.dart';
import 'package:okey_acar_mi/features/detection/domain/entities/detection_result.dart';
import 'package:okey_acar_mi/features/review/domain/entities/review_tile.dart';
import 'package:okey_acar_mi/features/review/domain/seed_review_tiles.dart';

DetectedTile _tile({
  required TileColor color,
  required int slot,
  int? number,
  double confidence = 0.9,
}) {
  return DetectedTile(
    color: color,
    number: number,
    position: TilePosition(row: 0, index: slot),
    confidence: confidence,
  );
}

DetectionResult _result(List<DetectedTile> tiles) {
  return DetectionResult(
    tiles: tiles,
    overallConfidence: 0.9,
    sourceImagePath: 'fixture.jpg',
    frameCount: 1,
    detectedAt: DateTime(2026, 6, 11),
  );
}

void main() {
  group('seedReviewTiles', () {
    test('preserves rack order and tile identities', () {
      final tiles = seedReviewTiles(
        _result([
          _tile(color: TileColor.red, number: 7, slot: 0),
          _tile(color: TileColor.black, number: 13, slot: 1),
          _tile(color: TileColor.blue, number: 1, slot: 2),
        ]),
      );

      check(tiles).deepEquals(const [
        ReviewTile(color: TileColor.red, number: 7),
        ReviewTile(color: TileColor.black, number: 13),
        ReviewTile(color: TileColor.blue, number: 1),
      ]);
    });

    test('flags strictly below 0.75; exactly 0.75 is NOT flagged', () {
      final tiles = seedReviewTiles(
        _result([
          _tile(color: TileColor.red, number: 7, slot: 0, confidence: 0.74),
          _tile(color: TileColor.black, number: 3, slot: 1, confidence: 0.75),
          _tile(color: TileColor.blue, number: 9, slot: 2, confidence: 0.76),
        ]),
      );

      check(tiles[0].lowConfidence).isTrue();
      check(tiles[1].lowConfidence).isFalse();
      check(tiles[2].lowConfidence).isFalse();
    });

    test('maps joker candidates to (joker, null), complete', () {
      final tiles = seedReviewTiles(
        _result([_tile(color: TileColor.joker, slot: 0)]),
      );

      check(tiles.single.color).equals(TileColor.joker);
      check(tiles.single.number).isNull();
      check(tiles.single.isComplete).isTrue();
    });
  });

  group('ReviewTile completeness', () {
    test('undefined placeholder is incomplete', () {
      check(const ReviewTile().isComplete).isFalse();
    });

    test('a real color without a number is incomplete', () {
      check(
        const ReviewTile(color: TileColor.red).isComplete,
      ).isFalse();
    });

    test('a numbered tile is complete and converts to a GameTile', () {
      const tile = ReviewTile(color: TileColor.red, number: 7);
      check(tile.isComplete).isTrue();
      check(tile.asGameTile.color).equals(TileColor.red);
      check(tile.asGameTile.number).equals(7);
    });
  });
}
