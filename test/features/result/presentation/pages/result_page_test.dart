import 'dart:async';

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
import 'package:okey_acar_mi/features/result/presentation/blocs/result_bloc.dart';
import 'package:okey_acar_mi/features/result/presentation/pages/result_page.dart';
import 'package:okey_acar_mi/features/result/presentation/reasoning_step_localizer.dart';
import 'package:okey_acar_mi/features/result/presentation/widgets/result_list_layout.dart';
import 'package:okey_acar_mi/features/result/presentation/widgets/result_rack_layout.dart';
import 'package:okey_acar_mi/features/result/presentation/widgets/result_verdict_header.dart';
import 'package:okey_acar_mi/features/review/domain/entities/review_outcome.dart';
import 'package:okey_acar_mi/features/solver/domain/entities/reasoning_step.dart';
import 'package:okey_acar_mi/features/solver/domain/entities/solve_request.dart';
import 'package:okey_acar_mi/features/solver/domain/entities/solve_result.dart';
import 'package:okey_acar_mi/features/solver/domain/entities/solve_verdict.dart';
import 'package:okey_acar_mi/features/solver/domain/entities/solved_meld.dart';
import 'package:okey_acar_mi/features/solver/domain/entities/solved_pair.dart';
import 'package:okey_acar_mi/features/solver/domain/entities/solved_spot.dart';
import 'package:okey_acar_mi/features/solver/domain/usecases/solve_rack.dart';
import 'package:okey_acar_mi/l10n/app_localizations.dart';

class _MockSolveRack extends Mock implements SolveRack {}

class _MockAppLogger extends Mock implements AppLogger {}

/// The locale every assertion reads its strings from.
final AppLocalizations _l10n = lookupAppLocalizations(const Locale('en'));

GameTile _t(TileColor color, int number) =>
    GameTile(color: color, number: number);

const GameTile _joker = GameTile(color: TileColor.joker);

SolvedSpot _rack(TileColor color, int number, int rackIndex) =>
    SolvedSpot.rackTile(
      physical: _t(color, number),
      rackIndex: rackIndex,
      playsAs: _t(color, number),
    );

SolvedSpot _wild(TileColor playsColor, int playsNumber, int rackIndex) =>
    SolvedSpot.wild(
      physical: _joker,
      rackIndex: rackIndex,
      playsAs: _t(playsColor, playsNumber),
    );

SolvedPair _natPair(TileColor color, int number, int firstIndex) => SolvedPair(
  identity: _t(color, number),
  first: _rack(color, number, firstIndex),
  second: _rack(color, number, firstIndex + 1),
);

/// The outcome under solve. The page renders from the [SolveResult] alone,
/// so the rack contents only have to be plausible.
final ReviewOutcome _outcome = ReviewOutcome(
  tiles: [
    for (var n = 1; n <= 13; n++) _t(TileColor.red, n),
    for (var n = 1; n <= 6; n++) _t(TileColor.blue, n),
    _joker,
  ],
  indicator: const Indicator(color: TileColor.yellow, number: 13),
  gameMode: GameMode.oneZeroOne,
);

/// 101 opens via melds: three scored melds + two leftovers.
final SolveResult _opensMelds = SolveResult(
  melds: [
    SolvedMeld(
      kind: MeldKind.run,
      spots: [
        _rack(TileColor.red, 1, 0),
        _rack(TileColor.red, 2, 1),
        _rack(TileColor.red, 3, 2),
      ],
      points: 6,
    ),
    SolvedMeld(
      kind: MeldKind.set,
      spots: [
        _rack(TileColor.red, 4, 3),
        _rack(TileColor.blue, 4, 4),
        _rack(TileColor.black, 4, 5),
      ],
      points: 12,
    ),
    SolvedMeld(
      kind: MeldKind.run,
      spots: [
        _rack(TileColor.yellow, 11, 6),
        _rack(TileColor.yellow, 12, 7),
        _rack(TileColor.yellow, 13, 8),
      ],
      points: 36,
    ),
  ],
  pairs: const [],
  leftovers: [_rack(TileColor.black, 9, 9), _rack(TileColor.blue, 11, 10)],
  totalScore: 104,
  verdict: const SolveVerdict.opens101(score: 104, via: OpenPath.melds),
  reasoning: const [
    ReasoningStep.wildsCounted(falseJokers: 1, okeyCopies: 0),
    ReasoningStep.thresholdChecked(total: 104, threshold: 101, opens: true),
    ReasoningStep.pathChosen(via: OpenPath.melds),
  ],
);

