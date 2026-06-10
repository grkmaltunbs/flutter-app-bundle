import 'package:flutter/widgets.dart';

/// Renders the camera viewfinder surface for the capture screen.
///
/// Split from `CaptureRepository` (D2) so the domain contract stays pure
/// Dart: the same concrete service implements both interfaces per
/// environment — a live `CameraPreview` in prod, a seeded fixture image in
/// the demo flavor.
abstract class ViewfinderService {
  /// Whether this service renders a real live preview (prod) as opposed to a
  /// static stand-in (demo fake).
  bool get hasLivePreview;

  /// Builds the full-bleed viewfinder widget.
  ///
  /// Renders a plain black surface while the camera is not initialized, so
  /// callers can embed it unconditionally.
  Widget buildViewfinder(BuildContext context);
}
