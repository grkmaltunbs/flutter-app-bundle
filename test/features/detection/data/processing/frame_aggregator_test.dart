import 'package:checks/checks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:okey_acar_mi/core/game/tile_color.dart';
import 'package:okey_acar_mi/features/detection/data/fakes/seeded_detections.dart';
import 'package:okey_acar_mi/features/detection/data/processing/frame_aggregator.dart';
import 'package:okey_acar_mi/features/detection/domain/entities/detected_tile.dart';

DetectedTile _tile({
  required int row,
  required int index,
  TileColor color = TileColor.red,
  int? number = 5,
  double confidence = 0.9,
}) => DetectedTile(
  color: color,
  number: number,
  confidence: confidence,
  position: TilePosition(row: row, index: index),
);

void main() {
  group('FrameAggregator.aggregate', () {
    test('no frames → empty', () {
      check(FrameAggregator.aggregate(const [])).isEmpty();
    });

    test('a single frame passes through untouched', () {
      final frame = [_tile(row: 0, index: 0), _tile(row: 1, index: 0)];

      check(FrameAggregator.aggregate([frame])).deepEquals(frame);
    });

    test('full agreement keeps the reading at its mean confidence', () {
      final frames = [
        [_tile(row: 0, index: 0, confidence: 0.92)],
        [_tile(row: 0, index: 0, confidence: 0.8)],
        [_tile(row: 0, index: 0, confidence: 0.83)],
      ];

      final aggregated = FrameAggregator.aggregate(frames);

      check(aggregated.length).equals(1);
      check(aggregated.single.color).equals(TileColor.red);
      check(aggregated.single.number).equals(5);
      check(aggregated.single.confidence).isCloseTo(0.85, 0.0001);
      check(
        aggregated.single.confidence,
      ).isGreaterOrEqual(kLowConfidenceThreshold);
    });

    test('a 2/3 disagreement pulls the position into low confidence', () {
      final frames = [
        [_tile(row: 0, index: 0, color: TileColor.blue, number: 7)],
        [_tile(row: 0, index: 0, number: 7)], // red — the default color
        [_tile(row: 0, index: 0, color: TileColor.blue, number: 7)],
      ];

      final aggregated = FrameAggregator.aggregate(frames);

      // Majority identity wins…
      check(aggregated.single.color).equals(TileColor.blue);
      check(aggregated.single.number).equals(7);
      // …at agreement (2/3) × mean confidence (0.9) — under the 0.75 flag.
      check(aggregated.single.confidence).isCloseTo(2 / 3 * 0.9, 0.0001);
      check(aggregated.single.confidence).isLessThan(kLowConfidenceThreshold);
    });

    test('an identity tie breaks toward the higher summed confidence', () {
      final frames = [
        [_tile(row: 0, index: 0, confidence: 0.6)], // red — the default
        [_tile(row: 0, index: 0, color: TileColor.blue, confidence: 0.95)],
      ];

      final aggregated = FrameAggregator.aggregate(frames);

      check(aggregated.single.color).equals(TileColor.blue);
      // agreement 1/2 × winner mean 0.95.
      check(aggregated.single.confidence).isCloseTo(0.475, 0.0001);
    });

    test('positions present in at most half the frames are dropped as '
        'transient mis-segmentations', () {
      final stable = _tile(row: 0, index: 0);
      final transient = _tile(row: 1, index: 5, color: TileColor.yellow);
      final frames = [
        [stable, transient],
        [stable],
        [stable],
      ];

      final aggregated = FrameAggregator.aggregate(frames);

      check(aggregated.length).equals(1);
      check(
        aggregated.single.position,
      ).equals(const TilePosition(row: 0, index: 0));
    });

    test('a position present in 2 of 3 frames survives', () {
      final stable = _tile(row: 0, index: 0);
      final flickering = _tile(row: 0, index: 1, color: TileColor.black);
      final frames = [
        [stable, flickering],
        [stable, flickering],
        [stable],
      ];

      final aggregated = FrameAggregator.aggregate(frames);

      check(aggregated.length).equals(2);
    });

    test('output is in rack order: row 0 left-to-right, then row 1', () {
      final frame = [
        _tile(row: 1, index: 1),
        _tile(row: 0, index: 1),
        _tile(row: 1, index: 0),
        _tile(row: 0, index: 0),
      ];

      final aggregated = FrameAggregator.aggregate([frame, frame]);

      check(aggregated.map((t) => t.position).toList()).deepEquals(const [
        TilePosition(row: 0, index: 0),
        TilePosition(row: 0, index: 1),
        TilePosition(row: 1, index: 0),
        TilePosition(row: 1, index: 1),
      ]);
    });

    test('the seeded frame readings disagree at exactly the two documented '
        'positions, which land low-confidence', () {
      final aggregated = FrameAggregator.aggregate(
        SeededDetections.frameReadings(),
      );

      check(aggregated.length).equals(21);

      DetectedTile at(int row, int index) => aggregated.singleWhere(
        (t) => t.position == TilePosition(row: row, index: index),
      );

      // Row 0 index 3: blue 7 misread as red in one frame → majority blue 7.
      check(at(0, 3).color).equals(TileColor.blue);
      check(at(0, 3).number).equals(7);
      check(at(0, 3).confidence).isLessThan(kLowConfidenceThreshold);
      // Row 1 index 9: red 9 misread as red 6 in one frame → majority red 9.
      check(at(1, 9).color).equals(TileColor.red);
      check(at(1, 9).number).equals(9);
      check(at(1, 9).confidence).isLessThan(kLowConfidenceThreshold);

      // Every other position keeps its full-agreement seeded confidence.
      final reference = {
        for (final tile in SeededDetections.rack101()) tile.position: tile,
      };
      for (final tile in aggregated) {
        if (tile.position == const TilePosition(row: 0, index: 3) ||
            tile.position == const TilePosition(row: 1, index: 9)) {
          continue;
        }
        check(
          because: 'position ${tile.position} must keep its seed',
          tile.confidence,
        ).isCloseTo(reference[tile.position]!.confidence, 0.0001);
      }
    });
  });
}
