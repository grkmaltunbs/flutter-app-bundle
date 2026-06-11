part of 'detection_bloc.dart';

/// Intent events for [DetectionBloc] (past-tense, no `BuildContext`).
@freezed
sealed class DetectionEvent with _$DetectionEvent {
  /// The analyzing screen opened: start the detection run.
  const factory DetectionEvent.started() = DetectionStarted;

  /// The user retried after a failure (cancels any in-flight run).
  const factory DetectionEvent.retryRequested() = DetectionRetryRequested;
}
