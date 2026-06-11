import 'dart:async';
import 'dart:isolate';

import 'package:okey_acar_mi/core/error/failure.dart';
import 'package:okey_acar_mi/features/capture/domain/entities/capture_payload.dart';
import 'package:okey_acar_mi/features/detection/domain/entities/detection_update.dart';

/// The single message handed to a worker entrypoint via [Isolate.spawn].
///
/// Everything inside must be **sendable** across isolates in the same group
/// (plain object trees without native resources): [payload] is a freezed
/// value, and [config] is whatever sendable snapshot the spawning detector
/// prepared (pipeline config for prod, a seeded replay script for the fake).
class DetectionWorkerRequest {
  /// Creates a [DetectionWorkerRequest].
  const DetectionWorkerRequest({
    required this.sendPort,
    required this.payload,
    this.config,
  });

  /// Where the worker posts its [DetectionUpdate]s.
  final SendPort sendPort;

  /// The capture being analyzed.
  final CapturePayload payload;

  /// Implementation-specific sendable configuration.
  final Object? config;
}

/// A worker entrypoint: a **top-level** function (required by
/// [Isolate.spawn]) that runs the detection pipeline and posts
/// [DetectionUpdate]s to `request.sendPort`, ending with a terminal
/// `completed` or `failed` update.
typedef DetectionWorkerEntrypoint =
    Future<void> Function(DetectionWorkerRequest request);

/// A non-terminal diagnostic from the worker (sendable: a plain string),
/// surfaced main-side through [DetectionWorkerChannel.run]'s `onLog` — the
/// worker's path for "recovered, but worth logging" events (e.g. the OpenCV
/// segmenter threw and the run fell back to the pure-Dart one).
class DetectionWorkerLog {
  /// Creates a [DetectionWorkerLog].
  const DetectionWorkerLog(this.message);

  /// The diagnostic to log on the main isolate.
  final String message;
}

/// Generic [Isolate.spawn] harness shared by the prod pipeline and the demo
/// fake, so both environments genuinely exercise spawn, cross-isolate update
/// marshalling, and cancel-kills.
abstract final class DetectionWorkerChannel {
  /// Grace period for a terminal update already in flight when the worker's
  /// exit notification lands first (cross-port ordering is not guaranteed).
  static const Duration _exitGrace = Duration(milliseconds: 50);

  /// Spawns [entrypoint] and streams its updates.
  ///
  /// Returns a **cold**, single-subscription stream:
  /// - listening spawns the worker isolate;
  /// - a terminal `completed` / `failed` update closes the stream;
  /// - cancelling the subscription kills the worker
  ///   ([Isolate.kill] at immediate priority) — cancellation is silent,
  ///   never a [Failure];
  /// - an uncaught worker error or a premature worker exit surfaces as a
  ///   single `failed(Failure.detectionFailed(...))` update;
  /// - [DetectionWorkerLog] messages are passed to [onLog] (dropped when
  ///   null) and never affect the update stream.
  static Stream<DetectionUpdate> run({
    required DetectionWorkerEntrypoint entrypoint,
    required CapturePayload payload,
    Object? config,
    void Function(String message)? onLog,
  }) {
    late StreamController<DetectionUpdate> controller;
    ReceivePort? updates;
    ReceivePort? errors;
    ReceivePort? exits;
    Isolate? isolate;
    Timer? exitGraceTimer;
    var finished = false;

    void finish(DetectionUpdate update) {
      if (finished || controller.isClosed) return;
      finished = true;
      controller.add(update);
      unawaited(controller.close());
    }

    Future<void> start() async {
      updates = ReceivePort()
        ..listen((message) {
          if (finished || controller.isClosed) return;
          if (message is DetectionWorkerLog) {
            onLog?.call(message.message);
          } else if (message is DetectionCompletedUpdate ||
              message is DetectionFailedUpdate) {
            finish(message as DetectionUpdate);
          } else if (message is DetectionUpdate) {
            controller.add(message);
          }
        });
      errors = ReceivePort()
        ..listen((message) {
          // Uncaught worker error: [error, stackTrace] strings.
          final description = message is List && message.isNotEmpty
              ? '${message.first}'
              : '$message';
          finish(DetectionUpdate.failed(Failure.detectionFailed(description)));
        });
      exits = ReceivePort()
        ..listen((_) {
          // The worker exited. Its terminal update may still be in flight on
          // the update port, so give it a beat before declaring failure.
          if (finished || controller.isClosed) return;
          exitGraceTimer = Timer(_exitGrace, () {
            finish(
              const DetectionUpdate.failed(
                Failure.detectionFailed('detection-worker-exited-early'),
              ),
            );
          });
        });

      try {
        isolate = await Isolate.spawn<DetectionWorkerRequest>(
          entrypoint,
          DetectionWorkerRequest(
            sendPort: updates!.sendPort,
            payload: payload,
            config: config,
          ),
          onError: errors!.sendPort,
          onExit: exits!.sendPort,
          debugName: 'tile-detection-worker',
        );
      } on Object catch (error) {
        finish(DetectionUpdate.failed(Failure.detectionFailed('$error')));
      }
    }

    void stop() {
      finished = true;
      exitGraceTimer?.cancel();
      updates?.close();
      errors?.close();
      exits?.close();
      // Killing an already-terminated isolate is a harmless no-op; killing a
      // live one is the cancellation contract (abort mid-pipeline).
      isolate?.kill(priority: Isolate.immediate);
    }

    controller = StreamController<DetectionUpdate>(
      onListen: start,
      onCancel: stop,
    );
    return controller.stream;
  }
}
