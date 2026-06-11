import 'dart:async';

import 'package:injectable/injectable.dart';
import 'package:okey_acar_mi/core/logging/app_logger.dart';
import 'package:okey_acar_mi/core/time/clock.dart';
import 'package:okey_acar_mi/features/detection/data/fakes/fake_tile_detector.dart';
import 'package:okey_acar_mi/features/detection/data/services/pipeline_tile_detector.dart';
import 'package:okey_acar_mi/features/detection/domain/services/tile_detector.dart';

/// Closes the [PipelineTileDetector]'s ML Kit recognizer when the DI
/// container resets (`getIt.reset()`).
FutureOr<void> disposePipelineTileDetector(PipelineTileDetector instance) =>
    instance.dispose();

/// DI module for the detection feature: one concrete detector per
/// environment, registered as itself, with [TileDetector] aliased to it.
@module
abstract class DetectionBindings {
  /// The production ML Kit + OpenCV-segmentation (luma-fallback) pipeline
  /// detector.
  @Environment('prod')
  @LazySingleton(dispose: disposePipelineTileDetector)
  PipelineTileDetector pipelineTileDetector(Clock clock, AppLogger logger) =>
      PipelineTileDetector(clock, logger);

  /// Aliases the prod [TileDetector] to the pipeline detector.
  @Environment('prod')
  @lazySingleton
  TileDetector prodTileDetector(PipelineTileDetector impl) => impl;

  /// The seeded demo detection fake (no ML, deterministic, off-isolate).
  @Environment('demo')
  @lazySingleton
  FakeTileDetector fakeTileDetector(Clock clock) => FakeTileDetector(clock);

  /// Aliases the demo [TileDetector] to the fake.
  @Environment('demo')
  @lazySingleton
  TileDetector demoTileDetector(FakeTileDetector fake) => fake;
}
