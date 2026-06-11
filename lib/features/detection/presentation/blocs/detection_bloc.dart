import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';
import 'package:okey_acar_mi/core/error/failure.dart';
import 'package:okey_acar_mi/core/logging/app_logger.dart';
import 'package:okey_acar_mi/features/capture/domain/entities/capture_payload.dart';
import 'package:okey_acar_mi/features/detection/domain/entities/detected_tile.dart';
import 'package:okey_acar_mi/features/detection/domain/entities/detection_result.dart';
import 'package:okey_acar_mi/features/detection/domain/entities/detection_stage.dart';
import 'package:okey_acar_mi/features/detection/domain/entities/detection_update.dart';
import 'package:okey_acar_mi/features/detection/domain/usecases/detect_tiles.dart';

part 'detection_bloc.freezed.dart';
part 'detection_event.dart';
part 'detection_state.dart';

/// Screen-scoped bloc for the analyzing screen: runs detection on the
/// payload it was created for and folds the update stream into staged
/// progress, the per-tile reveal, and the terminal success/failure.
///
/// Both events route into one `restartable` handler, so a retry cancels any
/// in-flight run before starting fresh.
@injectable
class DetectionBloc extends Bloc<DetectionEvent, DetectionState> {
  /// Creates a [DetectionBloc] for [payload].
  DetectionBloc(
    this._detectTiles,
    this._logger,
    @factoryParam CapturePayload payload,
  ) : _payload = payload,
      super(
        const DetectionState.processing(
          stage: DetectionStage.preparing,
          revealed: [],
        ),
      ) {
    on<DetectionEvent>(_onRun, transformer: restartable());
  }

  final DetectTiles _detectTiles;
  final AppLogger _logger;
  final CapturePayload _payload;

  /// Starts (or restarts) a detection run.
  ///
  /// Cancellation chain: popping the page disposes the `BlocProvider` →
  /// `close()` → the `emit.forEach` subscription cancels → the detector's
  /// cold-stream `onCancel` kills the worker isolate. `restartable()` gives
  /// a retry the same chain for the run it replaces.
  Future<void> _onRun(
    DetectionEvent event,
    Emitter<DetectionState> emit,
  ) async {
    emit(
      const DetectionState.processing(
        stage: DetectionStage.preparing,
        revealed: [],
      ),
    );
    await emit.forEach<DetectionUpdate>(
      _detectTiles(_payload),
      onData: _fold,
    );
  }

  DetectionState _fold(DetectionUpdate update) {
    final current = state;
    switch (update) {
      case DetectionStageUpdate(:final stage, :final totalTiles):
        if (current is DetectionProcessing) {
          return current.copyWith(
            stage: stage,
            totalTiles: totalTiles ?? current.totalTiles,
          );
        }
        return DetectionState.processing(
          stage: stage,
          revealed: const [],
          totalTiles: totalTiles,
        );
      case DetectionTileUpdate(:final tile):
        if (current is DetectionProcessing) {
          return current.copyWith(
            revealed: List.unmodifiable([...current.revealed, tile]),
          );
        }
        return current;
      case DetectionCompletedUpdate(:final result):
        return DetectionState.success(result: result);
      case DetectionFailedUpdate(:final failure):
        _logger.warning('Detection run failed: $failure');
        return DetectionState.failure(failure: failure);
    }
  }
}
