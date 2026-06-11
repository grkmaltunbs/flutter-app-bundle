import 'package:okey_acar_mi/core/game/tile_color.dart';
import 'package:okey_acar_mi/features/detection/domain/entities/detected_tile.dart';

/// Combines per-frame tile readings of a video burst into one rack reading
/// by majority vote per rack position.
///
/// Shared by the prod pipeline and the demo fake so both environments
/// exercise identical aggregation semantics (PRODUCT_SPEC flow-scan: frames
/// that disagree badly land those positions in low confidence).
abstract final class FrameAggregator {
  /// Aggregates [frames] (each one full rack reading, any order).
  ///
  /// - Positions present in at most half the frames are dropped (transient
  ///   mis-segmentations).
  /// - Per position, the most-voted `(color, number)` wins; ties break by
  ///   summed confidence.
  /// - Confidence = vote agreement × the winners' mean confidence, so any
  ///   disagreement pulls the position toward the low-confidence flag.
  ///
  /// The result is in rack order (row 0 left→right, then row 1).
  static List<DetectedTile> aggregate(List<List<DetectedTile>> frames) {
    if (frames.isEmpty) return const [];
    if (frames.length == 1) return List.unmodifiable(frames.single);

    // Group readings by rack position.
    final byPosition = <TilePosition, List<DetectedTile>>{};
    for (final frame in frames) {
      for (final tile in frame) {
        byPosition.putIfAbsent(tile.position, () => []).add(tile);
      }
    }

    final aggregated = <DetectedTile>[];
    byPosition.forEach((position, readings) {
      // Strict majority presence across frames.
      if (readings.length * 2 <= frames.length) return;

      // Vote on the (color, number) identity.
      final votes = <(TileColor, int?), List<DetectedTile>>{};
      for (final reading in readings) {
        votes
            .putIfAbsent((reading.color, reading.number), () => [])
            .add(reading);
      }
      final ranked = votes.values.toList()
        ..sort((a, b) {
          final byCount = b.length.compareTo(a.length);
          if (byCount != 0) return byCount;
          return _confidenceSum(b).compareTo(_confidenceSum(a));
        });
      final winners = ranked.first;

      final agreement = winners.length / readings.length;
      final meanConfidence = _confidenceSum(winners) / winners.length;
      aggregated.add(
        winners.last.copyWith(
          confidence: (agreement * meanConfidence).clamp(0.0, 1.0),
        ),
      );
    });

    aggregated.sort((a, b) {
      final byRow = a.position.row.compareTo(b.position.row);
      if (byRow != 0) return byRow;
      return a.position.index.compareTo(b.position.index);
    });
    return List.unmodifiable(aggregated);
  }

  static double _confidenceSum(List<DetectedTile> tiles) =>
      tiles.fold(0, (sum, tile) => sum + tile.confidence);
}
