part of 'result_bloc.dart';

/// The phase of the solve run — the sealed discriminant the body switches on.
@freezed
sealed class ResultSolveStatus with _$ResultSolveStatus {
  /// The solver is running.
  const factory ResultSolveStatus.solving() = ResultSolving;

  /// The solver finished with [result].
  const factory ResultSolveStatus.solved(SolveResult result) = ResultSolved;

  /// The solver threw; a retry is offered.
  const factory ResultSolveStatus.failed() = ResultSolveFailed;
}

/// The result screen state: the outcome under solve, the solve status, the
/// body layout, and the detail-unlock flag.
///
/// Has four fields — consumers must scope rebuilds with `BlocSelector` /
/// `buildWhen` per the project performance rules.
@freezed
abstract class ResultState with _$ResultState {
  /// Creates a [ResultState].
  const factory ResultState({
    /// The confirmed review outcome this screen solves (fixed at creation).
    required ReviewOutcome outcome,

    /// The solve phase (solving / solved / failed).
    required ResultSolveStatus status,

    /// The chosen body layout; survives a retry.
    @Default(ResultLayout.rack) ResultLayout layout,

    /// Whether the step-by-step reasoning is unlocked; survives a retry.
    @Default(false) bool detailUnlocked,
  }) = _ResultState;
}
