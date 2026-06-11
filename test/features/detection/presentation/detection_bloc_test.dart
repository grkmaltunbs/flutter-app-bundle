import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:checks/checks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:okey_acar_mi/core/error/failure.dart';
import 'package:okey_acar_mi/core/game/tile_color.dart';
import 'package:okey_acar_mi/core/logging/app_logger.dart';
import 'package:okey_acar_mi/features/capture/domain/entities/capture_payload.dart';
import 'package:okey_acar_mi/features/detection/domain/entities/detected_tile.dart';
import 'package:okey_acar_mi/features/detection/domain/entities/detection_result.dart';
import 'package:okey_acar_mi/features/detection/domain/entities/detection_stage.dart';
import 'package:okey_acar_mi/features/detection/domain/entities/detection_update.dart';
import 'package:okey_acar_mi/features/detection/domain/usecases/detect_tiles.dart';
import 'package:okey_acar_mi/features/detection/presentation/blocs/detection_bloc.dart';

class _MockDetectTiles extends Mock implements DetectTiles {}

class _MockAppLogger extends Mock implements AppLogger {}

/// Pinned instant for the payload and result timestamps.
final DateTime _instant = DateTime.utc(2026, 6, 11, 9, 30);

final CapturePayload _payload = CapturePayload.still(
  imagePath: '/captures/rack.png',
  source: CaptureSource.photo,
  capturedAt: _instant,
);

const DetectedTile _tile1 = DetectedTile(
  color: TileColor.red,
  number: 1,
  confidence: 0.93,
  position: TilePosition(row: 0, index: 0),
);

const DetectedTile _tile2 = DetectedTile(
  color: TileColor.joker,
  confidence: 0.82,
  position: TilePosition(row: 1, index: 0),
);

final DetectionResult _result = DetectionResult(
  tiles: const [_tile1, _tile2],
  overallConfidence: 0.875,
  sourceImagePath: '/captures/rack.png',
  frameCount: 1,
  detectedAt: _instant,
);

/// The detector's full happy-path update script for [_result].
List<DetectionUpdate> _successUpdates() => [
  const DetectionUpdate.stage(DetectionStage.preparing),
  const DetectionUpdate.stage(DetectionStage.locatingRack, totalTiles: 2),
  const DetectionUpdate.stage(DetectionStage.readingTiles, totalTiles: 2),
  const DetectionUpdate.tile(_tile1),
  const DetectionUpdate.tile(_tile2),
  const DetectionUpdate.stage(DetectionStage.finalizing),
  DetectionUpdate.completed(_result),
];

/// The states the bloc folds [_successUpdates] into, starting from the
/// handler's reset emission.
List<DetectionState> _successStates() => [
  const DetectionState.processing(
    stage: DetectionStage.preparing,
    revealed: [],
  ),
  const DetectionState.processing(
    stage: DetectionStage.locatingRack,
    revealed: [],
    totalTiles: 2,
  ),
  const DetectionState.processing(
    stage: DetectionStage.readingTiles,
    revealed: [],
    totalTiles: 2,
  ),
  const DetectionState.processing(
    stage: DetectionStage.readingTiles,
    revealed: [_tile1],
    totalTiles: 2,
  ),
  const DetectionState.processing(
    stage: DetectionStage.readingTiles,
    revealed: [_tile1, _tile2],
    totalTiles: 2,
  ),
  const DetectionState.processing(
    stage: DetectionStage.finalizing,
    revealed: [_tile1, _tile2],
    totalTiles: 2,
  ),
  DetectionState.success(result: _result),
];

