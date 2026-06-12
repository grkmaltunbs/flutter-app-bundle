import 'dart:async';

import 'package:checks/checks.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:okey_acar_mi/core/db/app_database.dart';
import 'package:okey_acar_mi/core/error/failure.dart';
import 'package:okey_acar_mi/core/game/game_mode.dart';
import 'package:okey_acar_mi/core/game/game_tile.dart';
import 'package:okey_acar_mi/core/game/indicator.dart';
import 'package:okey_acar_mi/core/game/tile_color.dart';
import 'package:okey_acar_mi/core/logging/app_logger.dart';
import 'package:okey_acar_mi/core/network/connectivity_service.dart';
import 'package:okey_acar_mi/core/time/clock.dart';
import 'package:okey_acar_mi/features/auth/domain/entities/app_user.dart';
import 'package:okey_acar_mi/features/auth/domain/repositories/auth_repository.dart';
import 'package:okey_acar_mi/features/history/data/datasources/scan_local_data_source.dart';
import 'package:okey_acar_mi/features/history/data/datasources/scan_remote_data_source.dart';
import 'package:okey_acar_mi/features/history/data/dtos/scan_dto.dart';
import 'package:okey_acar_mi/features/history/data/repositories/scan_repository_impl.dart';
import 'package:okey_acar_mi/features/history/domain/entities/history_filter.dart';
import 'package:okey_acar_mi/features/history/domain/entities/scan.dart';
import 'package:okey_acar_mi/features/history/domain/entities/scan_summary.dart';
import 'package:okey_acar_mi/features/solver/domain/entities/solve_verdict.dart';

class _MockScanRemoteDataSource extends Mock implements ScanRemoteDataSource {}

class _MockAuthRepository extends Mock implements AuthRepository {}

class _MockAppLogger extends Mock implements AppLogger {}

const AppUser _u1 = AppUser(
  id: 'u1',
  email: 'u1@demo.app',
  emailVerified: true,
  providers: [AuthProvider.password],
);

final DateTime _t0 = DateTime.utc(2026, 6, 1, 12);

Scan _scan(
  String id, {
  String? ownerId,
  DateTime? at,
  DateTime? updatedAt,
  int score = 104,
}) {
  final createdAt = at ?? _t0;
  return Scan(
    id: id,
    ownerId: ownerId,
    createdAt: createdAt,
    updatedAt: updatedAt ?? createdAt,
    tiles: const [GameTile(color: TileColor.red, number: 5)],
    indicator: const Indicator(color: TileColor.yellow, number: 13),
    gameMode: GameMode.oneZeroOne,
    summary: ScanSummary(
      kind: ScanVerdictKind.opens101,
      opened: true,
      score: score,
      openPath: OpenPath.melds,
    ),
  );
}

