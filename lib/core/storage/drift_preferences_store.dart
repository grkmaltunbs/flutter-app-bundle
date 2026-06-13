import 'dart:convert';

import 'package:okey_acar_mi/core/db/app_database.dart';
import 'package:okey_acar_mi/core/logging/app_logger.dart';
import 'package:okey_acar_mi/core/storage/preferences_store.dart';

/// Drift-backed [PreferencesStore] over the `Preferences` table.
///
/// [load] reads every row once into an in-memory snapshot, so [read] is
/// synchronous afterwards. The `valueJson` column stores a JSON string
/// literal (`jsonEncode` of the plain string value), keeping the column
/// future-proof for structured values without a migration.
class DriftPreferencesStore implements PreferencesStore {
  DriftPreferencesStore._(this._db, this._logger, this._snapshot);

  /// Loads the full preferences table into a snapshot-backed store.
  ///
  /// Corrupt or undecodable rows are logged and skipped — loading never
  /// throws, so a damaged row can never block app startup.
  static Future<DriftPreferencesStore> load(
    AppDatabase db,
    AppLogger logger,
  ) async {
    final snapshot = <String, String>{};
    try {
      final rows = await db.select(db.preferences).get();
      for (final row in rows) {
        try {
          final decoded = jsonDecode(row.valueJson);
          if (decoded is String) {
            snapshot[row.key] = decoded;
          } else {
            logger.warning(
              'Preference "${row.key}" holds a non-string JSON value; skipped',
            );
          }
        } on FormatException catch (error) {
          logger.warning(
            'Preference "${row.key}" is undecodable ($error); skipped',
          );
        }
      }
    } on Object catch (error, stackTrace) {
      // `on Object`, not `on Exception`: drift surfaces a closed/closing
      // database as a StateError, which must not break app startup either.
      logger.error('Failed to load preferences', error, stackTrace);
    }
    return DriftPreferencesStore._(db, logger, snapshot);
  }

  final AppDatabase _db;
  final AppLogger _logger;
  final Map<String, String> _snapshot;

  @override
  String? read(String key) => _snapshot[key];

  @override
  Future<void> write(String key, String value) async {
    // The snapshot is the source of truth for the session: update it first,
    // synchronously, so a same-frame read sees the new value even if the
    // durable write below fails.
    _snapshot[key] = value;
    try {
      await _db
          .into(_db.preferences)
          .insertOnConflictUpdate(
            PreferencesCompanion.insert(key: key, valueJson: jsonEncode(value)),
          );
    } on Object catch (error, stackTrace) {
      // `on Object`, not `on Exception`: a write racing the database close
      // (e.g. a settings tap just before container teardown) throws a
      // StateError, and callers persist fire-and-forget — anything escaping
      // here would surface as an unhandled async zone error.
      _logger.error('Failed to persist preference "$key"', error, stackTrace);
    }
  }
}
