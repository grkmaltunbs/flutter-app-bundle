import 'dart:math' as math;

import 'package:okey_acar_mi/core/game/tile_color.dart';

/// A color verdict for one tile's glyph region.
class HsvClassification {
  /// Creates an [HsvClassification].
  const HsvClassification({required this.color, required this.confidence});

  /// The winning tile-color bucket (never [TileColor.joker] — jokers are
  /// decided by the *absence of a numeral*, not by color).
  final TileColor color;

  /// Margin confidence in `0..1`: how decisively the winning bucket beat the
  /// runner-up across the sampled pixels.
  final double confidence;
}

/// Classifies glyph pixels into the four tile-color buckets in HSV space.
///
/// Tile faces are bright and near-neutral; the numeral glyph is saturated
/// (red/yellow/blue) or dark (black). Face pixels are skipped and the
/// remaining pixels vote for a bucket; the verdict's confidence is the vote
/// margin between the winner and the runner-up.
abstract final class HsvClassifier {
  /// Pixels at least this bright and this unsaturated are tile face, not
  /// glyph, and do not vote.
  static const double _faceMaxSaturation = 0.18;
  static const double _faceMinValue = 0.62;

  /// Returned when no pixel voted — a blind best guess, near-zero confidence.
  static const HsvClassification _noEvidence = HsvClassification(
    color: TileColor.black,
    confidence: 0.05,
  );

  /// Classifies [pixels] (RGB components in `0..255`) into a tile color.
  static HsvClassification classify(Iterable<(int, int, int)> pixels) {
    final votes = <TileColor, int>{
      TileColor.red: 0,
      TileColor.black: 0,
      TileColor.yellow: 0,
      TileColor.blue: 0,
    };
    var total = 0;
    for (final (r, g, b) in pixels) {
      final bucket = _bucket(r, g, b);
      if (bucket == null) continue;
      votes[bucket] = votes[bucket]! + 1;
      total++;
    }
    if (total == 0) return _noEvidence;

    final ranked = votes.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final margin = (ranked[0].value - ranked[1].value) / total;
    return HsvClassification(
      color: ranked[0].key,
      confidence: margin.clamp(0.0, 1.0),
    );
  }

  /// Buckets one pixel, or returns null for face/indeterminate pixels.
  static TileColor? _bucket(int r, int g, int b) {
    final (h, s, v) = rgbToHsv(r, g, b);
    if (s < _faceMaxSaturation && v > _faceMinValue) return null; // Face.
    if (v < 0.35) return TileColor.black;
    if (s < 0.25) return v < 0.45 ? TileColor.black : null;
    if (h < 20 || h >= 330) return TileColor.red;
    if (h >= 20 && h < 75) return TileColor.yellow;
    if (h >= 180 && h < 270) return TileColor.blue;
    return null; // Greens/purples: no tile color claims them.
  }

  /// Converts RGB components in `0..255` to HSV (`h` in degrees `0..360`,
  /// `s` and `v` in `0..1`).
  static (double, double, double) rgbToHsv(int r, int g, int b) {
    final rf = r / 255.0;
    final gf = g / 255.0;
    final bf = b / 255.0;
    final maxC = math.max(rf, math.max(gf, bf));
    final minC = math.min(rf, math.min(gf, bf));
    final delta = maxC - minC;

    var h = 0.0;
    if (delta > 0) {
      if (maxC == rf) {
        h = 60 * (((gf - bf) / delta) % 6);
      } else if (maxC == gf) {
        h = 60 * (((bf - rf) / delta) + 2);
      } else {
        h = 60 * (((rf - gf) / delta) + 4);
      }
      if (h < 0) h += 360;
    }
    final s = maxC == 0 ? 0.0 : delta / maxC;
    return (h, s, maxC);
  }
}
