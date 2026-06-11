import 'package:okey_acar_mi/features/capture/domain/entities/capture_payload.dart';
import 'package:okey_acar_mi/features/detection/domain/entities/detection_update.dart';

/// On-device tile detection behind an environment seam: the prod ML pipeline
/// and the demo fake both implement this interface.
abstract interface class TileDetector {
  /// Detects the tiles in [payload].
  ///
  /// Returns a **cold** stream: listening starts the detection run and
  /// cancelling the subscription aborts it (the implementation's `onCancel`
  /// kills the worker isolate). Detection runs **off the UI isolate** in
  /// every environment.
  Stream<DetectionUpdate> detect(CapturePayload payload);
}
