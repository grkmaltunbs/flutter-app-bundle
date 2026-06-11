import 'package:okey_acar_mi/core/error/failure.dart';
import 'package:okey_acar_mi/core/time/clock.dart';
import 'package:okey_acar_mi/features/capture/domain/entities/capture_payload.dart';
import 'package:okey_acar_mi/features/detection/data/fakes/seeded_detections.dart';
import 'package:okey_acar_mi/features/detection/data/isolate/detection_worker_channel.dart';
import 'package:okey_acar_mi/features/detection/data/processing/frame_aggregator.dart';
import 'package:okey_acar_mi/features/detection/domain/entities/detected_tile.dart';
import 'package:okey_acar_mi/features/detection/domain/entities/detection_result.dart';
import 'package:okey_acar_mi/features/detection/domain/entities/detection_stage.dart';
import 'package:okey_acar_mi/features/detection/domain/entities/detection_update.dart';
import 'package:okey_acar_mi/features/detection/domain/services/tile_detector.dart';

/// The detection outcomes the demo fake can be driven into, so every
/// analyzing/review state is reachable on a simulator without ML hardware.
enum FakeDetectionMode {
  /// Seeded rack keyed off the capture's fixture filename (default).
  fromFixture,

  /// The same rack read badly: low overall confidence + many flagged tiles.
  lowConfidence,

  /// Stages, then `Failure.noTilesDetected`.
  noTiles,

  /// A 19-tile reading (wrong for both game modes) for review's count flow.
  wrongCount,

  /// Stages, then `Failure.detectionFailed('fake-detection-error')`.
  error,
}

/// The sendable replay script the fake worker executes. Snapshotted on the
/// main isolate (including the Clock-stamped result) so the spawned worker
/// stays trivially deterministic.
class FakeDetectionScript {
  /// Creates a [FakeDetectionScript].
  const FakeDetectionScript({required this.updates, required this.revealPause});

  /// The updates to replay, in order, ending with a terminal update.
  final List<DetectionUpdate> updates;

  /// The pause before each `tile` update — the visible per-tile reveal.
  final Duration revealPause;
}

/// Fake worker entrypoint: replays the snapshot script off the main isolate.
///
/// Top-level (an `Isolate.spawn` requirement) and run through the same
/// [DetectionWorkerChannel] as prod, so the demo flavor genuinely exercises
/// worker spawn, cross-isolate update marshalling, and cancel-kills.
Future<void> fakeDetectionWorkerMain(DetectionWorkerRequest request) async {
  final script = request.config! as FakeDetectionScript;
  for (final update in script.updates) {
    if (update is DetectionTileUpdate && script.revealPause > Duration.zero) {
      await Future<void>.delayed(script.revealPause);
    }
    request.sendPort.send(update);
  }
}

/// In-memory, seeded [TileDetector] for the demo flavor.
///
/// Deterministic and offline — no ML Kit, no OpenCV. Flip [mode] (it is a
/// `demo`-scoped singleton, so tests resolve it from the DI container) to
/// drive failure/edge paths. Detection still runs **off the UI isolate**
/// through the shared [DetectionWorkerChannel].
class FakeTileDetector implements TileDetector {
  /// Creates a [FakeTileDetector] in [FakeDetectionMode.fromFixture].
  FakeTileDetector(this._clock);

  final Clock _clock;

  /// Controls the outcome of the next [detect] run.
  FakeDetectionMode mode = FakeDetectionMode.fromFixture;

  /// The pause before each per-tile reveal; lower it in tests for speed.
  Duration revealPause = const Duration(milliseconds: 60);

  /// The last completed result, recorded on the **main isolate** as the
  /// `completed` update passes through — integration tests assert on it.
  DetectionResult? lastResult;

  /// Restores the fake to its defaults.
  void reset() {
    mode = FakeDetectionMode.fromFixture;
    revealPause = const Duration(milliseconds: 60);
    lastResult = null;
  }

