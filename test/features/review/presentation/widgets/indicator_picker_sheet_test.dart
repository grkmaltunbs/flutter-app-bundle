import 'dart:async';

import 'package:checks/checks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:okey_acar_mi/core/game/game_mode.dart';
import 'package:okey_acar_mi/core/game/game_tile.dart';
import 'package:okey_acar_mi/core/game/indicator.dart';
import 'package:okey_acar_mi/core/theme/app_accent.dart';
import 'package:okey_acar_mi/core/theme/app_theme.dart';
import 'package:okey_acar_mi/core/theme/tile_style.dart';
import 'package:okey_acar_mi/core/widgets/app_buttons.dart';
import 'package:okey_acar_mi/core/widgets/tile.dart';
import 'package:okey_acar_mi/features/detection/data/fakes/seeded_detections.dart';
import 'package:okey_acar_mi/features/detection/domain/entities/detection_result.dart';
import 'package:okey_acar_mi/features/review/presentation/blocs/review_bloc.dart';
import 'package:okey_acar_mi/features/review/presentation/widgets/indicator_picker_sheet.dart';
import 'package:okey_acar_mi/l10n/app_localizations.dart';

/// The locale every assertion reads its strings from.
final AppLocalizations _l10n = lookupAppLocalizations(const Locale('en'));

DetectionResult _result() => DetectionResult(
  tiles: SeededDetections.rack101(),
  overallConfidence: 0.9,
  sourceImagePath: 'fixture.jpg',
  frameCount: 1,
  detectedAt: DateTime.utc(2026, 6, 11, 9, 30),
);

