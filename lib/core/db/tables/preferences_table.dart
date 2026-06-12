import 'package:drift/drift.dart';

/// Generic key→JSON preference store.
///
/// Created with schema v1 so the Step 10 settings work needs no migration;
/// unused until then.
class Preferences extends Table {
  /// Preference key.
  TextColumn get key => text()();

  /// JSON-encoded preference value.
  TextColumn get valueJson => text()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}
