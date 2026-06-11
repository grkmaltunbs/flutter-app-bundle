import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:okey_acar_mi/features/detection/domain/entities/detected_tile.dart';

part 'detection_result.freezed.dart';

/// The finished output of a detection run — the payload handed to the
/// `/review` route (Step 6 consumes it).
@freezed
sealed class DetectionResult with _$DetectionResult {
  /// Creates a [DetectionResult].
  const factory DetectionResult({
    /// All detected tiles in rack order: row 0 left→right, then row 1.
    required List<DetectedTile> tiles,

    /// Mean per-tile confidence; low values drive the "consider retaking"
    /// banner on review.
    required double overallConfidence,

    /// The representative captured image (the still, or a video burst's
    /// first frame) shown behind the bounding-box overlay.
    required String sourceImagePath,

    /// How many frames produced [tiles]: 1 = still; >1 = video aggregation.
    required int frameCount,

    /// When detection finished — stamped via the injected `Clock`, never a
    /// raw `DateTime.now()`.
    required DateTime detectedAt,
  }) = _DetectionResult;
}
