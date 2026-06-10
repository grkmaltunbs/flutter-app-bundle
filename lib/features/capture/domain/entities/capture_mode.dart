/// The capture mode selected in the camera UI's mode toggle.
enum CaptureMode {
  /// Single still photo via the shutter.
  photo,

  /// Timed still-burst presented as "recording" (no real video, no audio).
  video,

  /// Import a single image from the system photo library.
  gallery,
}
