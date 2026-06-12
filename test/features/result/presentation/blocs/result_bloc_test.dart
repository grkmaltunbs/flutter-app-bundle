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
import 'package:okey_acar_mi/features/result/presentation/blocs/result_bloc.dart';
import 'package:okey_acar_mi/features/review/domain/entities/review_outcome.dart';
import 'package:okey_acar_mi/features/solver/domain/entities/reasoning_step.dart';
import 'package:okey_acar_mi/features/solver/domain/entities/solve_request.dart';
import 'package:okey_acar_mi/features/solver/domain/entities/solve_result.dart';
import 'package:okey_acar_mi/features/solver/domain/entities/solve_verdict.dart';
import 'package:okey_acar_mi/features/solver/domain/entities/solved_meld.dart';
import 'package:okey_acar_mi/features/solver/domain/entities/solved_spot.dart';
import 'package:okey_acar_mi/features/solver/domain/usecases/solve_rack.dart';

class _MockSolveRack extends Mock implements SolveRack {}

class _MockAppLogger extends Mock implements AppLogger {}

GameTile _t(TileColor color, int number) =>
    GameTile(color: color, number: number);

final ReviewOutcome _outcome = ReviewOutcome(
  tiles: [
    for (var n = 1; n <= 13; n++) _t(TileColor.red, n),
    for (var n = 1; n <= 6; n++) _t(TileColor.blue, n),
    const GameTile(color: TileColor.joker),
  ],
  indicator: const Indicator(color: TileColor.yellow, number: 13),
  gameMode: GameMode.oneZeroOne,
);

final SolveResult _solved = SolveResult(
  melds: [
    SolvedMeld(
      kind: MeldKind.run,
      spots: [
        for (var n = 1; n <= 13; n++)
          SolvedSpot.rackTile(
            physical: _t(TileColor.red, n),
            rackIndex: n - 1,
            playsAs: _t(TileColor.red, n),
          ),
      ],
      points: 91,
    ),
  ],
  pairs: const [],
  leftovers: const [],
  totalScore: 104,
  verdict: const SolveVerdict.opens101(score: 104, via: OpenPath.melds),
  reasoning: const [
    ReasoningStep.thresholdChecked(total: 104, threshold: 101, opens: true),
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

  ResultBloc build() => ResultBloc(solveRack, logger, _outcome);

  ResultState state({
    ResultSolveStatus status = const ResultSolveStatus.solving(),
    ResultLayout layout = ResultLayout.rack,
    bool detailUnlocked = false,
  }) {
    return ResultState(
      outcome: _outcome,
      status: status,
      layout: layout,
      detailUnlocked: detailUnlocked,
    );
  }

  group('creation auto-solve', () {
    blocTest<ResultBloc, ResultState>(
      'emits [solving, solved] (the first emit is never deduplicated, even '
      'though solving is also the initial state) and passes the outcome '
      'verbatim as the SolveRequest',
      build: () {
        when(() => solveRack(any())).thenAnswer((_) async => _solved);
        return build();
      },
      expect: () => [
        state(),
        state(status: ResultSolveStatus.solved(_solved)),
      ],
      verify: (_) {
        verify(
          () => solveRack(
            SolveRequest(
              tiles: _outcome.tiles,
              indicator: _outcome.indicator,
              mode: _outcome.gameMode,
            ),
          ),
        ).called(1);
      },
    );

    blocTest<ResultBloc, ResultState>(
      'a throwing solver lands in [solving, failed] and logs the engine '
      'defect',
      build: () {
        when(() => solveRack(any())).thenThrow(StateError('engine defect'));
        return build();
      },
      expect: () => [
        state(),
        state(status: const ResultSolveStatus.failed()),
      ],
      verify: (_) {
        verify(
          () => logger.error('Rack solve failed', any<Object?>(), any()),
        ).called(1);
      },
    );
  });

  group('retry', () {
    blocTest<ResultBloc, ResultState>(
      'after a failure, solveRequested re-runs [solving, solved] and '
      'preserves the layout and unlock chosen in between',
      build: () {
        var calls = 0;
        when(() => solveRack(any())).thenAnswer((_) async {
          if (++calls == 1) throw StateError('engine defect');
          return _solved;
        });
        return build();
      },
      act: (bloc) async {
        await pumpEventQueue(); // let the initial solve fail
        bloc
          ..add(const ResultEvent.layoutToggled(ResultLayout.list))
          ..add(const ResultEvent.detailUnlockGranted())
          ..add(const ResultEvent.solveRequested());
        await pumpEventQueue();
      },
      expect: () => [
        state(),
        state(status: const ResultSolveStatus.failed()),
        state(
          status: const ResultSolveStatus.failed(),
          layout: ResultLayout.list,
        ),
        state(
          status: const ResultSolveStatus.failed(),
          layout: ResultLayout.list,
          detailUnlocked: true,
        ),
        state(layout: ResultLayout.list, detailUnlocked: true),
        state(
          status: ResultSolveStatus.solved(_solved),
          layout: ResultLayout.list,
          detailUnlocked: true,
        ),
      ],
      verify: (_) => verify(() => solveRack(any())).called(2),
    );
  });

  group('layoutToggled', () {
    blocTest<ResultBloc, ResultState>(
      'updates the layout each way without touching the solve status',
      build: () {
        when(() => solveRack(any())).thenAnswer((_) async => _solved);
        return build();
      },
      act: (bloc) async {
        await pumpEventQueue(); // let the auto-solve land first
        bloc
          ..add(const ResultEvent.layoutToggled(ResultLayout.list))
          ..add(const ResultEvent.layoutToggled(ResultLayout.rack));
        await pumpEventQueue();
      },
      expect: () => [
        state(),
        state(status: ResultSolveStatus.solved(_solved)),
        state(
          status: ResultSolveStatus.solved(_solved),
          layout: ResultLayout.list,
        ),
        state(status: ResultSolveStatus.solved(_solved)),
      ],
    );
  });

  group('detailUnlockGranted', () {
    blocTest<ResultBloc, ResultState>(
      'sets the flag once; a second grant is deduplicated',
      build: () {
        when(() => solveRack(any())).thenAnswer((_) async => _solved);
        return build();
      },
      act: (bloc) async {
        await pumpEventQueue();
        bloc
          ..add(const ResultEvent.detailUnlockGranted())
          ..add(const ResultEvent.detailUnlockGranted());
        await pumpEventQueue();
      },
      expect: () => [
        state(),
        state(status: ResultSolveStatus.solved(_solved)),
        state(
          status: ResultSolveStatus.solved(_solved),
          detailUnlocked: true,
        ),
      ],
    );
  });

  group('close mid-solve', () {
    test('a result landing after close() is dropped — no emit-after-close '
        'error, state stays solving', () async {
      final completer = Completer<SolveResult>();
      when(() => solveRack(any())).thenAnswer((_) => completer.future);

      final bloc = ResultBloc(solveRack, logger, _outcome);
      final emitted = <ResultState>[];
      final subscription = bloc.stream.listen(emitted.add);

      await pumpEventQueue(); // the handler is now suspended on the solver
      await bloc.close();
      completer.complete(_solved); // resumes the handler after close
      await pumpEventQueue();

      // Only the handler's eager solving re-emit landed — never the result.
      check(emitted.length).equals(1);
      check(emitted.single.status).equals(const ResultSolveStatus.solving());
      check(bloc.state.status).equals(const ResultSolveStatus.solving());
      await subscription.cancel();
    });
  });
}
