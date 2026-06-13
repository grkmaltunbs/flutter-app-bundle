import 'dart:convert';

import 'package:checks/checks.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:okey_acar_mi/core/db/app_database.dart';
import 'package:okey_acar_mi/core/logging/app_logger.dart';
import 'package:okey_acar_mi/core/storage/drift_preferences_store.dart';

class _MockAppLogger extends Mock implements AppLogger {}

/// Inserts a raw preferences row, bypassing the store's `jsonEncode` (the
/// only way to plant a corrupt `valueJson`).
Future<void> _insertRaw(AppDatabase db, String key, String valueJson) => db
    .into(db.preferences)
    .insert(PreferencesCompanion.insert(key: key, valueJson: valueJson));

void main() {
  late AppDatabase db;
  late _MockAppLogger logger;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    logger = _MockAppLogger();
  });
  tearDown(() => db.close());

  group('DriftPreferencesStore', () {
    test('write → read round-trips within the same session', () async {
      final store = await DriftPreferencesStore.load(db, logger);

      await store.write('settings.themeChoice', 'felt');

      check(store.read('settings.themeChoice')).equals('felt');
      check(store.read('never-written')).isNull();
    });

    test(
      'a second load over the same database sees persisted values',
      () async {
        final first = await DriftPreferencesStore.load(db, logger);
        await first.write('a', '1');
        await first.write('b', 'two');

        final second = await DriftPreferencesStore.load(db, logger);

        check(second.read('a')).equals('1');
        check(second.read('b')).equals('two');
      },
    );

    test('overwriting a key persists the latest value (upsert)', () async {
      final first = await DriftPreferencesStore.load(db, logger);
      await first.write('k', 'old');
      await first.write('k', 'new');

      final second = await DriftPreferencesStore.load(db, logger);

      check(second.read('k')).equals('new');
    });

    test('values persist as JSON string literals in valueJson', () async {
      final store = await DriftPreferencesStore.load(db, logger);
      await store.write('k', 'değer');

      final row = await (db.select(
        db.preferences,
      )..where((t) => t.key.equals('k'))).getSingle();
      check(row.valueJson).equals(jsonEncode('değer'));
    });

    test(
      'corrupt rows are logged and skipped at load — never thrown',
      () async {
        await _insertRaw(db, 'garbage', 'not json {{{');
        await _insertRaw(db, 'non-string', '42');
        await _insertRaw(db, 'good', jsonEncode('ok'));

        final store = await DriftPreferencesStore.load(db, logger);

        check(store.read('good')).equals('ok');
        check(store.read('garbage')).isNull();
        check(store.read('non-string')).isNull();
        verify(() => logger.warning(any())).called(2);
        verifyNever(() => logger.error(any(), any(), any()));
      },
    );

    test('a broken table at load logs the error and yields an empty (but '
        'working) store', () async {
      await db.customStatement('DROP TABLE preferences');

      final store = await DriftPreferencesStore.load(db, logger);

      verify(() => logger.error(any(), any(), any())).called(1);
      check(store.read('anything')).isNull();
      // The snapshot still serves session reads even though persistence is
      // gone: write completes normally and read sees the value.
      await store.write('k', 'v');
      check(store.read('k')).equals('v');
    });

    test('a failed durable write completes normally, keeps the snapshot, '
        'and logs', () async {
      final store = await DriftPreferencesStore.load(db, logger);
      await db.customStatement('DROP TABLE preferences');

      // Must not throw despite the insert failing underneath.
      await store.write('k', 'v');

      check(store.read('k')).equals('v');
      verify(() => logger.error(any(), any(), any())).called(1);
    });

    test('a write racing the database close completes normally, keeps the '
        'snapshot, and logs', () async {
      // A fire-and-forget SettingsCubit write can land after `getIt.reset()`
      // disposed the AppDatabase; drift then throws a StateError ("Can't
      // re-open a database after closing it"), which is an Error, not an
      // Exception — the never-throws contract must hold for it too.
      final store = await DriftPreferencesStore.load(db, logger);
      await db.close();

      await store.write('k', 'v');

      check(store.read('k')).equals('v');
      verify(() => logger.error(any(), any(), any())).called(1);
    });
  });
}
