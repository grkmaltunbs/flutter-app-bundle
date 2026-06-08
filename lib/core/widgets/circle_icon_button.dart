import 'package:flutter/material.dart';
import 'package:okey_acar_mi/core/extensions/context_extensions.dart';

/// A 40pt circular icon button on a surface-2 chip with a hairline border.
///
/// Ported from the recurring round header buttons in the design bundle (back /
/// help). The visual is 40pt but the tap target is expanded to ≥48dp for
/// accessibility, and a [semanticLabel] is required since the button is
/// icon-only.
class CircleIconButton extends StatelessWidget {
  /// Creates a [CircleIconButton].
  const CircleIconButton({
    required this.icon,
    required this.onPressed,
    required this.semanticLabel,
    super.key,
  });

  /// The glyph shown in the center.
  final IconData icon;

  /// Tap handler.
  final VoidCallback onPressed;

  /// Accessibility label (the button has no visible text).
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Semantics(
      button: true,
      label: semanticLabel,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(100),
        child: SizedBox(
          width: 48,
          height: 48,
          child: Center(
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: palette.surface2,
                shape: BoxShape.circle,
                border: Border.all(color: palette.line),
              ),
              child: Icon(icon, size: 18, color: palette.ink),
            ),
          ),
        ),
      ),
    );
  }
}
