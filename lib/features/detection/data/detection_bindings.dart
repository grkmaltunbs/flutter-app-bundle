import 'dart:async';

import 'package:injectable/injectable.dart';
import 'package:okey_acar_mi/core/logging/app_logger.dart';
import 'package:okey_acar_mi/core/time/clock.dart';
import 'package:okey_acar_mi/features/detection/data/fakes/fake_tile_detector.dart';
import 'package:okey_acar_mi/features/detection/data/services/gemini_client.dart';
import 'package:okey_acar_mi/features/detection/data/services/gemini_tile_detector.dart';
import 'package:okey_acar_mi/features/detection/data/services/pipeline_tile_detector.dart';
import 'package:okey_acar_mi/features/detection/domain/services/tile_detector.dart';

/// Closes the [PipelineTileDetector]'s ML Kit recognizer when the DI
/// container resets (`getIt.reset()`).
FutureOr<void> disposePipelineTileDetector(PipelineTileDetector instance) =>
    instance.dispose();

/// DI module for the detection feature: one concrete detector per
/// environment, with [TileDetector] aliased to it.
///
/// Prod now reads racks with Gemini (Firebase AI Logic). The legacy on-device
/// [PipelineTileDetector] is still registered as a one-line-revert fallback
/// until the Gemini path is validated on real devices and Phase 5 deletes it.
@module
abstract class DetectionBindings {
  /// The Firebase AI Logic client that owns the `firebase_ai` model. Prod only
  /// — Firebase is initialized for the prod flavor exclusively.
  @Environment('prod')
  @lazySingleton
  GeminiClient geminiClient() => FirebaseGeminiClient();

  /// The production Gemini-backed detector.
  @Environment('prod')
  @lazySingleton
  GeminiTileDetector geminiTileDetector(
    GeminiClient client,
    Clock clock,
    AppLogger logger,
  ) => GeminiTileDetector(client, clock, logger);

  /// Aliases the prod [TileDetector] to the Gemini detector.
  @Environment('prod')
  @lazySingleton
  TileDetector prodTileDetector(GeminiTileDetector impl) => impl;

  /// Legacy on-device ML Kit + OpenCV pipeline — kept registered as a fallback
  /// (resolve it explicitly to revert) but no longer the prod [TileDetector].
  @Environment('prod')
  @LazySingleton(dispose: disposePipelineTileDetector)
  PipelineTileDetector pipelineTileDetector(Clock clock, AppLogger logger) =>
      PipelineTileDetector(clock, logger);

  /// The seeded demo detection fake (no ML, deterministic, off-isolate).
  @Environment('demo')
  @lazySingleton
  FakeTileDetector fakeTileDetector(Clock clock) => FakeTileDetector(clock);

  /// Aliases the demo [TileDetector] to the fake.
  @Environment('demo')
  @lazySingleton
  TileDetector demoTileDetector(FakeTileDetector fake) => fake;
}
