import 'package:checks/checks.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:okey_acar_mi/core/db/app_database.dart';
import 'package:okey_acar_mi/core/game/game_mode.dart';
import 'package:okey_acar_mi/core/game/game_tile.dart';
import 'package:okey_acar_mi/core/game/indicator.dart';
import 'package:okey_acar_mi/core/game/tile_color.dart';
import 'package:okey_acar_mi/core/logging/app_logger.dart';
import 'package:okey_acar_mi/features/history/data/datasources/scan_local_data_source.dart';
import 'package:okey_acar_mi/features/history/data/dtos/scan_dto.dart';
import 'package:okey_acar_mi/features/history/domain/entities/history_filter.dart';
import 'package:okey_acar_mi/features/history/domain/entities/scan.dart';
import 'package:okey_acar_mi/features/history/domain/entities/scan_counts.dart';
import 'package:okey_acar_mi/features/history/domain/entities/scan_stats.dart';
import 'package:okey_acar_mi/features/history/domain/entities/scan_summary.dart';
import 'package:okey_acar_mi/features/solver/domain/entities/solve_verdict.dart';

class _MockAppLogger extends Mock implements AppLogger {}

final DateTime _t0 = DateTime.utc(2026, 6, 1, 12);

Scan _scan(
  String id, {
  String? ownerId,
  bool opened = true,
  int score = 104,
  DateTime? at,
  DateTime? updatedAt,
}) {
  final createdAt = at ?? _t0;
  return Scan(
    id: id,
    ownerId: ownerId,
    createdAt: createdAt,
    updatedAt: updatedAt ?? createdAt,
    tiles: const [
      GameTile(color: TileColor.red, number: 5),
      GameTile(color: TileColor.joker),
    ],
    indicator: const Indicator(color: TileColor.yellow, number: 13),
    gameMode: GameMode.oneZeroOne,
    summary: opened
        ? ScanSummary(
            kind: ScanVerdictKind.opens101,
            opened: true,
            score: score,
            openPath: OpenPath.melds,
          )
        : ScanSummary(
            kind: ScanVerdictKind.doesNotOpen101,
            opened: false,
            score: score,
            pointsShort: 101 - score,
          ),
  );
}

