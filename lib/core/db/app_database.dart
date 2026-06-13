import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:okey_acar_mi/core/db/tables/preferences_table.dart';
import 'package:okey_acar_mi/core/db/tables/scans_table.dart';

part 'app_database.g.dart';

/// The app's local drift database (scan history + preferences).
///
/// Registered as a lazy DI singleton via `DbModule`, which supplies a
/// `LazyDatabase` executor so nothing touches the filesystem until the first
/// query runs.
@DriftDatabase(tables: [Scans, Preferences])
class AppDatabase extends _$AppDatabase {
  /// Creates an [AppDatabase] over the given query executor.
  AppDatabase(super.e);

  /// Creates an [AppDatabase] over a query executor supplied by a test
  /// (e.g. `NativeDatabase.memory()`).
  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      // v2: the indicator columns became nullable (a face-down tile lets the
      // user skip the indicator). TableMigration recreates the table,
      // preserving every existing row's non-null values.
      if (from < 2) {
        await m.alterTable(TableMigration(scans));
      }
    },
  );

  /// Deletes every scan row — test seam for resetting persisted demo state
  /// between integration-test runs.
  @visibleForTesting
  Future<void> wipeScansForTest() => delete(scans).go();

  /// Deletes every preference row — test seam for resetting persisted
  /// settings between integration-test runs.
  @visibleForTesting
  Future<void> wipePreferencesForTest() => delete(preferences).go();
}
