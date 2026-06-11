import 'package:checks/checks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:okey_acar_mi/features/detection/data/services/rack_segmenter.dart';
import 'package:okey_acar_mi/features/detection/domain/entities/detected_tile.dart';

const _box = NormalizedRect(left: 0.1, top: 0.1, width: 0.05, height: 0.1);

/// A scripted segmenter: counts calls and either returns [boxes] or throws.
class _StubSegmenter implements RackSegmenter {
  _StubSegmenter({this.boxes = const [], this.error});

  final List<NormalizedRect> boxes;
  final Exception? error;
  int calls = 0;

  @override
  List<NormalizedRect> segment(img.Image image) {
    calls++;
    if (error != null) throw error!;
    return boxes;
  }
}

void main() {
  final image = img.Image(width: 64, height: 64);

  group('FallbackRackSegmenter', () {
    test('returns the primary result without touching the fallback', () {
      final primary = _StubSegmenter(boxes: const [_box]);
      final fallback = _StubSegmenter();
      final logs = <String>[];
      final segmenter = FallbackRackSegmenter(
        primary: primary,
        fallback: fallback,
        onPrimaryError: logs.add,
      );

      check(segmenter.segment(image)).deepEquals(const [_box]);
      check(primary.calls).equals(1);
      check(fallback.calls).equals(0);
      check(logs).isEmpty();
    });

    test('falls back and reports when the primary throws', () {
      final primary = _StubSegmenter(error: Exception('native lib missing'));
      final fallback = _StubSegmenter(boxes: const [_box]);
      final logs = <String>[];
      final segmenter = FallbackRackSegmenter(
        primary: primary,
        fallback: fallback,
        onPrimaryError: logs.add,
      );

      check(segmenter.segment(image)).deepEquals(const [_box]);
      check(fallback.calls).equals(1);
      check(logs).length.equals(1);
      check(logs.single).contains('native lib missing');
    });

    test('an empty primary result is NOT a fallback trigger', () {
      // Empty = legitimate "no tiles here" (pipeline maps it to
      // noTilesDetected); only a throw means the primary is unusable.
      final primary = _StubSegmenter();
      final fallback = _StubSegmenter(boxes: const [_box]);
      final segmenter = FallbackRackSegmenter(
        primary: primary,
        fallback: fallback,
      );

      check(segmenter.segment(image)).isEmpty();
      check(fallback.calls).equals(0);
    });

    test('tolerates a missing onPrimaryError listener', () {
      final segmenter = FallbackRackSegmenter(
        primary: _StubSegmenter(error: Exception('boom')),
        fallback: _StubSegmenter(boxes: const [_box]),
      );

      check(segmenter.segment(image)).deepEquals(const [_box]);
    });
  });
}
