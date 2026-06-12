import 'package:drift/drift.dart';

/// Local store for solved scans (Step 9 history).
///
/// One row per scan; the row is the offline source of truth and mirrors the
/// Firestore `scans/{id}` doc shape owned by `ScanDto`. Verdict fields are
/// denormalized into columns so the history list, filters, and stats are
/// single watched queries.
@TableIndex(name: 'idx_scans_owner_created', columns: {#ownerId, #createdAtMs})
@DataClassName('ScanRow')
class Scans extends Table {
  /// Scan id (uuid v4) — doubles as the Firestore document id.
  TextColumn get id => text()();

  /// Owning user id; `null` for guest-created scans awaiting adoption.
  TextColumn get ownerId => text().nullable()();

  /// Creation instant, epoch milliseconds UTC (via the injected `Clock`).
  IntColumn get createdAtMs => integer()();

  /// Last mutation instant, epoch milliseconds UTC — the last-write-wins key
  /// for remote/local conflict resolution.
  IntColumn get updatedAtMs => integer()();

  /// `GameMode.name` of the solved mode (`oneZeroOne` | `okey`).
  TextColumn get gameMode => text()();

  /// `TileColor.name` of the indicator (gösterge) tile.
  TextColumn get indicatorColor => text()();

  /// Number (1–13) of the indicator tile.
  IntColumn get indicatorNumber => integer()();

  /// Rack-order tile array as JSON: `[{"c":"red","n":5},{"c":"joker"},…]`
  /// (encoded/decoded by `ScanDto`).
  TextColumn get tilesJson => text()();

  /// `ScanVerdictKind.name` of the verdict.
  TextColumn get verdictKind => text()();

  /// Denormalized filter/stats column: did the hand open (101) or win (okey)?
  BoolColumn get opened => boolean()();

  /// Best meld total (`SolveResult.totalScore`).
  IntColumn get score => integer()();

  /// `OpenPath.name` for 101 openers, else `null`.
  TextColumn get openPath => text().nullable()();

  /// Points short of 101 for non-openers, else `null`.
  IntColumn get pointsShort => integer().nullable()();

  /// Minimum exchanges to a winning okey hand, else `null`.
  IntColumn get tilesToWin => integer().nullable()();

  /// `OkeyPath.name` of the okey winning template, else `null`.
  TextColumn get okeyPath => text().nullable()();

  /// Sync lifecycle marker (`localOnly` | `pendingUpload` | `synced`).
  TextColumn get syncState => text().withDefault(const Constant('localOnly'))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
