import 'package:checks/checks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:okey_acar_mi/core/theme/app_accent.dart';
import 'package:okey_acar_mi/core/theme/app_palette.dart';
import 'package:okey_acar_mi/core/theme/app_theme.dart';
import 'package:okey_acar_mi/core/theme/tile_style.dart';

void main() {
  group('AppTheme attaches the AppPalette extension', () {
    final builders = <String, ThemeData Function(AppAccent, TileStyle)>{
      'light': AppTheme.light,
      'dark': AppTheme.dark,
      'felt': AppTheme.felt,
    };

    for (final entry in builders.entries) {
      for (final accent in const [AppAccent.sage, AppAccent.coral]) {
        for (final style in const [TileStyle.classic, TileStyle.bold]) {
          // Built inside `testWidgets` because constructing the theme resolves
          // Google Fonts text styles, which need the widgets binding's asset
          // pipeline to be live.
          testWidgets(
            '${entry.key}($accent, $style) carries a palette with that style',
            (tester) async {
              final theme = entry.value(accent, style);
              final palette = theme.extension<AppPalette>();

              check(palette).isNotNull();
              check(palette!.tileStyle).equals(style);
              check(palette.accent).equals(accent.seed);
            },
          );
        }
      }
    }
  });
}