/// 101 opens via five pairs: pairs only, no melds.
final SolveResult _opensPairs = SolveResult(
  melds: const [],
  pairs: [
    _natPair(TileColor.yellow, 5, 0),
    _natPair(TileColor.blue, 1, 2),
    _natPair(TileColor.black, 7, 4),
    _natPair(TileColor.red, 9, 6),
    SolvedPair(
      identity: _t(TileColor.blue, 12),
      first: _rack(TileColor.blue, 12, 8),
      second: _wild(TileColor.blue, 12, 9),
    ),
  ],
  leftovers: const [],
  totalScore: 40,
  verdict: const SolveVerdict.opens101(score: 40, via: OpenPath.pairs),
  reasoning: const [
    ReasoningStep.pairsCounted(pairCount: 5, opens: true),
    ReasoningStep.pathChosen(via: OpenPath.pairs),
  ],
);

/// 101 does not open: two partial melds, the rest leftover.
final SolveResult _closes = SolveResult(
  melds: [
    SolvedMeld(
      kind: MeldKind.run,
      spots: [
        _rack(TileColor.blue, 7, 0),
        _rack(TileColor.blue, 8, 1),
        _rack(TileColor.blue, 9, 2),
      ],
      points: 24,
    ),
    SolvedMeld(
      kind: MeldKind.set,
      spots: [
        _rack(TileColor.red, 12, 3),
        _rack(TileColor.blue, 12, 4),
        _rack(TileColor.yellow, 12, 5),
      ],
      points: 36,
    ),
  ],
  pairs: const [],
  leftovers: [
    _rack(TileColor.black, 1, 6),
    _rack(TileColor.black, 5, 7),
    _rack(TileColor.yellow, 2, 8),
  ],
  totalScore: 60,
  verdict: const SolveVerdict.doesNotOpen101(score: 60, pointsShort: 41),
  reasoning: const [
    ReasoningStep.thresholdChecked(total: 60, threshold: 101, opens: false),
  ],
);

/// Okey melds + final pair: a wild in a run, a needed phantom in the 13s
/// set, the final pair last, and a suggested discard among the leftovers.
final SolveResult _okeyMeldsPair = SolveResult(
  melds: [
    SolvedMeld(
      kind: MeldKind.run,
      spots: [
        _rack(TileColor.red, 5, 0),
        _rack(TileColor.red, 6, 1),
        _rack(TileColor.red, 7, 2),
      ],
      points: 18,
    ),
    SolvedMeld(
      kind: MeldKind.run,
      spots: [
        _rack(TileColor.black, 1, 3),
        _wild(TileColor.black, 2, 4),
        _rack(TileColor.black, 3, 5),
      ],
      points: 6,
    ),
    SolvedMeld(
      kind: MeldKind.set,
      spots: [
        _rack(TileColor.red, 13, 6),
        _rack(TileColor.blue, 13, 7),
        const SolvedSpot.needed(
          playsAs: GameTile(color: TileColor.black, number: 13),
        ),
      ],
      points: 39,
    ),
  ],
  pairs: [_natPair(TileColor.yellow, 4, 8)],
  leftovers: [_rack(TileColor.black, 8, 10)],
  totalScore: 63,
  verdict: const SolveVerdict.okeyOutcome(
    tilesToWin: 1,
    via: OkeyPath.meldsAndPair,
  ),
  reasoning: [
    ReasoningStep.okeyDerived(
      indicator: const Indicator(color: TileColor.yellow, number: 9),
      okeyTile: _t(TileColor.yellow, 10),
    ),
    const ReasoningStep.okeyTemplateChosen(
      via: OkeyPath.meldsAndPair,
      matched: 13,
      wildsUsed: 1,
    ),
    const ReasoningStep.tilesToWinComputed(tilesToWin: 1),
  ],
  discardSuggested: _t(TileColor.black, 8),
  discardRackIndex: 10,
);