void main() {
  late AppDatabase db;
  late ScanLocalDataSource local;
  late _MockScanRemoteDataSource remote;
  late _MockAuthRepository auth;
  late FakeConnectivityService connectivity;
  late _MockAppLogger logger;
  late StreamController<AppUser?> authStream;
  late ScanRepositoryImpl repository;

  setUpAll(() {
    registerFallbackValue(<ScanDto>[]);
  });

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    logger = _MockAppLogger();
    local = ScanLocalDataSource(db, logger);
    remote = _MockScanRemoteDataSource();
    auth = _MockAuthRepository();
    connectivity = FakeConnectivityService();
    authStream = StreamController<AppUser?>.broadcast();
    when(auth.authStateChanges).thenAnswer((_) => authStream.stream);
    when(() => auth.currentUser).thenReturn(null);
    when(() => remote.fetchAll(any())).thenAnswer((_) async => []);
    when(() => remote.uploadAll(any())).thenAnswer((_) async {});
    when(() => remote.deleteAllForOwner(any())).thenAnswer((_) async {});
    repository = ScanRepositoryImpl(
      local,
      remote,
      auth,
      connectivity,
      const FakeClock(),
      logger,
    );
  });

  tearDown(() async {
    await repository.dispose();
    await authStream.close();
    connectivity.dispose();
    await db.close();
  });

  Future<String> syncStateOf(String id) async {
    final row = await (db.select(
      db.scans,
    )..where((t) => t.id.equals(id))).getSingle();
    return row.syncState;
  }

  group('watch* owner re-scoping', () {
    test("watchScans re-emits the new owner's rows when the auth stream "
        'switches user', () async {
      await local.insert(_scan('guest-1'), syncState: ScanSyncStates.localOnly);
      await local.insert(
        _scan('owned-1', ownerId: 'u1'),
        syncState: ScanSyncStates.synced,
      );

      final emissions = <List<String>>[];
      final subscription = repository
          .watchScans(filter: HistoryFilter.all, limit: 20)
          .listen(
            (scans) => emissions.add([for (final s in scans) s.id]),
          );

      authStream.add(null); // guest
      await pumpEventQueue(times: 50);
      check(emissions.last).deepEquals(['guest-1']);

      authStream.add(_u1); // sign-in: re-scope to u1
      await pumpEventQueue(times: 50);
      check(emissions.last).deepEquals(['owned-1']);

      authStream.add(null); // sign-out: back to guest rows
      await pumpEventQueue(times: 50);
      check(emissions.last).deepEquals(['guest-1']);

      await subscription.cancel();
    });

    test('watchCounts and watchStats re-scope the same way', () async {
      await local.insert(_scan('guest-1'), syncState: ScanSyncStates.localOnly);
      await local.insert(
        _scan('owned-1', ownerId: 'u1', score: 142),
        syncState: ScanSyncStates.synced,
      );
      await local.insert(
        _scan('owned-2', ownerId: 'u1', score: 110),
        syncState: ScanSyncStates.synced,
      );

      final counts = <int>[];
      final bests = <int>[];
      final countsSub = repository.watchCounts().listen(
        (c) => counts.add(c.all),
      );
      final statsSub = repository.watchStats().listen(
        (s) => bests.add(s.best),
      );

      authStream.add(null);
      await pumpEventQueue(times: 50);
      check(counts.last).equals(1);
      check(bests.last).equals(104);

      authStream.add(_u1);
      await pumpEventQueue(times: 50);
      check(counts.last).equals(2);
      check(bests.last).equals(142);

      await countsSub.cancel();
      await statsSub.cancel();
    });
  });

  group('save', () {
    test(
      'a guest scan is stored localOnly and never pokes the remote',
      () async {
        await repository.save(_scan('g1'));
        await pumpEventQueue(times: 50);

        check(await syncStateOf('g1')).equals(ScanSyncStates.localOnly);
        verifyNever(() => remote.fetchAll(any()));
        verifyNever(() => remote.uploadAll(any()));
      },
    );

    test('an owned scan is stored pendingUpload and a background sync '
        'pushes it (pull happens too), ending synced', () async {
      when(() => auth.currentUser).thenReturn(_u1);

      await repository.save(_scan('o1', ownerId: 'u1'));
      await pumpEventQueue(times: 50);

      verify(() => remote.fetchAll('u1')).called(1);
      final uploaded =
          verify(() => remote.uploadAll(captureAny())).captured.single
              as List<ScanDto>;
      check([for (final dto in uploaded) dto.id]).deepEquals(['o1']);
      check(await syncStateOf('o1')).equals(ScanSyncStates.synced);
    });
  });

  group('syncNow', () {
    test('is a no-op for a guest', () async {
      await repository.syncNow();

      verifyNever(() => remote.fetchAll(any()));
      verifyNever(() => remote.uploadAll(any()));
    });

    test('is a no-op while offline', () async {
      when(() => auth.currentUser).thenReturn(_u1);
      connectivity.setOnline(online: false);

      await repository.syncNow();

      verifyNever(() => remote.fetchAll(any()));
    });

    test('pulls before pushing; the pulled docs land via LWW upsert and the '
        'pushed rows are marked synced afterwards', () async {
      when(() => auth.currentUser).thenReturn(_u1);
      // A pending local row to push, and a newer local row the stale remote
      // copy must NOT clobber.
      await local.insert(
        _scan('pending-1', ownerId: 'u1'),
        syncState: ScanSyncStates.pendingUpload,
      );
      await local.insert(
        _scan('newer-local', ownerId: 'u1', updatedAt: _t0, score: 120),
        syncState: ScanSyncStates.pendingUpload,
      );
      final order = <String>[];
      when(() => remote.fetchAll('u1')).thenAnswer((_) async {
        order.add('pull');
        return [
          ScanDto.fromEntity(_scan('remote-1', ownerId: 'u1')),
          ScanDto.fromEntity(
            _scan(
              'newer-local',
              ownerId: 'u1',
              updatedAt: _t0.subtract(const Duration(hours: 1)),
              score: 1,
            ),
          ),
        ];
      });
      when(() => remote.uploadAll(any())).thenAnswer((_) async {
        order.add('push');
      });

      await repository.syncNow();

      check(order).deepEquals(['pull', 'push']);
      // The pulled doc was upserted as synced.
      check(await syncStateOf('remote-1')).equals(ScanSyncStates.synced);
      // LWW: the stale remote copy lost against the newer local row.
      final scans = await local
          .watchScans(filter: HistoryFilter.all, limit: 10, ownerId: 'u1')
          .first;
      check(
        scans.singleWhere((s) => s.id == 'newer-local').summary.score,
      ).equals(120);
      // Both pending rows were pushed, then marked synced.
      final uploaded =
          verify(() => remote.uploadAll(captureAny())).captured.single
              as List<ScanDto>;
      check([
        for (final dto in uploaded) dto.id,
      ]).unorderedEquals(['pending-1', 'newer-local']);
      check(await syncStateOf('pending-1')).equals(ScanSyncStates.synced);
      check(await syncStateOf('newer-local')).equals(ScanSyncStates.synced);
    });

    test('skips the push entirely when nothing is pending', () async {
      when(() => auth.currentUser).thenReturn(_u1);

      await repository.syncNow();

      verify(() => remote.fetchAll('u1')).called(1);
      verifyNever(() => remote.uploadAll(any()));
    });

    test('concurrent calls are serialized: calls during a running sync '
        'coalesce into exactly one trailing rerun', () async {
      when(() => auth.currentUser).thenReturn(_u1);
      var fetchCalls = 0;
      final firstFetchStarted = Completer<void>();
      final gate = Completer<List<ScanDto>>();
      when(() => remote.fetchAll('u1')).thenAnswer((_) {
        fetchCalls++;
        if (fetchCalls == 1) {
          firstFetchStarted.complete();
          return gate.future;
        }
        return Future.value(<ScanDto>[]);
      });

      final first = repository.syncNow();
      await firstFetchStarted.future;
      final second = repository.syncNow(); // queues the trailing rerun
      final third = repository.syncNow(); // coalesces into the same rerun
      gate.complete(<ScanDto>[]);
      await Future.wait([first, second, third]);

      check(fetchCalls).equals(2);
    });

    test('a remote failure is logged, never thrown', () async {
      when(() => auth.currentUser).thenReturn(_u1);
      when(() => remote.fetchAll('u1')).thenThrow(const Failure.network());

      await repository.syncNow(); // must complete normally

      verify(
        () => logger.error('Scan sync failed', any<Object?>(), any()),
      ).called(1);
    });

    test('a failed upload leaves the rows pending for the next sync', () async {
      when(() => auth.currentUser).thenReturn(_u1);
      await local.insert(
        _scan('p1', ownerId: 'u1'),
        syncState: ScanSyncStates.pendingUpload,
      );
      when(() => remote.uploadAll(any())).thenThrow(const Failure.network());

      await repository.syncNow();

      check(await syncStateOf('p1')).equals(ScanSyncStates.pendingUpload);
      verify(
        () => logger.error('Scan sync failed', any<Object?>(), any()),
      ).called(1);
    });
  });

  group('sync triggers', () {
    test('a sign-in event on the auth stream triggers a sync', () async {
      when(() => auth.currentUser).thenReturn(_u1);

      authStream.add(_u1);
      await pumpEventQueue(times: 50);

      verify(() => remote.fetchAll('u1')).called(1);
    });

    test('a sign-out (null) event does not trigger a sync', () async {
      authStream.add(null);
      await pumpEventQueue(times: 50);

      verifyNever(() => remote.fetchAll(any()));
    });

    test('the offline → online edge triggers a sync', () async {
      when(() => auth.currentUser).thenReturn(_u1);
      // Let the construction-time replay (online: true) settle first.
      await pumpEventQueue(times: 50);
      clearInteractions(remote);

      connectivity.setOnline(online: false);
      await pumpEventQueue(times: 50);
      verifyNever(() => remote.fetchAll(any()));

      connectivity.setOnline(online: true);
      await pumpEventQueue(times: 50);
      verify(() => remote.fetchAll('u1')).called(1);
    });
  });

  group('adoptGuestScans', () {
    test('re-owns guest rows locally and syncs them up', () async {
      when(() => auth.currentUser).thenReturn(_u1);
      await local.insert(_scan('g1'), syncState: ScanSyncStates.localOnly);
      await local.insert(_scan('g2'), syncState: ScanSyncStates.localOnly);

      await repository.adoptGuestScans(toUserId: 'u1');

      final uploaded =
          verify(() => remote.uploadAll(captureAny())).captured.single
              as List<ScanDto>;
      check([for (final dto in uploaded) dto.id]).unorderedEquals(['g1', 'g2']);
      for (final dto in uploaded) {
        check(dto.ownerId).equals('u1');
        // The LWW key was bumped to the injected clock's instant.
        check(dto.updatedAtMs).equals(FakeClock.seed.millisecondsSinceEpoch);
      }
      check(await syncStateOf('g1')).equals(ScanSyncStates.synced);
      check(await syncStateOf('g2')).equals(ScanSyncStates.synced);
    });
  });

  group('deleteAllForOwner', () {
    test('deletes locally and remotely', () async {
      await local.insert(
        _scan('o1', ownerId: 'u1'),
        syncState: ScanSyncStates.synced,
      );
      await local.insert(_scan('g1'), syncState: ScanSyncStates.localOnly);

      await repository.deleteAllForOwner('u1');

      verify(() => remote.deleteAllForOwner('u1')).called(1);
      final remaining = await db.select(db.scans).get();
      check([for (final row in remaining) row.id]).deepEquals(['g1']);
    });

    test('a remote purge Failure is logged and rethrown (account deletion '
        'must know)', () async {
      when(
        () => remote.deleteAllForOwner('u1'),
      ).thenThrow(const Failure.network());

      await check(repository.deleteAllForOwner('u1')).throws<NetworkFailure>();
      verify(
        () => logger.error('Remote scan purge failed', any<Object?>(), any()),
      ).called(1);
    });

    test('a non-Failure remote error is mapped to a Failure', () async {
      when(
        () => remote.deleteAllForOwner('u1'),
      ).thenThrow(StateError('firestore exploded'));

      await check(repository.deleteAllForOwner('u1')).throws<Failure>();
    });
  });

  group('dispose', () {
    test('cancels the sync triggers: later auth events sync nothing', () async {
      when(() => auth.currentUser).thenReturn(_u1);

      await repository.dispose();
      authStream.add(_u1);
      await pumpEventQueue(times: 50);

      verifyNever(() => remote.fetchAll(any()));
    });
  });
}
