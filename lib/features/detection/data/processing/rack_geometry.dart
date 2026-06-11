import 'dart:math' as math;

import 'package:okey_acar_mi/features/detection/domain/entities/detected_tile.dart';

/// A segmented tile box with its assigned rack slot.
class PositionedBox {
  /// Creates a [PositionedBox].
  const PositionedBox({required this.bounds, required this.position});

  /// The tile's box, normalized to the source image.
  final NormalizedRect bounds;

  /// The assigned 2-row rack slot.
  final TilePosition position;
}

/// Assigns rack positions to segmented tile boxes using the **2-row
/// baseline** assumption (PRODUCT_SPEC → Domain rules): tiles sit on the
/// rack in two parallel rows, so their vertical centers form two clusters.
abstract final class RackGeometry {
  /// Maximum 1-D k-means refinement passes (converges in far fewer).
  static const int _maxIterations = 32;

  /// The two row baselines must be separated by at least this fraction of
  /// the mean box height, or the layout is treated as a single row.
  static const double _minSeparationFactor = 0.6;

  /// Each cluster's vertical spread must stay below this fraction of the
  /// inter-cluster baseline distance. A wider cluster means k-means absorbed
  /// an extra baseline (a 3+-row scene), not a coherent rack row: for any
  /// equally spaced 3-row layout the merged cluster spans one full row gap
  /// while the baselines sit at most two gaps apart, so its ratio always
  /// exceeds 0.5, whereas a tilted-but-real rack row drifts far less than
  /// half the row gap.
  static const double _maxCohesionFactor = 0.5;

  /// Clusters [boxes] into the two rack rows and orders them left→right.
  ///
  /// Returns the boxes in rack order (row 0 top, then row 1 bottom), or
  /// `null` when the boxes do not form a 2-row layout (fewer than two boxes,
  /// an empty cluster, baselines too close together, or a cluster too
  /// vertically spread out to be a single row).
  static List<PositionedBox>? assignPositions(List<NormalizedRect> boxes) {
    if (boxes.length < 2) return null;

    final centers = [for (final box in boxes) box.top + box.height / 2];

    // 1-D k-means, k=2, seeded with the extreme centers.
    var c0 = centers.reduce(math.min);
    var c1 = centers.reduce(math.max);
    if (c0 == c1) return null; // All on one baseline: not a 2-row layout.

    late List<int> assignment;
    for (var iteration = 0; iteration < _maxIterations; iteration++) {
      assignment = [
        for (final y in centers) (y - c0).abs() <= (y - c1).abs() ? 0 : 1,
      ];
      var sum0 = 0.0;
      var sum1 = 0.0;
      var count0 = 0;
      var count1 = 0;
      for (var i = 0; i < centers.length; i++) {
        if (assignment[i] == 0) {
          sum0 += centers[i];
          count0++;
        } else {
          sum1 += centers[i];
          count1++;
        }
      }
      if (count0 == 0 || count1 == 0) return null; // Degenerate single row.
      final next0 = sum0 / count0;
      final next1 = sum1 / count1;
      if (next0 == c0 && next1 == c1) break;
      c0 = next0;
      c1 = next1;
    }

    // Reject layouts whose baselines are too close to be two real rows.
    final separation = (c1 - c0).abs();
    final meanHeight =
        boxes.fold<double>(0, (sum, box) => sum + box.height) / boxes.length;
    if (separation < meanHeight * _minSeparationFactor) return null;

    // Reject layouts where a cluster absorbed an extra baseline (3+ rows):
    // a real rack row is vertically tight relative to the row gap.
    var min0 = double.infinity;
    var max0 = double.negativeInfinity;
    var min1 = double.infinity;
    var max1 = double.negativeInfinity;
    for (var i = 0; i < centers.length; i++) {
      if (assignment[i] == 0) {
        min0 = math.min(min0, centers[i]);
        max0 = math.max(max0, centers[i]);
      } else {
        min1 = math.min(min1, centers[i]);
        max1 = math.max(max1, centers[i]);
      }
    }
    final spread = math.max(max0 - min0, max1 - min1);
    if (spread > separation * _maxCohesionFactor) return null;

    // Top cluster is row 0; order each row by horizontal center.
    final topIsCluster0 = c0 <= c1;
    final rows = (<NormalizedRect>[], <NormalizedRect>[]);
    for (var i = 0; i < boxes.length; i++) {
      final isTop = (assignment[i] == 0) == topIsCluster0;
      (isTop ? rows.$1 : rows.$2).add(boxes[i]);
    }
    int byCenterX(NormalizedRect a, NormalizedRect b) =>
        (a.left + a.width / 2).compareTo(b.left + b.width / 2);
    rows.$1.sort(byCenterX);
    rows.$2.sort(byCenterX);

    return [
      for (var i = 0; i < rows.$1.length; i++)
        PositionedBox(
          bounds: rows.$1[i],
          position: TilePosition(row: 0, index: i),
        ),
      for (var i = 0; i < rows.$2.length; i++)
        PositionedBox(
          bounds: rows.$2[i],
          position: TilePosition(row: 1, index: i),
        ),
    ];
  }
}
