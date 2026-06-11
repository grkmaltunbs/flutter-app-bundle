import 'dart:async';

import 'package:checks/checks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:okey_acar_mi/core/error/failure.dart';
import 'package:okey_acar_mi/core/game/tile_color.dart';
import 'package:okey_acar_mi/core/time/clock.dart';
import 'package:okey_acar_mi/features/capture/domain/entities/capture_payload.dart';
import 'package:okey_acar_mi/features/detection/data/fakes/fake_tile_detector.dart';
import 'package:okey_acar_mi/features/detection/data/fakes/seeded_detections.dart';
import 'package:okey_acar_mi/features/detection/domain/entities/detected_tile.dart';
import 'package:okey_acar_mi/features/detection/domain/entities/detection_stage.dart';
import 'package:okey_acar_mi/features/detection/domain/entities/detection_update.dart';

/// Pinned instant for `detectedAt` — never `DateTime.now()`.
class _FixedClock implements Clock {
  const _FixedClock();

  static final DateTime instant = DateTime.utc(2026, 6, 11, 9);

  @override
  DateTime now() => instant;
}

/// A 101-mode still whose path carries the 101 fixture filename (the fake
/// keys its seed off the filename, like `FakeCaptureService` temp copies).
final _still101 = CapturePayload.still(
  imagePath: '/tmp/fake_capture_1_rack_101_21.png',
  source: CaptureSource.photo,
  capturedAt: _FixedClock.instant,
);

/// An Okey-mode still (14-tile fixture filename).
final _stillOkey = CapturePayload.still(
  imagePath: '/tmp/fake_capture_2_rack_okey_14.png',
  source: CaptureSource.gallery,
  capturedAt: _FixedClock.instant,
);

/// A video burst; the seeded aggregation ignores the actual frame count.
final _burst = CapturePayload.frames(
  framePaths: const [
    '/tmp/fake_capture_3_rack_frame_1.png',
    '/tmp/fake_capture_4_rack_frame_2.png',
    '/tmp/fake_capture_5_rack_frame_3.png',
    '/tmp/fake_capture_6_rack_frame_1.png',
    '/tmp/fake_capture_7_rack_frame_2.png',
  ],
  capturedAt: _FixedClock.instant,
);

/// Asserts [tiles] form a legal seeded rack per PRODUCT_SPEC → Domain rules:
/// numerals 1–13 in the four tile colors, at most two copies of any
/// number/color pair, at most two unnumbered joker candidates, unique 2-row
/// positions, and in-image normalized bounds.
void _checkLegalRack(List<DetectedTile> tiles) {
  final copies = <(TileColor, int), int>{};
  final positions = <TilePosition>{};
  var jokers = 0;

  for (final tile in tiles) {
    check(
      because: 'rack slots must be unique (${tile.position})',
      positions.add(tile.position),
    ).isTrue();
    check(tile.position.row).isLessOrEqual(1);
    check(tile.confidence).isGreaterThan(0);
    check(tile.confidence).isLessOrEqual(1);

    final bounds = tile.bounds;
    check(bounds).isNotNull();
    check(bounds!.left).isGreaterOrEqual(0);
    check(bounds.top).isGreaterOrEqual(0);
    check(bounds.left + bounds.width).isLessOrEqual(1);
    check(bounds.top + bounds.height).isLessOrEqual(1);

    if (tile.color == TileColor.joker) {
      check(
        because: 'a joker candidate carries no numeral',
        tile.number,
      ).isNull();
      jokers++;
    } else {
      final number = tile.number;
      check(because: 'a colored tile must be numbered', number).isNotNull();
      check(number!).isGreaterOrEqual(1);
      check(number).isLessOrEqual(13);
      final key = (tile.color, number);
      copies[key] = (copies[key] ?? 0) + 1;
    }
  }

  check(because: 'at most 2 false jokers exist', jokers).isLessOrEqual(2);
  copies.forEach((key, count) {
    check(
      because: 'at most two copies of $key exist in the set',
      count,
    ).isLessOrEqual(2);
  });
  check(
    tiles.map((t) => t.position.row).toSet(),
  ).unorderedEquals(const {0, 1});
}

