import 'package:checks/checks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:okey_acar_mi/core/theme/app_accent.dart';
import 'package:okey_acar_mi/core/theme/app_palette.dart';
import 'package:okey_acar_mi/core/theme/app_theme.dart';
import 'package:okey_acar_mi/core/theme/tile_style.dart';
import 'package:okey_acar_mi/core/widgets/app_text_field.dart';
import 'package:okey_acar_mi/l10n/app_localizations.dart';

const ValueKey<String> _toggleKey = ValueKey('field-visibility');

/// Wraps the field with an `en`-locale theme so `context.palette` and the
/// l10n-backed visibility tooltip resolve.
Widget _harness(Widget child) {
  return MaterialApp(
    theme: AppTheme.light(AppAccent.sage, TileStyle.classic),
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: const [Locale('tr'), Locale('en')],
    home: Scaffold(
      body: Padding(padding: const EdgeInsets.all(16), child: child),
    ),
  );
}

void main() {
  late TextEditingController controller;

  setUp(() {
    controller = TextEditingController();
    addTearDown(controller.dispose);
  });

  group('AppTextField', () {
    testWidgets('renders its hint while empty', (tester) async {
      await tester.pumpWidget(
        _harness(
          AppTextField(controller: controller, hintText: 'Email address'),
        ),
      );

      check(find.text('Email address').evaluate()).length.equals(1);
      check(tester.takeException()).isNull();
    });

    testWidgets('renders errorText below the field in the bad color', (
      tester,
    ) async {
      final palette = AppTheme.light(
        AppAccent.sage,
        TileStyle.classic,
      ).extension<AppPalette>()!;

      await tester.pumpWidget(
        _harness(
          AppTextField(controller: controller, errorText: 'Invalid value'),
        ),
      );
      await tester.pumpAndSettle();

      final errorFinder = find.text('Invalid value');
      check(errorFinder.evaluate()).length.equals(1);
      check(tester.widget<Text>(errorFinder).style?.color).equals(palette.bad);
    });

    group('obscurable', () {
      testWidgets('starts obscured; the eye toggle reveals and re-hides', (
        tester,
      ) async {
        controller.text = 'gizli-parola';
        await tester.pumpWidget(
          _harness(
            AppTextField(
              controller: controller,
              obscurable: true,
              visibilityToggleKey: _toggleKey,
            ),
          ),
        );

        EditableText editable() =>
            tester.widget<EditableText>(find.byType(EditableText));
        IconButton toggle() =>
            tester.widget<IconButton>(find.byKey(_toggleKey));

        check(editable().obscureText).isTrue();
        // app_en.arb: textFieldShowPassword == "Show password".
        check(toggle().tooltip).equals('Show password');

        await tester.tap(find.byKey(_toggleKey));
        await tester.pump();
        check(editable().obscureText).isFalse();
        check(toggle().tooltip).equals('Hide password');

        await tester.tap(find.byKey(_toggleKey));
        await tester.pump();
        check(editable().obscureText).isTrue();
        check(toggle().tooltip).equals('Show password');
      });

      testWidgets('a non-obscurable field has no visibility toggle', (
        tester,
      ) async {
        await tester.pumpWidget(
          _harness(AppTextField(controller: controller)),
        );

        check(find.byType(IconButton).evaluate()).isEmpty();
      });
    });

    testWidgets('respects enabled: false', (tester) async {
      await tester.pumpWidget(
        _harness(AppTextField(controller: controller, enabled: false)),
      );

      check(
        tester.widget<TextField>(find.byType(TextField)).enabled,
      ).equals(false);
    });

    testWidgets('grows without exceptions at textScale 2.0 in a 320-wide '
        'viewport', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        _harness(
          MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 568),
              textScaler: TextScaler.linear(2),
            ),
            child: AppTextField(
              controller: controller,
              hintText: 'Email address',
              errorText:
                  'A long inline error message that has to wrap '
                  'across several lines at double text scale',
              obscurable: true,
              visibilityToggleKey: _toggleKey,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      check(tester.takeException()).isNull();
    });
  });
}
