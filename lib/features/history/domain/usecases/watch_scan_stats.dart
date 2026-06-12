import 'package:injectable/injectable.dart';
import 'package:okey_acar_mi/features/history/domain/entities/scan_stats.dart';
import 'package:okey_acar_mi/features/history/domain/repositories/scan_repository.dart';

/// Watches the current owner's aggregate scan stats (stats strip).
@injectable
class WatchScanStats {
  /// Creates a [WatchScanStats].
  const WatchScanStats(this._scans);

  final ScanRepository _scans;

  /// Streams the owner's stats, re-scoping on sign-in/out.
  Stream<ScanStats> call() => _scans.watchStats();
}
