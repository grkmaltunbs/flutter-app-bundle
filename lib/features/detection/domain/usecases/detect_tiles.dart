import 'package:injectable/injectable.dart';
import 'package:okey_acar_mi/features/capture/domain/entities/capture_payload.dart';
import 'package:okey_acar_mi/features/detection/domain/entities/detection_update.dart';
import 'package:okey_acar_mi/features/detection/domain/services/tile_detector.dart';

/// Runs on-device tile detection for a capture.
@injectable
class DetectTiles {
  /// Creates a [DetectTiles].
  const DetectTiles(this._detector);

  final TileDetector _detector;

  /// Starts a detection run for [payload].
  ///
  /// Cold stream semantics are inherited from [TileDetector.detect]:
  /// listening starts the run, cancelling aborts it.
  Stream<DetectionUpdate> call(CapturePayload payload) =>
      _detector.detect(payload);
}