  @override
  Stream<DetectionUpdate> detect(CapturePayload payload) {
    // Snapshot a fully sendable script now (main isolate): seeded tiles,
    // aggregation, and the Clock-stamped result are all precomputed.
    final script = FakeDetectionScript(
      updates: _buildScript(payload),
      revealPause: revealPause,
    );
    return DetectionWorkerChannel.run(
      entrypoint: fakeDetectionWorkerMain,
      payload: payload,
      config: script,
    ).map((update) {
      if (update is DetectionCompletedUpdate) lastResult = update.result;
      return update;
    });
  }

  List<DetectionUpdate> _buildScript(CapturePayload payload) {
    switch (mode) {
      case FakeDetectionMode.noTiles:
        return const [
          DetectionUpdate.stage(DetectionStage.preparing),
          DetectionUpdate.stage(DetectionStage.locatingRack),
          DetectionUpdate.failed(Failure.noTilesDetected()),
        ];
      case FakeDetectionMode.error:
        return const [
          DetectionUpdate.stage(DetectionStage.preparing),
          DetectionUpdate.failed(
            Failure.detectionFailed('fake-detection-error'),
          ),
        ];
      case FakeDetectionMode.fromFixture:
      case FakeDetectionMode.lowConfidence:
      case FakeDetectionMode.wrongCount:
        return _successScript(payload);
    }
  }

  List<DetectionUpdate> _successScript(CapturePayload payload) {
    final (tiles, frameCount) = _readings(payload);
    final overall =
        tiles.fold<double>(0, (sum, tile) => sum + tile.confidence) /
        tiles.length;
    return [
      const DetectionUpdate.stage(DetectionStage.preparing),
      DetectionUpdate.stage(
        DetectionStage.locatingRack,
        totalTiles: tiles.length,
      ),
      DetectionUpdate.stage(
        DetectionStage.readingTiles,
        totalTiles: tiles.length,
      ),
      if (frameCount > 1)
        DetectionUpdate.stage(
          DetectionStage.aggregatingFrames,
          totalTiles: tiles.length,
        ),
      for (final tile in tiles) DetectionUpdate.tile(tile),
      const DetectionUpdate.stage(DetectionStage.finalizing),
      DetectionUpdate.completed(
        DetectionResult(
          tiles: tiles,
          overallConfidence: overall,
          sourceImagePath: switch (payload) {
            StillCapture(:final imagePath) => imagePath,
            FramesCapture(:final framePaths) => framePaths.first,
          },
          frameCount: frameCount,
          detectedAt: _clock.now(),
        ),
      ),
    ];
  }

  /// The seeded tiles + effective frame count for [payload] under [mode].
  (List<DetectedTile>, int) _readings(CapturePayload payload) {
    switch (mode) {
      case FakeDetectionMode.lowConfidence:
        return (SeededDetections.lowConfidenceRack(), 1);
      case FakeDetectionMode.wrongCount:
        return (SeededDetections.rackWrongCount(), 1);
      case FakeDetectionMode.fromFixture:
      case FakeDetectionMode.noTiles:
      case FakeDetectionMode.error:
        break;
    }
    switch (payload) {
      case StillCapture(:final imagePath):
        // Keyed off the capture fixture: the FakeCaptureService copies its
        // asset fixtures to temp files, preserving the filename.
        final isOkeyRack = imagePath.contains('rack_okey_14');
        return (
          isOkeyRack ? SeededDetections.rackOkey() : SeededDetections.rack101(),
          1,
        );
      case FramesCapture():
        // Video burst: three seeded per-frame readings with disagreements at
        // two positions, run through the SHARED aggregator so those
        // positions land low-confidence (regardless of how many frames the
        // burst actually captured — the seed is deterministic).
        final readings = SeededDetections.frameReadings();
        return (FrameAggregator.aggregate(readings), readings.length);
    }
  }
}
