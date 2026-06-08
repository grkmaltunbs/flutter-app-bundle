import 'package:checks/checks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:okey_acar_mi/core/theme/app_accent.dart';
import 'package:okey_acar_mi/core/theme/app_theme.dart';
import 'package:okey_acar_mi/core/theme/tile_style.dart';
import 'package:okey_acar_mi/core/widgets/tile.dart';
import 'package:okey_acar_mi/l10n/app_localizations.dart';

/// Collects every [JokerGlyph] painter in the tree (it is a [CustomPainter]
/// hosted by a [CustomPaint], so it can't be located via `find.byType`).
Iterable<JokerGlyph> _jokerPainters(WidgetTester tester) {
  return tester
      .widgetList<CustomPaint>(find.byType(CustomPaint))
      .map((p) => p.painter)
      .whereType<JokerGlyph>();
}

/// Wraps a [Tile] with an `en`-locale theme so `context.palette` and
/// `context.l10n` resolve (the semantics labels are taken from `app_en.arb`).
Widget _harness(Widget child) {
  return MaterialApp(
    theme: AppTheme.light(AppAccent.sage, TileStyle.classic),
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: const [Locale('tr'), Locale('en')],
    home: Scaffold(body: Center(child: child)),
  );
}

void main() {
  group('Tile rendering', () {
    for (final style in TileStyle.values) {
      testWidgets('renders a numbered tile in $style without error', (
        tester,
      ) async {
        await tester.pumpWidget(
          _harness(Tile(number: 7, color: TileColor.red, style: style)),
        );
        await tester.pumpAndSettle();

        check(tester.takeException()).isNull();
        check(find.byType(Tile).evaluate()).length.equals(1);
        // A numbered tile shows its numeral as text.
        check(find.text('7').evaluate()).isNotEmpty();
      });

      testWidgets('renders a joker tile in $style as a glyph (no numeral)', (
        tester,
      ) async {
        await tester.pumpWidget(
          _harness(Tile(color: TileColor.joker, style: style)),
        );
        await tester.pumpAndSettle();

        check(tester.takeException()).isNull();
        // The joker is drawn by the JokerGlyph CustomPainter, not a numeral.
        check(_jokerPainters(tester)).isNotEmpty();
        check(find.text('0').evaluate()).isEmpty();
      });
    }
  });

  group('Tile semantics', () {
    testWidgets('numbered tile exposes a localized color+number label', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(const Tile(number: 7, color: TileColor.red)),
      );
      await tester.pumpAndSettle();

      // app_en.arb: tileSemantics == "{color} {number}", tileColorRed == "Red".
      check(find.bySemanticsLabel('Red 7').evaluate()).isNotEmpty();
    });

    testWidgets('joker tile exposes the joker label', (tester) async {
      await tester.pumpWidget(
        _harness(const Tile(color: TileColor.joker)),
      );
      await tester.pumpAndSettle();

      // app_en.arb: jokerSemantics == "Joker".
      check(find.bySemanticsLabel('Joker').evaluate()).isNotEmpty();
    });
  });

  group('Tile variants', () {
    testWidgets('faded variant pumps without error', (tester) async {
      await tester.pumpWidget(
        _harness(const Tile(number: 3, color: TileColor.blue, faded: true)),
      );
      await tester.pumpAndSettle();

      check(tester.takeException()).isNull();
      check(find.byType(Tile).evaluate()).length.equals(1);
    });

    testWidgets('selected variant pumps without error', (tester) async {
      await tester.pumpWidget(
        _harness(
          const Tile(number: 3, color: TileColor.blue, selected: true),
        ),
      );
      await tester.pumpAndSettle();

      check(tester.takeException()).isNull();
      check(find.byType(Tile).evaluate()).length.equals(1);
    });

    testWidgets('tappable tile invokes onTap and exposes a button', (
      tester,
    ) async {
      var tapped = false;
      await tester.pumpWidget(
        _harness(
          Tile(
            number: 5,
            color: TileColor.yellow,
            onTap: () => tapped = true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(Tile));
      await tester.pumpAndSettle();

      check(tapped).isTrue();
      check(tester.takeException()).isNull();
    });
  });
}
