import 'package:okey_acar_mi/core/game/tile_color.dart';
import 'package:okey_acar_mi/features/detection/domain/entities/detected_tile.dart';
import 'package:okey_acar_mi/features/detection/domain/entities/detection_result.dart';
import 'package:okey_acar_mi/features/review/domain/entities/review_tile.dart';

/// Maps a finished [DetectionResult] to the editable review rack.
///
/// Preserves rack order, flags tiles whose confidence is **strictly below**
/// [kLowConfidenceThreshold] (exactly 0.75 is not flagged), and maps joker
/// candidates to `(joker, null)`.
List<ReviewTile> seedReviewTiles(DetectionResult result) {
  return List.unmodifiable([
    for (final tile in result.tiles)
      ReviewTile(
        color: tile.color,
        number: tile.color == TileColor.joker ? null : tile.number,
        lowConfidence: tile.confidence < kLowConfidenceThreshold,
      ),
  ]);
}
