import 'package:flutter/material.dart';
import 'package:okey_acar_mi/core/theme/app_accent.dart';
import 'package:okey_acar_mi/core/theme/app_palette.dart';
import 'package:okey_acar_mi/core/theme/app_typography.dart';
import 'package:okey_acar_mi/core/theme/tile_style.dart';

/// Application themes.
///
/// Builds Material 3 [ThemeData] from the chosen [AppAccent] seed and
/// [TileStyle], attaching the design [AppPalette] as a [ThemeExtension] and the
/// design typography. Light / dark are Material brightness modes; **felt** is a
/// distinct green-table theme (not a brightness mode).
abstract final class AppTheme {
  /// Light scaffold background (`--bg`, light).
  static const Color _lightBg = Color(0xFFFAFAF9);

  /// Dark scaffold background (`--bg`, dark).
  static const Color _darkBg = Color(0xFF1B1A18);

  /// Felt scaffold background (`--bg`, felt).
  static const Color _feltBg = Color(0xFF1E4438);

  /// Light theme for the given [accent] and [tileStyle].
  static ThemeData light(AppAccent accent, TileStyle tileStyle) {
    final palette = AppPalette.light(accent, tileStyle, _lightBg);
    return _build(
      brightness: Brightness.light,
      accent: accent,
      bg: _lightBg,
      palette: palette,
    );
  }

  /// Dark theme for the given [accent] and [tileStyle].
  static ThemeData dark(AppAccent accent, TileStyle tileStyle) {
    final palette = AppPalette.dark(accent, tileStyle, _darkBg);
    return _build(
      brightness: Brightness.dark,
      accent: accent,
      bg: _darkBg,
      palette: palette,
    );
  }

  /// Felt (green-table) theme for the given [accent] and [tileStyle].
  ///
  /// Uses a dark [ColorScheme] base then overrides surfaces from the felt
  /// [AppPalette].
  static ThemeData felt(AppAccent accent, TileStyle tileStyle) {
    final palette = AppPalette.felt(accent, tileStyle, _feltBg);
    final base = _build(
      brightness: Brightness.dark,
      accent: accent,
      bg: _feltBg,
      palette: palette,
    );
    return base.copyWith(
      colorScheme: base.colorScheme.copyWith(
        surface: palette.surface,
        onSurface: palette.ink,
      ),
    );
  }

  static ThemeData _build({
    required Brightness brightness,
    required AppAccent accent,
    required Color bg,
    required AppPalette palette,
  }) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: accent.seed,
      brightness: brightness,
    );
    final base = ThemeData(colorScheme: colorScheme, useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: bg,
      textTheme: AppTypography.textTheme(base.textTheme),
      extensions: <ThemeExtension<dynamic>>[palette],
    );
  }
}
