import 'package:okey_acar_mi/features/detection/domain/entities/detected_tile.dart';

/// A plugin-agnostic recognized text fragment (one ML Kit `TextElement`,
/// with its box normalized to the source image). Pure Dart so the parser is
/// unit-testable without the ML Kit plugin.
class RecognizedTextElement {
  /// Creates a [RecognizedTextElement].
  const RecognizedTextElement({required this.text, required this.bounds});

  /// The raw recognized text.
  final String text;

  /// The element's box, normalized to the source image.
  final NormalizedRect bounds;
}

/// A numeral verdict for one tile cell.
class NumeralReading {
  /// Creates a [NumeralReading].
  const NumeralReading({required this.number, required this.confidence});

  /// No text matched the cell at all: the tile is a **joker candidate**.
  static const NumeralReading none = NumeralReading(
    number: null,
    confidence: 0,
  );

  /// The parsed numeral (1–13), or null when the cell held no text.
  final int? number;

  /// Certainty of the parse in `0..1`. ML Kit's own `TextElement.confidence`
  /// is deliberately ignored (often null on iOS); certainty comes from how
  /// much correction the raw text needed.
  final double confidence;
}

/// Matches recognized text elements to tile cells and parses Okey numerals
/// (1–13), absorbing the common OCR confusions ("ll" → 11, "O" → 0, …).
abstract final class NumeralParser {
  /// A cell is inflated by this fraction on every side when matching
  /// elements, since OCR boxes regularly bleed past the glyph.
  static const double _cellInflation = 0.2;

  /// Certainty for a clean digit-only parse.
  static const double _cleanConfidence = 0.95;

  /// Certainty after confusion-map substitutions.
  static const double _correctedConfidence = 0.7;

  /// Certainty after aggressive truncation of an out-of-range parse.
  static const double _salvagedConfidence = 0.2;

  /// Certainty of the blind best guess for unreadable-but-present text.
  static const double _guessConfidence = 0.05;

  /// Single-character OCR confusions mapped to digits.
  static const Map<String, String> _confusions = {
    'l': '1',
    'I': '1',
    '|': '1',
    '!': '1',
    'i': '1',
    'j': '1',
    'O': '0',
    'o': '0',
    'D': '0',
    'Q': '0',
    'S': '5',
    's': '5',
    'B': '8',
    'Z': '2',
    'z': '2',
    'g': '9',
    'q': '9',
    'G': '6',
    'b': '6',
    'T': '7',
    'A': '4',
  };

  /// Reads the numeral for [cell] from [elements].
  ///
  /// Returns [NumeralReading.none] when no element's center falls inside the
  /// (inflated) cell — the tile is a joker candidate. Unreadable text never
  /// yields a null number: it degrades to a best guess at [_guessConfidence],
  /// honoring the [DetectedTile] invariant.
  static NumeralReading readCell(
    NormalizedRect cell,
    List<RecognizedTextElement> elements,
  ) {
    final element = _matchElement(cell, elements);
    if (element == null) return NumeralReading.none;
    return _parse(element.text);
  }

  /// The matched element is the one whose center sits inside the inflated
  /// cell, closest to the cell's center (numerals sit mid-tile).
  static RecognizedTextElement? _matchElement(
    NormalizedRect cell,
    List<RecognizedTextElement> elements,
  ) {
    final inflateX = cell.width * _cellInflation;
    final inflateY = cell.height * _cellInflation;
    final left = cell.left - inflateX;
    final right = cell.left + cell.width + inflateX;
    final top = cell.top - inflateY;
    final bottom = cell.top + cell.height + inflateY;
    final cellCenterX = cell.left + cell.width / 2;
    final cellCenterY = cell.top + cell.height / 2;

    RecognizedTextElement? best;
    var bestDistance = double.infinity;
    for (final element in elements) {
      final centerX = element.bounds.left + element.bounds.width / 2;
      final centerY = element.bounds.top + element.bounds.height / 2;
      final inside =
          centerX >= left &&
          centerX <= right &&
          centerY >= top &&
          centerY <= bottom;
      if (!inside) continue;
      final dx = centerX - cellCenterX;
      final dy = centerY - cellCenterY;
      final distance = dx * dx + dy * dy;
      if (distance < bestDistance) {
        bestDistance = distance;
        best = element;
      }
    }
    return best;
  }

  static NumeralReading _parse(String raw) {
    final text = raw.trim();

    // Clean parse first.
    final direct = int.tryParse(text);
    if (direct != null && _inRange(direct)) {
      return NumeralReading(number: direct, confidence: _cleanConfidence);
    }

    // Confusion-mapped parse ("ll" → "11", "lO" → "10", …).
    final corrected = text.split('').map((c) => _confusions[c] ?? c).join();
    final mapped = int.tryParse(corrected);
    if (mapped != null && _inRange(mapped)) {
      return NumeralReading(number: mapped, confidence: _correctedConfidence);
    }

    // Salvage an out-of-range digit string by truncating ("121" → 12 → ok).
    final digits = corrected.replaceAll(RegExp('[^0-9]'), '');
    if (digits.isNotEmpty) {
      final two = digits.length >= 2 ? int.parse(digits.substring(0, 2)) : null;
      if (two != null && _inRange(two)) {
        return NumeralReading(number: two, confidence: _salvagedConfidence);
      }
      final one = int.parse(digits.substring(0, 1));
      if (_inRange(one)) {
        return NumeralReading(number: one, confidence: _salvagedConfidence);
      }
    }

    // Unreadable: blind best guess, never a null number with a real color.
    return const NumeralReading(number: 1, confidence: _guessConfidence);
  }

  static bool _inRange(int n) => n >= 1 && n <= 13;
}
