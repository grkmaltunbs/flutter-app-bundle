import 'dart:io';

import 'package:checks/checks.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:okey_acar_mi/core/db/app_database.dart';
import 'package:path/path.dart' as p;

/// A fully-populated scans row (every nullable column set).
ScansCompanion _fullRow(String id) => ScansCompanion.insert(
  id: id,
  ownerId: const Value('user-1'),
  createdAtMs: 1000,
  updatedAtMs: 2000,
  gameMode: 'oneZeroOne',
  indicatorColor: const Value('red'),
  indicatorNumber: const Value(5),
  tilesJson: '[{"c":"red","n":5},{"c":"joker"}]',
  verdictKind: 'opens101',
  opened: true,
  score: 104,
  openPath: const Value('melds'),
  pointsShort: const Value(13),
  tilesToWin: const Value(2),
  okeyPath: const Value('meldsAndPair'),
  syncState: const Value('synced'),
);

/// A minimal scans row (every nullable column absent, defaults in play).
ScansCompanion _minimalRow(String id) => ScansCompanion.insert(
  id: id,
  createdAtMs: 500,
  updatedAtMs: 500,
  gameMode: 'okey',
  indicatorColor: const Value('blue'),
  indicatorNumber: const Value(13),
  tilesJson: '[{"c":"blue","n":1}]',
  verdictKind: 'okeyOutcome',
  opened: false,
  score: 0,
);

void main() {
  group('AppDatabase schema smoke', () {
    late AppDatabase db;

    setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
    tearDown(() => db.close());

    test(
      'inserts and reads back a row with every nullable column set',
      () async {
        await db.into(db.scans).insert(_fullRow('scan-full'));

        final row = await (db.select(
          db.scans,
        )..where((t) => t.id.equals('scan-full'))).getSingle();
        check(row.id).equals('scan-full');
        check(row.ownerId).equals('user-1');
        check(row.createdAtMs).equals(1000);
        check(row.updatedAtMs).equals(2000);
        check(row.gameMode).equals('oneZeroOne');
        check(row.indicatorColor).equals('red');
        check(row.indicatorNumber).equals(5);
        check(row.tilesJson).equals('[{"c":"red","n":5},{"c":"joker"}]');
        check(row.verdictKind).equals('opens101');
        check(row.opened).isTrue();
        check(row.score).equals(104);
        check(row.openPath).equals('melds');
        check(row.pointsShort).equals(13);
        check(row.tilesToWin).equals(2);
        check(row.okeyPath).equals('meldsAndPair');
        check(row.syncState).equals('synced');
      },
    );

    test('nullable columns read back as null and syncState defaults to '
        'localOnly', () async {
      await db.into(db.scans).insert(_minimalRow('scan-min'));

      final row = await (db.select(
        db.scans,
      )..where((t) => t.id.equals('scan-min'))).getSingle();
      check(row.ownerId).isNull();
      check(row.openPath).isNull();
      check(row.pointsShort).isNull();
      check(row.tilesToWin).isNull();
      check(row.okeyPath).isNull();
      check(row.syncState).equals('localOnly');
    });

    test(
      'id is the primary key: inserting the same id twice conflicts',
      () async {
        await db.into(db.scans).insert(_minimalRow('dup'));

        await check(
          db.into(db.scans).insert(_minimalRow('dup')),
        ).throws<Object>();
      },
    );

    test('wipeScansForTest deletes every row', () async {
      await db.into(db.scans).insert(_fullRow('a'));
      await db.into(db.scans).insert(_minimalRow('b'));

      await db.wipeScansForTest();

      check(await db.select(db.scans).get()).isEmpty();
    });
  });

  group('AppDatabase restart persistence (file-backed)', () {
    // Host-side stand-in for the device acceptance "scans persist across
    // restarts": the DI-provided database is in-memory under `flutter test`,
    // so the drift layer is exercised here against a real temp FILE; the
    // end-to-end restart is asserted on-device by
    // `integration_test/history_flow_test.dart`.
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('okey_db_test');
    });
    tearDown(() async {
      await tempDir.delete(recursive: true);
    });

    test('rows written before close() are intact when a new AppDatabase '
        'reopens the same file', () async {
      final file = File(p.join(tempDir.path, 'scans.sqlite'));

      final first = AppDatabase.forTesting(NativeDatabase(file));
      await first.into(first.scans).insert(_fullRow('persisted-full'));
      await first.into(first.scans).insert(_minimalRow('persisted-min'));
      await first.close();

      final second = AppDatabase.forTesting(NativeDatabase(file));
      try {
        final rows = await (second.select(
          second.scans,
        )..orderBy([(t) => OrderingTerm(expression: t.id)])).get();

        check(rows.length).equals(2);
        check(rows[0].id).equals('persisted-full');
        check(rows[0].ownerId).equals('user-1');
        check(rows[0].score).equals(104);
        check(rows[0].openPath).equals('melds');
        check(rows[0].syncState).equals('synced');
        check(rows[1].id).equals('persisted-min');
        check(rows[1].ownerId).isNull();
        check(rows[1].syncState).equals('localOnly');
      } finally {
        await second.close();
      }
    });

    test(
      'a wipe before close persists too: the reopened file is empty',
      () async {
        final file = File(p.join(tempDir.path, 'wiped.sqlite'));

        final first = AppDatabase.forTesting(NativeDatabase(file));
        await first.into(first.scans).insert(_minimalRow('gone'));
        await first.wipeScansForTest();
        await first.close();

        final second = AppDatabase.forTesting(NativeDatabase(file));
        try {
          check(await second.select(second.scans).get()).isEmpty();
        } finally {
          await second.close();
        }
      },
    );
  });
}
