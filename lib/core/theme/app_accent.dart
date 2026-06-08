import 'package:flutter/painting.dart';

/// The four accent swatches offered by the in-app accent picker.
///
/// Each carries the [seed] color fed to `ColorScheme.fromSeed` and used to
/// derive the accent-soft / accent-ink tokens in the palette. Values are sRGB
/// approximations of the `oklch(...)` swatches in the design `app.jsx`.
enum AppAccent {
  /// Sage — the default brand accent (`oklch(0.55 0.13 165)`).
  sage(Color(0xFF4F9D89)),

  /// Coral (`oklch(0.62 0.17 25)`).
  coral(Color(0xFFD75A4A)),

  /// Indigo (`oklch(0.48 0.16 270)`).
  indigo(Color(0xFF5154C4)),

  /// Amber (`oklch(0.66 0.15 70)`).
  amber(Color(0xFFC49321))
  ;

  const AppAccent(this.seed);

  /// The base accent color and seed for the generated color scheme.
  final Color seed;
}
