part of 'detection_bloc.dart';

/// Sealed screen state for [DetectionBloc].
@freezed
sealed class DetectionState with _$DetectionState {
  /// Detection in flight: the current [stage], the tiles [revealed] so far
  /// (rack order, unmodifiable), and [totalTiles] once the rack is located.
  const factory DetectionState.processing({
    required DetectionStage stage,
    required List<DetectedTile> revealed,
    int? totalTiles,
  }) = DetectionProcessing;

  /// Terminal: detection finished — the listener navigates to review with
  /// [result].
  const factory DetectionState.success({required DetectionResult result}) =
      DetectionSuccess;

  /// Terminal: detection failed (no tiles, or a pipeline error). Never a
  /// dead-end — the failure view always offers retry/retake escapes.
  const factory DetectionState.failure({required Failure failure}) =
      DetectionFailure;
}
