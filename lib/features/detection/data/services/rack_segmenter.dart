import 'dart:math' as math;

import 'package:image/image.dart' as img;
import 'package:okey_acar_mi/features/detection/domain/entities/detected_tile.dart';

/// Segments a captured rack photo into per-tile boxes.
///
/// An interface seam so the pure-Dart v1 below can later be swapped for a
/// native OpenCV binding without touching the pipeline (opencv_dart itself
/// is excluded — its iOS xcframework breaks simulator linking).
// Single-method DI seam (one_member_abstracts is disabled project-wide).
abstract interface class RackSegmenter {
  /// Finds tile boxes in [image], normalized to the image dimensions.
  /// Returns an empty list when no tile-like regions are found.
  List<NormalizedRect> segment(img.Image image);
}

/// v1 pure-Dart segmenter using brightness (luma) projections.
///
/// Tile faces are bright against the darker rack/table, so:
/// 1. binarize sampled luma against an adaptive threshold
///    (mean + 0.4 × stdDev);
/// 2. project bright pixels onto the y-axis → horizontal bands (the rack's
///    two tile rows);
/// 3. within each band, project onto the x-axis → contiguous bright runs,
///    one per tile (runs much wider than the median split into equal tiles).
///
/// Known v1 limits (acceptable: prod is not simulator-verified this step and
/// the seam allows replacement): assumes a roughly level rack, even lighting,
/// and tiles brighter than the background.
class LumaProjectionSegmenter implements RackSegmenter {
  /// Creates a [LumaProjectionSegmenter].
  const LumaProjectionSegmenter();

  /// The image is sampled at most this many pixels across (stride sampling)
  /// to bound worker CPU on multi-megapixel captures.
  static const int _maxSampleWidth = 480;

  /// A row/column projection counts as "bright" above this fraction of the
  /// projection's own maximum.
  static const double _projectionThreshold = 0.4;

  /// Bands shorter than this fraction of the image height are noise.
  static const double _minBandHeightFraction = 0.04;

  /// Runs narrower than this fraction of the image width are noise.
  static const double _minRunWidthFraction = 0.012;

  /// A run wider than this multiple of the median run width is treated as
  /// several merged tiles and split evenly.
  static const double _mergedRunFactor = 1.6;

  @override
  List<NormalizedRect> segment(img.Image image) {
    final stride = math.max(1, image.width ~/ _maxSampleWidth);
    final sampleWidth = (image.width + stride - 1) ~/ stride;
    final sampleHeight = (image.height + stride - 1) ~/ stride;
    if (sampleWidth < 8 || sampleHeight < 8) return const [];

    // Sampled luma grid + adaptive brightness threshold.
    final luma = List<List<double>>.generate(
      sampleHeight,
      (sy) => List<double>.generate(sampleWidth, (sx) {
        final pixel = image.getPixel(sx * stride, sy * stride);
        return 0.299 * pixel.r + 0.587 * pixel.g + 0.114 * pixel.b;
      }),
    );
    var sum = 0.0;
    var squares = 0.0;
    for (final row in luma) {
      for (final value in row) {
        sum += value;
        squares += value * value;
      }
    }
    final count = sampleWidth * sampleHeight;
    final mean = sum / count;
    final variance = math.max(0, squares / count - mean * mean);
    final threshold = mean + 0.4 * math.sqrt(variance);

    // y-projection → horizontal bands of bright pixels (the tile rows).
    final rowFractions = [
      for (final row in luma)
        row.where((value) => value > threshold).length / sampleWidth,
    ];
    final bands = _runsAboveThreshold(
      rowFractions,
      minLength: (_minBandHeightFraction * sampleHeight).ceil(),
    );

    final boxes = <NormalizedRect>[];
    for (final band in bands) {
      boxes.addAll(
        _tilesInBand(
          luma: luma,
          band: band,
          threshold: threshold,
          sampleWidth: sampleWidth,
          sampleHeight: sampleHeight,
        ),
      );
    }
    return boxes;
  }

  /// x-projection within one band → per-tile boxes.
  List<NormalizedRect> _tilesInBand({
    required List<List<double>> luma,
    required ({int start, int end}) band,
    required double threshold,
    required int sampleWidth,
    required int sampleHeight,
  }) {
    final bandHeight = band.end - band.start;
    final columnFractions = List<double>.generate(sampleWidth, (sx) {
      var bright = 0;
      for (var sy = band.start; sy < band.end; sy++) {
        if (luma[sy][sx] > threshold) bright++;
      }
      return bright / bandHeight;
    });
    final runs = _runsAboveThreshold(
      columnFractions,
      minLength: math.max(1, (_minRunWidthFraction * sampleWidth).ceil()),
    );
    if (runs.isEmpty) return const [];

    // Split runs that are clearly several tiles merged together.
    final widths = runs.map((run) => run.end - run.start).toList()..sort();
    final median = widths[widths.length ~/ 2];
    final boxes = <NormalizedRect>[];
    for (final run in runs) {
      final width = run.end - run.start;
      final pieces = width > median * _mergedRunFactor
          ? math.max(1, (width / median).round())
          : 1;
      final pieceWidth = width / pieces;
      for (var piece = 0; piece < pieces; piece++) {
        boxes.add(
          NormalizedRect(
            left: (run.start + piece * pieceWidth) / sampleWidth,
            top: band.start / sampleHeight,
            width: pieceWidth / sampleWidth,
            height: bandHeight / sampleHeight,
          ),
        );
      }
    }
    return boxes;
  }

  /// Contiguous index runs where [values] exceeds [_projectionThreshold] of
  /// its own maximum, dropping runs shorter than [minLength].
  List<({int start, int end})> _runsAboveThreshold(
    List<double> values, {
    required int minLength,
  }) {
    final maxValue = values.fold<double>(0, math.max);
    if (maxValue <= 0) return const [];
    final cutoff = maxValue * _projectionThreshold;

    final runs = <({int start, int end})>[];
    int? start;
    for (var i = 0; i <= values.length; i++) {
      final above = i < values.length && values[i] >= cutoff;
      if (above) {
        start ??= i;
      } else if (start != null) {
        if (i - start >= minLength) runs.add((start: start, end: i));
        start = null;
      }
    }
    return runs;
  }
}