/// Okey seven pairs, already winning (tilesToWin == 0).
final SolveResult _okeySevenPairs = SolveResult(
  melds: const [],
  pairs: [
    for (var n = 1; n <= 7; n++) _natPair(TileColor.blue, n, 2 * (n - 1)),
  ],
  leftovers: const [],
  totalScore: 0,
  verdict: const SolveVerdict.okeyOutcome(
    tilesToWin: 0,
    via: OkeyPath.sevenPairs,
  ),
  reasoning: const [
    ReasoningStep.okeyTemplateChosen(
      via: OkeyPath.sevenPairs,
      matched: 14,
      wildsUsed: 0,
    ),
    ReasoningStep.tilesToWinComputed(tilesToWin: 0),
  ],
);

void main() {
  late _MockSolveRack solveRack;
  late _MockAppLogger logger;

  setUpAll(() {
    registerFallbackValue(
      const SolveRequest(
        tiles: [],
        indicator: Indicator(color: TileColor.red, number: 1),
        mode: GameMode.oneZeroOne,
      ),
    );
  });

  setUp(() {
    solveRack = _MockSolveRack();
    logger = _MockAppLogger();
  });

  /// `ResultView` on the result route, with stub home + camera routes so
  /// the footer/top-bar navigation is observable.
  Widget harness(ResultBloc bloc, {bool disableAnimations = false}) {
    final router = GoRouter(
      initialLocation: AppRoutes.result,
      routes: [
        GoRoute(
          path: AppRoutes.home,
          builder: (context, state) => const Scaffold(
            body: Center(child: Text('home-stub')),
          ),
        ),
        GoRoute(
          path: AppRoutes.camera,
          builder: (context, state) => const Scaffold(
            body: Center(child: Text('camera-stub')),
          ),
        ),
        GoRoute(
          path: AppRoutes.result,
          builder: (context, state) => BlocProvider<ResultBloc>.value(
            value: bloc,
            child: const ResultView(),
          ),
        ),
      ],
    );
    return MaterialApp.router(
      theme: AppTheme.light(AppAccent.sage, TileStyle.classic),
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: const [Locale('tr'), Locale('en')],
      routerConfig: router,
      builder: disableAnimations
          ? (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: child!,
            )
          : null,
    );
  }

  /// Builds the screen-scoped bloc on a stubbed solver and settles on the
  /// solved frame.
  Future<ResultBloc> pumpResult(WidgetTester tester, SolveResult result) async {
    when(() => solveRack(any())).thenAnswer((_) async => result);
    final bloc = ResultBloc(solveRack, logger, _outcome);
    addTearDown(bloc.close);
    await tester.pumpWidget(harness(bloc));
    await tester.pumpAndSettle();
    return bloc;
  }

  Finder key(String value) => find.byKey(ValueKey(value));

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  group('101 verdict — opens via melds', () {
    testWidgets('shows the good eyebrow, "Opens.", the score against 101, '
        'and one scored legend row per meld', (tester) async {
      await pumpResult(tester, _opensMelds);

      check(find.text(_l10n.resultOpensEyebrow).evaluate()).length.equals(1);
      check(find.text(_l10n.resultOpensVerdict).evaluate()).length.equals(1);
      check(find.text('104').evaluate()).length.equals(1);
      check(find.text(_l10n.resultScoreOutOf).evaluate()).length.equals(1);
      // No pairs-path caption on the melds path.
      check(find.text(_l10n.resultOpensViaPairs).evaluate()).isEmpty();
      // The legend: one +points row per meld and the leftover row.
      check(find.text('+6').evaluate()).length.equals(1);
      check(find.text('+12').evaluate()).length.equals(1);
      check(find.text('+36').evaluate()).length.equals(1);
      check(find.text(_l10n.resultLeftover(2)).evaluate()).length.equals(1);
      check(tester.takeException()).isNull();
    });
  });

  group('101 verdict — opens via pairs', () {
    testWidgets('renders the five pairs with the pairs caption and zero '
        'scored meld rows', (tester) async {
      await pumpResult(tester, _opensPairs);

      check(find.text(_l10n.resultOpensVerdict).evaluate()).length.equals(1);
      check(find.text(_l10n.resultOpensViaPairs).evaluate()).length.equals(1);
      // Five pair legend rows, no meld (+points) rows anywhere.
      check(
        find.textContaining(_l10n.resultPairLabel).evaluate(),
      ).length.equals(5);
      check(find.textContaining('+').evaluate()).isEmpty();
      check(tester.takeException()).isNull();
    });
  });

  group('101 verdict — does not open', () {
    testWidgets('shows the warn eyebrow, "No open.", the points-short '
        'caption, and the partial melds', (tester) async {
      await pumpResult(tester, _closes);

      check(find.text(_l10n.resultClosesEyebrow).evaluate()).length.equals(1);
      check(find.text(_l10n.resultClosesVerdict).evaluate()).length.equals(1);
      check(find.text(_l10n.resultOpensVerdict).evaluate()).isEmpty();
      check(find.text('60').evaluate()).length.equals(1);
      check(
        find.text(_l10n.resultPointsShort(41)).evaluate(),
      ).length.equals(1);
      // The best partial arrangement is still shown.
      check(find.text('+24').evaluate()).length.equals(1);
      check(find.text('+36').evaluate()).length.equals(1);
      check(find.text(_l10n.resultLeftover(3)).evaluate()).length.equals(1);
      check(tester.takeException()).isNull();
    });
  });

  group('okey verdict — melds and pair', () {
    testWidgets('shows tiles-to-win, never Açar/Açmaz, the needed and wild '
        'cells, the final pair, and the discard row', (tester) async {
      await pumpResult(tester, _okeyMeldsPair);

      check(
        find.text(_l10n.resultOkeyTilesToWinHeadline(1)).evaluate(),
      ).length.equals(1);
      check(
        find.text(_l10n.resultOkeyTilesToWinLabel).evaluate(),
      ).length.equals(1);
      // The okey screen never renders the 101 verdict words.
      check(find.text(_l10n.resultOpensVerdict).evaluate()).isEmpty();
      check(find.text(_l10n.resultClosesVerdict).evaluate()).isEmpty();
      check(find.text(_l10n.resultOpensEyebrow).evaluate()).isEmpty();
      check(find.text(_l10n.resultClosesEyebrow).evaluate()).isEmpty();
      check(find.text(_l10n.resultOkeyEyebrow).evaluate()).length.equals(1);

      // The needed phantom and the wild stand-in carry their composed
      // semantics inside their groups (set #3 / run #2).
      final handle = tester.ensureSemantics();
      final neededLabel = _l10n.resultCellSemantics(
        _l10n.resultNeededTileSemantics(
          _l10n.tileSemantics(_l10n.tileColorBlack, 13),
        ),
        _l10n.resultGroupSemantics(_l10n.resultMeldSet, 3),
      );
      check(find.bySemanticsLabel(neededLabel).evaluate()).length.equals(1);
      final wildLabel = _l10n.resultCellSemantics(
        _l10n.resultWildTileSemantics(
          _l10n.tileSemantics(_l10n.tileColorBlack, 2),
        ),
        _l10n.resultGroupSemantics(_l10n.resultMeldRun, 2),
      );
      check(find.bySemanticsLabel(wildLabel).evaluate()).length.equals(1);
      // The leftover discard cell announces itself.
      check(
        find
            .bySemanticsLabel(
              _l10n.resultDiscardTileSemantics(
                _l10n.tileSemantics(_l10n.tileColorBlack, 8),
              ),
            )
            .evaluate(),
      ).length.equals(1);
      handle.dispose();

      // The final pair is a legend group; the okey extras show the discard
      // suggestion and the tiles-needed summary.
      check(
        find.textContaining(_l10n.resultPairLabel).evaluate(),
      ).length.equals(1);
      check(
        find.text(_l10n.resultDiscardSuggestion).evaluate(),
      ).length.equals(1);
      check(find.text(_l10n.resultTilesNeeded(1)).evaluate()).length.equals(1);
      check(tester.takeException()).isNull();
    });
  });

  group('okey verdict — seven pairs, winning', () {
    testWidgets('tilesToWin 0 shows the winning headline with the '
        'seven-pairs caption and seven pair rows', (tester) async {
      await pumpResult(tester, _okeySevenPairs);

      check(find.text(_l10n.resultOkeyWin).evaluate()).length.equals(1);
      check(
        find.text(_l10n.resultOkeyViaSevenPairs).evaluate(),
      ).length.equals(1);
      check(find.text(_l10n.resultOpensVerdict).evaluate()).isEmpty();
      check(find.text(_l10n.resultClosesVerdict).evaluate()).isEmpty();
      check(
        find.textContaining(_l10n.resultPairLabel).evaluate(),
      ).length.equals(7);
      // No discard / tiles-needed extras for a complete hand.
      check(find.text(_l10n.resultDiscardSuggestion).evaluate()).isEmpty();
      check(tester.takeException()).isNull();
    });
  });

  group('solve lifecycle', () {
    testWidgets('shows the solving spinner until the solver returns', (
      tester,
    ) async {
      final completer = Completer<SolveResult>();
      when(() => solveRack(any())).thenAnswer((_) => completer.future);
      final bloc = ResultBloc(solveRack, logger, _outcome);
      addTearDown(bloc.close);

      await tester.pumpWidget(harness(bloc));
      await tester.pump();
      check(
        find.byType(CircularProgressIndicator).evaluate(),
      ).length.equals(1);
      check(find.text(_l10n.resultSolving).evaluate()).length.equals(1);

      completer.complete(_opensMelds);
      await tester.pumpAndSettle();
      check(find.text(_l10n.resultOpensVerdict).evaluate()).length.equals(1);
      check(find.byType(CircularProgressIndicator).evaluate()).isEmpty();
      check(tester.takeException()).isNull();
    });

    testWidgets('a solver error shows the failure view; retry re-solves to '
        'the verdict', (tester) async {
      // Solver-error coverage lives here at the widget level only: the pure
      // engine cannot be made to fail through the demo fakes, so the
      // integration suite has no error-path variant for this screen.
      var calls = 0;
      when(() => solveRack(any())).thenAnswer((_) async {
        if (++calls == 1) throw StateError('engine defect');
        return _opensMelds;
      });
      final bloc = ResultBloc(solveRack, logger, _outcome);
      addTearDown(bloc.close);

      await tester.pumpWidget(harness(bloc));
      await tester.pumpAndSettle();
      check(find.text(_l10n.resultErrorTitle).evaluate()).length.equals(1);
      check(find.text(_l10n.resultErrorBody).evaluate()).length.equals(1);

      await tap(tester, key('result-retry'));
      check(find.text(_l10n.resultOpensVerdict).evaluate()).length.equals(1);
      check(find.text(_l10n.resultErrorTitle).evaluate()).isEmpty();
      check(tester.takeException()).isNull();
    });
  });

  group('layout toggle', () {
    testWidgets('list swaps the rack for group cards and back', (
      tester,
    ) async {
      await pumpResult(tester, _opensMelds);

      check(find.byType(ResultRackLayout).evaluate()).length.equals(1);
      check(find.byType(ResultListLayout).evaluate()).isEmpty();
      check(find.text(_l10n.resultBestArrangement).evaluate()).length.equals(1);

      await tap(tester, key('result-layout-list'));
      check(find.byType(ResultListLayout).evaluate()).length.equals(1);
      check(find.byType(ResultRackLayout).evaluate()).isEmpty();
      check(find.text(_l10n.resultGroups).evaluate()).length.equals(1);

      await tap(tester, key('result-layout-rack'));
      check(find.byType(ResultRackLayout).evaluate()).length.equals(1);
      check(find.byType(ResultListLayout).evaluate()).isEmpty();
      check(tester.takeException()).isNull();
    });
  });

  group('detail unlock', () {
    testWidgets('locked: no reasoning rows, just the CTA; unlocking reveals '
        'the localized steps', (tester) async {
      await pumpResult(tester, _opensMelds);

      check(key('result-detail-unlock').evaluate()).length.equals(1);
      check(find.text(_l10n.resultWhyThis).evaluate()).isEmpty();
      final firstStep = reasoningStepText(_l10n, _opensMelds.reasoning.first);
      check(find.text(firstStep).evaluate()).isEmpty();

      await tap(tester, key('result-detail-unlock'));
      check(key('result-detail-unlock').evaluate()).isEmpty();
      check(find.text(_l10n.resultWhyThis).evaluate()).length.equals(1);
      for (final step in _opensMelds.reasoning) {
        check(
          find.text(reasoningStepText(_l10n, step)).evaluate(),
        ).length.equals(1);
      }
      check(tester.takeException()).isNull();
    });
  });

  group('reduce motion', () {
    testWidgets('disableAnimations renders the verdict directly, without '
        'the entrance wrapper', (tester) async {
      when(() => solveRack(any())).thenAnswer((_) async => _opensMelds);
      final bloc = ResultBloc(solveRack, logger, _outcome);
      addTearDown(bloc.close);

      await tester.pumpWidget(harness(bloc, disableAnimations: true));
      // One pump lands the solved frame; no settle needed — there is no
      // entrance animation under reduce-motion.
      await tester.pump();

      check(find.text(_l10n.resultOpensVerdict).evaluate()).length.equals(1);
      check(
        find
            .descendant(
              of: find.byType(ResultVerdictHeader),
              matching: find.byType(TweenAnimationBuilder<double>),
            )
            .evaluate(),
      ).isEmpty();
      check(tester.takeException()).isNull();
    });
  });

  group('navigation', () {
    testWidgets('"Again" goes to the camera', (tester) async {
      await pumpResult(tester, _opensMelds);
      await tap(tester, key('result-again'));
      check(find.text('camera-stub').evaluate()).length.equals(1);
      check(tester.takeException()).isNull();
    });

    testWidgets('"Done" finishes to home', (tester) async {
      await pumpResult(tester, _opensMelds);
      await tap(tester, key('result-done'));
      check(find.text('home-stub').evaluate()).length.equals(1);
      check(tester.takeException()).isNull();
    });

    testWidgets('the top-bar close goes home', (tester) async {
      await pumpResult(tester, _opensMelds);
      await tap(tester, key('result-close'));
      check(find.text('home-stub').evaluate()).length.equals(1);
      check(tester.takeException()).isNull();
    });
  });

  group('ResultPage wiring (demo DI)', () {
    setUp(() async => configureDependencies('demo'));
    tearDown(() async => getIt.reset());

    testWidgets('resolves its bloc via getIt(param1:) and solves the real '
        'outcome end-to-end', (tester) async {
      // The §6 three-parallel-runs rack: the real engine opens it at 102.
      final outcome = ReviewOutcome(
        tiles: [
          for (final n in [9, 10, 11, 11, 12, 12, 13, 13]) _t(TileColor.red, n),
          _joker,
        ],
        indicator: const Indicator(color: TileColor.black, number: 1),
        gameMode: GameMode.oneZeroOne,
      );
      final pageRouter = GoRouter(
        initialLocation: AppRoutes.result,
        routes: [
          GoRoute(
            path: AppRoutes.result,
            builder: (context, state) => ResultPage(outcome: outcome),
          ),
        ],
      );

      // The real SolveRack hops isolates, which never completes under the
      // tester's fake async — run the pump + wait on the real event loop.
      await tester.runAsync(() async {
        await tester.pumpWidget(
          MaterialApp.router(
            theme: AppTheme.light(AppAccent.sage, TileStyle.classic),
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: const [Locale('tr'), Locale('en')],
            routerConfig: pageRouter,
          ),
        );
        final bloc = BlocProvider.of<ResultBloc>(
          tester.element(find.byType(ResultView)),
        );
        // Await the real isolate boundary: the bloc's solved emission.
        while (bloc.state.status is! ResultSolved) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
      });
      await tester.pumpAndSettle();

      check(find.text(_l10n.resultOpensVerdict).evaluate()).length.equals(1);
      check(find.text('102').evaluate()).length.equals(1);
      check(tester.takeException()).isNull();
    });
  });
}
