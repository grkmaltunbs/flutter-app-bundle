/// Tunable, non-secret configuration for the Gemini-backed tile detector.
///
/// Lives in `core/env` alongside the app flavor because these are compile-time
/// knobs, not runtime state. **No API key lives here:** Firebase AI
/// Logic brokers auth through the initialized Firebase app, so the app ships no
/// Gemini key to extract.
abstract final class GeminiConfig {
  const GeminiConfig._();

  /// The Gemini model id — Gemini 3.1 Flash-Lite: multimodal, low-latency, and
  /// optimized for lightweight extraction. If generation calls fail with a
  /// "model not found", confirm the exact string against the Firebase AI Logic
  /// "supported models" list.
  static const String modelId = 'gemini-3.1-flash-lite';

  /// Use the Vertex AI backend (stronger data governance — no training on app
  /// data) rather than the Gemini Developer API backend. One-line toggle; both
  /// run through Firebase AI Logic.
  static const bool useVertexBackend = true;

  /// Vertex AI location. On the Vertex backend, all Gemini 2.5+ preview models
  /// released after June 2025 (Flash-Lite included) live ONLY in `global` — the
  /// `firebase_ai` default of `us-central1` returns "model not found". Ignored
  /// by the Gemini Developer API backend.
  static const String vertexLocation = 'global';

  /// Longest-edge cap applied to the rack photo before upload. Lower is cheaper
  /// and faster; higher reads fine digits/colors better. Tunable live in the
  /// detection lab to find the accuracy floor.
  static const int maxImageDimension = 768;

  /// JPEG quality (0–100) used when re-encoding the downscaled rack.
  static const int jpegQuality = 85;

  /// Hard ceiling on a single detection request before it fails as transient.
  static const Duration requestTimeout = Duration(seconds: 30);
}
