import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:okey_acar_mi/features/solver/domain/entities/solve_result.dart';
import 'package:okey_acar_mi/features/solver/domain/entities/solve_verdict.dart';

part 'scan_summary.freezed.dart';

/// Which solver verdict a stored scan carries (the persisted, flat mirror of
/// the sealed [SolveVerdict]).
enum ScanVerdictKind {
  /// 101 mode: the hand finishes the round (all 21 playable tiles meld).
  finishes101,

  /// 101 mode: the hand opens.
  opens101,

  /// 101 mode: the hand does not open.
  doesNotOpen101,

  /// Okey mode: tiles-to-win outcome.
  okeyOutcome,
}

/// The persisted essence of a [SolveResult] — enough to render history rows
/// and stats without re-running the solver.
///
/// Field population follows [kind]: [openPath] for [ScanVerdictKind.opens101],
/// [pointsShort] for [ScanVerdictKind.doesNotOpen101], and [tilesToWin] +
/// [okeyPath] for [ScanVerdictKind.okeyOutcome].
@freezed
abstract class ScanSummary with _$ScanSummary {
  /// Creates a [ScanSummary].
  const factory ScanSummary({
    /// The verdict discriminant.
    required ScanVerdictKind kind,

    /// Denormalized filter bit: opens (101) or winning now (okey).
    required bool opened,

    /// Best meld total ([SolveResult.totalScore]) — populated for every kind.
    required int score,

    /// How a 101 hand opened, else `null`.
    OpenPath? openPath,

    /// Points short of 101 for a non-opener, else `null`.
    int? pointsShort,

    /// Minimum exchanges to an okey win, else `null`.
    int? tilesToWin,

    /// The okey winning template, else `null`.
    OkeyPath? okeyPath,
  }) = _ScanSummary;

  /// Derives the summary of [result]: `opened` is true for an 101 opener or
  /// a winning-now okey hand; `score` is always [SolveResult.totalScore].
  factory ScanSummary.fromResult(SolveResult result) {
    return switch (result.verdict) {
      Finishes101() => ScanSummary(
        kind: ScanVerdictKind.finishes101,
        opened: true,
        score: result.totalScore,
        openPath: OpenPath.melds,
      ),
      Opens101(:final via) => ScanSummary(
        kind: ScanVerdictKind.opens101,
        opened: true,
        score: result.totalScore,
        openPath: via,
      ),
      DoesNotOpen101(:final pointsShort) => ScanSummary(
        kind: ScanVerdictKind.doesNotOpen101,
        opened: false,
        score: result.totalScore,
        pointsShort: pointsShort,
      ),
      OkeyOutcome(:final tilesToWin, :final via) => ScanSummary(
        kind: ScanVerdictKind.okeyOutcome,
        opened: tilesToWin == 0,
        score: result.totalScore,
        tilesToWin: tilesToWin,
        okeyPath: via,
      ),
    };
  }
}
