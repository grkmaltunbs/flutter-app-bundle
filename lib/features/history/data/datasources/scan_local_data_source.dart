import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:injectable/injectable.dart';
import 'package:okey_acar_mi/core/db/app_database.dart';
import 'package:okey_acar_mi/core/logging/app_logger.dart';
import 'package:okey_acar_mi/features/history/data/dtos/scan_dto.dart';
import 'package:okey_acar_mi/features/history/domain/entities/history_filter.dart';
import 'package:okey_acar_mi/features/history/domain/entities/scan.dart';
import 'package:okey_acar_mi/features/history/domain/entities/scan_counts.dart';
import 'package:okey_acar_mi/features/history/domain/entities/scan_stats.dart';

/// The `syncState` column values of the local `scans` table.
abstract final class ScanSyncStates {
  /// Guest-owned row; never uploaded.
  static const String localOnly = 'localOnly';

  /// Account-owned row awaiting upload.
  static const String pendingUpload = 'pendingUpload';

  /// Row confirmed present remotely.
  static const String synced = 'synced';
}

/// Drift-backed reads/writes of the local `scans` table.
///
/// Owner scoping is explicit on every call: `null` means guest rows
/// (`ownerId IS NULL`). Malformed rows are logged and skipped, never thrown.
@lazySingleton
class ScanLocalDataSource {
  /// Creates a [ScanLocalDataSource] over [_db].
  const ScanLocalDataSource(this._db, this._logger);

  final AppDatabase _db;
  final AppLogger _logger;

  Expression<bool> _ownedBy($ScansTable t, String? ownerId) =>
      ownerId == null ? t.ownerId.isNull() : t.ownerId.equals(ownerId);

  /// Watches [ownerId]'s rows matching [filter], newest first ([limit]ed).
  ///
  /// Ordered by `createdAtMs DESC, rowid DESC` — the demo flavor's FakeClock
  /// pins a single instant, so insertion order (rowid) breaks the ties.
  Stream<List<Scan>> watchScans({
    required HistoryFilter filter,
    required int limit,
    String? ownerId,
  }) {
    final query = _db.select(_db.scans)
      ..where((t) => _ownedBy(t, ownerId))
      ..orderBy([
        (t) => OrderingTerm(expression: t.createdAtMs, mode: OrderingMode.desc),
        (t) => OrderingTerm(expression: t.rowId, mode: OrderingMode.desc),
      ])
      ..limit(limit);
    if (filter != HistoryFilter.all) {
      query.where((t) => t.opened.equals(filter == HistoryFilter.opened));
    }
    return query.watch().map(
      (rows) => [
        for (final row in rows) ?_toScan(row),
      ],
    );
  }

  /// Watches [ownerId]'s per-filter row counts as one aggregate query.
  Stream<ScanCounts> watchCounts({String? ownerId}) {
    final t = _db.scans;
    final total = countAll();
    final openedCount = countAll(filter: t.opened.equals(true));
    final query = _db.selectOnly(t)
      ..addColumns([total, openedCount])
      ..where(_ownedBy(t, ownerId));
    return query.watchSingle().map((row) {
      final all = row.read(total) ?? 0;
      final opened = row.read(openedCount) ?? 0;
      return ScanCounts(all: all, opened: opened, closed: all - opened);
    });
  }

  /// Watches [ownerId]'s aggregate stats (COUNT, opened count, MAX(score))
  /// as one aggregate query.
  Stream<ScanStats> watchStats({String? ownerId}) {
    final t = _db.scans;
    final total = countAll();
    final openedCount = countAll(filter: t.opened.equals(true));
    final best = t.score.max();
    final query = _db.selectOnly(t)
      ..addColumns([total, openedCount, best])
      ..where(_ownedBy(t, ownerId));
    return query.watchSingle().map(
      (row) => ScanStats(
        total: row.read(total) ?? 0,
        opened: row.read(openedCount) ?? 0,
        best: row.read(best) ?? 0,
      ),
    );
  }

  /// Inserts (or replaces) [scan] with the given [syncState]
  /// (a [ScanSyncStates] value).
  Future<void> insert(Scan scan, {required String syncState}) => _db
      .into(_db.scans)
      .insertOnConflictUpdate(
        _toCompanion(ScanDto.fromEntity(scan), syncState: syncState),
      );