void main() {
  late ReviewBloc bloc;

  setUp(() => bloc = ReviewBloc(_result(), GameMode.oneZeroOne));
  tearDown(() => bloc.close());

  /// A host screen whose button opens the real modal sheet (sharing [bloc]),
  /// so the pop-on-confirm contract is observable.
  Widget harness() {
    return MaterialApp(
      theme: AppTheme.light(AppAccent.sage, TileStyle.classic),
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: const [Locale('tr'), Locale('en')],
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              key: const ValueKey('open-sheet'),
              onPressed: () {
                unawaited(showIndicatorPickerSheet(context, bloc: bloc));
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> openSheet(WidgetTester tester) async {
    await tester.pumpWidget(harness());
    await tester.tap(find.byKey(const ValueKey('open-sheet')));
    await tester.pumpAndSettle();
    check(find.byType(IndicatorPickerSheet).evaluate()).length.equals(1);
  }

  Finder colorOption(String colorName) =>
      find.bySemanticsLabel(_l10n.indicatorColorSemantics(colorName));

  Finder numberOption(int number) =>
      find.bySemanticsLabel(_l10n.indicatorNumberSemantics(number));

  PrimaryButton confirmButton(WidgetTester tester) => tester
      .widget<PrimaryButton>(find.byKey(const ValueKey('indicator-confirm')));

  /// The live okey preview tile inside the sheet, or null while hidden.
  Tile? previewTile(WidgetTester tester) {
    final finder = find.descendant(
      of: find.byType(IndicatorPickerSheet),
      matching: find.byType(Tile),
    );
    if (finder.evaluate().isEmpty) return null;
    return tester.widget<Tile>(finder);
  }

  testWidgets('offers exactly the four real colors — never the joker (D5)', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await openSheet(tester);

    for (final colorName in [
      _l10n.tileColorRed,
      _l10n.tileColorBlack,
      _l10n.tileColorYellow,
      _l10n.tileColorBlue,
    ]) {
      check(
        because: 'the $colorName option must be offered',
        colorOption(colorName).evaluate(),
      ).length.equals(1);
    }
    check(
      because: 'the joker is never a legal indicator',
      colorOption(_l10n.jokerSemantics).evaluate(),
    ).isEmpty();
    check(tester.takeException()).isNull();
    handle.dispose();
  });

  testWidgets('offers the numerals 1–13, each with a semantics label', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await openSheet(tester);

    for (var n = 1; n <= 13; n++) {
      check(
        because: 'numeral $n must be offered',
        numberOption(n).evaluate(),
      ).length.equals(1);
    }
    check(numberOption(0).evaluate()).isEmpty();
    check(numberOption(14).evaluate()).isEmpty();
    handle.dispose();
  });

  testWidgets('confirm stays disabled and no preview shows until both the '
      'color and the number are picked', (tester) async {
    final handle = tester.ensureSemantics();
    await openSheet(tester);

    check(confirmButton(tester).onPressed).isNull();
    check(previewTile(tester)).isNull();

    await tester.tap(colorOption(_l10n.tileColorBlue));
    await tester.pump();
    check(confirmButton(tester).onPressed).isNull();
    check(previewTile(tester)).isNull();

    await tester.tap(numberOption(5));
    await tester.pump();
    check(confirmButton(tester).onPressed).isNotNull();
    handle.dispose();
  });

  testWidgets('the live okey preview updates with the pick, wrapping '
      '13 → 1', (tester) async {
    final handle = tester.ensureSemantics();
    await openSheet(tester);

    // Blue 5 → okey blue 6.
    await tester.tap(colorOption(_l10n.tileColorBlue));
    await tester.pump();
    await tester.tap(numberOption(5));
    await tester.pump();
    check(previewTile(tester)).isNotNull();
    check(previewTile(tester)!.color).equals(TileColor.blue);
    check(previewTile(tester)!.number).equals(6);
    check(
      find.text(_l10n.reviewOkeyLabel(_l10n.tileColorBlue, 6)).evaluate(),
    ).length.equals(1);

    // Blue 13 → okey blue 1 (the wrap).
    await tester.tap(numberOption(13));
    await tester.pump();
    check(previewTile(tester)!.number).equals(1);
    check(
      find.text(_l10n.reviewOkeyLabel(_l10n.tileColorBlue, 1)).evaluate(),
    ).length.equals(1);

    // Same number, other color.
    await tester.tap(colorOption(_l10n.tileColorYellow));
    await tester.pump();
    check(previewTile(tester)!.color).equals(TileColor.yellow);
    check(previewTile(tester)!.number).equals(1);
    check(tester.takeException()).isNull();
    handle.dispose();
  });

  testWidgets('confirm dispatches indicatorPicked to the bloc and closes '
      'the sheet', (tester) async {
    final handle = tester.ensureSemantics();
    await openSheet(tester);

    await tester.tap(colorOption(_l10n.tileColorYellow));
    await tester.pump();
    await tester.tap(numberOption(13));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('indicator-confirm')));
    await tester.pumpAndSettle();

    check(find.byType(IndicatorPickerSheet).evaluate()).isEmpty();
    check(bloc.state.indicator).equals(
      const Indicator(color: TileColor.yellow, number: 13),
    );
    check(bloc.state.okeyTile).equals(
      const GameTile(color: TileColor.yellow, number: 1),
    );
    check(tester.takeException()).isNull();
    handle.dispose();
  });

  testWidgets('selection is ephemeral: closing without confirming leaves '
      'the bloc untouched', (tester) async {
    final handle = tester.ensureSemantics();
    await openSheet(tester);

    await tester.tap(colorOption(_l10n.tileColorRed));
    await tester.pump();
    await tester.tap(numberOption(3));
    await tester.pump();

    // Dismiss via the modal barrier instead of confirming.
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    check(find.byType(IndicatorPickerSheet).evaluate()).isEmpty();
    check(bloc.state.indicator).isNull();
    handle.dispose();
  });

  testWidgets('reopens preselected with the already-picked indicator', (
    tester,
  ) async {
    bloc.add(const ReviewEvent.indicatorPicked(TileColor.red, 7));
    final handle = tester.ensureSemantics();
    await openSheet(tester);

    // The current pick is live immediately: preview + enabled confirm.
    check(previewTile(tester)).isNotNull();
    check(previewTile(tester)!.color).equals(TileColor.red);
    check(previewTile(tester)!.number).equals(8);
    check(confirmButton(tester).onPressed).isNotNull();
    handle.dispose();
  });
}