void main() {
  late AppDatabase db;
  late _MockAppLogger logger;
  late ScanLocalDataSource source;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    logger = _MockAppLogger();
    source = ScanLocalDataSource(db, logger);
  });

  tearDown(() => db.close());

  Future<List<String>> watchIds({
    HistoryFilter filter = HistoryFilter.all,
    int limit = 20,
    String? ownerId,
  }) async {
    final scans = await source
        .watchScans(filter: filter, limit: limit, ownerId: ownerId)
        .first;
    return [for (final scan in scans) scan.id];
  }

  Future<String> syncStateOf(String id) async {
    final row = await (db.select(
      db.scans,
    )..where((t) => t.id.equals(id))).getSingle();
    return row.syncState;
  }

  group('watchScans', () {
    test('orders by createdAtMs DESC with rowid DESC breaking equal-instant '
        'ties (insertion order, newest insert first)', () async {
      await source.insert(
        _scan('old', at: _t0.subtract(const Duration(days: 1))),
        syncState: ScanSyncStates.localOnly,
      );
      // Three rows pinned to the SAME instant — only rowid can order them.
      await source.insert(_scan('same-1'), syncState: ScanSyncStates.localOnly);
      await source.insert(_scan('same-2'), syncState: ScanSyncStates.localOnly);
      await source.insert(_scan('same-3'), syncState: ScanSyncStates.localOnly);

      check(
        await watchIds(),
      ).deepEquals(['same-3', 'same-2', 'same-1', 'old']);
    });

    test('scopes to the owner: null means guest rows only', () async {
      await source.insert(
        _scan('guest-1'),
        syncState: ScanSyncStates.localOnly,
      );
      await source.insert(
        _scan('owned-1', ownerId: 'u1'),
        syncState: ScanSyncStates.synced,
      );
      await source.insert(
        _scan('owned-2', ownerId: 'u2'),
        syncState: ScanSyncStates.synced,
      );

      check(await watchIds()).deepEquals(['guest-1']);
      check(await watchIds(ownerId: 'u1')).deepEquals(['owned-1']);
      check(await watchIds(ownerId: 'u2')).deepEquals(['owned-2']);
    });

    test('filters all / opened / closed', () async {
      await source.insert(_scan('open-1'), syncState: ScanSyncStates.localOnly);
      await source.insert(
        _scan('closed-1', opened: false, score: 60),
        syncState: ScanSyncStates.localOnly,
      );
      await source.insert(_scan('open-2'), syncState: ScanSyncStates.localOnly);

      check(await watchIds()).deepEquals(['open-2', 'closed-1', 'open-1']);
      check(
        await watchIds(filter: HistoryFilter.opened),
      ).deepEquals(['open-2', 'open-1']);
      check(
        await watchIds(filter: HistoryFilter.closed),
      ).deepEquals(['closed-1']);
    });

    test('caps at the limit window: 25 rows → limit 20 gives 20, limit 40 '
        'gives all 25', () async {
      for (var i = 1; i <= 25; i++) {
        await source.insert(
          _scan('s-$i', at: _t0.add(Duration(minutes: i))),
          syncState: ScanSyncStates.localOnly,
        );
      }

      final window20 = await watchIds();
      check(window20.length).equals(20);
      check(window20.first).equals('s-25'); // newest first
      check(window20.last).equals('s-6');

      final window40 = await watchIds(limit: 40);
      check(window40.length).equals(25);
      check(window40.last).equals('s-1');
    });

    test('a live watch re-emits when a matching row is inserted', () async {
      final emissions = <List<Scan>>[];
      final subscription = source
          .watchScans(filter: HistoryFilter.all, limit: 20)
          .listen(emissions.add);
      await pumpEventQueue();
      check(emissions.last).isEmpty();

      await source.insert(_scan('live'), syncState: ScanSyncStates.localOnly);
      await pumpEventQueue();

      check(emissions.last.single.id).equals('live');
      await subscription.cancel();
    });

    test('a malformed row is logged and skipped, never thrown', () async {
      await source.insert(_scan('good'), syncState: ScanSyncStates.localOnly);
      await db
          .into(db.scans)
          .insert(
            ScansCompanion.insert(
              id: 'bad',
              createdAtMs: _t0.millisecondsSinceEpoch,
              updatedAtMs: _t0.millisecondsSinceEpoch,
              gameMode: 'oneZeroOne',
              indicatorColor: const Value('red'),
              indicatorNumber: const Value(5),
              tilesJson: 'garbage',
              verdictKind: 'opens101',
              opened: true,
              score: 1,
            ),
          );

      check(await watchIds()).deepEquals(['good']);
      verify(() => logger.warning(any())).called(greaterThan(0));
    });
  });

  group('watchCounts', () {
    test('counts all / opened / closed per owner scope', () async {
      await source.insert(_scan('o1'), syncState: ScanSyncStates.localOnly);
      await source.insert(_scan('o2'), syncState: ScanSyncStates.localOnly);
      await source.insert(_scan('o3'), syncState: ScanSyncStates.localOnly);
      await source.insert(
        _scan('c1', opened: false, score: 50),
        syncState: ScanSyncStates.localOnly,
      );
      await source.insert(
        _scan('c2', opened: false, score: 60),
        syncState: ScanSyncStates.localOnly,
      );
      await source.insert(
        _scan('other', ownerId: 'u1'),
        syncState: ScanSyncStates.synced,
      );

      check(
        await source.watchCounts().first,
      ).equals(const ScanCounts(all: 5, opened: 3, closed: 2));
      check(
        await source.watchCounts(ownerId: 'u1').first,
      ).equals(const ScanCounts(all: 1, opened: 1, closed: 0));
    });

    test('an empty scope yields all-zero counts', () async {
      check(
        await source.watchCounts(ownerId: 'nobody').first,
      ).equals(const ScanCounts(all: 0, opened: 0, closed: 0));
    });
  });

  group('watchStats', () {
    test('aggregates COUNT, opened COUNT, and MAX(score)', () async {
      await source.insert(
        _scan('a', score: 90),
        syncState: ScanSyncStates.localOnly,
      );
      await source.insert(
        _scan('b', score: 142),
        syncState: ScanSyncStates.localOnly,
      );
      await source.insert(
        _scan('c', opened: false, score: 87),
        syncState: ScanSyncStates.localOnly,
      );

      check(
        await source.watchStats().first,
      ).equals(const ScanStats(total: 3, opened: 2, best: 142));
    });

    test(
      'an empty scope yields zeros (MAX over nothing is 0, not null)',
      () async {
        check(
          await source.watchStats().first,
        ).equals(const ScanStats(total: 0, opened: 0, best: 0));
      },
    );
  });

  group('upsertFromRemote (last-write-wins)', () {
    ScanDto dto(String id, {required DateTime updatedAt, int score = 104}) =>
        ScanDto.fromEntity(
          _scan(id, ownerId: 'u1', updatedAt: updatedAt, score: score),
        );

    test(
      'a newer remote doc replaces the local row and marks it synced',
      () async {
        await source.insert(
          _scan('x', ownerId: 'u1', updatedAt: _t0, score: 100),
          syncState: ScanSyncStates.pendingUpload,
        );

        await source.upsertFromRemote([
          dto('x', updatedAt: _t0.add(const Duration(hours: 1)), score: 120),
        ]);

        final scans = await source
            .watchScans(filter: HistoryFilter.all, limit: 10, ownerId: 'u1')
            .first;
        check(scans.single.summary.score).equals(120);
        check(await syncStateOf('x')).equals(ScanSyncStates.synced);
      },
    );

    test('an older remote doc is ignored', () async {
      await source.insert(
        _scan('x', ownerId: 'u1', updatedAt: _t0, score: 100),
        syncState: ScanSyncStates.pendingUpload,
      );

      await source.upsertFromRemote([
        dto('x', updatedAt: _t0.subtract(const Duration(hours: 1)), score: 1),
      ]);

      final scans = await source
          .watchScans(filter: HistoryFilter.all, limit: 10, ownerId: 'u1')
          .first;
      check(scans.single.summary.score).equals(100);
      check(await syncStateOf('x')).equals(ScanSyncStates.pendingUpload);
    });

    test('an equal-timestamp remote doc wins (>= rule)', () async {
      await source.insert(
        _scan('x', ownerId: 'u1', updatedAt: _t0, score: 100),
        syncState: ScanSyncStates.pendingUpload,
      );

      await source.upsertFromRemote([dto('x', updatedAt: _t0, score: 99)]);

      final scans = await source
          .watchScans(filter: HistoryFilter.all, limit: 10, ownerId: 'u1')
          .first;
      check(scans.single.summary.score).equals(99);
      check(await syncStateOf('x')).equals(ScanSyncStates.synced);
    });

    test('unknown ids are inserted as synced rows', () async {
      await source.upsertFromRemote([
        dto('fresh-1', updatedAt: _t0),
        dto('fresh-2', updatedAt: _t0.add(const Duration(minutes: 1))),
      ]);

      check(
        await watchIds(ownerId: 'u1'),
      ).deepEquals(['fresh-2', 'fresh-1']);
      check(await syncStateOf('fresh-1')).equals(ScanSyncStates.synced);
    });
  });

  group('adoptGuestScans', () {
    test('re-owns every guest row to the uid, marks pendingUpload, and bumps '
        'updatedAtMs to the given instant; other owners untouched', () async {
      await source.insert(_scan('g1'), syncState: ScanSyncStates.localOnly);
      await source.insert(_scan('g2'), syncState: ScanSyncStates.localOnly);
      await source.insert(
        _scan('theirs', ownerId: 'u2'),
        syncState: ScanSyncStates.synced,
      );
      final adoptionInstant = _t0.add(const Duration(days: 1));

      await source.adoptGuestScans(toOwnerId: 'u1', at: adoptionInstant);

      check(await watchIds()).isEmpty(); // no guest rows remain
      final adopted = await source
          .watchScans(filter: HistoryFilter.all, limit: 10, ownerId: 'u1')
          .first;
      check([for (final s in adopted) s.id]).unorderedEquals(['g1', 'g2']);
      for (final scan in adopted) {
        check(scan.updatedAt).equals(adoptionInstant);
        check(scan.createdAt).equals(_t0); // creation instant untouched
      }
      check(await syncStateOf('g1')).equals(ScanSyncStates.pendingUpload);
      check(await syncStateOf('g2')).equals(ScanSyncStates.pendingUpload);
      check(await syncStateOf('theirs')).equals(ScanSyncStates.synced);
      check(await watchIds(ownerId: 'u2')).deepEquals(['theirs']);
    });
  });

  group('pendingUploads / markSynced', () {
    test("pendingUploads returns only the owner's pendingUpload rows, "
        'oldest first', () async {
      await source.insert(
        _scan('p2', ownerId: 'u1', at: _t0.add(const Duration(hours: 2))),
        syncState: ScanSyncStates.pendingUpload,
      );
      await source.insert(
        _scan('p1', ownerId: 'u1', at: _t0),
        syncState: ScanSyncStates.pendingUpload,
      );
      await source.insert(
        _scan('done', ownerId: 'u1'),
        syncState: ScanSyncStates.synced,
      );
      await source.insert(
        _scan('foreign', ownerId: 'u2'),
        syncState: ScanSyncStates.pendingUpload,
      );
      await source.insert(_scan('guest'), syncState: ScanSyncStates.localOnly);

      final pending = await source.pendingUploads('u1');

      check([for (final dto in pending) dto.id]).deepEquals(['p1', 'p2']);
      check(pending.first.ownerId).equals('u1');
    });

    test('markSynced flips the given ids to synced; an empty list is a '
        'no-op', () async {
      await source.insert(
        _scan('p1', ownerId: 'u1'),
        syncState: ScanSyncStates.pendingUpload,
      );
      await source.insert(
        _scan('p2', ownerId: 'u1'),
        syncState: ScanSyncStates.pendingUpload,
      );

      await source.markSynced([]);
      check((await source.pendingUploads('u1')).length).equals(2);

      await source.markSynced(['p1']);
      check([
        for (final dto in await source.pendingUploads('u1')) dto.id,
      ]).deepEquals(['p2']);
      check(await syncStateOf('p1')).equals(ScanSyncStates.synced);
    });
  });

  group('deleteAllForOwner', () {
    setUp(() async {
      await source.insert(_scan('g1'), syncState: ScanSyncStates.localOnly);
      await source.insert(
        _scan('o1', ownerId: 'u1'),
        syncState: ScanSyncStates.synced,
      );
      await source.insert(
        _scan('o2', ownerId: 'u2'),
        syncState: ScanSyncStates.synced,
      );
    });

    test('null deletes guest rows only', () async {
      await source.deleteAllForOwner(null);

      check(await watchIds()).isEmpty();
      check(await watchIds(ownerId: 'u1')).deepEquals(['o1']);
      check(await watchIds(ownerId: 'u2')).deepEquals(['o2']);
    });

    test("a uid deletes that owner's rows only", () async {
      await source.deleteAllForOwner('u1');

      check(await watchIds(ownerId: 'u1')).isEmpty();
      check(await watchIds()).deepEquals(['g1']);
      check(await watchIds(ownerId: 'u2')).deepEquals(['o2']);
    });
  });

  group('insert', () {
    test('insertOnConflictUpdate replaces an existing id in place', () async {
      await source.insert(
        _scan('x', score: 100),
        syncState: ScanSyncStates.localOnly,
      );
      await source.insert(
        _scan('x', score: 120),
        syncState: ScanSyncStates.pendingUpload,
      );

      final scans = await source
          .watchScans(filter: HistoryFilter.all, limit: 10)
          .first;
      check(scans.single.summary.score).equals(120);
      check(await syncStateOf('x')).equals(ScanSyncStates.pendingUpload);
    });
  });
}