  /// Upserts remote [dtos] under last-write-wins: an incoming doc replaces
  /// the local row only when its `updatedAtMs` is `>=` the local one.
  /// Upserted rows are marked [ScanSyncStates.synced]. Runs in one
  /// transaction (multi-row write).
  Future<void> upsertFromRemote(List<ScanDto> dtos) {
    return _db.transaction(() async {
      for (final dto in dtos) {
        final existing = await (_db.select(
          _db.scans,
        )..where((t) => t.id.equals(dto.id))).getSingleOrNull();
        if (existing != null && existing.updatedAtMs > dto.updatedAtMs) {
          continue;
        }
        await _db
            .into(_db.scans)
            .insertOnConflictUpdate(
              _toCompanion(dto, syncState: ScanSyncStates.synced),
            );
      }
    });
  }

  /// Returns [ownerId]'s rows still awaiting upload, as wire DTOs.
  Future<List<ScanDto>> pendingUploads(String ownerId) async {
    final rows =
        await (_db.select(_db.scans)
              ..where(
                (t) =>
                    t.ownerId.equals(ownerId) &
                    t.syncState.equals(ScanSyncStates.pendingUpload),
              )
              ..orderBy([(t) => OrderingTerm(expression: t.createdAtMs)]))
            .get();
    return [
      for (final row in rows) ?_toDto(row),
    ];
  }

  /// Marks the rows with [ids] as [ScanSyncStates.synced] (single UPDATE).
  Future<void> markSynced(List<String> ids) async {
    if (ids.isEmpty) return;
    await (_db.update(_db.scans)..where((t) => t.id.isIn(ids))).write(
      const ScansCompanion(syncState: Value(ScanSyncStates.synced)),
    );
  }

  /// Re-owns every guest row (`ownerId IS NULL`) to [toOwnerId] in a single
  /// UPDATE: sets `syncState` to pending and bumps `updatedAtMs` to [at].
  Future<void> adoptGuestScans({
    required String toOwnerId,
    required DateTime at,
  }) async {
    await (_db.update(_db.scans)..where((t) => t.ownerId.isNull())).write(
      ScansCompanion(
        ownerId: Value(toOwnerId),
        syncState: const Value(ScanSyncStates.pendingUpload),
        updatedAtMs: Value(at.toUtc().millisecondsSinceEpoch),
      ),
    );
  }

  /// Deletes every row of [ownerId] (`null` = guest rows).
  Future<void> deleteAllForOwner(String? ownerId) async {
    await (_db.delete(_db.scans)..where((t) => _ownedBy(t, ownerId))).go();
  }

  ScansCompanion _toCompanion(ScanDto dto, {required String syncState}) {
    final summary = dto.summary;
    return ScansCompanion.insert(
      id: dto.id,
      ownerId: Value(dto.ownerId),
      createdAtMs: dto.createdAtMs,
      updatedAtMs: dto.updatedAtMs,
      gameMode: dto.gameMode,
      indicatorColor: Value(dto.indicator?.color),
      indicatorNumber: Value(dto.indicator?.number),
      // Same shape as ScanDto.encodeTiles by construction (the DTO owns the
      // per-tile JSON shape).
      tilesJson: jsonEncode([for (final tile in dto.tiles) tile.toJson()]),
      verdictKind: summary.kind,
      opened: summary.opened,
      score: summary.score,
      openPath: Value(summary.openPath),
      pointsShort: Value(summary.pointsShort),
      tilesToWin: Value(summary.tilesToWin),
      okeyPath: Value(summary.okeyPath),
      syncState: Value(syncState),
    );
  }

  Scan? _toScan(ScanRow row) {
    final dto = _toDto(row);
    if (dto == null) return null;
    try {
      return dto.toEntity();
    } on FormatException catch (error) {
      _logger.warning('Skipping malformed scan row ${row.id}: $error');
      return null;
    }
  }

  ScanDto? _toDto(ScanRow row) {
    try {
      return ScanDto(
        id: row.id,
        ownerId: row.ownerId,
        createdAtMs: row.createdAtMs,
        updatedAtMs: row.updatedAtMs,
        gameMode: row.gameMode,
        indicator: switch ((row.indicatorColor, row.indicatorNumber)) {
          (final String color, final int number) => ScanIndicatorDto(
            color: color,
            number: number,
          ),
          _ => null,
        },
        tiles: [
          for (final tile in ScanDto.decodeTiles(row.tilesJson))
            ScanTileDto.fromTile(tile),
        ],
        summary: ScanSummaryDto(
          kind: row.verdictKind,
          opened: row.opened,
          score: row.score,
          openPath: row.openPath,
          pointsShort: row.pointsShort,
          tilesToWin: row.tilesToWin,
          okeyPath: row.okeyPath,
        ),
      );
    } on FormatException catch (error) {
      _logger.warning('Skipping malformed scan row ${row.id}: $error');
      return null;
    }
  }
}
