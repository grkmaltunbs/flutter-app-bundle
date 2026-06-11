import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:okey_acar_mi/core/error/failure.dart';
import 'package:okey_acar_mi/features/detection/domain/entities/detected_tile.dart';
import 'package:okey_acar_mi/features/detection/domain/entities/detection_result.dart';
import 'package:okey_acar_mi/features/detection/domain/entities/detection_stage.dart';

part 'detection_update.freezed.dart';

/// The streamed protocol of a detection run.
///
/// A well-formed run emits any number of [DetectionUpdate.stage] /
/// [DetectionUpdate.tile] updates and ends with exactly one terminal update:
/// [DetectionUpdate.completed] or [DetectionUpdate.failed]. Cancellation
/// (the listener unsubscribing) ends the stream without a terminal update.
@freezed
sealed class DetectionUpdate with _$DetectionUpdate {
  /// The pipeline entered [stage]. [totalTiles] is attached once the rack has
  /// been located (the tile count drives the determinate progress bar).
  const factory DetectionUpdate.stage(
    DetectionStage stage, {
    int? totalTiles,
  }) = DetectionStageUpdate;

  /// One tile finished reading — drives the progressive rack reveal.
  const factory DetectionUpdate.tile(DetectedTile tile) = DetectionTileUpdate;

  /// Terminal: the run finished with [result].
  const factory DetectionUpdate.completed(DetectionResult result) =
      DetectionCompletedUpdate;

  /// Terminal: the run failed with [failure]. Cancellation is NOT a failure.
  const factory DetectionUpdate.failed(Failure failure) = DetectionFailedUpdate;
}
