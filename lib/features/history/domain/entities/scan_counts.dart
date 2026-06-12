import 'package:freezed_annotation/freezed_annotation.dart';

part 'scan_counts.freezed.dart';

/// Row counts per history filter segment, for the filter chips.
@freezed
abstract class ScanCounts with _$ScanCounts {
  /// Creates a [ScanCounts].
  const factory ScanCounts({
    /// Every scan of the current owner.
    required int all,

    /// Scans whose hand opened / was winning.
    required int opened,

    /// Scans whose hand did not open / was not winning.
    required int closed,
  }) = _ScanCounts;
}
