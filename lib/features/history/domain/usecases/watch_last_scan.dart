import 'package:injectable/injectable.dart';
import 'package:okey_acar_mi/features/history/domain/entities/history_filter.dart';
import 'package:okey_acar_mi/features/history/domain/entities/scan.dart';
import 'package:okey_acar_mi/features/history/domain/repositories/scan_repository.dart';

/// Watches the current owner's most recent scan (home "last scan" card).
@injectable
class WatchLastScan {
  /// Creates a [WatchLastScan].
  const WatchLastScan(this._scans);

  final ScanRepository _scans;

  /// Streams the newest scan, or `null` when the owner has none.
  Stream<Scan?> call() => _scans
      .watchScans(filter: HistoryFilter.all, limit: 1)
      .map((scans) => scans.isEmpty ? null : scans.first);
}
