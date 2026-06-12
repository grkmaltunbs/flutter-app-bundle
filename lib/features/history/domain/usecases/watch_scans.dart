import 'package:injectable/injectable.dart';
import 'package:okey_acar_mi/features/history/domain/entities/history_filter.dart';
import 'package:okey_acar_mi/features/history/domain/entities/scan.dart';
import 'package:okey_acar_mi/features/history/domain/repositories/scan_repository.dart';

/// Watches the current owner's scan list for the history screen.
@injectable
class WatchScans {
  /// Creates a [WatchScans].
  const WatchScans(this._scans);

  final ScanRepository _scans;

  /// Streams the owner's scans matching [filter], newest first, capped at
  /// [limit].
  Stream<List<Scan>> call({
    required HistoryFilter filter,
    required int limit,
  }) => _scans.watchScans(filter: filter, limit: limit);
}
