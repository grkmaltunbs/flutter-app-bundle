import 'package:checks/checks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:okey_acar_mi/core/theme/app_accent.dart';
import 'package:okey_acar_mi/core/theme/app_theme.dart';
import 'package:okey_acar_mi/core/theme/tile_style.dart';
import 'package:okey_acar_mi/core/widgets/rack.dart';
import 'package:okey_acar_mi/core/widgets/tile.dart';
import 'package:okey_acar_mi/core/widgets/tile_data.dart';
import 'package:okey_acar_mi/l10n/app_localizations.dart';

/// Responsive size matrix from `CLAUDE.md`: smallest phone, typical phone,
/// largest phone, tablet. A `RenderFlex` overflow throws in debug, so pumping
/// each size at text scales 1.0 and 2.0 and asserting no exception catches an
/// overflow deterministically.
const _matrix = <Size>[
  Size(320, 568),
  Size(393, 852),
  Size(430, 932),
  Size(834, 1194),
];

const _textScales = <double>[1, 2];

/// The variable rack lengths from `PRODUCT_SPEC.md`: 14/15 for Okey,
/// 20/21 for 101.
const _tileCounts = <int>[14, 15, 20, 21];

/// Builds a representative [TileData] list of [count] tiles, cycling the four
/// colors and salting in a joker plus a low-confidence tile so the rack's
/// every branch (numeral, glyph, warn ring) is exercised.
List<TileData> _tiles(int count) {
  const colors = [
    TileColor.red,
    TileColor.black,
    TileColor.yellow,
    TileColor.blue,
  ];
  return [
    for (var i = 0; i < count; i++)
      if (i == count - 1)
        const TileData(color: TileColor.joker)
      else
        TileData(
          number: (i % 13) + 1,
          color: colors[i % colors.length],
          lowConfidence: i == 0,
        ),
  ];
}

/// Wraps a [Rack] with the theme (so `context.palette` resolves) and the matrix
/// [size]/[textScale], without a fixed-size `MaterialApp` view that could mask
/// an overflow.
Widget _harness({
  required Size size,
  required double textScale,
  required Widget child,
}) {
  return MaterialApp(
    theme: AppTheme.light(AppAccent.sage, TileStyle.classic),
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: const [Locale('tr'), Locale('en')],
    home: MediaQuery(
      data: MediaQueryData(
        size: size,
        textScaler: TextScaler.linear(textScale),
      ),
      // Pin the rack to the screen width via a full-width Align so the
      // LayoutBuilder receives realistic constraints (an unbounded width would
      // not reproduce the real layout).
      child: Align(
        alignment: Alignment.topCenter,
        child: SizedBox(width: size.width, child: child),
      ),
    ),
  );
}

/// Collects every [JokerGlyph] painter in the tree (it is a [CustomPainter]
/// hosted by a [CustomPaint], so it can't be located via `find.byType`).
Iterable<JokerGlyph> _jokerPainters(WidgetTester tester) {
  return tester
      .widgetList<CustomPaint>(find.byType(CustomPaint))
      .map((p) => p.painter)
      .whereType<JokerGlyph>();
}

void main() {
  group('Rack overflow guard', () {
    for (final count in _tileCounts) {
      for (final size in _matrix) {
        for (final textScale in _textScales) {
          testWidgets('$count tiles no overflow @ $size x$textScale', (
            tester,
          ) async {
            tester.view.physicalSize = size;
            tester.view.devicePixelRatio = 1.0;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);

            await tester.pumpWidget(
              _harness(
                size: size,
                textScale: textScale,
                child: Rack(tiles: _tiles(count)),
              ),
            );
            await tester.pumpAndSettle();

            check(tester.takeException()).isNull();
            // The rack actually rendered all its tiles.
            check(find.byType(Rack).evaluate()).length.equals(1);
            check(find.byType(Tile).evaluate()).length.equals(count);
            // The joker glyph (a CustomPainter in a CustomPaint) is present.
            check(_jokerPainters(tester)).isNotEmpty();
          });
        }
      }
    }

    testWidgets('worst case: 21 tiles @ Size(320, 568) x2.0 — no overflow', (
      tester,
    ) async {
      const size = Size(320, 568);
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        _harness(
          size: size,
          textScale: 2,
          child: Rack(tiles: _tiles(21)),
        ),
      );
      await tester.pumpAndSettle();

      check(tester.takeException()).isNull();
      check(find.byType(Rack).evaluate()).length.equals(1);
    });
  });
}
