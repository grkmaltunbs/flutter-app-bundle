import 'package:okey_acar_mi/core/game/tile_color.dart';
import 'package:okey_acar_mi/features/detection/domain/entities/detected_tile.dart';

/// One seeded tile spec: color, numeral (null = joker candidate), confidence.
typedef _Spec = (TileColor, int?, double);

/// Deterministic seeded rack readings for the demo flavor.
///
/// Every rack is **legal** per PRODUCT_SPEC → Domain rules: numerals 1–13 in
/// the four tile colors with at most two copies of any number/color pair,
/// plus unnumbered joker candidates. Bounds are fabricated in two parallel
/// rows so the analyzing overlay and `RackGeometry` consumers see realistic
/// 2-row geometry.
abstract final class SeededDetections {
  /// The 21-tile 101-mode rack (11 + 10): one joker candidate and two
  /// low-confidence tiles (yellow 5 @ 0.58, blue 1 @ 0.62).
  static List<DetectedTile> rack101() => _rack(const [
    [
      (TileColor.red, 1, 0.93),
      (TileColor.red, 2, 0.95),
      (TileColor.red, 3, 0.91),
      (TileColor.blue, 7, 0.94),
      (TileColor.blue, 8, 0.9),
      (TileColor.blue, 9, 0.92),
      (TileColor.black, 10, 0.9),
      (TileColor.black, 11, 0.93),
      (TileColor.black, 12, 0.95),
      (TileColor.yellow, 5, 0.58),
      (TileColor.yellow, 5, 0.9),
    ],
    [
      (TileColor.joker, null, 0.82),
      (TileColor.yellow, 11, 0.9),
      (TileColor.yellow, 12, 0.94),
      (TileColor.yellow, 13, 0.91),
      (TileColor.blue, 1, 0.62),
      (TileColor.blue, 1, 0.9),
      (TileColor.red, 4, 0.93),
      (TileColor.blue, 4, 0.9),
      (TileColor.black, 4, 0.95),
      (TileColor.red, 9, 0.88),
    ],
  ]);

  /// The 14-tile Okey-mode rack (7 + 7) with one low-confidence tile
  /// (black 8 @ 0.66).
  static List<DetectedTile> rackOkey() => _rack(const [
    [
      (TileColor.red, 5, 0.92),
      (TileColor.red, 6, 0.9),
      (TileColor.red, 7, 0.94),
      (TileColor.black, 1, 0.91),
      (TileColor.black, 2, 0.9),
      (TileColor.black, 3, 0.93),
      (TileColor.blue, 10, 0.9),
    ],
    [
      (TileColor.blue, 11, 0.92),
      (TileColor.blue, 12, 0.9),
      (TileColor.blue, 13, 0.94),
      (TileColor.yellow, 4, 0.91),
      (TileColor.yellow, 4, 0.9),
      (TileColor.black, 8, 0.66),
      (TileColor.red, 13, 0.9),
    ],
  ]);

  /// A 19-tile reading (10 + 9): valid for neither game mode, so Step 6's
  /// review screen can exercise its wrong-count warning.
  static List<DetectedTile> rackWrongCount() => _rack(const [
    [
      (TileColor.red, 1, 0.93),
      (TileColor.red, 2, 0.95),
      (TileColor.red, 3, 0.91),
      (TileColor.blue, 7, 0.94),
      (TileColor.blue, 8, 0.9),
      (TileColor.blue, 9, 0.92),
      (TileColor.black, 10, 0.9),
      (TileColor.black, 11, 0.93),
      (TileColor.black, 12, 0.95),
      (TileColor.yellow, 5, 0.58),
    ],
    [
      (TileColor.joker, null, 0.82),
      (TileColor.yellow, 11, 0.9),
      (TileColor.yellow, 12, 0.94),
      (TileColor.yellow, 13, 0.91),
      (TileColor.blue, 1, 0.62),
      (TileColor.blue, 1, 0.9),
      (TileColor.red, 4, 0.93),
      (TileColor.blue, 4, 0.9),
      (TileColor.black, 4, 0.95),
    ],
  ]);

  /// The 21-tile rack re-read under poor conditions: ten tiles fall under
  /// the low-confidence threshold (the eight remapped below, plus the 0.88
  /// damping dragging the joker and the second blue 1 under it) and the mean
  /// lands below it too, driving the "consider retaking" review path.
  static List<DetectedTile> lowConfidenceRack() {
    // Rack-order indices remapped to sub-threshold confidences.
    const lows = <int, double>{
      0: 0.52,
      3: 0.61,
      5: 0.68,
      9: 0.5,
      12: 0.66,
      14: 0.55,
      17: 0.63,
      19: 0.7,
    };
    final tiles = rack101();
    return List.unmodifiable([
      for (var i = 0; i < tiles.length; i++)
        tiles[i].copyWith(
          confidence: lows[i] ?? (tiles[i].confidence * 0.88),
        ),
    ]);
  }

  /// Three per-frame readings of [rack101] with disagreements at exactly two
  /// positions — row 0 index 3 (blue 7 misread as red 7 in frame 2) and
  /// row 1 index 9 (red 9 misread as red 6 in frame 3). Run through the
  /// shared `FrameAggregator`, those two positions land below the
  /// low-confidence threshold (2/3 agreement).
  static List<List<DetectedTile>> frameReadings() {
    final frame1 = rack101();
    final frame2 = [
      for (final tile in rack101())
        if (tile.position == const TilePosition(row: 0, index: 3))
          tile.copyWith(color: TileColor.red)
        else
          tile,
    ];
    final frame3 = [
      for (final tile in rack101())
        if (tile.position == const TilePosition(row: 1, index: 9))
          tile.copyWith(number: 6)
        else
          tile,
    ];
    return [frame1, frame2, frame3];
  }

  /// Builds a rack from per-row specs, fabricating 2-row normalized bounds.
  static List<DetectedTile> _rack(List<List<_Spec>> rows) {
    const rowTops = [0.12, 0.54];
    const rowHeight = 0.34;
    final tiles = <DetectedTile>[];
    for (var row = 0; row < rows.length; row++) {
      final specs = rows[row];
      final slotWidth = 0.94 / specs.length;
      for (var index = 0; index < specs.length; index++) {
        final (color, number, confidence) = specs[index];
        tiles.add(
          DetectedTile(
            color: color,
            number: number,
            confidence: confidence,
            position: TilePosition(row: row, index: index),
            bounds: NormalizedRect(
              left: 0.03 + index * slotWidth,
              top: rowTops[row],
              width: slotWidth * 0.86,
              height: rowHeight,
            ),
          ),
        );
      }
    }
    return List.unmodifiable(tiles);
  }
}
