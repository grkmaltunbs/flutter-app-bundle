import 'package:flutter/material.dart';
import 'package:okey_acar_mi/core/extensions/context_extensions.dart';
import 'package:okey_acar_mi/core/widgets/tile.dart';

/// A ghost placeholder for an empty tile position.
///
/// Same footprint as a [Tile] of the same size, drawn as a 1.5px dashed
/// outline in the palette's secondary line color.
class TileSlot extends StatelessWidget {
  /// Creates a [TileSlot].
  const TileSlot({
    this.size = TileSize.md,
    this.widthOverride,
    super.key,
  });

  /// The preset size; ignored when [widthOverride] is set.
  final TileSize size;

  /// An explicit width override (to match a rack row).
  final double? widthOverride;

  @override
  Widget build(BuildContext context) {
    final width = widthOverride ?? size.width;
    final height = width * 1.42;
    final radius = width * 0.13;
    return SizedBox(
      width: width,
      height: height,
      child: CustomPaint(
        painter: _DashedBorderPainter(
          color: context.palette.line2,
          radius: radius,
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rrect);

    const dash = 4.0;
    const gap = 3.0;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = distance + dash;
        canvas.drawPath(
          metric.extractPath(distance, next.clamp(0, metric.length)),
          paint,
        );
        distance = next + gap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.radius != radius;
}
