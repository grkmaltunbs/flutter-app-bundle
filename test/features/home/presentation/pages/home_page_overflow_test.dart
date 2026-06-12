import 'package:checks/checks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:okey_acar_mi/core/di/injection.dart';
import 'package:okey_acar_mi/core/game/game_tile.dart';
import 'package:okey_acar_mi/core/game/indicator.dart';
import 'package:okey_acar_mi/core/game/tile_color.dart';
import 'package:okey_acar_mi/core/logging/app_logger.dart';
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
import 'package:okey_acar_mi/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:okey_acar_mi/features/solver/domain/entities/solve_verdict.dart';
import 'package:okey_acar_mi/l10n/app_localizations.dart';

/// Responsive size matrix from `CLAUDE.md`. The bare (empty-state) HomePage
/// is already guarded by `test/features/screens_overflow_test.dart`; this
/// file pins the POPULATED dashboard — the live last-scan card with the max
/// 21-tile rack plus the three-card stats strip — which that guard cannot
/// reach (the demo DI database is empty on the host).
const _matrix = <Size>[
  Size(320, 568),
  Size(393, 852),
  Size(430, 932),
  Size(834, 1194),
];

const _textScales = <double>[1, 2];

const _locales = <Locale>[Locale('tr'), Locale('en')];

class _MockAppLogger extends Mock implements AppLogger {}

class _FixedWatchLastScan implements WatchLastScan {
  const _FixedWatchLastScan(this.scan);

  final Scan scan;

  @override
  Stream<Scan?> call() => Stream.value(scan);
}

class _FixedWatchScanStats implements WatchScanStats {
  const _FixedWatchScanStats(this.stats);

  final ScanStats stats;

  @override
  Stream<ScanStats> call() => Stream.value(stats);
}

/// The newest scan with the hardest content: a 21-tile rack and the long
/// "tiles to win" pill (neutral tone, widest label).
final Scan _scan21 = Scan(
  id: 'newest',
  createdAt: DateTime.utc(2025, 12, 30, 21, 48),
  updatedAt: DateTime.utc(2025, 12, 30, 21, 48),
  tiles: [
    for (var i = 0; i < 20; i++)
      GameTile(color: TileColor.values[i % 4], number: i % 13 + 1),
    const GameTile(color: TileColor.joker),
  ],
  indicator: const Indicator(color: TileColor.yellow, number: 13),
  gameMode: GameMode.okey,
  summary: const ScanSummary(
    kind: ScanVerdictKind.okeyOutcome,
    opened: false,
    score: 54,
    tilesToWin: 12,
    okeyPath: OkeyPath.meldsAndPair,
  ),
);

/// Three-digit stats: the widest values the strip can carry.
const ScanStats _bigStats = ScanStats(total: 134, opened: 87, best: 142);

void main() {
  // Demo DI: the last-scan card resolves getIt<Clock> at build time.
  setUp(() async => configureDependencies('demo'));
  tearDown(() async => getIt.reset());

  Widget harness({
    required Size size,
    required double textScale,
    required Locale locale,
    required HomeCubit cubit,
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
        child: MultiBlocProvider(
          providers: [
            BlocProvider<SettingsCubit>(create: (_) => SettingsCubit()),
            BlocProvider<HomeCubit>.value(value: cubit),
          ],
          child: const HomeView(),
        ),
      ),
    );
  }

  for (final locale in _locales) {
    for (final size in _matrix) {
      for (final textScale in _textScales) {
        testWidgets(
          'HomeView (last-scan card + stats strip) no overflow '
          '@ ${locale.languageCode} $size x$textScale',
          (tester) async {
            tester.view.physicalSize = size;
            tester.view.devicePixelRatio = 1.0;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);

            final cubit = HomeCubit(
              _FixedWatchLastScan(_scan21),
              const _FixedWatchScanStats(_bigStats),
              _MockAppLogger(),
            );
            addTearDown(cubit.close);

            await tester.pumpWidget(
              harness(
                size: size,
                textScale: textScale,
                locale: locale,
                cubit: cubit,
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
