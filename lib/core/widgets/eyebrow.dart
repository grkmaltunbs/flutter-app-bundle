import 'package:flutter/material.dart';
import 'package:okey_acar_mi/core/extensions/context_extensions.dart';
import 'package:okey_acar_mi/core/theme/app_typography.dart';

/// A small uppercase mono label used above sections and melds.
///
/// Ported from the `.eyebrow` style in the design bundle's `styles.css`
/// (mono, 11px, 0.08em tracking, uppercase, muted).
class Eyebrow extends StatelessWidget {
  /// Creates an [Eyebrow] with the given [text].
  const Eyebrow(this.text, {this.color, super.key});

  /// The label text (rendered uppercase).
  final String text;

  /// Optional color override; defaults to the palette's muted ink.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: AppTypography.monoStyle(
        fontSize: 11,
        color: color ?? context.palette.muted,
        letterSpacing: 0.88, // ~0.08em at 11px
      ),
    );
  }
}
