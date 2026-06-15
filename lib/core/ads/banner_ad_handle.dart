import 'package:flutter/widgets.dart';

/// An opaque handle to a created banner ad.
///
/// The `AdsService` returns one of these so the widget layer never touches the
/// native `BannerAd` directly. The prod impl wraps a real `BannerAd` (+ its
/// `AdWidget`); the demo impl carries nothing and renders a placeholder. The
/// owning widget MUST call [dispose] when it unmounts.
abstract class BannerAdHandle {
  /// The widget to render for this banner (a real `AdWidget` in prod, a
  /// placeholder in demo).
  Widget build(BuildContext context);

  /// Releases the underlying native ad. Idempotent.
  void dispose();
}
