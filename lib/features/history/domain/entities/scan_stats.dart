import 'package:freezed_annotation/freezed_annotation.dart';

part 'scan_stats.freezed.dart';

/// Aggregate history stats for the stats strip.
@freezed
abstract class ScanStats with _$ScanStats {
  /// Creates a [ScanStats].
  const factory ScanStats({
    /// Total scans of the current owner.
    required int total,

    /// How many opened / were winning.
    required int opened,

    /// The best score across all scans (0 when there are none).
    required int best,
  }) = _ScanStats;

  const ScanStats._();

  /// Percentage of scans that opened, rounded; 0 when [total] is 0.
  int get openRatePercent => total == 0 ? 0 : (100 * opened / total).round();
}
