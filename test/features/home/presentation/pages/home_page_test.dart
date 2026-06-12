import 'dart:async';

import 'package:checks/checks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:okey_acar_mi/core/di/injection.dart';
import 'package:okey_acar_mi/core/game/game_tile.dart';
import 'package:okey_acar_mi/core/game/indicator.dart';
import 'package:okey_acar_mi/core/game/tile_color.dart';
import 'package:okey_acar_mi/core/logging/app_logger.dart';
import 'package:okey_acar_mi/core/router/app_router.dart';
import 'package:okey_acar_mi/core/theme/app_accent.dart';
import 'package:okey_acar_mi/core/theme/app_theme.dart';
import 'package:okey_acar_mi/core/theme/tile_style.dart';
import 'package:okey_acar_mi/features/history/domain/entities/scan.dart';
import 'package:okey_acar_mi/features/history/domain/entities/scan_stats.dart';
import 'package:okey_acar_mi/features/history/domain/entities/scan_summary.dart';
import 'package:okey_acar_mi/features/history/domain/usecases/watch_last_scan.dart';
import 'package:okey_acar_mi/features/history/domain/usecases/watch_scan_stats.dart';
import 'package:okey_acar_mi/features/home/presentation/cubit/home_cubit.dart';
import 'package:okey_acar_mi/features/home/presentation/pages/home_page.dart';
import 'package:okey_acar_mi/features/result/domain/entities/result_args.dart';
import 'package:okey_acar_mi/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:okey_acar_mi/features/solver/domain/entities/solve_verdict.dart';
import 'package:okey_acar_mi/l10n/app_localizations.dart';

class _MockWatchLastScan extends Mock implements WatchLastScan {}

class _MockWatchScanStats extends Mock implements WatchScanStats {}

class _MockAppLogger extends Mock implements AppLogger {}

final AppLocalizations _l10n = lookupAppLocalizations(const Locale('en'));

final Scan _scan = Scan(
  id: 'newest',
  createdAt: DateTime.utc(2025, 12, 30, 21, 48),
  updatedAt: DateTime.utc(2025, 12, 30, 21, 48),
  tiles: const [
    GameTile(color: TileColor.red, number: 5),
    GameTile(color: TileColor.joker),
  ],
  indicator: const Indicator(color: TileColor.yellow, number: 13),
  gameMode: GameMode.oneZeroOne,
  summary: const ScanSummary(
    kind: ScanVerdictKind.opens101,
    opened: true,
    score: 104,
    openPath: OpenPath.melds,
  ),
);