void main() {
  late _MockDetectTiles detectTiles;
  late _MockAppLogger logger;

  setUp(() {
    detectTiles = _MockDetectTiles();
    logger = _MockAppLogger();
  });

  DetectionBloc buildBloc() => DetectionBloc(detectTiles, logger, _payload);

  void stubUpdates(List<DetectionUpdate> updates) {
    when(
      () => detectTiles.call(_payload),
    ).thenAnswer((_) => Stream.fromIterable(updates));
  }

  test('initial state is processing(preparing) with nothing revealed', () {
    stubUpdates(_successUpdates());
    final bloc = buildBloc();
    addTearDown(bloc.close);

    check(bloc.state).equals(
      const DetectionState.processing(
        stage: DetectionStage.preparing,
        revealed: [],
      ),
    );
  });

  group('started', () {
    blocTest<DetectionBloc, DetectionState>(
      'folds the full stage → tile → completed sequence into staged '
      'processing with a growing reveal, then success',
      setUp: () => stubUpdates(_successUpdates()),
      build: buildBloc,
      act: (bloc) => bloc.add(const DetectionEvent.started()),
      expect: _successStates,
      verify: (_) => verify(() => detectTiles.call(_payload)).called(1),
    );

    blocTest<DetectionBloc, DetectionState>(
      'failed(noTilesDetected) lands in failure and is logged',
      setUp: () => stubUpdates(const [
        DetectionUpdate.stage(DetectionStage.preparing),
        DetectionUpdate.stage(DetectionStage.locatingRack),
        DetectionUpdate.failed(Failure.noTilesDetected()),
      ]),
      build: buildBloc,
      act: (bloc) => bloc.add(const DetectionEvent.started()),
      expect: () => const [
        DetectionState.processing(
          stage: DetectionStage.preparing,
          revealed: [],
        ),
        DetectionState.processing(
          stage: DetectionStage.locatingRack,
          revealed: [],
        ),
        DetectionState.failure(failure: Failure.noTilesDetected()),
      ],
      verify: (_) => verify(() => logger.warning(any())).called(1),
    );

    blocTest<DetectionBloc, DetectionState>(
      'failed(detectionFailed) lands in failure',
      setUp: () => stubUpdates(const [
        DetectionUpdate.stage(DetectionStage.preparing),
        DetectionUpdate.failed(Failure.detectionFailed('boom')),
      ]),
      build: buildBloc,
      act: (bloc) => bloc.add(const DetectionEvent.started()),
      expect: () => const [
        DetectionState.processing(
          stage: DetectionStage.preparing,
          revealed: [],
        ),
        DetectionState.failure(failure: Failure.detectionFailed('boom')),
      ],
    );

    blocTest<DetectionBloc, DetectionState>(
      'a tile update before any rack location still grows the reveal from '
      'the current processing state',
      setUp: () => stubUpdates(const [
        DetectionUpdate.tile(_tile1),
      ]),
      build: buildBloc,
      act: (bloc) => bloc.add(const DetectionEvent.started()),
      expect: () => const [
        DetectionState.processing(
          stage: DetectionStage.preparing,
          revealed: [],
        ),
        DetectionState.processing(
          stage: DetectionStage.preparing,
          revealed: [_tile1],
        ),
      ],
    );
  });

  group('retryRequested', () {
    blocTest<DetectionBloc, DetectionState>(
      'after a failure, retry resets to processing and re-runs the detector '
      'to success',
      setUp: () {
        var call = 0;
        when(() => detectTiles.call(_payload)).thenAnswer(
          (_) => ++call == 1
              ? Stream.fromIterable(const [
                  DetectionUpdate.stage(DetectionStage.preparing),
                  DetectionUpdate.failed(Failure.detectionFailed('boom')),
                ])
              : Stream.fromIterable(_successUpdates()),
        );
      },
      build: buildBloc,
      act: (bloc) async {
        bloc.add(const DetectionEvent.started());
        await pumpEventQueue();
        bloc.add(const DetectionEvent.retryRequested());
      },
      expect: () => [
        const DetectionState.processing(
          stage: DetectionStage.preparing,
          revealed: [],
        ),
        const DetectionState.failure(
          failure: Failure.detectionFailed('boom'),
        ),
        ..._successStates(),
      ],
      verify: (_) => verify(() => detectTiles.call(_payload)).called(2),
    );

    test('retry while a run is in flight cancels it (restartable) before '
        'starting fresh', () async {
      var firstCancelled = false;
      final first = StreamController<DetectionUpdate>(
        onCancel: () => firstCancelled = true,
      );
      var call = 0;
      when(() => detectTiles.call(_payload)).thenAnswer(
        (_) =>
            ++call == 1 ? first.stream : Stream.fromIterable(_successUpdates()),
      );

      final bloc = buildBloc()..add(const DetectionEvent.started());
      await pumpEventQueue();
      first.add(
        const DetectionUpdate.stage(
          DetectionStage.locatingRack,
          totalTiles: 21,
        ),
      );
      await pumpEventQueue();
      check(firstCancelled).isFalse();

      bloc.add(const DetectionEvent.retryRequested());
      await pumpEventQueue();

      check(firstCancelled).isTrue();
      check(bloc.state).equals(DetectionState.success(result: _result));
      verify(() => detectTiles.call(_payload)).called(2);

      await bloc.close();
    });
  });

  group('close', () {
    test('closing the bloc mid-stream cancels the source (killing the '
        'worker) and emits nothing further', () async {
      var cancelled = false;
      final controller = StreamController<DetectionUpdate>(
        onCancel: () => cancelled = true,
      );
      when(
        () => detectTiles.call(_payload),
      ).thenAnswer((_) => controller.stream);

      final bloc = buildBloc()..add(const DetectionEvent.started());
      await pumpEventQueue();
      controller.add(
        const DetectionUpdate.stage(
          DetectionStage.locatingRack,
          totalTiles: 21,
        ),
      );
      await pumpEventQueue();
      const midStream = DetectionState.processing(
        stage: DetectionStage.locatingRack,
        revealed: [],
        totalTiles: 21,
      );
      check(bloc.state).equals(midStream);

      await bloc.close();
      check(cancelled).isTrue();

      // A late update from the (now cancelled) source changes nothing.
      controller.add(const DetectionUpdate.tile(_tile1));
      await pumpEventQueue();
      check(bloc.state).equals(midStream);

      await controller.close();
    });
  });
}