void main() {
  late FakeTileDetector detector;

  setUp(() {
    detector = FakeTileDetector(const _FixedClock())
      // Pacing is irrelevant to most assertions — replay instantly.
      ..revealPause = Duration.zero;
  });

  List<DetectedTile> tilesOf(List<DetectionUpdate> updates) => [
    for (final update in updates.whereType<DetectionTileUpdate>()) update.tile,
  ];

  group('defaults & reset', () {
    test('a fresh fake replays fixtures with a 60ms reveal and no recorded '
        'result', () {
      final fresh = FakeTileDetector(const _FixedClock());

      check(fresh.mode).equals(FakeDetectionMode.fromFixture);
      check(fresh.revealPause).equals(const Duration(milliseconds: 60));
      check(fresh.lastResult).isNull();
    });

    test('reset restores mode, pacing, and clears lastResult', () async {
      detector
        ..mode = FakeDetectionMode.noTiles
        ..revealPause = const Duration(seconds: 9);
      await detector.detect(_still101).toList();

      detector.reset();

      check(detector.mode).equals(FakeDetectionMode.fromFixture);
      check(detector.revealPause).equals(const Duration(milliseconds: 60));
      check(detector.lastResult).isNull();
    });
  });

  group('fromFixture', () {
    test('the 101 fixture streams stages, 21 tiles in rack order, and a '
        'completed result', () async {
      final updates = await detector.detect(_still101).toList();

      // Stage protocol: prepare → locate (count known) → read → finalize.
      check(
        updates.whereType<DetectionStageUpdate>().map((u) => u.stage).toList(),
      ).deepEquals(const [
        DetectionStage.preparing,
        DetectionStage.locatingRack,
        DetectionStage.readingTiles,
        DetectionStage.finalizing,
      ]);
      check(
        updates
            .whereType<DetectionStageUpdate>()
            .singleWhere((u) => u.stage == DetectionStage.locatingRack)
            .totalTiles,
      ).equals(21);

      // 21 tiles revealed in 2-row rack order (11 + 10).
      final tiles = tilesOf(updates);
      check(tiles.length).equals(21);
      check(tiles.map((t) => t.position).toList()).deepEquals([
        for (var i = 0; i < 11; i++) TilePosition(row: 0, index: i),
        for (var i = 0; i < 10; i++) TilePosition(row: 1, index: i),
      ]);

      // Exactly one joker candidate (joker color, null number).
      check(
        tiles
            .where((t) => t.color == TileColor.joker && t.number == null)
            .length,
      ).equals(1);
      // Exactly two tiles under the low-confidence threshold.
      check(
        tiles.where((t) => t.confidence < kLowConfidenceThreshold).length,
      ).equals(2);

      // Terminal result mirrors the streamed tiles.
      final result = check(updates.last).isA<DetectionCompletedUpdate>();
      result.has((u) => u.result.tiles, 'tiles').deepEquals(tiles);
      result.has((u) => u.result.frameCount, 'frameCount').equals(1);
      result
          .has((u) => u.result.sourceImagePath, 'sourceImagePath')
          .equals('/tmp/fake_capture_1_rack_101_21.png');
      result
          .has((u) => u.result.detectedAt, 'detectedAt')
          .equals(_FixedClock.instant);
      final mean =
          tiles.fold<double>(0, (sum, t) => sum + t.confidence) / tiles.length;
      result
          .has((u) => u.result.overallConfidence, 'overallConfidence')
          .isCloseTo(mean, 0.0001);

      // The completed result is recorded for integration assertions.
      check(detector.lastResult).isNotNull();
      check(
        detector.lastResult!,
      ).equals((updates.last as DetectionCompletedUpdate).result);

      _checkLegalRack(tiles);
    });

    test('the Okey fixture yields the 14-tile rack (7 + 7)', () async {
      final updates = await detector.detect(_stillOkey).toList();

      final tiles = tilesOf(updates);
      check(tiles.length).equals(14);
      check(tiles.where((t) => t.position.row == 0).length).equals(7);
      check(tiles.where((t) => t.position.row == 1).length).equals(7);
      check(updates.last).isA<DetectionCompletedUpdate>();
      check(
        (updates.last as DetectionCompletedUpdate).result.frameCount,
      ).equals(1);
      _checkLegalRack(tiles);
    });

    test('a video burst aggregates the three seeded frames and flags the '
        'two disagreement positions low-confidence', () async {
      final updates = await detector.detect(_burst).toList();

      // The multi-frame stage appears…
      check(
        updates.whereType<DetectionStageUpdate>().map((u) => u.stage).toList(),
      ).deepEquals(const [
        DetectionStage.preparing,
        DetectionStage.locatingRack,
        DetectionStage.readingTiles,
        DetectionStage.aggregatingFrames,
        DetectionStage.finalizing,
      ]);

      // …and the result reflects 3 aggregated frames (the seed, not the
      // burst length).
      final result = (updates.last as DetectionCompletedUpdate).result;
      check(result.frameCount).equals(3);
      check(
        result.sourceImagePath,
      ).equals('/tmp/fake_capture_3_rack_frame_1.png');
      check(result.tiles.length).equals(21);

      DetectedTile at(int row, int index) => result.tiles.singleWhere(
        (t) => t.position == TilePosition(row: row, index: index),
      );
      check(at(0, 3).confidence).isLessThan(kLowConfidenceThreshold);
      check(at(1, 9).confidence).isLessThan(kLowConfidenceThreshold);
      _checkLegalRack(result.tiles);
    });
  });

  group('failure modes', () {
    test('noTiles stages then fails with Failure.noTilesDetected', () async {
      detector.mode = FakeDetectionMode.noTiles;

      final updates = await detector.detect(_still101).toList();

      check(updates).deepEquals(const [
        DetectionUpdate.stage(DetectionStage.preparing),
        DetectionUpdate.stage(DetectionStage.locatingRack),
        DetectionUpdate.failed(Failure.noTilesDetected()),
      ]);
      check(detector.lastResult).isNull();
    });

    test('error stages then fails with Failure.detectionFailed', () async {
      detector.mode = FakeDetectionMode.error;

      final updates = await detector.detect(_still101).toList();

      check(updates).deepEquals(const [
        DetectionUpdate.stage(DetectionStage.preparing),
        DetectionUpdate.failed(
          Failure.detectionFailed('fake-detection-error'),
        ),
      ]);
      check(detector.lastResult).isNull();
    });
  });

  group('edge modes', () {
    test('wrongCount completes with a 19-tile rack (valid for neither game '
        'mode)', () async {
      detector.mode = FakeDetectionMode.wrongCount;

      final updates = await detector.detect(_still101).toList();

      final tiles = tilesOf(updates);
      check(tiles.length).equals(19);
      check(updates.last).isA<DetectionCompletedUpdate>();
      _checkLegalRack(tiles);
    });

    test('lowConfidence re-reads the 21-tile rack with a sub-threshold '
        'mean and many flagged tiles', () async {
      detector.mode = FakeDetectionMode.lowConfidence;

      final updates = await detector.detect(_still101).toList();

      final result = (updates.last as DetectionCompletedUpdate).result;
      check(result.tiles.length).equals(21);
      check(result.overallConfidence).isLessThan(kLowConfidenceThreshold);
      check(
        result.tiles
            .where((t) => t.confidence < kLowConfidenceThreshold)
            .length,
      ).isGreaterOrEqual(8);
      // Identities still match the seeded 101 rack — only confidence drops.
      check(
        result.tiles.map((t) => (t.color, t.number)).toList(),
      ).deepEquals([
        for (final tile in SeededDetections.rack101())
          (tile.color, tile.number),
      ]);
    });
  });

  group('cancellation', () {
    test('cancelling the subscription mid-stream aborts the run: no further '
        'events, no recorded result', () async {
      // Paced reveal so the cancel deterministically lands mid-stream.
      detector.revealPause = const Duration(milliseconds: 40);
      final received = <DetectionUpdate>[];
      final firstTile = Completer<void>();

      late final StreamSubscription<DetectionUpdate> subscription;
      subscription = detector.detect(_still101).listen((update) {
        received.add(update);
        if (update is DetectionTileUpdate && !firstTile.isCompleted) {
          firstTile.complete();
        }
      });
      await firstTile.future;
      await subscription.cancel();

      final countAtCancel = received.length;
      check(
        received.whereType<DetectionCompletedUpdate>(),
      ).isEmpty();

      // A quiescence window many reveal-pauses long: a survived worker
      // would have pushed more tile updates by now.
      await Future<void>.delayed(const Duration(milliseconds: 300));
      check(received.length).equals(countAtCancel);
      check(detector.lastResult).isNull();
    });
  });
}
