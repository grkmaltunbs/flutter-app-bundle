import 'dart:ui';

import 'package:checks/checks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:okey_acar_mi/core/game/game_mode.dart';
import 'package:okey_acar_mi/core/game/game_tile.dart';
import 'package:okey_acar_mi/core/game/indicator.dart';
import 'package:okey_acar_mi/core/game/tile_color.dart';
import 'package:okey_acar_mi/features/result/presentation/reasoning_step_localizer.dart';
import 'package:okey_acar_mi/features/solver/domain/entities/reasoning_step.dart';
import 'package:okey_acar_mi/features/solver/domain/entities/solve_verdict.dart';
import 'package:okey_acar_mi/features/solver/domain/entities/solved_meld.dart';
import 'package:okey_acar_mi/features/solver/domain/entities/solved_spot.dart';
import 'package:okey_acar_mi/l10n/app_localizations.dart';

GameTile _t(TileColor color, int number) =>
    GameTile(color: color, number: number);

SolvedSpot _rack(TileColor color, int number, int rackIndex) =>
    SolvedSpot.rackTile(
      physical: _t(color, number),
      rackIndex: rackIndex,
      playsAs: _t(color, number),
    );

/// Every sealed [ReasoningStep] variant (12), with boolean/enum branches
/// covered by extra instances so each l10n arm is exercised.
final Map<String, ReasoningStep> _steps = {
  'okeyDerived': ReasoningStep.okeyDerived(
    indicator: const Indicator(color: TileColor.yellow, number: 13),
    okeyTile: _t(TileColor.yellow, 1),
  ),
  'wildsCounted': const ReasoningStep.wildsCounted(
    falseJokers: 1,
    okeyCopies: 2,
  ),
  'rackCountNoted (101)': const ReasoningStep.rackCountNoted(
    count: 21,
    mode: GameMode.oneZeroOne,
  ),
  'rackCountNoted (okey)': const ReasoningStep.rackCountNoted(
    count: 15,
    mode: GameMode.okey,
  ),
  'countsClamped': ReasoningStep.countsClamped(
    kind: _t(TileColor.black, 7),
    dropped: 1,
  ),
  'meldFormed (run)': ReasoningStep.meldFormed(
    meld: SolvedMeld(
      kind: MeldKind.run,
      spots: [
        _rack(TileColor.red, 5, 0),
        _rack(TileColor.red, 6, 1),
        _rack(TileColor.red, 7, 2),
      ],
      points: 18,
    ),
    runningTotal: 18,
  ),
  'meldFormed (set)': ReasoningStep.meldFormed(
    meld: SolvedMeld(
      kind: MeldKind.set,
      spots: [
        _rack(TileColor.red, 4, 3),
        _rack(TileColor.blue, 4, 4),
        _rack(TileColor.black, 4, 5),
      ],
      points: 12,
    ),
    runningTotal: 30,
  ),
  'thresholdChecked (opens)': const ReasoningStep.thresholdChecked(
    total: 104,
    threshold: 101,
    opens: true,
  ),
  'thresholdChecked (short)': const ReasoningStep.thresholdChecked(
    total: 96,
    threshold: 101,
    opens: false,
  ),
  'pairsCounted (opens)': const ReasoningStep.pairsCounted(
    pairCount: 5,
    opens: true,
  ),
  'pairsCounted (short)': const ReasoningStep.pairsCounted(
    pairCount: 3,
    opens: false,
  ),
  'pathChosen (melds)': const ReasoningStep.pathChosen(via: OpenPath.melds),
  'pathChosen (pairs)': const ReasoningStep.pathChosen(via: OpenPath.pairs),
  'okeyTemplateChosen (meldsAndPair)': const ReasoningStep.okeyTemplateChosen(
    via: OkeyPath.meldsAndPair,
    matched: 12,
    wildsUsed: 1,
  ),
  'okeyTemplateChosen (sevenPairs)': const ReasoningStep.okeyTemplateChosen(
    via: OkeyPath.sevenPairs,
    matched: 13,
    wildsUsed: 0,
  ),
  'tilesNeeded': ReasoningStep.tilesNeeded(
    needed: [
      _t(TileColor.black, 13),
      const GameTile(color: TileColor.joker),
    ],
  ),
  'discardSuggested': ReasoningStep.discardSuggested(
    tile: _t(TileColor.red, 13),
    rackIndex: 13,
  ),
  'tilesToWinComputed (1)': const ReasoningStep.tilesToWinComputed(
    tilesToWin: 1,
  ),
  'tilesToWinComputed (2)': const ReasoningStep.tilesToWinComputed(
    tilesToWin: 2,
  ),
};

/// The numeric placeholders each step must surface verbatim in its text.
final Map<String, List<String>> _expectedFigures = {
  'wildsCounted': ['1', '2'],
  'rackCountNoted (101)': ['21'],
  'rackCountNoted (okey)': ['15'],
  'countsClamped': ['7', '1'],
  'meldFormed (run)': ['5', '7', '18'],
  'meldFormed (set)': ['4', '30'],
  'thresholdChecked (opens)': ['104', '101'],
  'thresholdChecked (short)': ['96', '101'],
  'pairsCounted (opens)': ['5'],
  'pairsCounted (short)': ['3'],
  'okeyTemplateChosen (meldsAndPair)': ['12', '1'],
  'okeyTemplateChosen (sevenPairs)': ['13', '0'],
  'tilesNeeded': ['13'],
  'discardSuggested': ['13'],
  'tilesToWinComputed (1)': ['1'],
  'tilesToWinComputed (2)': ['2'],
};

void main() {
  for (final locale in const [Locale('tr'), Locale('en')]) {
    final l10n = lookupAppLocalizations(locale);

    group('reasoningStepText (${locale.languageCode})', () {
      for (final MapEntry(key: name, value: step) in _steps.entries) {
        test('$name produces substituted, non-empty text', () {
          final text = reasoningStepText(l10n, step);

          check(text.trim()).isNotEmpty();
          // No leftover ICU placeholders.
          check(text.contains('{')).isFalse();
          check(text.contains('}')).isFalse();
          (_expectedFigures[name] ?? const <String>[]).forEach(
            check(text).contains,
          );
        });
      }

      test('okeyDerived carries both formatted tiles', () {
        final text = reasoningStepText(l10n, _steps['okeyDerived']!);
        check(text).contains(
          formatIndicator(
            l10n,
            const Indicator(color: TileColor.yellow, number: 13),
          ),
        );
        check(text).contains(formatGameTile(l10n, _t(TileColor.yellow, 1)));
      });

      test('tilesNeeded joins every needed tile, jokers included', () {
        final text = reasoningStepText(l10n, _steps['tilesNeeded']!);
        check(text).contains(formatGameTile(l10n, _t(TileColor.black, 13)));
        check(text).contains(l10n.jokerSemantics);
      });

      group('formatGameTile', () {
        test('a numbered tile is "<color> <number>"', () {
          check(formatGameTile(l10n, _t(TileColor.red, 7))).equals(
            l10n.tileSemantics(l10n.tileColorRed, 7),
          );
        });

        test('the joker renders its own label, never a number', () {
          check(
            formatGameTile(l10n, const GameTile(color: TileColor.joker)),
          ).equals(l10n.jokerSemantics);
        });
      });
    });
  }
}
