import 'dart:async';
import 'dart:ui' show Tristate;

import 'package:checks/checks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:okey_acar_mi/core/di/injection.dart';
import 'package:okey_acar_mi/core/game/game_mode.dart';
import 'package:okey_acar_mi/core/game/game_tile.dart';
import 'package:okey_acar_mi/core/game/indicator.dart';
import 'package:okey_acar_mi/core/game/tile_color.dart';
import 'package:okey_acar_mi/core/logging/app_logger.dart';
import 'package:okey_acar_mi/core/router/app_router.dart';
import 'package:okey_acar_mi/core/theme/app_accent.dart';
import 'package:okey_acar_mi/core/theme/app_theme.dart';
import 'package:okey_acar_mi/core/theme/tile_style.dart';
import 'package:okey_acar_mi/features/history/domain/entities/history_filter.dart';
import 'package:okey_acar_mi/features/history/domain/entities/scan.dart';
import 'package:okey_acar_mi/features/history/domain/entities/scan_counts.dart';
import 'package:okey_acar_mi/features/history/domain/entities/scan_summary.dart';
import 'package:okey_acar_mi/features/history/domain/usecases/watch_scan_counts.dart';
import 'package:okey_acar_mi/features/history/domain/usecases/watch_scans.dart';
import 'package:okey_acar_mi/features/history/presentation/blocs/history_bloc.dart';
import 'package:okey_acar_mi/features/history/presentation/pages/history_page.dart';
import 'package:okey_acar_mi/features/result/domain/entities/result_args.dart';
import 'package:okey_acar_mi/features/solver/domain/entities/solve_verdict.dart';
import 'package:okey_acar_mi/l10n/app_localizations.dart';

class _MockWatchScans extends Mock implements WatchScans {}

class _MockWatchScanCounts extends Mock implements WatchScanCounts {}

class _MockAppLogger extends Mock implements AppLogger {}

final AppLocalizations _l10n = lookupAppLocalizations(const Locale('en'));

