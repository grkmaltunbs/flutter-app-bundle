import 'dart:async';

import 'package:checks/checks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:okey_acar_mi/core/game/game_mode.dart';
import 'package:okey_acar_mi/core/game/game_tile.dart';
import 'package:okey_acar_mi/core/game/indicator.dart';
import 'package:okey_acar_mi/core/game/tile_color.dart';
import 'package:okey_acar_mi/core/logging/app_logger.dart';
import 'package:okey_acar_mi/features/history/domain/entities/scan.dart';
import 'package:okey_acar_mi/features/history/domain/entities/scan_stats.dart';
import 'package:okey_acar_mi/features/history/domain/entities/scan_summary.dart';
import 'package:okey_acar_mi/features/history/domain/usecases/watch_last_scan.dart';
import 'package:okey_acar_mi/features/history/domain/usecases/watch_scan_stats.dart';
import 'package:okey_acar_mi/features/home/presentation/cubit/home_cubit.dart';
import 'package:okey_acar_mi/features/solver/domain/entities/solve_verdict.dart';

class _MockWatchLastScan extends Mock implements WatchLastScan {}

class _MockWatchScanStats extends Mock implements WatchScanStats {}

class _MockAppLogger extends Mock implements AppLogger {}

final Scan _scan = Scan(
  id: 'newest',
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

const ScanStats _stats = ScanStats(total: 5, opened: 3, best: 142);
const ScanStats _zeroStats = ScanStats(total: 0, opened: 0, best: 0);

void main() {
  late _MockWatchLastScan watchLastScan;
  late _MockWatchScanStats watchStats;
  late _MockAppLogger logger;
  late StreamController<Scan?> lastScanStream;
  late StreamController<ScanStats> statsStream;

  setUp(() {
    watchLastScan = _MockWatchLastScan();
    watchStats = _MockWatchScanStats();
    logger = _MockAppLogger();
    lastScanStream = StreamController<Scan?>.broadcast();
    statsStream = StreamController<ScanStats>.broadcast();
    when(watchLastScan.call).thenAnswer((_) => lastScanStream.stream);
    when(watchStats.call).thenAnswer((_) => statsStream.stream);
  });

  tearDown(() async {
    await lastScanStream.close();
    await statsStream.close();
  });

  HomeCubit build() => HomeCubit(watchLastScan, watchStats, logger);

  group('HomeCubit', () {
    test('subscribes on construction and surfaces the last scan + stats; '
        'ready flips only once BOTH have delivered', () async {
      final cubit = build();
      addTearDown(cubit.close);
      final states = <HomeState>[];
      final subscription = cubit.stream.listen(states.add);

      lastScanStream.add(_scan);
      await pumpEventQueue();
      check(states).deepEquals([HomeState(lastScan: _scan)]);
      check(cubit.state.ready).isFalse();

      statsStream.add(_stats);
      await pumpEventQueue();
      check(states.last).equals(
        HomeState(lastScan: _scan, stats: _stats, ready: true),
      );

      await subscription.cancel();
    });

    test(
      'stats arriving first also hold ready until the last scan lands',
      () async {
        final cubit = build();
        addTearDown(cubit.close);

        statsStream.add(_stats);
        await pumpEventQueue();
        check(cubit.state.ready).isFalse();
        check(cubit.state.stats).equals(_stats);

        lastScanStream.add(_scan);
        await pumpEventQueue();
        check(cubit.state.ready).isTrue();
      },
    );

    test('a null last scan is a legitimate first delivery: empty history '
        'reaches ready with null lastScan + zero stats', () async {
      final cubit = build();
      addTearDown(cubit.close);

      lastScanStream.add(null);
      statsStream.add(_zeroStats);
      await pumpEventQueue();

      check(cubit.state).equals(
        const HomeState(stats: _zeroStats, ready: true),
      );
      check(cubit.state.lastScan).isNull();
    });

    test('a live update replaces the last scan in place', () async {
      final cubit = build();
      addTearDown(cubit.close);
      lastScanStream.add(null);
      statsStream.add(_zeroStats);
      await pumpEventQueue();

      lastScanStream.add(_scan);
      statsStream.add(const ScanStats(total: 1, opened: 1, best: 104));
      await pumpEventQueue();

      check(cubit.state.lastScan).equals(_scan);
      check(cubit.state.stats).equals(
        const ScanStats(total: 1, opened: 1, best: 104),
      );
    });

    test('a stream error keeps the last state (logged, no failure state), '
        'and later deliveries still land', () async {
      final cubit = build();
      addTearDown(cubit.close);
      lastScanStream.add(_scan);
      statsStream.add(_stats);
      await pumpEventQueue();
      final before = cubit.state;

      lastScanStream.addError(StateError('db hiccup'));
      statsStream.addError(StateError('db hiccup'));
      await pumpEventQueue();

      check(cubit.state).equals(before);
      verify(
        () =>
            logger.error('Home last-scan stream failed', any<Object?>(), any()),
      ).called(1);
      verify(
        () => logger.error('Home stats stream failed', any<Object?>(), any()),
      ).called(1);

      // The subscriptions survive the error (no cancelOnError).
      statsStream.add(const ScanStats(total: 9, opened: 9, best: 200));
      await pumpEventQueue();
      check(cubit.state.stats).equals(
        const ScanStats(total: 9, opened: 9, best: 200),
      );
    });

    test('close cancels both subscriptions', () async {
      final cubit = build();

      await cubit.close();

      check(lastScanStream.hasListener).isFalse();
      check(statsStream.hasListener).isFalse();
    });
  });
}
