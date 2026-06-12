import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:checks/checks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:okey_acar_mi/core/game/game_mode.dart';
import 'package:okey_acar_mi/core/game/game_tile.dart';
import 'package:okey_acar_mi/core/game/indicator.dart';
import 'package:okey_acar_mi/core/game/tile_color.dart';
import 'package:okey_acar_mi/core/logging/app_logger.dart';
import 'package:okey_acar_mi/core/network/connectivity_service.dart';
import 'package:okey_acar_mi/features/history/domain/entities/history_filter.dart';
import 'package:okey_acar_mi/features/history/domain/entities/scan.dart';
import 'package:okey_acar_mi/features/history/domain/entities/scan_counts.dart';
import 'package:okey_acar_mi/features/history/domain/entities/scan_summary.dart';
import 'package:okey_acar_mi/features/history/domain/usecases/watch_scan_counts.dart';
import 'package:okey_acar_mi/features/history/domain/usecases/watch_scans.dart';
import 'package:okey_acar_mi/features/history/presentation/blocs/history_bloc.dart';
import 'package:okey_acar_mi/features/solver/domain/entities/solve_verdict.dart';

class _MockWatchScans extends Mock implements WatchScans {}

class _MockWatchScanCounts extends Mock implements WatchScanCounts {}

class _MockConnectivityService extends Mock implements ConnectivityService {}

class _MockAppLogger extends Mock implements AppLogger {}

Scan _scan(String id) => Scan(
  id: id,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
  tiles: const [GameTile(color: TileColor.red, number: 5)],
  indicator: const Indicator(color: TileColor.yellow, number: 13),
  gameMode: GameMode.oneZeroOne,
  summary: const ScanSummary(
    kind: ScanVerdictKind.opens101,
    opened: true,
    score: 104,
    openPath: OpenPath.melds,
  ),
);

List<Scan> _scans(int count) => [for (var i = 1; i <= count; i++) _scan('s$i')];

const ScanCounts _counts = ScanCounts(all: 12, opened: 8, closed: 4);

