import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Typography tokens for the app, built on the three design-bundle families.
///
/// - **Instrument Serif** — editorial display moments ("Açar mı?", verdicts).
/// - **Geist** — UI / body text.
/// - **Geist Mono** — tile numerals, scores, eyebrows, stats.
///
/// Step 0 provides a base [textTheme] plus a couple of named accents. The full
/// type scale and per-theme tuning land in Step 1.
abstract final class AppTypography {
  /// The editorial display style (Instrument Serif), e.g. the title moment.
  static TextStyle display([Color? color]) => GoogleFonts.instrumentSerif(
    fontSize: 48,
    height: 1.05,
    color: color,
  );

  /// Monospaced style for numerals, scores, and eyebrows (Geist Mono).
  static TextStyle mono([Color? color]) => GoogleFonts.geistMono(
    fontSize: 14,
    letterSpacing: 0.5,
    color: color,
  );

  /// Builds the base [TextTheme] (Geist for UI/body, Instrument Serif for
  /// display headlines) layered over [base].
  static TextTheme textTheme(TextTheme base) {
    final body = GoogleFonts.geistTextTheme(base);
    return body.copyWith(
      displayLarge: GoogleFonts.instrumentSerif(textStyle: base.displayLarge),
      displayMedium: GoogleFonts.instrumentSerif(textStyle: base.displayMedium),
      displaySmall: GoogleFonts.instrumentSerif(textStyle: base.displaySmall),
    );
  }
}
