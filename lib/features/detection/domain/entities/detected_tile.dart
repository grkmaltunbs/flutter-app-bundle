import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:okey_acar_mi/core/game/tile_color.dart';

part 'detected_tile.freezed.dart';

/// Confidence below this flags a [DetectedTile] for user review (the warn
/// ring on the rack and the low-confidence handling on the review screen).
const double kLowConfidenceThreshold = 0.75;

/// A tile's slot on the 2-row rack.
@freezed
sealed class TilePosition with _$TilePosition {
  /// Creates a [TilePosition]. [row] is 0 (top) or 1 (bottom); [index] is the
  /// 0-based slot within the row, left to right.
  const factory TilePosition({
    required int row,
    required int index,
  }) = _TilePosition;
}

/// An axis-aligned rectangle normalized to the source image (all components
/// are fractions in `0..1` of the image's width/height).
@freezed
sealed class NormalizedRect with _$NormalizedRect {
  /// Creates a [NormalizedRect].
  const factory NormalizedRect({
    required double left,
    required double top,
    required double width,
    required double height,
  }) = _NormalizedRect;
}

/// One tile as read by the detection pipeline.
///
/// Invariant: a [DetectedTile] is either a **numbered tile** ([number] 1–13,
/// [color] one of the four tile colors) or a **joker candidate**
/// ([color] == [TileColor.joker], [number] == null — no numeral was found in
/// the cell). An *unreadable* numeral never produces a null [number] with a
/// real color: the pipeline emits its best guess with near-zero [confidence]
/// instead, so the review step always has a concrete tile to correct.
@freezed
sealed class DetectedTile with _$DetectedTile {
  /// Creates a [DetectedTile].
  const factory DetectedTile({
    required TileColor color,
    required TilePosition position,
    required double confidence,
    int? number,
    NormalizedRect? bounds,
  }) = _DetectedTile;
}
