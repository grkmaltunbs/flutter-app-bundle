import 'package:okey_acar_mi/features/history/domain/entities/history_filter.dart';
import 'package:okey_acar_mi/features/history/domain/entities/scan.dart';
import 'package:okey_acar_mi/features/history/domain/entities/scan_counts.dart';
import 'package:okey_acar_mi/features/history/domain/entities/scan_stats.dart';

/// Persistence + sync for scan history.
///
/// Offline-first: every read is served from the local store; sync runs in
/// the background and never surfaces errors to watchers. All `watch*`
/// streams are scoped to the **current owner** (the signed-in user, or guest
/// rows when signed out) and re-scope automatically on sign-in/out.
abstract class ScanRepository {
  /// Persists [scan] locally and, when it is account-owned, schedules a
  /// background upload.
  Future<void> save(Scan scan);

  /// Watches the current owner's scans matching [filter], newest first,
  /// capped at [limit]. Re-emits with the new owner's rows on sign-in/out.
  Stream<List<Scan>> watchScans({
    required HistoryFilter filter,
    required int limit,
  });

  /// Watches the current owner's per-filter row counts.
  Stream<ScanCounts> watchCounts();

  /// Watches the current owner's aggregate stats.
  Stream<ScanStats> watchStats();

  /// Runs a pull-then-push sync now. Serialized (a call during a running
  /// sync queues one trailing rerun); a no-op when guest or offline; never
  /// throws — sync errors are logged background noise.
  Future<void> syncNow();

  /// Re-owns every guest scan to [toUserId] and schedules their upload.
  Future<void> adoptGuestScans({required String toUserId});

  /// Deletes all of [ownerId]'s scans locally and remotely (account
  /// deletion). Throws a `Failure` when the remote purge fails.
  Future<void> deleteAllForOwner(String ownerId);
}
