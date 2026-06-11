import 'dart:io';

import 'package:flutter/material.dart';
import 'package:okey_acar_mi/core/extensions/context_extensions.dart';
import 'package:okey_acar_mi/features/detection/domain/entities/detected_tile.dart';
import 'package:okey_acar_mi/features/detection/presentation/widgets/scan_line.dart';

/// The captured image with accent bounding boxes over each revealed tile and
/// the scan-line sweep while detection is running.
///
/// The image is letterboxed into a fixed 3:2 frame with `BoxFit.cover`, so
/// the normalized boxes are a stylized progress visualization, not a
/// pixel-perfect registration (good enough for the analyzing moment; review
/// shows the real editable rack).
class DetectionOverlay extends StatelessWidget {
  /// Creates a [DetectionOverlay].
  const DetectionOverlay({
    required this.imagePath,
    required this.bounds,
    required this.scanning,
    super.key,
  });

  /// The captured still (or the burst's first frame).
  final String imagePath;

  /// Normalized boxes of the tiles revealed so far.
  final List<NormalizedRect> bounds;

  /// Whether the scan line sweeps (false once detection finished).
  final bool scanning;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 3 / 2,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.file(
              File(imagePath),
              fit: BoxFit.cover,
              // Missing/undecodable file (e.g. in widget tests): keep the
              // frame, drop the photo.
              errorBuilder: (context, error, stackTrace) =>
                  const ColoredBox(color: Color(0xFF161616)),
            ),
            CustomPaint(
              painter: _TileBoundsPainter(
                bounds: bounds,
                color: context.palette.accent,
              ),
            ),
            if (scanning) const ScanLine(),
          ],
        ),
      ),
    );
  }
}

/// Strokes one rounded rect per revealed tile box.
class _TileBoundsPainter extends CustomPainter {
  const _TileBoundsPainter({required this.bounds, required this.color});

  final List<NormalizedRect> bounds;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    for (final box in bounds) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            box.left * size.width,
            box.top * size.height,
            box.width * size.width,
            box.height * size.height,
          ),
          const Radius.circular(4),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_TileBoundsPainter oldDelegate) =>
      oldDelegate.bounds.length != bounds.length || oldDelegate.color != color;
}
