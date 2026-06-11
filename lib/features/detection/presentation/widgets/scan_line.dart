import 'dart:async';

import 'package:flutter/material.dart';
import 'package:okey_acar_mi/core/extensions/context_extensions.dart';

/// The accent scan line sweeping the detection overlay while processing.
///
/// Respects reduce-motion: when `MediaQuery.disableAnimationsOf` is true the
/// line is rendered static at mid-height instead of sweeping.
class ScanLine extends StatefulWidget {
  /// Creates a [ScanLine].
  const ScanLine({super.key});

  @override
  State<ScanLine> createState() => _ScanLineState();
}

class _ScanLineState extends State<ScanLine>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller
        ..stop()
        ..value = 0.5;
    } else if (!_controller.isAnimating) {
      unawaited(_controller.repeat(reverse: true));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = context.palette.accent;
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) => Align(
          // Sweep between 15% and 85% of the available height.
          alignment: Alignment(0, -0.7 + 1.4 * _controller.value),
          child: child,
        ),
        child: Container(
          height: 2,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                accent.withValues(alpha: 0),
                accent,
                accent.withValues(alpha: 0),
              ],
            ),
            boxShadow: [
              BoxShadow(color: accent.withValues(alpha: 0.6), blurRadius: 18),
            ],
          ),
        ),
      ),
    );
  }
}
