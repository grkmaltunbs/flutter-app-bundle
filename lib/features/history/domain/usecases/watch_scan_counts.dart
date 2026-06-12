import 'package:injectable/injectable.dart';
import 'package:okey_acar_mi/features/history/domain/entities/scan_counts.dart';
import 'package:okey_acar_mi/features/history/domain/repositories/scan_repository.dart';

/// Watches the current owner's per-filter scan counts (filter chips).
@injectable
class WatchScanCounts {
  /// Creates a [WatchScanCounts].
  const WatchScanCounts(this._scans);

  final ScanRepository _scans;

  /// Streams the owner's counts, re-scoping on sign-in/out.
  Stream<ScanCounts> call() => _scans.watchCounts();
}
