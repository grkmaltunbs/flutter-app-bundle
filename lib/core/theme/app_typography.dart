import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Typography tokens for the app, built on the three design-bundle families.
///
/// - **Instrument Serif** — editorial display moments ("Açar mı?", verdicts).
/// - **Geist** — UI / body text.
/// - **Geist Mono** — tile numerals, scores, eyebrows, stats.
abstract final class AppTypography {
  /// The editorial display style (Instrument Serif), e.g. the title moment.
  static TextStyle display([Color? color]) => GoogleFonts.instrumentSerif(
    fontSize: 48,
    height: 1.05,
    letterSpacing: -0.5,
    color: color,
  );

  /// Monospaced style for numerals, scores, and eyebrows (Geist Mono).
  static TextStyle mono([Color? color]) => GoogleFonts.geistMono(
    fontSize: 14,
    letterSpacing: 0.5,
    color: color,
  );

  /// A Geist Mono style at an arbitrary [fontSize] / [color] / weight.
  ///
  /// Used by tiles (numerals), pills, eyebrows, and scores so callers don't
  /// reach for [GoogleFonts] directly.
  static TextStyle monoStyle({
    double fontSize = 14,
    Color? color,
    FontWeight fontWeight = FontWeight.w500,
    double letterSpacing = -0.02,
    double? height,
  }) => GoogleFonts.geistMono(
    fontSize: fontSize,
    color: color,
    fontWeight: fontWeight,
    letterSpacing: letterSpacing,
    height: height,
  );

  /// An Instrument Serif style at an arbitrary [fontSize] / [color] / weight.
  ///
  /// Used by tiles (classic / bold numerals) and editorial moments.
  static TextStyle serifStyle({
    double fontSize = 24,
    Color? color,
    FontStyle fontStyle = FontStyle.normal,
    double height = 1,
    double letterSpacing = 0,
  }) => GoogleFonts.instrumentSerif(
    fontSize: fontSize,
    color: color,
    fontStyle: fontStyle,
    height: height,
    letterSpacing: letterSpacing,
  );

  /// Builds the base [TextTheme] (Geist for UI/body, Instrument Serif for
  /// display headlines) layered over [base].
  static TextTheme textTheme(TextTheme base) {
    final body = GoogleFonts.geistTextTheme(base);
    return body.copyWith(
      displayLarge: GoogleFonts.instrumentSerif(
        textStyle: base.displayLarge,
        letterSpacing: -0.5,
        height: 1.02,
      ),
      displayMedium: GoogleFonts.instrumentSerif(
        textStyle: base.displayMedium,
        letterSpacing: -0.5,
        height: 1.04,
      ),
      displaySmall: GoogleFonts.instrumentSerif(
        textStyle: base.displaySmall,
        letterSpacing: -0.5,
        height: 1.05,
      ),
      headlineLarge: GoogleFonts.instrumentSerif(textStyle: base.headlineLarge),
      headlineMedium: GoogleFonts.instrumentSerif(
        textStyle: base.headlineMedium,
      ),
      // Titles / body / labels stay in Geist (inherited from geistTextTheme),
      // tuned for the UI scale from the design bundle.
      titleLarge: body.titleLarge?.copyWith(fontWeight: FontWeight.w600),
      titleMedium: body.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      titleSmall: body.titleSmall?.copyWith(fontWeight: FontWeight.w500),
      labelLarge: body.labelLarge?.copyWith(
        fontWeight: FontWeight.w500,
        letterSpacing: 0.1,
      ),
      labelMedium: body.labelMedium?.copyWith(fontWeight: FontWeight.w500),
    );
  }
}
