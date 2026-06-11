import 'package:checks/checks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:okey_acar_mi/features/detection/data/services/opencv_rack_segmenter.dart';

/// Paints a synthetic rack photo: bright rounded tiles in two rows on a dark
/// felt background — the geometry the prod pipeline assumes (2-row rack,
/// tiles brighter than the table).
img.Image _syntheticRack({
  required int topRowTiles,
  required int bottomRowTiles,
  int width = 1280,
  int height = 720,
}) {
  final image = img.Image(width: width, height: height)
    ..clear(img.ColorRgb8(28, 52, 38)); // Dark green felt.

  const tileWidth = 80;
  const tileHeight = 112;
  const gap = 14;
  final bright = img.ColorRgb8(236, 230, 214); // Ivory tile face.

  void paintRow(int count, int top) {
    final rowWidth = count * tileWidth + (count - 1) * gap;
    final left0 = (width - rowWidth) ~/ 2;
    for (var i = 0; i < count; i++) {
      final left = left0 + i * (tileWidth + gap);
      img.fillRect(
        image,
        x1: left,
        y1: top,
        x2: left + tileWidth - 1,
        y2: top + tileHeight - 1,
        color: bright,
        radius: 10,
      );
    }
  }

  paintRow(topRowTiles, 140);
  paintRow(bottomRowTiles, 420);
  return image;
}

void main() {
  const segmenter = OpenCvRackSegmenter();

  group('OpenCvRackSegmenter', () {
    test('finds every tile of an 11 + 10 rack, split into two bands', () {
      final image = _syntheticRack(topRowTiles: 11, bottomRowTiles: 10);

      final boxes = segmenter.segment(image);

      check(boxes.length).equals(21);
      // The rows were painted around y=140..252 and y=420..532 of 720: the
      // image midline cleanly separates the two bands.
      final topBand = boxes.where((b) => b.top + b.height / 2 < 0.5);
      final bottomBand = boxes.where((b) => b.top + b.height / 2 >= 0.5);
      check(topBand.length).equals(11);
      check(bottomBand.length).equals(10);
    });

    test('emits normalized, plausibly tile-sized bounds', () {
      final image = _syntheticRack(topRowTiles: 10, bottomRowTiles: 10);

      final boxes = segmenter.segment(image);

      check(boxes).isNotEmpty();
      for (final box in boxes) {
        check(box.left).isGreaterOrEqual(0);
        check(box.top).isGreaterOrEqual(0);
        check(box.left + box.width).isLessOrEqual(1);
        check(box.top + box.height).isLessOrEqual(1);
        // Painted tiles are 80/1280 wide and 112/720 tall; allow threshold
        // and morphology slack of a few sampled pixels either way.
        check(box.width).isCloseTo(80 / 1280, 0.02);
        check(box.height).isCloseTo(112 / 720, 0.04);
      }
    });

    test('an all-dark image yields no boxes', () {
      final image = img.Image(width: 640, height: 480)
        ..clear(img.ColorRgb8(22, 24, 20));

      check(segmenter.segment(image)).isEmpty();
    });

    test('a tiny image yields no boxes and does not crash', () {
      final image = img.Image(width: 10, height: 10)
        ..clear(img.ColorRgb8(236, 230, 214));

      check(segmenter.segment(image)).isEmpty();
    });

    test('boxes feed RackGeometry-compatible coordinates '
        '(top row above bottom row)', () {
      final image = _syntheticRack(topRowTiles: 7, bottomRowTiles: 7);

      final boxes = segmenter.segment(image);

      check(boxes.length).equals(14);
      final centers = boxes.map((b) => b.top + b.height / 2).toList()..sort();
      // Two tight clusters: the 7th and 8th sorted centers straddle the gap.
      check(centers[7] - centers[6]).isGreaterThan(0.2);
      check(centers[6] - centers[0]).isLessThan(0.05);
      check(centers[13] - centers[7]).isLessThan(0.05);
    });
  });
}
