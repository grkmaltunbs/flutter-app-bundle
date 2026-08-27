import 'package:flutter/material.dart' hide Step, StepState;
import 'package:flutter_kit/kit.dart';

/// The board's colour tokens, as a theme extension. Defaults are the
/// renderer's; a project's `board.colors` overrides them by key.
class KitTokens extends ThemeExtension<KitTokens> {
  const KitTokens({
    required this.brightness,
    required this.bg,
    required this.surface,
    required this.ink,
    required this.ink2,
    required this.muted,
    required this.line,
    required this.accent,
    required this.accentSoft,
    required this.good,
    required this.warn,
    required this.critical,
  });

  static const light = KitTokens(
    brightness: Brightness.light,
    bg: Color(0xFFF6F7F4),
    surface: Color(0xFFFFFFFF),
    ink: Color(0xFF16201F),
    ink2: Color(0xFF3B4644),
    muted: Color(0xFF7C8886),
    line: Color(0xFFDDE2DF),
    accent: Color(0xFF2F5BEA),
    accentSoft: Color(0xFFE3EAFF),
    good: Color(0xFF1F8A4C),
    warn: Color(0xFFB7791F),
    critical: Color(0xFFC53030),
  );

  static const dark = KitTokens(
    brightness: Brightness.dark,
    bg: Color(0xFF101413),
    surface: Color(0xFF181D1C),
    ink: Color(0xFFEEF1EF),
    ink2: Color(0xFFC3CAC7),
    muted: Color(0xFF8B9591),
    line: Color(0xFF2A3230),
    accent: Color(0xFF7FA3FF),
    accentSoft: Color(0xFF1B2540),
    good: Color(0xFF5FD08A),
    warn: Color(0xFFE4B25A),
    critical: Color(0xFFF28B82),
  );

  final Brightness brightness;
  final Color bg;
  final Color surface;
  final Color ink;
  final Color ink2;
  final Color muted;
  final Color line;
  final Color accent;
  final Color accentSoft;
  final Color good;
  final Color warn;
  final Color critical;

  /// Applies a project's `board.colors.<light|dark>` map on top of these.
  KitTokens withOverrides(Map<String, String> m) {
    Color pick(String key, Color base) {
      final v = m[key];
      if (v == null) return base;
      final hex = v.replaceFirst('#', '');
      final n = int.tryParse(hex.length == 6 ? 'FF$hex' : hex, radix: 16);
      return n == null ? base : Color(n);
    }

    return KitTokens(
      brightness: brightness,
      bg: pick('bg', bg),
      surface: pick('surface', surface),
      ink: pick('ink', ink),
      ink2: pick('ink2', ink2),
      muted: pick('muted', muted),
      line: pick('line', line),
      accent: pick('accent', accent),
      accentSoft: pick('accent_soft', accentSoft),
      good: pick('good', good),
      warn: pick('warn', warn),
      critical: pick('critical', critical),
    );
  }

  Color forState(StepState s) {
    switch (s) {
      case StepState.done:
      case StepState.flippable:
        return good;
      case StepState.ready:
      case StepState.active:
        return accent;
      case StepState.codeComplete:
        return warn;
      case StepState.blocked:
      case StepState.waiting:
        return muted;
    }
  }

  @override
  KitTokens copyWith() => this;

  @override
  KitTokens lerp(ThemeExtension<KitTokens>? other, double t) => t < 0.5 ? this : (other as KitTokens? ?? this);
}

extension KitTokensX on BuildContext {
  KitTokens get tokens => Theme.of(this).extension<KitTokens>() ?? KitTokens.light;
}

ThemeData kitTheme(KitTokens t) {
  final scheme = ColorScheme(
    brightness: t.brightness,
    primary: t.accent,
    onPrimary: t.brightness == Brightness.light ? Colors.white : const Color(0xFF0B1020),
    secondary: t.accent,
    onSecondary: Colors.white,
    error: t.critical,
    onError: Colors.white,
    surface: t.surface,
    onSurface: t.ink,
    outline: t.line,
    surfaceContainerHighest: t.accentSoft,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: t.bg,
    cardColor: t.surface,
    dividerColor: t.line,
    extensions: [t],
    appBarTheme: AppBarTheme(backgroundColor: t.bg, foregroundColor: t.ink, elevation: 0, scrolledUnderElevation: 0),
    cardTheme: CardThemeData(color: t.surface, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: t.line)), margin: EdgeInsets.zero),
    chipTheme: ChipThemeData(side: BorderSide(color: t.line), backgroundColor: t.surface, labelStyle: TextStyle(color: t.ink2, fontSize: 12), padding: const EdgeInsets.symmetric(horizontal: 6)),
    inputDecorationTheme: InputDecorationTheme(
      isDense: true,
      filled: true,
      fillColor: t.surface,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: t.line)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: t.line)),
    ),
    textTheme: Typography.material2021(platform: TargetPlatform.android).black.apply(bodyColor: t.ink, displayColor: t.ink),
  );
}
