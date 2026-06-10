import 'package:flutter/material.dart';
import 'package:okey_acar_mi/core/extensions/context_extensions.dart';
import 'package:okey_acar_mi/core/theme/app_typography.dart';

/// The color treatment of an [AppPill].
enum PillVariant {
  /// Surface-2 background with muted ink (default).
  neutral,

  /// Accent-soft background with accent ink.
  accent,

  /// Soft-good background with good ink.
  good,

  /// Soft-bad background with bad ink.
  bad,
}

/// A compact uppercase mono pill, ported from `.pill*` in the design bundle.
class AppPill extends StatelessWidget {
  /// Creates an [AppPill].
  const AppPill({
    required this.label,
    this.variant = PillVariant.neutral,
    this.icon,
    super.key,
  });

  /// The pill label (rendered uppercase).
  final String label;

  /// The color variant.
  final PillVariant variant;

  /// Optional leading icon.
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final (bg, fg, border) = switch (variant) {
      PillVariant.neutral => (palette.surface2, palette.muted, palette.line),
      PillVariant.accent => (
        palette.accentSoft,
        palette.accentInk,
        Colors.transparent,
      ),
      PillVariant.good => (
        palette.good.withValues(alpha: 0.14),
        palette.good,
        Colors.transparent,
      ),
      PillVariant.bad => (
        palette.bad.withValues(alpha: 0.12),
        palette.bad,
        Colors.transparent,
      ),
    };

    return Container(
      // Height comes from padding (~28 at scale 1.0) so the pill grows with
      // text scale instead of clipping its label.
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: fg),
            const SizedBox(width: 6),
          ],
          Text(
            label.toUpperCase(),
            style: AppTypography.monoStyle(
              fontSize: 11,
              color: fg,
              letterSpacing: 0.44, // ~0.04em at 11px
            ),
          ),
        ],
      ),
    );
  }
}
