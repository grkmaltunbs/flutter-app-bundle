import 'package:checks/checks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:okey_acar_mi/features/detection/data/processing/numeral_parser.dart';
import 'package:okey_acar_mi/features/detection/domain/entities/detected_tile.dart';

/// The cell under test: a tile box in the middle of the image.
const _cell = NormalizedRect(left: 0.4, top: 0.4, width: 0.1, height: 0.2);

/// An element whose box is centered on [centerX]/[centerY].
RecognizedTextElement _element(
  String text, {
  double centerX = 0.45,
  double centerY = 0.5,
}) => RecognizedTextElement(
  text: text,
  bounds: NormalizedRect(
    left: centerX - 0.02,
    top: centerY - 0.04,
    width: 0.04,
    height: 0.08,
  ),
);

/// Reads [_cell] against a single centered element of [text].
NumeralReading _read(String text) =>
    NumeralParser.readCell(_cell, [_element(text)]);

void main() {
  group('numeral parsing', () {
    test('parses every clean numeral 1..13 at full certainty', () {
      for (var n = 1; n <= 13; n++) {
        final reading = _read('$n');
        check(because: '"$n" must parse cleanly', reading.number).equals(n);
        check(reading.confidence).equals(0.95);
      }
    });

    test('"0" is out of range and degrades to the blind guess — never a '
        'zero tile', () {
      final reading = _read('0');

      check(reading.number).equals(1);
      check(reading.confidence).equals(0.05);
    });

    test('"14" is out of range and is salvaged by truncation at low '
        'certainty', () {
      final reading = _read('14');

      check(reading.number).equals(1);
      check(reading.confidence).equals(0.2);
    });

    test('"121" salvages its leading two digits ("12")', () {
      final reading = _read('121');

      check(reading.number).equals(12);
      check(reading.confidence).equals(0.2);
    });

    test('common OCR confusions map to digits at corrected certainty', () {
      final cases = <String, int>{
        'll': 11, // double lowercase L → 11
        'lO': 10, // L + capital O → 10
        'I3': 13,
        'B': 8,
        'S': 5,
        'Z': 2,
        'g': 9,
        'T': 7,
        'A': 4,
      };

      for (final MapEntry(key: raw, value: expected) in cases.entries) {
        final reading = _read(raw);
        check(
          because: '"$raw" must correct to $expected',
          reading.number,
        ).equals(expected);
        check(reading.confidence).equals(0.7);
      }
    });

    test('unreadable text degrades to the blind guess — never a null '
        'number for a present element (DetectedTile invariant)', () {
      for (final raw in const ['??', '*', 'xy', '']) {
        final reading = _read(raw);
        check(because: '"$raw" must blind-guess', reading.number).equals(1);
        check(reading.confidence).equals(0.05);
      }
    });

    test('every parse lands in 1..13 across hostile inputs', () {
      for (final raw in const ['0', '14', '99', '00', 'O', 'lll', '!!']) {
        final number = _read(raw).number;
        check(because: '"$raw" must stay in range', number).isNotNull();
        check(number!).isGreaterOrEqual(1);
        check(number).isLessOrEqual(13);
      }
    });
  });

  group('box-to-cell matching', () {
    test('no element near the cell → NumeralReading.none (joker '
        'candidate)', () {
      final reading = NumeralParser.readCell(_cell, [
        _element('7', centerX: 0.1, centerY: 0.1),
      ]);

      check(reading.number).isNull();
      check(reading.confidence).equals(0);
    });

    test('an element inside the inflated cell margin still matches', () {
      // Cell x-range 0.40..0.50 inflates by 0.02 → 0.38..0.52; the element
      // center at 0.39 is outside the raw cell but inside the inflation.
      final reading = NumeralParser.readCell(_cell, [
        _element('7', centerX: 0.39),
      ]);

      check(reading.number).equals(7);
    });

    test('an element just past the inflated margin does not match', () {
      final reading = NumeralParser.readCell(_cell, [
        _element('7', centerX: 0.37),
      ]);

      check(reading.number).isNull();
    });

    test('of two candidates, the one closest to the cell center wins', () {
      // Numerals sit mid-tile: "9" is dead center, "4" hugs the edge.
      final reading = NumeralParser.readCell(_cell, [
        _element('4', centerX: 0.41, centerY: 0.42),
        _element('9'), // dead center (the defaults)
      ]);

      check(reading.number).equals(9);
    });

    test('no elements at all → none', () {
      check(NumeralParser.readCell(_cell, const []).number).isNull();
    });
  });
}
