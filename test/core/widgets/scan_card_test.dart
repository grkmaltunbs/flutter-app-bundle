import 'package:checks/checks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:okey_acar_mi/core/game/tile_color.dart';
import 'package:okey_acar_mi/core/theme/app_accent.dart';
import 'package:okey_acar_mi/core/theme/app_theme.dart';
import 'package:okey_acar_mi/core/theme/tile_style.dart';
import 'package:okey_acar_mi/core/widgets/scan_card.dart';
import 'package:okey_acar_mi/core/widgets/tile_data.dart';
import 'package:okey_acar_mi/l10n/app_localizations.dart';

const List<TileData> _fourTiles = [
  TileData(color: TileColor.red, number: 5),
  TileData(color: TileColor.black, number: 13),
  TileData(color: TileColor.joker),
  TileData(color: TileColor.blue, number: 1),
];

/// The hardest legal rack: 21 tiles (101 mode max), incl. a joker.
final List<TileData> _twentyOneTiles = [
  for (var i = 0; i < 20; i++)
    TileData(color: TileColor.values[i % 4], number: i % 13 + 1),
  const TileData(color: TileColor.joker),
];

Widget _harness({
  ScanCardTone tone = ScanCardTone.good,
  String pillLabel = 'Opened · 104',
  List<TileData> tiles = _fourTiles,
  VoidCallback? onTap,
}) {
  // (tiles defaults to the four-tile rack; pass _twentyOneTiles for the max.)
  return MaterialApp(
    theme: AppTheme.light(AppAccent.sage, TileStyle.classic),
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: const [Locale('tr'), Locale('en')],
    home: Scaffold(
      body: Center(
        child: ScanCard(
          timestamp: '21:48',
          modeLabel: '101 Okey',
          pillLabel: pillLabel,
          tone: tone,
          tiles: tiles,
          semanticsLabel: '21:48, Opened · 104. Open result.',
          onTap: onTap ?? () {},
        ),
      ),
    ),
  );
}

void main() {
  group('ScanCard', () {
    testWidgets('renders the timestamp · mode header and the pill label', (
      tester,
    ) async {
      await tester.pumpWidget(_harness());

      // Timestamp and mode share one Text.rich span tree.
      check(
        find.textContaining('21:48', findRichText: true).evaluate(),
      ).isNotEmpty();
      check(
        find.textContaining('101 Okey', findRichText: true).evaluate(),
      ).isNotEmpty();
      // The pill renders its label uppercase.
      check(find.text('OPENED · 104').evaluate()).length.equals(1);
      check(tester.takeException()).isNull();
    });

    testWidgets('good tone shows the check icon', (tester) async {
      await tester.pumpWidget(_harness());

      check(find.byIcon(Icons.check).evaluate()).length.equals(1);
      check(find.byIcon(Icons.close).evaluate()).isEmpty();
    });

    testWidgets('bad tone shows the close icon', (tester) async {
      await tester.pumpWidget(
        _harness(tone: ScanCardTone.bad, pillLabel: 'No · 60'),
      );

      check(find.byIcon(Icons.close).evaluate()).length.equals(1);
      check(find.byIcon(Icons.check).evaluate()).isEmpty();
    });

    testWidgets('neutral tone shows no verdict icon at all', (tester) async {
      await tester.pumpWidget(
        _harness(tone: ScanCardTone.neutral, pillLabel: '2 tiles'),
      );

      check(find.byIcon(Icons.check).evaluate()).isEmpty();
      check(find.byIcon(Icons.close).evaluate()).isEmpty();
      check(find.text('2 TILES').evaluate()).length.equals(1);
    });

    testWidgets('a 21-tile rack renders without throwing', (tester) async {
      await tester.pumpWidget(_harness(tiles: _twentyOneTiles));

      check(find.byType(ScanCard).evaluate()).length.equals(1);
      check(tester.takeException()).isNull();
    });

    testWidgets('announces exactly the composed semantics label (inner '
        'semantics excluded)', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_harness());

      check(
        find.bySemanticsLabel('21:48, Opened · 104. Open result.').evaluate(),
      ).length.equals(1);
      handle.dispose();
    });

    testWidgets('the whole card is the tap target and fires onTap', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(_harness(onTap: () => taps++));

      await tester.tap(find.byType(ScanCard));
      check(taps).equals(1);

      // A tap on the header area (not just the rack) also lands: the
      // InkWell spans the whole card.
      await tester.tapAt(
        tester.getTopLeft(find.byType(ScanCard)) + const Offset(40, 16),
      );
      check(taps).equals(2);
    });

    testWidgets('meets the 48dp minimum tap-target height', (tester) async {
      await tester.pumpWidget(_harness());

      check(
        tester.getSize(find.byType(ScanCard)).height,
      ).isGreaterOrEqual(48);
    });
  });
}
