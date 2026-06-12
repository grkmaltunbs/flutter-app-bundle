import 'package:checks/checks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:okey_acar_mi/core/di/injection.dart';
import 'package:okey_acar_mi/core/game/game_mode.dart';
import 'package:okey_acar_mi/core/game/game_tile.dart';
import 'package:okey_acar_mi/core/game/indicator.dart';
import 'package:okey_acar_mi/core/game/tile_color.dart';
import 'package:okey_acar_mi/core/logging/app_logger.dart';
import 'package:okey_acar_mi/core/network/connectivity_service.dart';
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
import 'package:okey_acar_mi/features/solver/domain/entities/solve_verdict.dart';
import 'package:okey_acar_mi/l10n/app_localizations.dart';

/// Responsive size matrix from `CLAUDE.md`: smallest phone, typical phone,
/// largest phone, tablet — each at textScale 1.0 and 2.0, in both locales.
/// A `RenderFlex` overflow throws in debug, so asserting no exception per
/// pump catches an overflow deterministically.
const _matrix = <Size>[
  Size(320, 568),
  Size(393, 852),
  Size(430, 932),
  Size(834, 1194),
];

const _textScales = <double>[1, 2];

const _locales = <Locale>[Locale('tr'), Locale('en')];

class _MockAppLogger extends Mock implements AppLogger {}

/// A [WatchScans] pinned to one window — the overflow guard needs pinned
/// content, not live queries.
class _FixedWatchScans implements WatchScans {
  const _FixedWatchScans(this.scans);

  final List<Scan> scans;

  @override
  Stream<List<Scan>> call({
    required HistoryFilter filter,
    required int limit,
  }) => Stream.value(scans);
}

class _FixedWatchScanCounts implements WatchScanCounts {
  const _FixedWatchScanCounts(this.counts);

  final ScanCounts counts;

  @override
  Stream<ScanCounts> call() => Stream.value(counts);
}

/// A [ConnectivityService] pinned offline so the banner is part of the
/// worst-case layout.
class _OfflineConnectivity implements ConnectivityService {
  const _OfflineConnectivity();

  @override
  Stream<bool> get onlineStream => Stream.value(false);

  @override
  Future<bool> isOnline() async => false;
}

GameTile _t(TileColor color, int number) =>
    GameTile(color: color, number: number);

/// The hardest legal rack: 21 tiles (101 max) incl. a joker.
final List<GameTile> _rack21 = [
  for (var i = 0; i < 20; i++) _t(TileColor.values[i % 4], i % 13 + 1),
  const GameTile(color: TileColor.joker),
];

Scan _scan(int index, {List<GameTile>? tiles, ScanSummary? summary}) => Scan(
  id: 'overflow-$index',
  createdAt: DateTime.utc(2025, 12).add(Duration(hours: index)),
  updatedAt: DateTime.utc(2025, 12).add(Duration(hours: index)),
  tiles:
      tiles ??
      [for (var i = 0; i < 14; i++) _t(TileColor.values[i % 4], i % 13 + 1)],
  indicator: const Indicator(color: TileColor.yellow, number: 13),
  gameMode: GameMode.oneZeroOne,
  summary:
      summary ??
      const ScanSummary(
        kind: ScanVerdictKind.opens101,
        opened: true,
        score: 104,
        openPath: OpenPath.melds,
      ),
);

/// 22 scans: one 21-tile rack, an okey tiles-to-win card (longest pill), a
/// closed card — the worst-case list content.
final List<Scan> _scans22 = [
  _scan(0, tiles: _rack21),
  _scan(
    1,
    summary: const ScanSummary(
      kind: ScanVerdictKind.okeyOutcome,
      opened: false,
      score: 54,
      tilesToWin: 12,
      okeyPath: OkeyPath.meldsAndPair,
    ),
  ),
  _scan(
    2,
    summary: const ScanSummary(
      kind: ScanVerdictKind.doesNotOpen101,
      opened: false,
      score: 60,
      pointsShort: 41,
    ),
  ),
  for (var i = 3; i < 22; i++) _scan(i),
];

const ScanCounts _counts = ScanCounts(all: 122, opened: 88, closed: 34);

void main() {
  // Demo DI: the scan cards resolve getIt<Clock> at build time.
  setUp(() async => configureDependencies('demo'));
  tearDown(() async => getIt.reset());

  final scenarios = <String, HistoryBloc Function()>{
    // Populated window (22 cards incl. a 21-tile rack) + chips + the
    // offline banner all visible at once.
    'populated, 21-tile rack, offline banner': () => HistoryBloc(
      _FixedWatchScans(_scans22),
      const _FixedWatchScanCounts(_counts),
      const _OfflineConnectivity(),
      _MockAppLogger(),
    ),
    // Scans exist but none match the filter: chips + no-results copy.
    'no-results under a filter': () => HistoryBloc(
      const _FixedWatchScans([]),
      const _FixedWatchScanCounts(_counts),
      const _OfflineConnectivity(),
      _MockAppLogger(),
    ),
    // The no-scans-at-all empty state with its CTA.
    'empty state': () => HistoryBloc(
      const _FixedWatchScans([]),
      const _FixedWatchScanCounts(ScanCounts(all: 0, opened: 0, closed: 0)),
      const _OfflineConnectivity(),
      _MockAppLogger(),
    ),
  };

  // The bloc is OWNED by `BlocProvider(create:)` (production wiring): the
  // provider closes it unawaited at unmount. Never `await` a
  // `HistoryBloc.close()` under testWidgets — its `droppable()` event
  // transformer keeps `Bloc.close()` from completing inside FakeAsync,
  // which deadlocks the test.
  Widget harness({
    required Size size,
    required double textScale,
    required Locale locale,
    required HistoryBloc Function() buildBloc,
  }) {
    return MaterialApp(
      theme: AppTheme.light(AppAccent.sage, TileStyle.classic),
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: const [Locale('tr'), Locale('en')],
      home: MediaQuery(
        data: MediaQueryData(
          size: size,
          textScaler: TextScaler.linear(textScale),
        ),
        child: BlocProvider<HistoryBloc>(
          create: (_) => buildBloc()..add(const HistoryEvent.started()),
          child: const HistoryView(),
        ),
      ),
    );
  }

  for (final MapEntry(key: name, value: buildBloc) in scenarios.entries) {
    for (final locale in _locales) {
      for (final size in _matrix) {
        for (final textScale in _textScales) {
          testWidgets(
            'HistoryView ($name) no overflow '
            '@ ${locale.languageCode} $size x$textScale',
            (tester) async {
              tester.view.physicalSize = size;
              tester.view.devicePixelRatio = 1.0;
              addTearDown(tester.view.resetPhysicalSize);
              addTearDown(tester.view.resetDevicePixelRatio);

              await tester.pumpWidget(
                harness(
                  size: size,
                  textScale: textScale,
                  locale: locale,
                  buildBloc: buildBloc,
                ),
              );
              await tester.pumpAndSettle();

              check(tester.takeException()).isNull();
            },
          );
        }
      }
    }
  }
}
