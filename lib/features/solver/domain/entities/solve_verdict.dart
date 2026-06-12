import 'package:freezed_annotation/freezed_annotation.dart';

part 'solve_verdict.freezed.dart';

/// How a 101-mode hand opens.
enum OpenPath {
  /// Sets/runs totaling ≥ 101.
  melds,

  /// Five (or more) pairs.
  pairs,
}

/// The shape of an okey-mode winning template.
enum OkeyPath {
  /// All tiles in melds (≥3) plus at most one final pair.
  meldsAndPair,

  /// Seven pairs.
  sevenPairs,
}

/// The solver's answer for the requested mode.
@freezed
sealed class SolveVerdict with _$SolveVerdict {
  /// 101 mode: the hand opens (score ≥ 101 via melds, or ≥ 5 pairs).
  const factory SolveVerdict.opens101({
    required int score,
    required OpenPath via,
  }) = Opens101;

  /// 101 mode: the hand does not open; [pointsShort] = 101 − [score].
  const factory SolveVerdict.doesNotOpen101({
    required int score,
    required int pointsShort,
  }) = DoesNotOpen101;

  /// Okey mode: exact minimum tile exchanges to a winning hand
  /// (0 = winning now).
  const factory SolveVerdict.okeyOutcome({
    required int tilesToWin,
    required OkeyPath via,
  }) = OkeyOutcome;
}
