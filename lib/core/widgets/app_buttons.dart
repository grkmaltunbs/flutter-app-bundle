import 'package:flutter/material.dart';
import 'package:okey_acar_mi/core/extensions/context_extensions.dart';
import 'package:okey_acar_mi/core/theme/app_palette.dart';

/// Visual variants for the button family, ported from `.btn*` in the design
/// bundle's `styles.css`.
enum _ButtonVariant { primary, secondary, ghost, accent }

/// Shared base for the four button styles (52pt tall, fully rounded).
///
/// Disabled (and visually dimmed) when [onPressed] is null. Guarantees a
/// >=48dp tap target.
class _AppButton extends StatelessWidget {
  const _AppButton({
    required this.label,
    required this.variant,
    this.onPressed,
    this.icon,
    this.fullWidth = false,
  });

  final String label;
  final _ButtonVariant variant;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final enabled = onPressed != null;
    final (bg, fg, border) = _colors(palette);

    final content = Row(
      mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 18, color: fg),
          const SizedBox(width: 8),
        ],
        Flexible(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: context.textTheme.labelLarge?.copyWith(
              color: fg,
              fontWeight: FontWeight.w500,
              fontSize: 16,
            ),
          ),
        ),
      ],
    );

    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(100),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(100),
          child: Container(
            height: 52,
            constraints: const BoxConstraints(minHeight: 48),
            padding: const EdgeInsets.symmetric(horizontal: 22),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(100),
              border: border == null ? null : Border.all(color: border),
            ),
            alignment: Alignment.center,
            child: content,
          ),
        ),
      ),
    );
  }

  (Color bg, Color fg, Color? border) _colors(AppPalette palette) {
    switch (variant) {
      case _ButtonVariant.primary:
        return (palette.ink, palette.surface, null);
      case _ButtonVariant.secondary:
        return (palette.surface2, palette.ink, palette.line);
      case _ButtonVariant.ghost:
        return (Colors.transparent, palette.ink, null);
      case _ButtonVariant.accent:
        return (palette.accent, Colors.white, null);
    }
  }
}

/// The primary action button (ink background, surface foreground).
class PrimaryButton extends StatelessWidget {
  /// Creates a [PrimaryButton].
  const PrimaryButton({
    required this.label,
    this.onPressed,
    this.icon,
    this.fullWidth = false,
    super.key,
  });

  /// The button label.
  final String label;

  /// Tap handler; null disables the button.
  final VoidCallback? onPressed;

  /// Optional leading icon.
  final IconData? icon;

  /// Whether the button stretches to its parent's width.
  final bool fullWidth;

  @override
  Widget build(BuildContext context) => _AppButton(
    label: label,
    variant: _ButtonVariant.primary,
    onPressed: onPressed,
    icon: icon,
    fullWidth: fullWidth,
  );
}

/// The secondary action button (surface-2 background, hairline border).
class SecondaryButton extends StatelessWidget {
  /// Creates a [SecondaryButton].
  const SecondaryButton({
    required this.label,
    this.onPressed,
    this.icon,
    this.fullWidth = false,
    super.key,
  });

  /// The button label.
  final String label;

  /// Tap handler; null disables the button.
  final VoidCallback? onPressed;

  /// Optional leading icon.
  final IconData? icon;

  /// Whether the button stretches to its parent's width.
  final bool fullWidth;

  @override
  Widget build(BuildContext context) => _AppButton(
    label: label,
    variant: _ButtonVariant.secondary,
    onPressed: onPressed,
    icon: icon,
    fullWidth: fullWidth,
  );
}

/// A transparent text button.
class GhostButton extends StatelessWidget {
  /// Creates a [GhostButton].
  const GhostButton({
    required this.label,
    this.onPressed,
    this.icon,
    this.fullWidth = false,
    super.key,
  });

  /// The button label.
  final String label;

  /// Tap handler; null disables the button.
  final VoidCallback? onPressed;

  /// Optional leading icon.
  final IconData? icon;

  /// Whether the button stretches to its parent's width.
  final bool fullWidth;

  @override
  Widget build(BuildContext context) => _AppButton(
    label: label,
    variant: _ButtonVariant.ghost,
    onPressed: onPressed,
    icon: icon,
    fullWidth: fullWidth,
  );
}

/// An accent-colored action button.
class AccentButton extends StatelessWidget {
  /// Creates an [AccentButton].
  const AccentButton({
    required this.label,
    this.onPressed,
    this.icon,
    this.fullWidth = false,
    super.key,
  });

  /// The button label.
  final String label;

  /// Tap handler; null disables the button.
  final VoidCallback? onPressed;

  /// Optional leading icon.
  final IconData? icon;

  /// Whether the button stretches to its parent's width.
  final bool fullWidth;

  @override
  Widget build(BuildContext context) => _AppButton(
    label: label,
    variant: _ButtonVariant.accent,
    onPressed: onPressed,
    icon: icon,
    fullWidth: fullWidth,
  );
}
