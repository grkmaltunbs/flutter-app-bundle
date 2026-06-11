import 'package:checks/checks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:okey_acar_mi/features/detection/data/processing/rack_geometry.dart';
import 'package:okey_acar_mi/features/detection/domain/entities/detected_tile.dart';

/// A tile-sized box whose center column is [centerX] and top is [top].
NormalizedRect _box(double centerX, double top, {double height = 0.3}) =>
    NormalizedRect(left: centerX - 0.03, top: top, width: 0.06, height: height);

void main() {
  group('RackGeometry.assignPositions', () {
    test('clusters a level 11 + 10 layout into two rows, ordered '
        'left-to-right within each row', () {
      // Built shuffled (interleaved rows, descending x) to prove the
      // ordering comes from geometry, not input order.
      final row0 = [for (var i = 0; i < 11; i++) _box(0.05 + i * 0.09, 0.10)];
      final row1 = [for (var i = 0; i < 10; i++) _box(0.07 + i * 0.09, 0.55)];
      final shuffled = <NormalizedRect>[
        ...row1.reversed,
        ...row0.reversed,
      ];

      final positioned = RackGeometry.assignPositions(shuffled);

      check(positioned).isNotNull();
      check(positioned!.length).equals(21);
      check(
        positioned.map((p) => p.position).toList(),
      ).deepEquals([
        for (var i = 0; i < 11; i++) TilePosition(row: 0, index: i),
        for (var i = 0; i < 10; i++) TilePosition(row: 1, index: i),
      ]);
      // Row 0 is the geometric top row and each row is sorted by center x.
      check(positioned[0].bounds).equals(row0.first);
      check(positioned[10].bounds).equals(row0.last);
      check(positioned[11].bounds).equals(row1.first);
      check(positioned[20].bounds).equals(row1.last);
    });

    test('survives skewed baselines (a tilted rack still forms two '
        'clusters)', () {
      // Tops drift by 0.08 across the row — a visibly tilted rack.
      final row0 = [
        for (var i = 0; i < 7; i++) _box(0.08 + i * 0.13, 0.08 + i * 0.011),
      ];
      final row1 = [
        for (var i = 0; i < 7; i++) _box(0.08 + i * 0.13, 0.52 + i * 0.011),
      ];

      final positioned = RackGeometry.assignPositions([...row0, ...row1]);

      check(positioned).isNotNull();
      check(positioned!.length).equals(14);
      check(
        positioned.where((p) => p.position.row == 0).map((p) => p.bounds),
      ).deepEquals(row0);
      check(
        positioned.where((p) => p.position.row == 1).map((p) => p.bounds),
      ).deepEquals(row1);
    });

    test('rejects a single-row layout (identical baselines)', () {
      final boxes = [for (var i = 0; i < 10; i++) _box(0.06 + i * 0.09, 0.4)];

      check(RackGeometry.assignPositions(boxes)).isNull();
    });

    test('rejects baselines too close to be two real rows (jittered single '
        'row)', () {
      // Vertical jitter of 0.02 on 0.3-tall boxes: separation far below the
      // 0.6 × meanHeight floor.
      final boxes = [
        for (var i = 0; i < 10; i++)
          _box(0.06 + i * 0.09, 0.40 + (i.isEven ? 0.0 : 0.02)),
      ];

      check(RackGeometry.assignPositions(boxes)).isNull();
    });

    test('rejects a clean 3-row layout instead of absorbing the middle '
        'baseline into a neighboring row', () {
      // Three level rows of 7 with vertical centers at y 0.2 / 0.5 / 0.8.
      // k=2 k-means merges two baselines into one wide cluster; the cluster
      // cohesion check must reject it rather than report a plausible rack.
      final boxes = [
        for (final top in const [0.05, 0.35, 0.65])
          for (var i = 0; i < 7; i++) _box(0.08 + i * 0.13, top),
      ];

      check(RackGeometry.assignPositions(boxes)).isNull();
    });

    test('rejects a tilted 3-row layout (skew must not mask the extra '
        'baseline)', () {
      // Same three bands, each drifting by 0.011 per column like the
      // accepted tilted 2-row rack.
      final boxes = [
        for (final top in const [0.05, 0.35, 0.65])
          for (var i = 0; i < 7; i++) _box(0.08 + i * 0.13, top + i * 0.011),
      ];

      check(RackGeometry.assignPositions(boxes)).isNull();
    });

    test('rejects fewer than two boxes', () {
      check(RackGeometry.assignPositions(const [])).isNull();
      check(RackGeometry.assignPositions([_box(0.5, 0.4)])).isNull();
    });

    test('a lone outlier forms its own row rather than rejecting the '
        'layout', () {
      // 5 boxes on one baseline + 1 far below: k-means yields a 5 + 1 split.
      final boxes = [
        for (var i = 0; i < 5; i++) _box(0.1 + i * 0.15, 0.1),
        _box(0.5, 0.6),
      ];

      final positioned = RackGeometry.assignPositions(boxes);

      check(positioned).isNotNull();
      check(
        positioned!.where((p) => p.position.row == 0).length,
      ).equals(5);
      check(
        positioned.where((p) => p.position.row == 1).length,
      ).equals(1);
    });
  });
}
