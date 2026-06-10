import 'package:freezed_annotation/freezed_annotation.dart';

part 'capture_payload.freezed.dart';

/// Where a still capture came from.
enum CaptureSource {
  /// The in-app camera shutter.
  photo,

  /// The system photo library.
  gallery,
}

/// The result of a capture flow, handed to the analyzing/detection step.
///
/// Game mode is intentionally NOT part of the payload — it lives in
/// `SettingsCubit` and the detection step reads it from there.
@freezed
sealed class CapturePayload with _$CapturePayload {
  /// A single still image at [imagePath], captured from [source] at
  /// [capturedAt] (stamped by the injected `Clock`, never `DateTime.now()`).
  const factory CapturePayload.still({
    required String imagePath,
    required CaptureSource source,
    required DateTime capturedAt,
  }) = StillCapture;

  /// A burst of still frames at [framePaths] (in capture order), finished at
  /// [capturedAt] (stamped by the injected `Clock`).
  const factory CapturePayload.frames({
    required List<String> framePaths,
    required DateTime capturedAt,
  }) = FramesCapture;
}
