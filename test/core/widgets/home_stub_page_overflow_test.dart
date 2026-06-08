import 'package:checks/checks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:okey_acar_mi/core/widgets/home_stub_page.dart';
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

/// Wraps the screen under test with the theme + localization ancestry it needs
/// (`context.textTheme`, `context.l10n`) and the matrix [size]/[textScale],
/// without a fixed-size `MaterialApp` view that could mask an overflow.
Widget _harness({
  required Size size,
  required double textScale,
  required Widget child,
}) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: const [Locale('tr'), Locale('en')],
    home: MediaQuery(
      data: MediaQueryData(
        size: size,
        textScaler: TextScaler.linear(textScale),
      ),
      child: child,
    ),
  );
}

void main() {
  group('HomeStubPage overflow guard', () {
    for (final size in _matrix) {
      for (final textScale in _textScales) {
        testWidgets('no overflow @ $size x$textScale', (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          await tester.pumpWidget(
            _harness(
              size: size,
              textScale: textScale,
              child: const HomeStubPage(),
            ),
          );
          await tester.pumpAndSettle();

          check(tester.takeException()).isNull();
          check(find.text('101 Okey Açar Mı').evaluate()).length.equals(1);
        });
      }
    }
  });
}
