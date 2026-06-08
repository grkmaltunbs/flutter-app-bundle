import 'package:flutter/material.dart';
import 'package:okey_acar_mi/core/extensions/context_extensions.dart';
import 'package:okey_acar_mi/core/theme/app_radii.dart';

/// A surface card with a hairline border and large radius.
///
/// Ported from the `.card` style in the design bundle's `styles.css`.
class AppCard extends StatelessWidget {
  /// Creates an [AppCard] wrapping [child].
  const AppCard({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    super.key,
  });

  /// The card contents.
  final Widget child;

  /// Inner padding around [child].
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: palette.line),
      ),
      child: child,
    );
  }
}
