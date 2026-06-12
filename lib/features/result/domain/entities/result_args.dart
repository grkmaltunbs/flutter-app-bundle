import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:okey_acar_mi/features/history/domain/entities/scan.dart';
import 'package:okey_acar_mi/features/review/domain/entities/review_outcome.dart';

part 'result_args.freezed.dart';

/// What the result screen was opened with: a freshly confirmed review
/// outcome (Scan flow — the solve gets persisted), or a stored [Scan]
/// replayed from history (read-only — never saved again).
@freezed
sealed class ResultArgs with _$ResultArgs {
  /// A fresh solve straight from the review screen; the result is saved to
  /// history once it lands.
  const factory ResultArgs.fresh(ReviewOutcome outcome) = ResultArgsFresh;

  /// A replay of a persisted [scan] opened from history/home; never saved.
  const factory ResultArgs.replay(Scan scan) = ResultArgsReplay;

  const ResultArgs._();

  /// The solver input for this screen, regardless of variant.
  ReviewOutcome get outcome => switch (this) {
    ResultArgsFresh(:final outcome) => outcome,
    ResultArgsReplay(:final scan) => scan.outcome,
  };
}
