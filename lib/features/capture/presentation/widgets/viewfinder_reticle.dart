import 'package:flutter/material.dart';

/// The corner-bracket framing guide over the viewfinder, ported from
/// `ViewfinderReticle` in the design bundle.
///
/// Fraction-sized via [LayoutBuilder] (never fixed pixels) so it frames the
/// rack on every screen in the size matrix.
class ViewfinderReticle extends StatelessWidget {
  /// Creates a [ViewfinderReticle].
  const ViewfinderReticle({super.key});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Center(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth * 0.84;
            final height = constraints.maxHeight * 0.24;
            return SizedBox(
              width: width,
              height: height,
              child: const CustomPaint(painter: _ReticlePainter()),
            );
          },
        ),
      ),
    );
  }
}

/// Paints four white rounded corner brackets.
class _ReticlePainter extends CustomPainter {
  const _ReticlePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final arm = (size.shortestSide * 0.18).clamp(14.0, 26.0);
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Each bracket: an L-shaped path hugging its corner.
    final corners = <(Offset, Offset, Offset)>[
      // (arm end A, corner, arm end B)
      (Offset(0, arm), Offset.zero, Offset(arm, 0)),
      (
        Offset(size.width - arm, 0),
        Offset(size.width, 0),
        Offset(size.width, arm),
      ),
      (
        Offset(0, size.height - arm),
        Offset(0, size.height),
        Offset(arm, size.height),
      ),
      (
        Offset(size.width, size.height - arm),
        Offset(size.width, size.height),
        Offset(size.width - arm, size.height),
      ),
    ];
    for (final (a, corner, b) in corners) {
      final path = Path()
        ..moveTo(a.dx, a.dy)
        ..lineTo(corner.dx, corner.dy)
        ..lineTo(b.dx, b.dy);
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_ReticlePainter oldDelegate) => false;
}