void main() {
  late _MockWatchLastScan watchLastScan;
  late _MockWatchScanStats watchStats;
  late StreamController<Scan?> lastScanStream;
  late StreamController<ScanStats> statsStream;
  late Object? pushedExtra;

  setUp(() async {
    // Demo DI: the last-scan card resolves getIt<Clock> at build time.
    await configureDependencies('demo');
    watchLastScan = _MockWatchLastScan();
    watchStats = _MockWatchScanStats();
    lastScanStream = StreamController<Scan?>.broadcast();
    statsStream = StreamController<ScanStats>.broadcast();
    pushedExtra = null;
    when(watchLastScan.call).thenAnswer((_) => lastScanStream.stream);
    when(watchStats.call).thenAnswer((_) => statsStream.stream);
  });

  tearDown(() async {
    await lastScanStream.close();
    await statsStream.close();
    await getIt.reset();
  });

  Future<void> pumpHome(WidgetTester tester) async {
    final cubit = HomeCubit(watchLastScan, watchStats, _MockAppLogger());
    addTearDown(cubit.close);
    final router = GoRouter(
      initialLocation: AppRoutes.home,
      routes: [
        GoRoute(
          path: AppRoutes.home,
          builder: (context, state) => MultiBlocProvider(
            providers: [
              BlocProvider<SettingsCubit>(create: (_) => SettingsCubit()),
              BlocProvider<HomeCubit>.value(value: cubit),
            ],
            child: const HomeView(),
          ),
        ),
        GoRoute(
          path: AppRoutes.result,
          builder: (context, state) {
            pushedExtra = state.extra;
            return const Scaffold(body: Center(child: Text('result-stub')));
          },
        ),
        GoRoute(
          path: AppRoutes.camera,
          builder: (context, state) =>
              const Scaffold(body: Center(child: Text('camera-stub'))),
        ),
        GoRoute(
          path: AppRoutes.history,
          builder: (context, state) =>
              const Scaffold(body: Center(child: Text('history-stub'))),
        ),
        GoRoute(
          path: AppRoutes.tutorial,
          builder: (context, state) =>
              const Scaffold(body: Center(child: Text('tutorial-stub'))),
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp.router(
        theme: AppTheme.light(AppAccent.sage, TileStyle.classic),
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: const [Locale('tr'), Locale('en')],
        routerConfig: router,
      ),
    );
    await tester.pump();
  }

  Future<void> deliver(
    WidgetTester tester, {
    required ScanStats stats,
    Scan? lastScan,
  }) async {
    lastScanStream.add(lastScan);
    statsStream.add(stats);
    await tester.pumpAndSettle();
  }

  group('last-scan slot', () {
    testWidgets('shows the inviting empty slot while no scan exists, and no '
        'stats row at total 0', (tester) async {
      await pumpHome(tester);
      await deliver(
        tester,
        stats: const ScanStats(total: 0, opened: 0, best: 0),
      );

      check(find.text(_l10n.homeEmptyTitle).evaluate()).length.equals(1);
      check(find.text(_l10n.homeEmptyBody).evaluate()).length.equals(1);
      check(find.byKey(const ValueKey('home-last-scan')).evaluate()).isEmpty();
      check(find.byKey(const ValueKey('home-stats')).evaluate()).isEmpty();
      check(tester.takeException()).isNull();
    });

    testWidgets('shows the live ScanCard once a scan exists', (tester) async {
      await pumpHome(tester);
      await deliver(
        tester,
        lastScan: _scan,
        stats: const ScanStats(total: 1, opened: 1, best: 104),
      );

      check(
        find.byKey(const ValueKey('home-last-scan')).evaluate(),
      ).length.equals(1);
      check(find.text(_l10n.homeEmptyTitle).evaluate()).isEmpty();
      check(tester.takeException()).isNull();
    });

    testWidgets('tapping the card pushes /result with ResultArgs.replay of '
        'the newest scan', (tester) async {
      await pumpHome(tester);
      await deliver(
        tester,
        lastScan: _scan,
        stats: const ScanStats(total: 1, opened: 1, best: 104),
      );

      final card = find.byKey(const ValueKey('home-last-scan'));
      await tester.ensureVisible(card);
      await tester.pumpAndSettle();
      await tester.tap(card);
      await tester.pumpAndSettle();

      check(find.text('result-stub').evaluate()).length.equals(1);
      final extra = check(pushedExtra).isA<ResultArgsReplay>();
      extra.has((args) => args.scan.id, 'scan.id').equals('newest');
      check(tester.takeException()).isNull();
    });
  });

  group('stats row', () {
    testWidgets('renders total, open rate (computed %), and best once scans '
        'exist', (tester) async {
      await pumpHome(tester);
      await deliver(
        tester,
        lastScan: _scan,
        stats: const ScanStats(total: 5, opened: 3, best: 142),
      );

      final stats = find.byKey(const ValueKey('home-stats'));
      await tester.ensureVisible(stats);
      await tester.pumpAndSettle();
      check(stats.evaluate()).length.equals(1);
      Finder inStats(String text) =>
          find.descendant(of: stats, matching: find.text(text));
      check(inStats('5').evaluate()).length.equals(1);
      check(inStats('60%').evaluate()).length.equals(1); // 3/5 rounded
      check(inStats('142').evaluate()).length.equals(1);
      check(tester.takeException()).isNull();
    });

    testWidgets('live-updates when a new scan lands', (tester) async {
      await pumpHome(tester);
      await deliver(
        tester,
        lastScan: _scan,
        stats: const ScanStats(total: 1, opened: 1, best: 104),
      );

      statsStream.add(const ScanStats(total: 2, opened: 1, best: 120));
      await tester.pumpAndSettle();

      final stats = find.byKey(const ValueKey('home-stats'));
      Finder inStats(String text) =>
          find.descendant(of: stats, matching: find.text(text));
      check(inStats('2').evaluate()).length.equals(1);
      check(inStats('50%').evaluate()).length.equals(1);
      check(inStats('120').evaluate()).length.equals(1);
      check(tester.takeException()).isNull();
    });
  });
}
