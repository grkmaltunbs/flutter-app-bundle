import 'package:checks/checks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:okey_acar_mi/core/game/tile_color.dart';
import 'package:okey_acar_mi/features/detection/data/processing/hsv_classifier.dart';

/// Representative glyph pixels for each of the four tile colors.
const _redPixel = (220, 30, 40);
const _blackPixel = (25, 25, 28);
const _yellowPixel = (235, 190, 30);
const _bluePixel = (30, 80, 200);

/// A bright, unsaturated tile-face pixel (must never vote).
const _facePixel = (245, 243, 240);

void main() {
  group('HsvClassifier.classify', () {
    test('buckets representative samples of the four tile colors', () {
      final cases = <(int, int, int), TileColor>{
        _redPixel: TileColor.red,
        _blackPixel: TileColor.black,
        _yellowPixel: TileColor.yellow,
        _bluePixel: TileColor.blue,
      };

      for (final MapEntry(key: pixel, value: expected) in cases.entries) {
        final verdict = HsvClassifier.classify([pixel, pixel, pixel]);
        check(
          because: '$pixel must classify as $expected',
          verdict.color,
        ).equals(expected);
        check(verdict.confidence).equals(1);
      }
    });

    test('a dark red still reads as red, not black', () {
      // v above the 0.35 black cutoff, strongly red hue.
      final verdict = HsvClassifier.classify(const [(130, 20, 25)]);

      check(verdict.color).equals(TileColor.red);
    });

    test('a wrap-around red hue (magenta-leaning, h >= 330) reads as red', () {
      final verdict = HsvClassifier.classify(const [(210, 25, 95)]);

      check(verdict.color).equals(TileColor.red);
    });

    test('face pixels never vote: an all-face sample degrades to the '
        'near-zero blind guess', () {
      final verdict = HsvClassifier.classify(const [
        _facePixel,
        _facePixel,
        _facePixel,
      ]);

      check(verdict.color).equals(TileColor.black);
      check(verdict.confidence).equals(0.05);
    });

    test('an empty sample degrades to the near-zero blind guess', () {
      final verdict = HsvClassifier.classify(const []);

      check(verdict.color).equals(TileColor.black);
      check(verdict.confidence).equals(0.05);
    });

    test('greens and purples claim no tile color and are skipped', () {
      // Only the lone blue pixel votes, so blue wins with full margin.
      final verdict = HsvClassifier.classify(const [
        (40, 200, 40), // green: h ~ 120, no bucket
        (150, 40, 200), // purple: h ~ 290, no bucket
        _bluePixel,
      ]);

      check(verdict.color).equals(TileColor.blue);
      check(verdict.confidence).equals(1);
    });

    test('confidence is the vote margin between winner and runner-up', () {
      // 3 red vs 1 blue of 4 voting pixels → margin (3 - 1) / 4 = 0.5.
      final verdict = HsvClassifier.classify(const [
        _redPixel,
        _redPixel,
        _redPixel,
        _bluePixel,
      ]);

      check(verdict.color).equals(TileColor.red);
      check(verdict.confidence).isCloseTo(0.5, 0.0001);
    });

    test('an even split lands at zero confidence', () {
      final verdict = HsvClassifier.classify(const [
        _redPixel,
        _redPixel,
        _bluePixel,
        _bluePixel,
      ]);

      check(verdict.confidence).equals(0);
    });

    test('face pixels reduce neither the margin nor the vote total', () {
      // 2 red + 2 face: faces are skipped, so red wins 2/2 → margin 1.0.
      final verdict = HsvClassifier.classify(const [
        _redPixel,
        _redPixel,
        _facePixel,
        _facePixel,
      ]);

      check(verdict.color).equals(TileColor.red);
      check(verdict.confidence).equals(1);
    });

    test('a dim desaturated pixel below the gray cutoff votes black', () {
      // s ~ 0.04 (< 0.25), v ~ 0.41 (in 0.35..0.45) → black.
      final verdict = HsvClassifier.classify(const [(100, 100, 104)]);

      check(verdict.color).equals(TileColor.black);
    });
  });

  group('HsvClassifier.rgbToHsv', () {
    test('converts the primary corners exactly', () {
      check(HsvClassifier.rgbToHsv(255, 0, 0)).equals((0.0, 1.0, 1.0));
      check(HsvClassifier.rgbToHsv(255, 255, 0)).equals((60.0, 1.0, 1.0));
      check(HsvClassifier.rgbToHsv(0, 0, 255)).equals((240.0, 1.0, 1.0));
      check(HsvClassifier.rgbToHsv(0, 0, 0)).equals((0.0, 0.0, 0.0));
      check(HsvClassifier.rgbToHsv(255, 255, 255)).equals((0.0, 0.0, 1.0));
    });

    test('hue stays in 0..360 for blue-of-red mixes (negative-h branch)', () {
      final (h, s, v) = HsvClassifier.rgbToHsv(200, 10, 60);

      check(h).isGreaterOrEqual(0);
      check(h).isLessThan(360);
      check(s).isGreaterThan(0.9);
      check(v).isCloseTo(200 / 255, 0.001);
    });
  });
}
