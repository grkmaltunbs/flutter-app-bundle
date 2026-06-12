import 'package:checks/checks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:okey_acar_mi/core/game/game_mode.dart';
import 'package:okey_acar_mi/core/game/game_tile.dart';
import 'package:okey_acar_mi/core/game/indicator.dart';
import 'package:okey_acar_mi/core/game/tile_color.dart';
import 'package:okey_acar_mi/core/logging/app_logger.dart';
import 'package:okey_acar_mi/core/theme/app_accent.dart';
import 'package:okey_acar_mi/core/theme/app_theme.dart';
import 'package:okey_acar_mi/core/theme/tile_style.dart';
import 'package:okey_acar_mi/features/result/presentation/blocs/result_bloc.dart';
import 'package:okey_acar_mi/features/result/presentation/pages/result_page.dart';
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

/// A [SolveRack] pinned to one result — the overflow guard needs pinned
/// content, not engine output.
class _FixedSolveRack implements SolveRack {
  _FixedSolveRack(this.result);

  final SolveResult result;

  @override
  Future<SolveResult> call(SolveRequest request) async => result;
}

/// A [SolveRack] that always fails, pinning the error view.
class _ThrowingSolveRack implements SolveRack {
  @override
  Future<SolveResult> call(SolveRequest request) async =>
      throw StateError('overflow-guard');
}

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

ReviewOutcome _outcome(GameMode mode, int tileCount) => ReviewOutcome(
  tiles: [
    for (var i = 0; i < tileCount; i++) _t(TileColor.red, i % 13 + 1),
  ],
  indicator: const Indicator(color: TileColor.yellow, number: 13),
  gameMode: mode,
);

/// The worst-case 101 board: 21 cells across six groups (the ring cycle
/// wraps past 4) plus leftovers, with full reasoning for the unlocked
/// variant.
final SolveResult _result101 = SolveResult(
  melds: [
    for (var i = 0; i < 6; i++)
      SolvedMeld(
        kind: i.isEven ? MeldKind.run : MeldKind.set,
        spots: [
          _rack(TileColor.red, i + 1, 3 * i),
          if (i == 1)
            _wild(TileColor.blue, i + 1, 3 * i + 1)
          else
            _rack(TileColor.blue, i + 1, 3 * i + 1),
          _rack(TileColor.black, i + 1, 3 * i + 2),
        ],
        points: 3 * (i + 1),
      ),
  ],
  pairs: const [],
  leftovers: [
    _rack(TileColor.yellow, 9, 18),
    _rack(TileColor.yellow, 11, 19),
    _rack(TileColor.black, 13, 20),
  ],
  totalScore: 104,
  verdict: const SolveVerdict.opens101(score: 104, via: OpenPath.melds),
  reasoning: const [
    ReasoningStep.wildsCounted(falseJokers: 1, okeyCopies: 0),
    ReasoningStep.rackCountNoted(count: 21, mode: GameMode.oneZeroOne),
    ReasoningStep.thresholdChecked(total: 104, threshold: 101, opens: true),
    ReasoningStep.pathChosen(via: OpenPath.melds),
  ],
);

/// The worst-case okey board: needed phantoms, a wild, the final pair, a
/// suggested discard, and the extras section all visible at once.
final SolveResult _resultOkey = SolveResult(
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
    SolvedMeld(
      kind: MeldKind.run,
      spots: [
        _rack(TileColor.blue, 10, 8),
        _rack(TileColor.blue, 11, 9),
        const SolvedSpot.needed(
          playsAs: GameTile(color: TileColor.blue, number: 12),
        ),
      ],
      points: 33,
    ),
  ],
  pairs: [
    SolvedPair(
      identity: _t(TileColor.yellow, 4),
      first: _rack(TileColor.yellow, 4, 10),
      second: _rack(TileColor.yellow, 4, 11),
    ),
  ],
  leftovers: [
    _rack(TileColor.black, 8, 12),
    _rack(TileColor.yellow, 9, 13),
    _rack(TileColor.red, 1, 14),
  ],
  totalScore: 96,
  verdict: const SolveVerdict.okeyOutcome(
    tilesToWin: 2,
    via: OkeyPath.meldsAndPair,
  ),
  reasoning: const [
    ReasoningStep.rackCountNoted(count: 15, mode: GameMode.okey),
    ReasoningStep.okeyTemplateChosen(
      via: OkeyPath.meldsAndPair,
      matched: 12,
      wildsUsed: 1,
    ),
    ReasoningStep.tilesToWinComputed(tilesToWin: 2),
  ],
  discardSuggested: _t(TileColor.black, 8),
  discardRackIndex: 12,
);

void main() {
  final logger = _MockAppLogger();

  /// One pinned-content scenario: how to build the bloc, plus the events
  /// that pin the layout/unlock variant.
  final scenarios = <String, ResultBloc Function()>{
    '21-tile 101, 6 groups, rack layout, detail locked': () => ResultBloc(
      _FixedSolveRack(_result101),
      logger,
      _outcome(
        GameMode.oneZeroOne,
        21,
      ),
    ),
    '21-tile 101, 6 groups, list layout, detail unlocked': () =>
        ResultBloc(
            _FixedSolveRack(_result101),
            logger,
            _outcome(
              GameMode.oneZeroOne,
              21,
            ),
          )
          ..add(const ResultEvent.layoutToggled(ResultLayout.list))
          ..add(const ResultEvent.detailUnlockGranted()),
    '15-tile okey, neededs + discard, detail unlocked': () => ResultBloc(
      _FixedSolveRack(_resultOkey),
      logger,
      _outcome(
        GameMode.okey,
        15,
      ),
    )..add(const ResultEvent.detailUnlockGranted()),
    'solver error state': () => ResultBloc(
      _ThrowingSolveRack(),
      logger,
      _outcome(
        GameMode.oneZeroOne,
        21,
      ),
    ),
  };

  Widget harness({
    required Size size,
    required double textScale,
    required Locale locale,
    required ResultBloc bloc,
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
        child: BlocProvider<ResultBloc>.value(
          value: bloc,
          child: const ResultView(),
        ),
      ),
    );
  }

  for (final MapEntry(key: name, value: buildBloc) in scenarios.entries) {
    for (final locale in _locales) {
      for (final size in _matrix) {
        for (final textScale in _textScales) {
          testWidgets(
            'ResultView ($name) no overflow '
            '@ ${locale.languageCode} $size x$textScale',
            (tester) async {
              tester.view.physicalSize = size;
              tester.view.devicePixelRatio = 1.0;
              addTearDown(tester.view.resetPhysicalSize);
              addTearDown(tester.view.resetDevicePixelRatio);

              final bloc = buildBloc();
              addTearDown(bloc.close);

              await tester.pumpWidget(
                harness(
                  size: size,
                  textScale: textScale,
                  locale: locale,
                  bloc: bloc,
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
