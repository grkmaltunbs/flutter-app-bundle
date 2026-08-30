import 'package:flutter/material.dart' hide Step, StepState;
import 'package:flutter_kit/kit.dart';

/// The three bundled families of the Instrument skin (OFL, in `fonts/`):
/// Rajdhani for headings and buttons, IBM Plex Sans for prose,
/// JetBrains Mono for readouts.
const kDisplayFont = 'Rajdhani';
const kBodyFont = 'IBM Plex Sans';
const kMonoFont = 'JetBrains Mono';

/// The board's colour tokens, as a theme extension. Defaults are the two
/// skins the direction item picked — **Instrument** by night, **Daylight**
/// by day; a project's `board.colors` overrides them by key.
class KitTokens extends ThemeExtension<KitTokens> {
  const KitTokens({
    required this.brightness,
    required this.bg,
    required this.surface,
    required this.bubble,
    required this.ground,
    required this.ink,
    required this.ink2,
    required this.muted,
    required this.line,
    required this.lineStrong,
    required this.accent,
    required this.accentSoft,
    required this.good,
    required this.warn,
    required this.warnSoft,
    required this.critical,
  });

  /// Daylight — the Instrument language on paper, for reading in sun.
  static const light = KitTokens(
    brightness: Brightness.light,
    bg: Color(0xFFF3F5F8),
    surface: Color(0xFFFFFFFF),
    bubble: Color(0xFFFFFFFF),
    ground: Color(0xFFEDF1F6),
    ink: Color(0xFF0F1722),
    ink2: Color(0xFF3C4A5E),
    muted: Color(0xFF6F7C8E),
    line: Color(0xFFD9E0EA),
    lineStrong: Color(0xFFB7C2D0),
    accent: Color(0xFF0B7FC2),
    accentSoft: Color(0xFFE3F1FA),
    good: Color(0xFF1F8A4C),
    warn: Color(0xFFB2610A),
    warnSoft: Color(0xFFFFF7EC),
    critical: Color(0xFFC43D3D),
  );

  /// Instrument — deep blue-black, one cyan for the system, one amber for
  /// anything that waits on the person.
  static const dark = KitTokens(
    brightness: Brightness.dark,
    bg: Color(0xFF070B12),
    surface: Color(0xFF0C1320),
    bubble: Color(0xFF111B2B),
    ground: Color(0xFF090E17),
    ink: Color(0xFFE7EEF8),
    ink2: Color(0xFFA7B4C7),
    muted: Color(0xFF67788F),
    line: Color(0x2974A8FF), // rgba(116,168,255,.16) — the HUD hairline
    lineStrong: Color(0x4774A8FF), // rgba(116,168,255,.28)
    accent: Color(0xFF58D7FF),
    accentSoft: Color(0x1A58D7FF), // rgba(88,215,255,.10)
    good: Color(0xFF5FE3A1),
    warn: Color(0xFFFFB454),
    warnSoft: Color(0x12FFB454),
    critical: Color(0xFFFF7A7A),
  );

  final Brightness brightness;
  final Color bg;
  final Color surface;

  /// The person's own bubble in the Deck.
  final Color bubble;

  /// The constellation's ground, a shade below [bg].
  final Color ground;
  final Color ink;
  final Color ink2;
  final Color muted;
  final Color line;
  final Color lineStrong;
  final Color accent;
  final Color accentSoft;
  final Color good;
  final Color warn;
  final Color warnSoft;
  final Color critical;

  /// Text on a filled accent surface.
  Color get onAccent => brightness == Brightness.dark ? const Color(0xFF06202B) : Colors.white;

  /// Text on a filled amber surface.
  Color get onWarn => brightness == Brightness.dark ? const Color(0xFF1A1206) : Colors.white;

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
      bubble: pick('bubble', bubble),
      ground: pick('ground', ground),
      ink: pick('ink', ink),
      ink2: pick('ink2', ink2),
      muted: pick('muted', muted),
      line: pick('line', line),
      lineStrong: pick('line_strong', lineStrong),
      accent: pick('accent', accent),
      accentSoft: pick('accent_soft', accentSoft),
      good: pick('good', good),
      warn: pick('warn', warn),
      warnSoft: pick('warn_soft', warnSoft),
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

  // --- The three voices of the skin ---------------------------------------

  /// Rajdhani — headings, wordmarks, buttons. Tracking scales with size.
  TextStyle display(double size, {FontWeight weight = FontWeight.w700, Color? color, double? ls, double height = 1.05}) =>
      TextStyle(fontFamily: kDisplayFont, fontSize: size, fontWeight: weight, color: color ?? ink, letterSpacing: ls ?? size * 0.14, height: height);

  /// JetBrains Mono — readouts, commands, tool rows.
  TextStyle mono(double size, {Color? color, FontWeight weight = FontWeight.w400, double ls = 0, double height = 1.4}) =>
      TextStyle(fontFamily: kMonoFont, fontSize: size, color: color ?? ink2, fontWeight: weight, letterSpacing: ls, height: height);

  /// The small ALL-CAPS mono readout (`NOW · /STEP …`).
  TextStyle readout(double size, {Color? color, FontWeight weight = FontWeight.w400}) =>
      mono(size, color: color ?? muted, weight: weight, ls: size * 0.08, height: 1.3);

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
    onPrimary: t.onAccent,
    secondary: t.accent,
    onSecondary: t.onAccent,
    error: t.critical,
    onError: Colors.white,
    surface: t.surface,
    onSurface: t.ink,
    outline: t.line,
    surfaceContainerHighest: t.accentSoft,
  );
  final button = TextStyle(fontFamily: kDisplayFont, fontWeight: FontWeight.w700, fontSize: 15, letterSpacing: 1.8);
  final buttonQuiet = TextStyle(fontFamily: kDisplayFont, fontWeight: FontWeight.w600, fontSize: 14, letterSpacing: 1.4);
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: t.bg,
    cardColor: t.surface,
    dividerColor: t.line,
    splashFactory: NoSplash.splashFactory,
    extensions: [t],
    appBarTheme: AppBarTheme(
      backgroundColor: t.bg,
      foregroundColor: t.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: t.display(20, color: t.ink),
    ),
    cardTheme: CardThemeData(color: t.surface, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: t.line)), margin: EdgeInsets.zero),
    chipTheme: ChipThemeData(side: BorderSide(color: t.line), backgroundColor: Colors.transparent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), labelStyle: t.mono(12, color: t.ink2), padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6)),
    tabBarTheme: TabBarThemeData(
      labelColor: t.ink,
      unselectedLabelColor: t.muted,
      indicatorColor: t.accent,
      dividerColor: Colors.transparent,
      labelStyle: t.display(13, weight: FontWeight.w600, ls: 2.2),
      unselectedLabelStyle: t.display(13, weight: FontWeight.w600, ls: 2.2, color: t.muted),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: t.accent,
        foregroundColor: t.onAccent,
        minimumSize: const Size(64, 44),
        padding: const EdgeInsets.symmetric(horizontal: 18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: button,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: t.ink2,
        side: BorderSide(color: t.lineStrong),
        minimumSize: const Size(64, 44),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: buttonQuiet,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: t.ink2,
        minimumSize: const Size(48, 44),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: buttonQuiet,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      isDense: true,
      filled: true,
      fillColor: t.surface,
      hintStyle: TextStyle(color: t.muted),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: t.line)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: t.line)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: t.accent.withValues(alpha: 0.55))),
    ),
    textTheme: Typography.material2021(platform: TargetPlatform.android).black.apply(fontFamily: kBodyFont, bodyColor: t.ink, displayColor: t.ink),
  );
}
