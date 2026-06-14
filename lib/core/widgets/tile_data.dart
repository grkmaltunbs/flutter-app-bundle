import 'package:flutter/foundation.dart';
import 'package:okey_acar_mi/core/widgets/tile.dart';

/// Immutable description of a single tile for use by the rack and meld widgets.
///
/// A joker carries [TileColor.joker] and a null [number]. [lowConfidence]
/// flags a detection the user should review (rendered with a warn ring). A
/// [faceDown] tile is a wild (joker color) that renders as a blank back rather
/// than the joker glyph.
@immutable
class TileData {
  /// Creates a [TileData].
  const TileData({
    required this.color,
    this.number,
    this.lowConfidence = false,
    this.faceDown = false,
  });

  /// The tile numeral, or null for a joker.
  final int? number;

  /// The tile color (one of the four, or joker).
  final TileColor color;

  /// Whether detection confidence for this tile was low (review prompt).
  final bool lowConfidence;

  /// Whether this is a blank face-down (okey) tile — rendered as a blank back.
  final bool faceDown;

  @override
  bool operator ==(Object other) =>
      other is TileData &&
      other.number == number &&
      other.color == color &&
      other.lowConfidence == lowConfidence &&
      other.faceDown == faceDown;

  @override
  int get hashCode => Object.hash(number, color, lowConfidence, faceDown);
}
