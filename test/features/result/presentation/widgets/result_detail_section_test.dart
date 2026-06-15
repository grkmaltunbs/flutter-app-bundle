import 'package:checks/checks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:okey_acar_mi/core/ads/ads_service.dart';
import 'package:okey_acar_mi/core/ads/fakes/fake_ads_service.dart';
import 'package:okey_acar_mi/core/di/injection.dart';
import 'package:okey_acar_mi/core/game/game_mode.dart';
import 'package:okey_acar_mi/core/game/game_tile.dart';
import 'package:okey_acar_mi/core/game/indicator.dart';
import 'package:okey_acar_mi/core/game/tile_color.dart';
import 'package:okey_acar_mi/core/logging/app_logger.dart';
import 'package:okey_acar_mi/core/network/connectivity_service.dart';
import 'package:okey_acar_mi/core/payments/data/fakes/fake_purchase_repository.dart';
import 'package:okey_acar_mi/core/payments/domain/repositories/purchase_repository.dart';
import 'package:okey_acar_mi/core/payments/subscription_bloc.dart';
import 'package:okey_acar_mi/core/router/app_router.dart';
import 'package:okey_acar_mi/core/theme/app_accent.dart';
import 'package:okey_acar_mi/core/theme/app_theme.dart';
import 'package:okey_acar_mi/core/theme/tile_style.dart';
import 'package:okey_acar_mi/features/history/domain/entities/scan.dart';
import 'package:okey_acar_mi/features/history/domain/entities/scan_summary.dart';
import 'package:okey_acar_mi/features/history/domain/usecases/save_scan.dart';
import 'package:okey_acar_mi/features/result/domain/entities/result_args.dart';
import 'package:okey_acar_mi/features/result/presentation/blocs/result_bloc.dart';
import 'package:okey_acar_mi/features/result/presentation/reasoning_step_localizer.dart';
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

final AppLocalizations _l10n = lookupAppLocalizations(const Locale('en'));

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
    id: 'noop',
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
    tiles: outcome.tiles,
    indicator: outcome.indicator,
    gameMode: outcome.gameMode,
    summary: ScanSummary.fromResult(result),
  );
}

void main() {
  late ResultBloc resultBloc;

  setUp(() async {
    await configureDependencies('demo');
    resultBloc = ResultBloc(
      _FixedSolveRack(),
      const _NoopSaveScan(),
      _MockAppLogger(),
      ResultArgs.fresh(_outcome),
    );
  });

  tearDown(() async {
    await resultBloc.close();
    await getIt.reset();
  });

  FakePurchaseRepository fakePurchases() =>
      getIt<PurchaseRepository>() as FakePurchaseRepository;
  FakeAdsService fakeAds() => getIt<AdsService>() as FakeAdsService;
  FakeConnectivityService fakeConnectivity() =>
      getIt<ConnectivityService>() as FakeConnectivityService;

  /// Pumps the detail section under both blocs, inside a router exposing a stub
  /// /paywall so the "go premium" path is observable. The section is settled
  /// onto the solved result.
  Future<void> pumpSection(WidgetTester tester) async {
    final router = GoRouter(
      initialLocation: '/x',
      routes: [
        GoRoute(
          path: '/x',
          builder: (context, state) => Scaffold(
            body: ResultDetailSection(steps: _result.reasoning),
          ),
        ),
        GoRoute(
          path: AppRoutes.paywall,
          builder: (context, state) =>
              const Scaffold(body: Center(child: Text('paywall-stub'))),
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
        builder: (context, child) => MultiBlocProvider(
          providers: [
            BlocProvider<ResultBloc>.value(value: resultBloc),
            BlocProvider<SubscriptionBloc>(
              create: (_) => getIt<SubscriptionBloc>()
                ..add(const SubscriptionEvent.started()),
            ),
          ],
          child: child!,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder key(String value) => find.byKey(ValueKey(value));

  bool reasoningShown() =>
      find.text(_l10n.resultWhyThis).evaluate().isNotEmpty &&
      find
          .text(reasoningStepText(_l10n, _result.reasoning.first))
          .evaluate()
          .isNotEmpty;

  group('premium', () {
    testWidgets('shows the reasoning immediately, no lock card', (
      tester,
    ) async {
      fakePurchases().setMode(FakePurchaseMode.premium);
      await pumpSection(tester);

      check(reasoningShown()).isTrue();
      check(key('result-detail-unlock').evaluate()).isEmpty();
      check(tester.takeException()).isNull();
    });
  });

  group('free + locked', () {
    testWidgets('shows the lock card with the unlock CTA, no reasoning', (
      tester,
    ) async {
      await pumpSection(tester);

      check(key('result-detail-unlock').evaluate()).length.equals(1);
      check(reasoningShown()).isFalse();
      check(tester.takeException()).isNull();
    });

    testWidgets('watching a rewarded ad that grants reveals the reasoning '
        '(via ResultDetailUnlockGranted)', (tester) async {
      await pumpSection(tester);

      await tester.tap(key('result-detail-unlock'));
      await tester.pumpAndSettle();
      // Online → the sheet offers the watch-ad path.
      check(key('detail-unlock-watch-ad').evaluate()).length.equals(1);

      await tester.tap(key('detail-unlock-watch-ad'));
      // showRewarded resolves on a real async boundary; cross it so the reward
      // callback dispatches ResultDetailUnlockGranted, then rebuild.
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pumpAndSettle();

      // The fake grants by default → the bloc unlocked the detail.
      check(resultBloc.state.detailUnlocked).isTrue();
      check(reasoningShown()).isTrue();
      check(tester.takeException()).isNull();
    });

    testWidgets('an ad that fails to load keeps the section locked', (
      tester,
    ) async {
      fakeAds().failNextRewarded = true;
      await pumpSection(tester);

      await tester.tap(key('result-detail-unlock'));
      await tester.pumpAndSettle();
      await tester.tap(key('detail-unlock-watch-ad'));
      await tester.pumpAndSettle();

      check(resultBloc.state.detailUnlocked).isFalse();
      check(key('result-detail-unlock').evaluate()).length.equals(1);
      // The failure SnackBar surfaced.
      check(find.text(_l10n.detailUnlockAdFailed).evaluate()).length.equals(1);
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      check(tester.takeException()).isNull();
    });

    testWidgets('an ad dismissed before the reward keeps the section locked', (
      tester,
    ) async {
      fakeAds().dismissNextWithoutReward = true;
      await pumpSection(tester);

      await tester.tap(key('result-detail-unlock'));
      await tester.pumpAndSettle();
      await tester.tap(key('detail-unlock-watch-ad'));
      await tester.pumpAndSettle();

      check(resultBloc.state.detailUnlocked).isFalse();
      check(key('result-detail-unlock').evaluate()).length.equals(1);
      check(
        find.text(_l10n.detailUnlockAdDismissed).evaluate(),
      ).length.equals(1);
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      check(tester.takeException()).isNull();
    });

    testWidgets('offline: the sheet offers only the go-premium path '
        '(no watch-ad)', (tester) async {
      fakeConnectivity().setOnline(online: false);
      await pumpSection(tester);

      await tester.tap(key('result-detail-unlock'));
      await tester.pumpAndSettle();

      check(key('detail-unlock-watch-ad').evaluate()).isEmpty();
      check(key('detail-unlock-go-premium').evaluate()).length.equals(1);

      // Go premium routes to the paywall.
      await tester.tap(key('detail-unlock-go-premium'));
      await tester.pumpAndSettle();
      check(find.text('paywall-stub').evaluate()).length.equals(1);
      check(tester.takeException()).isNull();
    });
  });
}
