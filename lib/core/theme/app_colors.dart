import 'package:flutter/painting.dart';

/// Static color tokens ported from the design bundle (`styles.css`).
///
/// These are raw, theme-independent token values. Full theme wiring
/// (light / dark / felt + accent picker) lands in Step 1; this holder exists so
/// later steps can reference stable token names instead of magic hex literals.
///
/// CSS sources are `oklch(...)`; the values below are sRGB approximations.
abstract final class AppColors {
  /// Brand seed (sage accent, `oklch(0.55 0.13 165)`).
  ///
  /// Feeds `ColorScheme.fromSeed` and, later, the accent picker.
  static const Color seed = Color(0xFF4F9D89);

  // --- Tile palette: the four legal tile colors (joker is a glyph) ---

  /// Red tile (`--tile-red`).
  static const Color tileRed = Color(0xFFC8393A);

  /// Black tile (`--tile-black`).
  static const Color tileBlack = Color(0xFF171B1F);

  /// Yellow tile (`--tile-yellow`).
  static const Color tileYellow = Color(0xFFD6A20A);

  /// Blue tile (`--tile-blue`).
  static const Color tileBlue = Color(0xFF005FA8);

  // --- Semantic feedback colors ---

  /// Positive / success (`--good`).
  static const Color good = Color(0xFF399D57);

  /// Caution (`--warn`).
  static const Color warn = Color(0xFFE18528);

  /// Negative / error (`--bad`).
  static const Color bad = Color(0xFFD74745);
}
