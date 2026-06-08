import 'package:flutter/material.dart';
import 'package:okey_acar_mi/core/theme/app_accent.dart';
import 'package:okey_acar_mi/core/theme/tile_style.dart';

/// Design tokens that don't map cleanly onto Material's [ColorScheme], plus the
/// active [TileStyle].
///
/// Exposed as a [ThemeExtension] so widgets can read brand surfaces, ink ramps,
/// tile colors, and feedback colors via `context.palette`. Token values are
/// sRGB approximations of the `oklch(...)` custom properties in the design
/// bundle's `styles.css`, with per-theme sets for light / dark / felt.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  /// Creates an [AppPalette] with every token specified.
  const AppPalette({
    required this.surface,
    required this.surface2,
    required this.surface3,
    required this.ink,
    required this.ink2,
    required this.muted,
    required this.faint,
    required this.line,
    required this.line2,
    required this.tileRed,
    required this.tileBlack,
    required this.tileYellow,
    required this.tileBlue,
    required this.tileFace,
    required this.tileFaceEdge,
    required this.good,
    required this.warn,
    required this.bad,
    required this.accent,
    required this.accentSoft,
    required this.accentInk,
    required this.rackTop,
    required this.rackBottom,
    required this.rackBorder,
    required this.tileStyle,
  });

  /// Builds the light-theme palette for the given [accent] and [tileStyle].
  ///
  /// [bg] is the scaffold background used to derive accent-soft.
  factory AppPalette.light(AppAccent accent, TileStyle tileStyle, Color bg) {
    return AppPalette._build(
      accent: accent,
      tileStyle: tileStyle,
      bg: bg,
      surface: const Color(0xFFFFFFFF),
      surface2: const Color(0xFFF4F3F1),
      surface3: const Color(0xFFEBE9E6),
      ink: const Color(0xFF1F1D1A),
      ink2: const Color(0xFF3E3B36),
      muted: const Color(0xFF7A756D),
      faint: const Color(0xFFABA69E),
      line: const Color(0xFFE7E5E2),
      line2: const Color(0xFFDCD9D5),
      tileFace: const Color(0xFFF5F1EA),
      tileFaceEdge: const Color(0xFFE0DACF),
      rackTop: const Color(0xFFEBE9E6),
      rackBottom: const Color(0xFFF4F3F1),
      rackBorder: const Color(0xFFDCD9D5),
    );
  }

  /// Builds the dark-theme palette for the given [accent] and [tileStyle].
  ///
  /// [bg] is the scaffold background used to derive accent-soft.
  factory AppPalette.dark(AppAccent accent, TileStyle tileStyle, Color bg) {
    return AppPalette._build(
      accent: accent,
      tileStyle: tileStyle,
      bg: bg,
      surface: const Color(0xFF242220),
      surface2: const Color(0xFF2B2926),
      surface3: const Color(0xFF34322E),
      ink: const Color(0xFFF4F3F1),
      ink2: const Color(0xFFD5D2CE),
      muted: const Color(0xFF918C84),
      faint: const Color(0xFF625E58),
      line: const Color(0xFF36332F),
      line2: const Color(0xFF423E39),
      tileFace: const Color(0xFFEDE8E1),
      tileFaceEdge: const Color(0xFFD3CCC0),
      rackTop: const Color(0xFF34322E),
      rackBottom: const Color(0xFF2B2926),
      rackBorder: const Color(0xFF423E39),
    );
  }

  /// Builds the felt (green-table) palette for the given [accent] and
  /// [tileStyle].
  ///
  /// [bg] is the scaffold background used to derive accent-soft.
  factory AppPalette.felt(AppAccent accent, TileStyle tileStyle, Color bg) {
    return AppPalette._build(
      accent: accent,
      tileStyle: tileStyle,
      bg: bg,
      surface: const Color(0xFF234E41),
      surface2: const Color(0xFF29594A),
      surface3: const Color(0xFF2F6453),
      ink: const Color(0xFFF7F5F2),
      ink2: const Color(0xFFE3E0DB),
      muted: const Color(0xFFA8C4B8),
      faint: const Color(0xFF6E9384),
      line: const Color(0xFF356957),
      line2: const Color(0xFF3F7B66),
      tileFace: const Color(0xFFEFE9E1),
      tileFaceEdge: const Color(0xFFD4CCBF),
      rackTop: const Color(0xFF2F6453),
      rackBottom: const Color(0xFF234E41),
      rackBorder: const Color(0xFF356957),
    );
  }

  /// Assembles a palette from theme-specific tokens plus the shared tile /
  /// feedback colors, deriving accent-soft / accent-ink from [accent] over [bg].
  factory AppPalette._build({
    required AppAccent accent,
    required TileStyle tileStyle,
    required Color bg,
    required Color surface,
    required Color surface2,
    required Color surface3,
    required Color ink,
    required Color ink2,
    required Color muted,
    required Color faint,
    required Color line,
    required Color line2,
    required Color tileFace,
    required Color tileFaceEdge,
    required Color rackTop,
    required Color rackBottom,
    required Color rackBorder,
  }) {
    final accentColor = accent.seed;
    return AppPalette(
      surface: surface,
      surface2: surface2,
      surface3: surface3,
      ink: ink,
      ink2: ink2,
      muted: muted,
      faint: faint,
      line: line,
      line2: line2,
      tileRed: _tileRed,
      tileBlack: _tileBlack,
      tileYellow: _tileYellow,
      tileBlue: _tileBlue,
      tileFace: tileFace,
      tileFaceEdge: tileFaceEdge,
      good: _good,
      warn: _warn,
      bad: _bad,
      accent: accentColor,
      accentSoft: Color.lerp(bg, accentColor, 0.14)!,
      accentInk: Color.lerp(accentColor, Colors.black, 0.32)!,
      rackTop: rackTop,
      rackBottom: rackBottom,
      rackBorder: rackBorder,
      tileStyle: tileStyle,
    );
  }

  /// Shared tile color for red across all themes.
  static const Color _tileRed = Color(0xFFC8393A);

  /// Shared tile color for black across all themes.
  static const Color _tileBlack = Color(0xFF171B1F);

  /// Shared tile color for yellow across all themes.
  static const Color _tileYellow = Color(0xFFD6A20A);

  /// Shared tile color for blue across all themes.
  static const Color _tileBlue = Color(0xFF005FA8);

  /// Shared positive feedback color across all themes.
  static const Color _good = Color(0xFF399D57);

  /// Shared caution feedback color across all themes.
  static const Color _warn = Color(0xFFE18528);

  /// Shared negative feedback color across all themes.
  static const Color _bad = Color(0xFFD74745);

  /// Primary surface (`--surface`).
  final Color surface;

  /// Secondary surface (`--surface-2`).
  final Color surface2;

  /// Tertiary surface (`--surface-3`).
  final Color surface3;

  /// Primary ink / text (`--ink`).
  final Color ink;

  /// Secondary ink (`--ink-2`).
  final Color ink2;

  /// Muted text (`--muted`).
  final Color muted;

  /// Faint text (`--faint`).
  final Color faint;

  /// Hairline divider (`--line`).
  final Color line;

  /// Stronger divider / border (`--line-2`).
  final Color line2;

  /// Red tile color (`--tile-red`).
  final Color tileRed;

  /// Black tile color (`--tile-black`).
  final Color tileBlack;

  /// Yellow tile color (`--tile-yellow`).
  final Color tileYellow;

  /// Blue tile color (`--tile-blue`).
  final Color tileBlue;

  /// Cream tile face (`--tile-face`).
  final Color tileFace;

  /// Tile face gradient edge (`--tile-face-edge`).
  final Color tileFaceEdge;

  /// Positive / success feedback (`--good`).
  final Color good;

  /// Caution feedback (`--warn`).
  final Color warn;

  /// Negative / error feedback (`--bad`).
  final Color bad;

  /// The active accent color (`--accent`).
  final Color accent;

  /// Accent blended softly over the background (`--accent-soft`).
  final Color accentSoft;

  /// Darkened accent for text on accent-soft surfaces (`--accent-ink`).
  final Color accentInk;

  /// Rack gradient top stop.
  final Color rackTop;

  /// Rack gradient bottom stop.
  final Color rackBottom;

  /// Rack border color.
  final Color rackBorder;

  /// The active tile rendering style.
  final TileStyle tileStyle;

  @override
  AppPalette copyWith({
    Color? surface,
    Color? surface2,
    Color? surface3,
    Color? ink,
    Color? ink2,
    Color? muted,
    Color? faint,
    Color? line,
    Color? line2,
    Color? tileRed,
    Color? tileBlack,
    Color? tileYellow,
    Color? tileBlue,
    Color? tileFace,
    Color? tileFaceEdge,
    Color? good,
    Color? warn,
    Color? bad,
    Color? accent,
    Color? accentSoft,
    Color? accentInk,
    Color? rackTop,
    Color? rackBottom,
    Color? rackBorder,
    TileStyle? tileStyle,
  }) {
    return AppPalette(
      surface: surface ?? this.surface,
      surface2: surface2 ?? this.surface2,
      surface3: surface3 ?? this.surface3,
      ink: ink ?? this.ink,
      ink2: ink2 ?? this.ink2,
      muted: muted ?? this.muted,
      faint: faint ?? this.faint,
      line: line ?? this.line,
      line2: line2 ?? this.line2,
      tileRed: tileRed ?? this.tileRed,
      tileBlack: tileBlack ?? this.tileBlack,
      tileYellow: tileYellow ?? this.tileYellow,
      tileBlue: tileBlue ?? this.tileBlue,
      tileFace: tileFace ?? this.tileFace,
      tileFaceEdge: tileFaceEdge ?? this.tileFaceEdge,
      good: good ?? this.good,
      warn: warn ?? this.warn,
      bad: bad ?? this.bad,
      accent: accent ?? this.accent,
      accentSoft: accentSoft ?? this.accentSoft,
      accentInk: accentInk ?? this.accentInk,
      rackTop: rackTop ?? this.rackTop,
      rackBottom: rackBottom ?? this.rackBottom,
      rackBorder: rackBorder ?? this.rackBorder,
      tileStyle: tileStyle ?? this.tileStyle,
    );
  }

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    return AppPalette(
      surface: Color.lerp(surface, other.surface, t)!,
      surface2: Color.lerp(surface2, other.surface2, t)!,
      surface3: Color.lerp(surface3, other.surface3, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      ink2: Color.lerp(ink2, other.ink2, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      faint: Color.lerp(faint, other.faint, t)!,
      line: Color.lerp(line, other.line, t)!,
      line2: Color.lerp(line2, other.line2, t)!,
      tileRed: Color.lerp(tileRed, other.tileRed, t)!,
      tileBlack: Color.lerp(tileBlack, other.tileBlack, t)!,
      tileYellow: Color.lerp(tileYellow, other.tileYellow, t)!,
      tileBlue: Color.lerp(tileBlue, other.tileBlue, t)!,
      tileFace: Color.lerp(tileFace, other.tileFace, t)!,
      tileFaceEdge: Color.lerp(tileFaceEdge, other.tileFaceEdge, t)!,
      good: Color.lerp(good, other.good, t)!,
      warn: Color.lerp(warn, other.warn, t)!,
      bad: Color.lerp(bad, other.bad, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentSoft: Color.lerp(accentSoft, other.accentSoft, t)!,
      accentInk: Color.lerp(accentInk, other.accentInk, t)!,
      rackTop: Color.lerp(rackTop, other.rackTop, t)!,
      rackBottom: Color.lerp(rackBottom, other.rackBottom, t)!,
      rackBorder: Color.lerp(rackBorder, other.rackBorder, t)!,
      tileStyle: t < 0.5 ? tileStyle : other.tileStyle,
    );
  }
}
