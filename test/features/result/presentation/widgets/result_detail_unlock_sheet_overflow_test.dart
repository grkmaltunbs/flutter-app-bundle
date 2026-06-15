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
import 'package:okey_acar_mi/core/payments/subscription_bloc.dart';
import 'package:okey_acar_mi/core/theme/app_accent.dart';
import 'package:okey_acar_mi/core/theme/app_theme.dart';
import 'package:okey_acar_mi/core/theme/tile_style.dart';
import 'package:okey_acar_mi/features/history/domain/entities/scan.dart';
import 'package:okey_acar_mi/features/history/domain/entities/scan_summary.dart';
import 'package:okey_acar_mi/features/history/domain/usecases/save_scan.dart';
import 'package:okey_acar_mi/features/result/domain/entities/result_args.dart';
import 'package:okey_acar_mi/features/result/presentation/blocs/result_bloc.dart';
import 'package:okey_acar_mi/features/result/presentation/widgets/result_detail_section.dart';
import 'package:okey_acar_mi/features/review/domain/entities/review_outcome.dart';
import 'package:okey_acar_mi/features/solver/domain/entities/reasoning_step.dart';
import 'package:okey_acar_mi/features/solver/domain/entities/solve_request.dart';
import 'package:okey_acar_mi/features/solver/domain/entities/solve_result.dart';
import 'package:okey_acar_mi/features/solver/domain/entities/solve_verdict.dart';
import 'package:okey_acar_mi/features/solver/domain/entities/solved_meld.dart';
import 'package:okey_acar_mi/features/solver/domain/entities/solved_spot.dart';
import 'package:okey_acar_mi/features/solver/domain/usecases/solve_rack.dart';
import 'package:okey_acar_mi/l10n/app_localizations.dart';

import '../../../../support/payments_test_support.dart';

/// Responsive size matrix from `CLAUDE.md`: smallest phone, typical phone,
/// largest phone, tablet — each at textScale 1.0 and 2.0, in both locales.
/// A `RenderFlex` overflow throws in debug, so asserting no exception per
/// pump catches an overflow deterministically.
///
/// The detail-unlock bottom sheet is behaviour-tested in
/// `result_detail_section_test.dart`; this guard pins it across the size
/// matrix (the sheet was the one result surface not yet matrix-covered). It
/// opens the REAL sheet through the free + locked `ResultDetailSection`, online
/// (the demo default) so BOTH the watch-ad and go-premium buttons render — the
/// tallest variant — then asserts the open sheet is overflow-free.
const _matrix = <Size>[
  Size(320, 568),
  Size(393, 852),
  Size(430, 932),
  Size(834, 1194),
];

const _textScales = <double>[1, 2];

const _locales = <Locale>[Locale('tr'), Locale('en')];

class _MockAppLogger extends Mock implements AppLogger {}

GameTile _t(TileColor color, int number) =>
    GameTile(color: color, number: number);

const _reasoning = <ReasoningStep>[
  ReasoningStep.wildsCounted(faceDowns: 1, okeyCopies: 0),
  ReasoningStep.thresholdChecked(total: 104, threshold: 101, opens: true),
  ReasoningStep.pathChosen(via: OpenPath.melds),
];

final _result = SolveResult(
  melds: [
    SolvedMeld(
      kind: MeldKind.run,
      spots: [
        SolvedSpot.rackTile(
          physical: _t(TileColor.red, 1),
          rackIndex: 0,
          playsAs: _t(TileColor.red, 1),
        ),
        SolvedSpot.rackTile(
          physical: _t(TileColor.red, 2),
          rackIndex: 1,
          playsAs: _t(TileColor.red, 2),
        ),
        SolvedSpot.rackTile(
          physical: _t(TileColor.red, 3),
          rackIndex: 2,
          playsAs: _t(TileColor.red, 3),
        ),
      ],
      points: 6,
    ),
  ],
  pairs: const [],
  leftovers: const [],
  totalScore: 104,
  verdict: const SolveVerdict.opens101(score: 104, via: OpenPath.melds),
  reasoning: _reasoning,
);

final _outcome = ReviewOutcome(
  tiles: [for (var i = 0; i < 14; i++) _t(TileColor.red, i % 13 + 1)],
  indicator: const Indicator(color: TileColor.yellow, number: 13),
  gameMode: GameMode.oneZeroOne,
);

/// A [SolveRack] pinned to [_result].
class _FixedSolveRack implements SolveRack {
  @override
  Future<SolveResult> call(SolveRequest request) async => _result;
}

/// A [SaveScan] that persists nothing.
class _NoopSaveScan implements SaveScan {
  const _NoopSaveScan();
  @override
  Future<Scan> call({
    required ReviewOutcome outcome,
    required SolveResult result,
  }) async => Scan(
    id: 'overflow-guard',
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
    tiles: outcome.tiles,
    indicator: outcome.indicator,
    gameMode: outcome.gameMode,
    summary: ScanSummary.fromResult(result),
  );
}

void main() {
  final logger = _MockAppLogger();

  setUp(() async => configureDependencies('demo'));
  tearDown(() async => getIt.reset());

  ResultBloc buildResultBloc() => ResultBloc(
    _FixedSolveRack(),
    const _NoopSaveScan(),
    logger,
    ResultArgs.fresh(_outcome),
  );

  Widget harness({
    required Size size,
    required double textScale,
    required Locale locale,
    required ResultBloc bloc,
    required SubscriptionBloc subscription,
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
        // Free entitlement so the locked card + its unlock CTA render.
        child: BlocProvider<SubscriptionBloc>.value(
          value: subscription,
          child: BlocProvider<ResultBloc>.value(
            value: bloc,
            child: const Scaffold(
              body: ResultDetailSection(steps: _reasoning),
            ),
          ),
        ),
      ),
    );
  }

  for (final locale in _locales) {
    for (final size in _matrix) {
      for (final textScale in _textScales) {
        testWidgets(
          'DetailUnlockSheet no overflow '
          '@ ${locale.languageCode} $size x$textScale',
          (tester) async {
            tester.view.physicalSize = size;
            tester.view.devicePixelRatio = 1.0;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);

            final bloc = buildResultBloc();
            addTearDown(bloc.close);
            // Free entitlement → the section is locked → the unlock CTA shows.
            final subscription = buildSubscriptionBloc();
            addTearDown(subscription.close);

            await tester.pumpWidget(
              harness(
                size: size,
                textScale: textScale,
                locale: locale,
                bloc: bloc,
                subscription: subscription,
              ),
            );
            await tester.pumpAndSettle();

            // Open the real sheet. Demo connectivity defaults to online, so
            // both the watch-ad and go-premium buttons render (tallest body).
            await tester.tap(
              find.byKey(const ValueKey('result-detail-unlock')),
            );
            await tester.pumpAndSettle();
            check(
              find.byKey(const ValueKey('detail-unlock-watch-ad')).evaluate(),
            ).length.equals(1);
            check(
              find.byKey(const ValueKey('detail-unlock-go-premium')).evaluate(),
            ).length.equals(1);

            check(tester.takeException()).isNull();
          },
        );
      }
    }
  }
}
