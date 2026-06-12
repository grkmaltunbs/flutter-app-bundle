import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';
import 'package:okey_acar_mi/core/logging/app_logger.dart';
import 'package:okey_acar_mi/features/history/domain/usecases/save_scan.dart';
import 'package:okey_acar_mi/features/result/domain/entities/result_args.dart';
import 'package:okey_acar_mi/features/review/domain/entities/review_outcome.dart';
import 'package:okey_acar_mi/features/solver/domain/entities/solve_request.dart';
import 'package:okey_acar_mi/features/solver/domain/entities/solve_result.dart';
import 'package:okey_acar_mi/features/solver/domain/usecases/solve_rack.dart';

part 'result_bloc.freezed.dart';
part 'result_event.dart';
part 'result_state.dart';

/// Screen-scoped bloc for the result screen: runs the solver on the
/// [ResultArgs] it was created for, exposes the solve status, the body
/// layout choice, and the detail-unlock flag.
///
/// A successful solve of a [ResultArgs.fresh] is persisted to history once
/// (best-effort: a save failure is logged, never surfaced); a
/// [ResultArgs.replay] is read-only and never saved again. The injected
/// [SolveRack] is a fresh instance per bloc (its LRU(1) memo is
/// per-instance), so a retry of the *same* outcome returns the cached result
/// instantly. Navigation is a widget-side effect — the bloc never navigates.
/// Holds no subscriptions, so `close()` is not overridden.
@injectable
class ResultBloc extends Bloc<ResultEvent, ResultState> {
  /// Creates a [ResultBloc] for [args] and kicks off the solve.
  ResultBloc(
    this._solveRack,
    this._saveScan,
    this._logger,
    @factoryParam ResultArgs args,
  ) : _args = args,
      super(
        ResultState(
          outcome: args.outcome,
          status: const ResultSolveStatus.solving(),
        ),
      ) {
    on<ResultSolveRequested>(_onSolveRequested);
    on<ResultLayoutToggled>(_onLayoutToggled);
    on<ResultDetailUnlockGranted>(_onDetailUnlockGranted);
    add(const ResultEvent.solveRequested());
  }

  final SolveRack _solveRack;
  final SaveScan _saveScan;
  final AppLogger _logger;
  final ResultArgs _args;

  /// Latched on the first *successful* solve of a fresh outcome so a retry
  /// after a failure saves exactly once.
  bool _saved = false;

  Future<void> _onSolveRequested(
    ResultSolveRequested event,
    Emitter<ResultState> emit,
  ) async {
    emit(state.copyWith(status: const ResultSolveStatus.solving()));
    final SolveResult result;
    try {
      result = await _solveRack(
        SolveRequest(
          tiles: state.outcome.tiles,
          indicator: state.outcome.indicator,
          mode: state.outcome.gameMode,
        ),
      );
    } on Object catch (error, stackTrace) {
      // Broad on purpose: the solver is pure logic, so anything it throws is
      // an engine defect (an `Error`, not a mapped `Failure`) — and the spec
      // mandates a retryable error state over a crash.
      _logger.error('Rack solve failed', error, stackTrace);
      if (emit.isDone) return;
      emit(state.copyWith(status: const ResultSolveStatus.failed()));
      return;
    }
    if (emit.isDone) return;
    // Emit before the save so the verdict renders instantly; persisting is
    // local-best-effort background work (sync is the repository's job).
    emit(state.copyWith(status: ResultSolveStatus.solved(result)));
    await _saveFreshOnce(result);
  }

  Future<void> _saveFreshOnce(SolveResult result) async {
    if (_saved || _args is! ResultArgsFresh) return;
    _saved = true;
    try {
      await _saveScan(outcome: state.outcome, result: result);
    } on Object catch (error, stackTrace) {
      // A failed save never disturbs the solved state — log and move on.
      _logger.error('Scan save failed', error, stackTrace);
    }
  }

  void _onLayoutToggled(ResultLayoutToggled event, Emitter<ResultState> emit) {
    emit(state.copyWith(layout: event.layout));
  }

  void _onDetailUnlockGranted(
    ResultDetailUnlockGranted event,
    Emitter<ResultState> emit,
  ) {
    emit(state.copyWith(detailUnlocked: true));
  }
}
