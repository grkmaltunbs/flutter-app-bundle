import 'package:flutter/material.dart';
import 'package:okey_acar_mi/core/theme/app_colors.dart';
import 'package:okey_acar_mi/core/theme/app_typography.dart';

/// Application themes.
///
/// Step 0 ships seed-derived [light] and [dark] Material 3 themes wired to the
/// design typography. The felt (green-table) theme, the system/accent picker,
/// and tile-style settings are Step 1.
// TODO(step-1): add felt theme, accent picker, tile-style, and ThemeExtensions.
abstract final class AppTheme {
  /// Light theme.
  static ThemeData get light => _build(Brightness.light);

  /// Dark theme.
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.seed,
      brightness: brightness,
    );
    final base = ThemeData(colorScheme: colorScheme, useMaterial3: true);
    return base.copyWith(
      textTheme: AppTypography.textTheme(base.textTheme),
    );
  }
}