Scan _scan(String id) => Scan(
  id: id,
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

List<Scan> _scans(int count) => [for (var i = 1; i <= count; i++) _scan('s$i')];

void main() {
  late _MockWatchScans watchScans;
  late _MockWatchScanCounts watchCounts;
  late _MockAppLogger logger;
  late StreamController<List<Scan>> scansStream;
  late StreamController<ScanCounts> countsStream;
  late Object? pushedExtra;

  setUpAll(() {
    registerFallbackValue(HistoryFilter.all);
  });

  setUp(() async {
    // Demo DI: the page's scan cards resolve getIt<Clock> at build time.
    await configureDependencies('demo');
    watchScans = _MockWatchScans();
    watchCounts = _MockWatchScanCounts();
    logger = _MockAppLogger();
    scansStream = StreamController<List<Scan>>.broadcast();
    countsStream = StreamController<ScanCounts>.broadcast();
    pushedExtra = null;
    when(
      () => watchScans(
        filter: any(named: 'filter'),
        limit: any(named: 'limit'),
      ),
    ).thenAnswer((_) => scansStream.stream);
    when(watchCounts.call).thenAnswer((_) => countsStream.stream);
  });

  tearDown(() async {
    await scansStream.close();
    await countsStream.close();
    await getIt.reset();
  });

  /// Pumps `HistoryView` under a started bloc built on the mocked streams,
  /// inside a router exposing stub /result and /camera destinations.
  ///
  /// The bloc is OWNED by `BlocProvider(create:)` (production wiring): the
  /// provider closes it unawaited at unmount. Never `await` a
  /// `HistoryBloc.close()` under testWidgets — its `droppable()` event
  /// transformer keeps `Bloc.close()` from completing inside FakeAsync,
  /// which deadlocks the test.
  Future<HistoryBloc> pumpHistory(WidgetTester tester) async {
    final router = GoRouter(
      initialLocation: AppRoutes.history,
      routes: [
        GoRoute(
          path: AppRoutes.history,
          builder: (context, state) => BlocProvider<HistoryBloc>(
            create: (_) =>
                HistoryBloc(watchScans, watchCounts, logger)
                  ..add(const HistoryEvent.started()),
            child: const HistoryView(),
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
    return BlocProvider.of<HistoryBloc>(
      tester.element(find.byType(HistoryView)),
    );
  }

  /// Delivers one scans + counts emission and settles.
  Future<void> deliver(
    WidgetTester tester, {
    required List<Scan> scans,
    required ScanCounts counts,
  }) async {
    scansStream.add(scans);
    countsStream.add(counts);
    await tester.pumpAndSettle();
  }

  group('load phases', () {
    testWidgets('shows the spinner until both streams deliver', (tester) async {
      await pumpHistory(tester);

      check(
        find.byType(CircularProgressIndicator).evaluate(),
      ).length.equals(1);
      check(find.text(_l10n.historyEmptyTitle).evaluate()).isEmpty();
      check(tester.takeException()).isNull();
    });

    testWidgets('a stream failure shows the retry view; retry resubscribes '
        'back to the live list', (tester) async {
      await pumpHistory(tester);
      await deliver(
        tester,
        scans: _scans(2),
        counts: const ScanCounts(all: 2, opened: 2, closed: 0),
      );

      scansStream.addError(StateError('db exploded'));
      await tester.pumpAndSettle();
      check(
        find.text(_l10n.historyLoadFailedTitle).evaluate(),
      ).length.equals(1);

      await tester.tap(find.byKey(const ValueKey('history-retry')));
      await tester.pump();
      check(find.byType(CircularProgressIndicator).evaluate()).length.equals(1);

      await deliver(
        tester,
        scans: _scans(2),
        counts: const ScanCounts(all: 2, opened: 2, closed: 0),
      );
      check(find.text(_l10n.historyLoadFailedTitle).evaluate()).isEmpty();
      check(find.byKey(const ValueKey('scan-card-s1')).evaluate()).isNotEmpty();
      check(tester.takeException()).isNull();
    });
  });

  group('empty vs no-results', () {
    testWidgets('zero scans anywhere shows the inviting empty state (with '
        'CTA), never the no-results copy', (tester) async {
      await pumpHistory(tester);
      await deliver(
        tester,
        scans: const [],
        counts: const ScanCounts(all: 0, opened: 0, closed: 0),
      );

      check(find.text(_l10n.historyEmptyTitle).evaluate()).length.equals(1);
      check(find.text(_l10n.historyEmptyBody).evaluate()).length.equals(1);
      check(find.text(_l10n.historyEmptyCta).evaluate()).length.equals(1);
      check(find.text(_l10n.historyNoResultsTitle).evaluate()).isEmpty();
      check(tester.takeException()).isNull();
    });

    testWidgets('scans that all fail the filter show the DISTINCT no-results '
        'copy, with the chips still visible', (tester) async {
      await pumpHistory(tester);
      await deliver(
        tester,
        scans: const [],
        counts: const ScanCounts(all: 5, opened: 0, closed: 5),
      );

      check(find.text(_l10n.historyNoResultsTitle).evaluate()).length.equals(1);
      check(find.text(_l10n.historyNoResultsBody).evaluate()).length.equals(1);
      check(find.text(_l10n.historyEmptyTitle).evaluate()).isEmpty();
      check(find.text(_l10n.historyEmptyCta).evaluate()).isEmpty();
      check(
        find.byKey(const ValueKey('history-filter-all')).evaluate(),
      ).length.equals(1);
      check(tester.takeException()).isNull();
    });
  });

  group('filter chips', () {
    testWidgets('show the live counts and mark the active filter selected', (
      tester,
    ) async {
      await pumpHistory(tester);
      await deliver(
        tester,
        scans: _scans(3),
        counts: const ScanCounts(all: 12, opened: 8, closed: 4),
      );

      Finder inChip(String key, String text) => find.descendant(
        of: find.byKey(ValueKey(key)),
        matching: find.text(text),
      );
      check(inChip('history-filter-all', '12').evaluate()).length.equals(1);
      check(inChip('history-filter-opened', '8').evaluate()).length.equals(1);
      check(inChip('history-filter-closed', '4').evaluate()).length.equals(1);

      final handle = tester.ensureSemantics();
      check(
        tester
            .getSemantics(find.byKey(const ValueKey('history-filter-all')))
            .flagsCollection
            .isSelected,
      ).equals(Tristate.isTrue);
      check(
        tester
            .getSemantics(find.byKey(const ValueKey('history-filter-opened')))
            .flagsCollection
            .isSelected,
      ).equals(Tristate.isFalse);
      handle.dispose();
      check(tester.takeException()).isNull();
    });

    testWidgets('tapping a chip fires filterChanged and re-watches with the '
        'new filter', (tester) async {
      final bloc = await pumpHistory(tester);
      await deliver(
        tester,
        scans: _scans(3),
        counts: const ScanCounts(all: 12, opened: 8, closed: 4),
      );

      await tester.tap(find.byKey(const ValueKey('history-filter-opened')));
      await tester.pump();

      check(bloc.state.filter).equals(HistoryFilter.opened);
      verify(
        () => watchScans(filter: HistoryFilter.opened, limit: 20),
      ).called(1);
      check(tester.takeException()).isNull();
    });
  });

  group('pagination footer', () {
    testWidgets('scrolling near the end grows the window and shows the '
        'loading-more footer until the next delivery', (tester) async {
      final bloc = await pumpHistory(tester);
      await deliver(
        tester,
        scans: _scans(20),
        counts: const ScanCounts(all: 25, opened: 25, closed: 0),
      );
      check(find.byType(CircularProgressIndicator).evaluate()).isEmpty();

      // The real user path: the near-end scroll notification fires
      // loadMoreRequested; the footer spinner appears at the list tail.
      await tester.drag(
        find.byType(CustomScrollView),
        const Offset(0, -4000),
      );
      await tester.pump();
      check(bloc.state.loadingMore).isTrue();
      check(bloc.state.pagesRequested).equals(2);
      check(
        find.byType(CircularProgressIndicator).evaluate(),
      ).length.equals(1);

      scansStream.add(_scans(25));
      await tester.pumpAndSettle();
      check(bloc.state.loadingMore).isFalse();
      check(find.byType(CircularProgressIndicator).evaluate()).isEmpty();
      check(tester.takeException()).isNull();
    });
  });

  group('tap-to-replay', () {
    testWidgets('tapping a card pushes /result with ResultArgs.replay of '
        'that scan', (tester) async {
      await pumpHistory(tester);
      await deliver(
        tester,
        scans: _scans(2),
        counts: const ScanCounts(all: 2, opened: 2, closed: 0),
      );

      await tester.tap(find.byKey(const ValueKey('scan-card-s2')));
      await tester.pumpAndSettle();

      check(find.text('result-stub').evaluate()).length.equals(1);
      final extra = check(pushedExtra).isA<ResultArgsReplay>();
      extra.has((args) => args.scan.id, 'scan.id').equals('s2');
      check(tester.takeException()).isNull();
    });
  });
}
