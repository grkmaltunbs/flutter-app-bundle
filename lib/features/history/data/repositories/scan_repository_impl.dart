import 'dart:async';

import 'package:injectable/injectable.dart';
import 'package:okey_acar_mi/core/error/error_mapper.dart';
import 'package:okey_acar_mi/core/error/failure.dart';
import 'package:okey_acar_mi/core/logging/app_logger.dart';
import 'package:okey_acar_mi/core/network/connectivity_service.dart';
import 'package:okey_acar_mi/core/streams/switch_latest.dart';
import 'package:okey_acar_mi/core/time/clock.dart';
import 'package:okey_acar_mi/features/auth/domain/entities/app_user.dart';
import 'package:okey_acar_mi/features/auth/domain/repositories/auth_repository.dart';
import 'package:okey_acar_mi/features/history/data/datasources/scan_local_data_source.dart';
import 'package:okey_acar_mi/features/history/data/datasources/scan_remote_data_source.dart';
import 'package:okey_acar_mi/features/history/domain/entities/history_filter.dart';
import 'package:okey_acar_mi/features/history/domain/entities/scan.dart';
import 'package:okey_acar_mi/features/history/domain/entities/scan_counts.dart';
import 'package:okey_acar_mi/features/history/domain/entities/scan_stats.dart';
import 'package:okey_acar_mi/features/history/domain/repositories/scan_repository.dart';

/// Cancels the [ScanRepositoryImpl]'s auth/connectivity subscriptions when
/// the DI container resets (`getIt.reset()`).
FutureOr<void> disposeScanRepository(ScanRepository instance) =>
    (instance as ScanRepositoryImpl).dispose();

/// Offline-first [ScanRepository] over the local drift store and a
/// [ScanRemoteDataSource].
///
/// Registered in BOTH environments — the environment split lives entirely in
/// the injected data source (Firestore in prod, the seeded fake in demo).
///
/// Sync model: local is the source of truth for reads; [syncNow] pulls the
/// owner's remote docs (last-write-wins upsert) then pushes pending local
/// rows. Sync triggers: explicit calls, save of an owned scan, sign-in, and
/// the offline → online edge.
@LazySingleton(as: ScanRepository, dispose: disposeScanRepository)
class ScanRepositoryImpl implements ScanRepository {
  /// Creates a [ScanRepositoryImpl] and starts the sign-in/online sync
  /// triggers.
  ScanRepositoryImpl(
    this._local,
    this._remote,
    this._auth,
    this._connectivity,
    this._clock,
    this._logger,
  ) {
    _authSubscription = _auth.authStateChanges().listen((user) {
      if (user != null) unawaited(syncNow());
    });
    _connectivitySubscription = _connectivity.onlineStream.listen((online) {
      if (online && !_wasOnline) unawaited(syncNow());
      _wasOnline = online;
    });
  }

  final ScanLocalDataSource _local;
  final ScanRemoteDataSource _remote;
  final AuthRepository _auth;
  final ConnectivityService _connectivity;
  final Clock _clock;
  final AppLogger _logger;

  late final StreamSubscription<AppUser?> _authSubscription;
  late final StreamSubscription<bool> _connectivitySubscription;
  // Edge detector for offline → online; starts false so a replayed initial
  // `true` (demo fake) costs at most one harmless no-op sync.
  bool _wasOnline = false;

  bool _syncing = false;
  bool _rerunRequested = false;

  @override
  Future<void> save(Scan scan) async {
    final owned = scan.ownerId != null;
    await _local.insert(
      scan,
      syncState: owned
          ? ScanSyncStates.pendingUpload
          : ScanSyncStates.localOnly,
    );
    // Fire-and-forget: the save must return on the local write; the upload
    // is background work (syncNow logs its own failures).
    if (owned) unawaited(syncNow());
  }

  @override
  Stream<List<Scan>> watchScans({
    required HistoryFilter filter,
    required int limit,
  }) => switchLatest(
    _auth.authStateChanges(),
    (user) => _local.watchScans(
      ownerId: user?.id,
      filter: filter,
      limit: limit,
    ),
  );

  @override
  Stream<ScanCounts> watchCounts() => switchLatest(
    _auth.authStateChanges(),
    (user) => _local.watchCounts(ownerId: user?.id),
  );

  @override
  Stream<ScanStats> watchStats() => switchLatest(
    _auth.authStateChanges(),
    (user) => _local.watchStats(ownerId: user?.id),
  );

  @override
  Future<void> syncNow() async {
    if (_syncing) {
      // Serialized: remember that state changed mid-sync and rerun once.
      _rerunRequested = true;
      return;
    }
    _syncing = true;
    try {
      do {
        _rerunRequested = false;
        await _syncOnce();
      } while (_rerunRequested);
    } finally {
      _syncing = false;
    }
  }

  Future<void> _syncOnce() async {
    final user = _auth.currentUser;
    if (user == null) return;
    try {
      if (!await _connectivity.isOnline()) return;
      // Pull first so the push below never clobbers a newer remote doc
      // (the LWW gate in upsertFromRemote arbitrates).
      final remote = await _remote.fetchAll(user.id);
      await _local.upsertFromRemote(remote);
      final pending = await _local.pendingUploads(user.id);
      if (pending.isNotEmpty) {
        await _remote.uploadAll(pending);
        await _local.markSynced([for (final dto in pending) dto.id]);
      }
    } on Object catch (error, stackTrace) {
      // Background work: never throw — log and wait for the next trigger.
      _logger.error('Scan sync failed', error, stackTrace);
    }
  }

  @override
  Future<void> adoptGuestScans({required String toUserId}) async {
    await _local.adoptGuestScans(toOwnerId: toUserId, at: _clock.now());
    await syncNow();
  }

  @override
  Future<void> deleteAllForOwner(String ownerId) async {
    await _local.deleteAllForOwner(ownerId);
    try {
      await _remote.deleteAllForOwner(ownerId);
    } on Failure catch (failure, stackTrace) {
      _logger.error('Remote scan purge failed', failure, stackTrace);
      rethrow;
    } on Object catch (error, stackTrace) {
      _logger.error('Remote scan purge failed', error, stackTrace);
      throw mapToFailure(error);
    }
  }

  /// Cancels the sync-trigger subscriptions; called via
  /// [disposeScanRepository] when the DI container resets.
  Future<void> dispose() async {
    await _authSubscription.cancel();
    await _connectivitySubscription.cancel();
  }
}