void main() {
  late _MockWatchScans watchScans;
  late _MockWatchScanCounts watchCounts;
  late _MockConnectivityService connectivity;
  late _MockAppLogger logger;
  late StreamController<List<Scan>> scansStream;
  late StreamController<ScanCounts> countsStream;
  late StreamController<bool> onlineStream;

  setUpAll(() {
    registerFallbackValue(HistoryFilter.all);
  });

  setUp(() {
    watchScans = _MockWatchScans();
    watchCounts = _MockWatchScanCounts();
    connectivity = _MockConnectivityService();
    logger = _MockAppLogger();
    scansStream = StreamController<List<Scan>>.broadcast();
    countsStream = StreamController<ScanCounts>.broadcast();
    onlineStream = StreamController<bool>.broadcast();
    when(
      () => watchScans(
        filter: any(named: 'filter'),
        limit: any(named: 'limit'),
      ),
    ).thenAnswer((_) => scansStream.stream);
    when(watchCounts.call).thenAnswer((_) => countsStream.stream);
    when(
      () => connectivity.onlineStream,
    ).thenAnswer((_) => onlineStream.stream);
  });

  tearDown(() async {
    await scansStream.close();
    await countsStream.close();
    await onlineStream.close();
  });

  HistoryBloc build() =>
      HistoryBloc(watchScans, watchCounts, connectivity, logger);

  /// Drives a started bloc to `ready` with [scans] and [counts] delivered.
  Future<HistoryBloc> startedAndReady({
    List<Scan>? scans,
    ScanCounts counts = _counts,
  }) async {
    final bloc = build()..add(const HistoryEvent.started());
    await pumpEventQueue();
    scansStream.add(scans ?? _scans(3));
    countsStream.add(counts);
    await pumpEventQueue();
    check(bloc.state.status).equals(HistoryStatus.ready);
    return bloc;
  }

  group('started', () {
    blocTest<HistoryBloc, HistoryState>(
      'subscribes with the default window and leaves loading only once BOTH '
      'scans and counts have delivered',
      build: build,
      act: (bloc) async {
        bloc.add(const HistoryEvent.started());
        await pumpEventQueue();
        scansStream.add(_scans(3));
        await pumpEventQueue();
        countsStream.add(_counts);
        await pumpEventQueue();
      },
      expect: () => [
        // Scans alone: still loading (counts not yet arrived).
        HistoryState(scans: _scans(3), hasMore: false),
        HistoryState(
          status: HistoryStatus.ready,
          scans: _scans(3),
          hasMore: false,
          counts: _counts,
        ),
      ],
      verify: (_) {
        verify(
          () => watchScans(filter: HistoryFilter.all, limit: 20),
        ).called(1);
        verify(watchCounts.call).called(1);
      },
    );

    test(
      'isEmpty when ready with zero scans anywhere; never isNoResults',
      () async {
        final bloc = await startedAndReady(
          scans: const [],
          counts: const ScanCounts(all: 0, opened: 0, closed: 0),
        );
        addTearDown(bloc.close);

        check(bloc.state.isEmpty).isTrue();
        check(bloc.state.isNoResults).isFalse();
      },
    );

    test('a full first window keeps hasMore true', () async {
      final bloc = await startedAndReady(scans: _scans(20));
      addTearDown(bloc.close);

      check(bloc.state.hasMore).isTrue();
    });
  });

  group('filterChanged', () {
    blocTest<HistoryBloc, HistoryState>(
      'resets the page window and re-watches with limit 20; an empty '
      'filtered result is isNoResults (scans exist, none match)',
      build: build,
      act: (bloc) async {
        bloc.add(const HistoryEvent.started());
        await pumpEventQueue();
        scansStream.add(_scans(3));
        countsStream.add(_counts);
        await pumpEventQueue();
        bloc.add(const HistoryEvent.filterChanged(HistoryFilter.opened));
        await pumpEventQueue();
        scansStream.add(const []);
        await pumpEventQueue();
      },
      expect: () => [
        HistoryState(scans: _scans(3), hasMore: false),
        HistoryState(
          status: HistoryStatus.ready,
          scans: _scans(3),
          hasMore: false,
          counts: _counts,
        ),
        HistoryState(
          status: HistoryStatus.ready,
          scans: _scans(3),
          counts: _counts,
          filter: HistoryFilter.opened,
        ),
        const HistoryState(
          status: HistoryStatus.ready,
          hasMore: false,
          counts: _counts,
          filter: HistoryFilter.opened,
        ),
      ],
      verify: (bloc) {
        verify(
          () => watchScans(filter: HistoryFilter.all, limit: 20),
        ).called(1);
        verify(
          () => watchScans(filter: HistoryFilter.opened, limit: 20),
        ).called(1);
        check(bloc.state.isNoResults).isTrue();
        check(bloc.state.isEmpty).isFalse();
      },
    );

    test(
      're-selecting the active filter neither emits nor resubscribes',
      () async {
        final bloc = await startedAndReady();
        addTearDown(bloc.close);
        clearInteractions(watchScans);

        bloc.add(const HistoryEvent.filterChanged(HistoryFilter.all));
        await pumpEventQueue();

        verifyNever(
          () => watchScans(
            filter: any(named: 'filter'),
            limit: any(named: 'limit'),
          ),
        );
      },
    );

    test(
      'filterChanged after loadMore resets pagesRequested back to 1',
      () async {
        final bloc = await startedAndReady(scans: _scans(20));
        addTearDown(bloc.close);
        bloc.add(const HistoryEvent.loadMoreRequested());
        await pumpEventQueue();
        check(bloc.state.pagesRequested).equals(2);

        bloc.add(const HistoryEvent.filterChanged(HistoryFilter.closed));
        await pumpEventQueue();

        check(bloc.state.pagesRequested).equals(1);
        check(bloc.state.hasMore).isTrue();
        check(bloc.state.loadingMore).isFalse();
        verify(
          () => watchScans(filter: HistoryFilter.closed, limit: 20),
        ).called(1);
      },
    );
  });

  group('loadMoreRequested', () {
    test('grows the window to limit 40, flags loadingMore until the next '
        'emission, and clears hasMore when the emission is short', () async {
      final bloc = await startedAndReady(scans: _scans(20));
      addTearDown(bloc.close);

      bloc.add(const HistoryEvent.loadMoreRequested());
      await pumpEventQueue();
      check(bloc.state.loadingMore).isTrue();
      check(bloc.state.pagesRequested).equals(2);
      verify(
        () => watchScans(filter: HistoryFilter.all, limit: 40),
      ).called(1);

      scansStream.add(_scans(25)); // 25 < 40: the well ran dry
      await pumpEventQueue();
      check(bloc.state.loadingMore).isFalse();
      check(bloc.state.scans.length).equals(25);
      check(bloc.state.hasMore).isFalse();
    });

    test('a full second window keeps hasMore true', () async {
      final bloc = await startedAndReady(scans: _scans(20));
      addTearDown(bloc.close);

      bloc.add(const HistoryEvent.loadMoreRequested());
      await pumpEventQueue();
      scansStream.add(_scans(40));
      await pumpEventQueue();

      check(bloc.state.hasMore).isTrue();
      check(bloc.state.pagesRequested).equals(2);
    });

    test('is droppable: a double-fire while loading yields one increment '
        'and one resubscription', () async {
      final bloc = await startedAndReady(scans: _scans(20));
      addTearDown(bloc.close);
      clearInteractions(watchScans);

      bloc
        ..add(const HistoryEvent.loadMoreRequested())
        ..add(const HistoryEvent.loadMoreRequested());
      await pumpEventQueue();

      check(bloc.state.pagesRequested).equals(2);
      verify(
        () => watchScans(filter: HistoryFilter.all, limit: 40),
      ).called(1);
      verifyNever(() => watchScans(filter: HistoryFilter.all, limit: 60));
    });

    test('is ignored once hasMore is false', () async {
      final bloc = await startedAndReady(scans: _scans(5));
      addTearDown(bloc.close);
      check(bloc.state.hasMore).isFalse();
      clearInteractions(watchScans);

      bloc.add(const HistoryEvent.loadMoreRequested());
      await pumpEventQueue();

      check(bloc.state.pagesRequested).equals(1);
      verifyNever(
        () => watchScans(
          filter: any(named: 'filter'),
          limit: any(named: 'limit'),
        ),
      );
    });
  });

  group('connectivity', () {
    test('online changes flip state.online both ways', () async {
      final bloc = await startedAndReady();
      addTearDown(bloc.close);
      check(bloc.state.online).isTrue();

      onlineStream.add(false);
      await pumpEventQueue();
      check(bloc.state.online).isFalse();

      onlineStream.add(true);
      await pumpEventQueue();
      check(bloc.state.online).isTrue();
    });

    test(
      'a connectivity stream error is logged but never fails the screen',
      () async {
        final bloc = await startedAndReady();
        addTearDown(bloc.close);

        onlineStream.addError(StateError('radio gone'));
        await pumpEventQueue();

        check(bloc.state.status).equals(HistoryStatus.ready);
        verify(
          () =>
              logger.error('Connectivity stream failed', any<Object?>(), any()),
        ).called(1);
      },
    );
  });

  group('stream failure & retry', () {
    test('a scans stream error lands in failure and stops the watchers — '
        'late emissions cannot resurrect the screen', () async {
      final bloc = await startedAndReady();
      addTearDown(bloc.close);

      scansStream.addError(StateError('db exploded'));
      await pumpEventQueue();
      check(bloc.state.status).equals(HistoryStatus.failure);

      // The watchers were cancelled: nothing flips the failure screen back.
      scansStream.add(_scans(9));
      countsStream.add(_counts);
      await pumpEventQueue();
      check(bloc.state.status).equals(HistoryStatus.failure);
      check(bloc.state.scans.length).equals(3);
    });

    test('a counts stream error also lands in failure', () async {
      final bloc = await startedAndReady();
      addTearDown(bloc.close);

      countsStream.addError(StateError('aggregate exploded'));
      await pumpEventQueue();

      check(bloc.state.status).equals(HistoryStatus.failure);
      verify(
        () =>
            logger.error('History counts stream failed', any<Object?>(), any()),
      ).called(1);
    });

    test('retryRequested re-enters loading, resubscribes, and reaches ready '
        'again once both streams redeliver', () async {
      final bloc = await startedAndReady();
      addTearDown(bloc.close);
      scansStream.addError(StateError('boom'));
      await pumpEventQueue();
      check(bloc.state.status).equals(HistoryStatus.failure);
      clearInteractions(watchScans);

      bloc.add(const HistoryEvent.retryRequested());
      await pumpEventQueue();
      check(bloc.state.status).equals(HistoryStatus.loading);
      verify(
        () => watchScans(filter: HistoryFilter.all, limit: 20),
      ).called(1);

      scansStream.add(_scans(2));
      countsStream.add(_counts);
      await pumpEventQueue();
      check(bloc.state.status).equals(HistoryStatus.ready);
      check(bloc.state.scans.length).equals(2);
    });
  });

  group('close', () {
    test('cancels every subscription — no listeners survive, no late '
        'emissions land', () async {
      final bloc = await startedAndReady();

      await bloc.close();

      check(scansStream.hasListener).isFalse();
      check(countsStream.hasListener).isFalse();
      check(onlineStream.hasListener).isFalse();
    });
  });
}
