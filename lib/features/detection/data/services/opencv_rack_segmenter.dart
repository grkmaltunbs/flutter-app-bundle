import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:okey_acar_mi/features/detection/data/services/rack_segmenter.dart';
import 'package:okey_acar_mi/features/detection/domain/entities/detected_tile.dart';
import 'package:opencv_dart/opencv_dart.dart' as cv;

/// v2 [RackSegmenter] on OpenCV (`opencv_dart` 2.x, native-assets line).
///
/// Classical CV, tuned for bright tile faces on a darker rack/table:
/// 1. stride-sample the source into a grayscale (luma) byte grid, capped at
///    [_maxSampleWidth] across, and wrap it in a single-channel `cv.Mat`
///    (cheapest correct conversion: one Dart pass, no encode/imdecode and no
///    extra `cvtColor` Mat);
/// 2. adaptive mean threshold with a window of [_blockSizeFraction] of the
///    sampled width — much wider than one tile, so whole tile faces stay
///    solid — keeping pixels that beat their local mean by [_thresholdC]
///    (robust to lighting gradients across the rack);
/// 3. 3×3 morphological close to heal small fragmentation of a tile face
///    without bridging the dark seams between adjacent tiles;
/// 4. external contours → bounding rects → plausibility filter (relative
///    width/height + height/width aspect of an okey tile under perspective).
///
/// Boxes are emitted normalized to the source dimensions (stride sampling
/// scales both axes uniformly, so sample-space fractions equal source-space
/// fractions). Every native Mat/Vec created here is disposed before
/// returning — this runs per frame inside the detection worker, so a leak
/// would compound. Throws (e.g. the native library failed to load) are the
/// caller's concern: the worker wraps this segmenter in a
/// [FallbackRackSegmenter] over the pure-Dart [LumaProjectionSegmenter].
class OpenCvRackSegmenter implements RackSegmenter {
  /// Creates an [OpenCvRackSegmenter].
  const OpenCvRackSegmenter();

  /// The image is sampled at most this many pixels across (stride sampling)
  /// to bound worker CPU on multi-megapixel captures — mirrors
  /// [LumaProjectionSegmenter].
  static const int _maxSampleWidth = 480;

  /// Sampled grids smaller than this on either axis carry no usable rack.
  static const int _minSampleDimension = 32;

  /// Adaptive-threshold window as a fraction of the sampled width. A rack
  /// row holds up to 11 tiles, so a quarter-width window always spans
  /// several tiles plus background — tile interiors stay above the local
  /// mean instead of hollowing out.
  static const double _blockSizeFraction = 0.25;

  /// Adaptive-threshold constant `C` (OpenCV computes `T = mean − C`): a
  /// pixel must beat its local mean by 10 gray levels to count as tile face.
  static const double _thresholdC = -10;

  /// Candidate boxes narrower/shorter than this fraction of the frame are
  /// specks; wider/taller ones are background slabs, not tiles.
  static const double _minWidthFraction = 0.015;

  /// See [_minWidthFraction].
  static const double _maxWidthFraction = 0.25;

  /// See [_minWidthFraction].
  static const double _minHeightFraction = 0.03;

  /// See [_minWidthFraction].
  static const double _maxHeightFraction = 0.6;

  /// Plausible height/width ratio band. An okey tile is ≈1.4× taller than
  /// wide; the band allows generous perspective foreshortening either way.
  static const double _minAspect = 0.6;

  /// See [_minAspect].
  static const double _maxAspect = 3.5;

  /// Boxes under this many sample pixels per side are noise regardless of
  /// the fractional thresholds.
  static const int _minSamplePixels = 3;

  @override
  List<NormalizedRect> segment(img.Image image) {
    final stride = math.max(1, image.width ~/ _maxSampleWidth);
    final sampleWidth = (image.width + stride - 1) ~/ stride;
    final sampleHeight = (image.height + stride - 1) ~/ stride;
    if (sampleWidth < _minSampleDimension ||
        sampleHeight < _minSampleDimension) {
      return const [];
    }

    // One pass: sampled luma bytes (Rec. 601 weights, as the v1 segmenter).
    final luma = Uint8List(sampleWidth * sampleHeight);
    var offset = 0;
    for (var sy = 0; sy < sampleHeight; sy++) {
      for (var sx = 0; sx < sampleWidth; sx++) {
        final pixel = image.getPixel(sx * stride, sy * stride);
        luma[offset++] = (0.299 * pixel.r + 0.587 * pixel.g + 0.114 * pixel.b)
            .round()
            .clamp(0, 255);
      }
    }

    cv.Mat? gray;
    cv.Mat? binary;
    cv.Mat? kernel;
    cv.Mat? closed;
    cv.VecVecPoint? contours;
    cv.VecVec4i? hierarchy;
    try {
      gray = cv.Mat.fromList(
        sampleHeight,
        sampleWidth,
        cv.MatType.CV_8UC1,
        luma,
      );

      // Window must be odd and ≥3 for adaptiveThreshold.
      final blockSize =
          math.max(3, (sampleWidth * _blockSizeFraction).round()) | 1;
      binary = cv.adaptiveThreshold(
        gray,
        255,
        cv.ADAPTIVE_THRESH_MEAN_C,
        cv.THRESH_BINARY,
        blockSize,
        _thresholdC,
      );

      kernel = cv.getStructuringElement(cv.MORPH_RECT, (3, 3));
      closed = cv.morphologyEx(binary, cv.MORPH_CLOSE, kernel);

      final found = cv.findContours(
        closed,
        cv.RETR_EXTERNAL,
        cv.CHAIN_APPROX_SIMPLE,
      );
      contours = found.$1;
      hierarchy = found.$2;

      final boxes = <NormalizedRect>[];
      // `contours[i]` is a reference owned by the parent vector — the parent
      // dispose in `finally` frees them; disposing one here would double-free.
      for (final contour in contours) {
        final rect = cv.boundingRect(contour);
        try {
          if (_isPlausibleTile(rect, sampleWidth, sampleHeight)) {
            boxes.add(
              NormalizedRect(
                left: rect.x / sampleWidth,
                top: rect.y / sampleHeight,
                width: rect.width / sampleWidth,
                height: rect.height / sampleHeight,
              ),
            );
          }
        } finally {
          rect.dispose();
        }
      }
      return boxes;
    } finally {
      hierarchy?.dispose();
      contours?.dispose();
      closed?.dispose();
      kernel?.dispose();
      binary?.dispose();
      gray?.dispose();
    }
  }

  bool _isPlausibleTile(cv.Rect rect, int sampleWidth, int sampleHeight) {
    if (rect.width < _minSamplePixels || rect.height < _minSamplePixels) {
      return false;
    }
    final widthFraction = rect.width / sampleWidth;
    final heightFraction = rect.height / sampleHeight;
    final aspect = rect.height / rect.width;
    return widthFraction >= _minWidthFraction &&
        widthFraction <= _maxWidthFraction &&
        heightFraction >= _minHeightFraction &&
        heightFraction <= _maxHeightFraction &&
        aspect >= _minAspect &&
        aspect <= _maxAspect;
  }
}
