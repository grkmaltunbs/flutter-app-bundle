import 'dart:async';
import 'dart:typed_data';

import 'package:firebase_ai/firebase_ai.dart';
import 'package:okey_acar_mi/core/env/gemini_config.dart';
import 'package:okey_acar_mi/core/error/failure.dart';
import 'package:okey_acar_mi/features/detection/data/services/gemini_rack_schema.dart';

/// Sends a prepared rack JPEG to Gemini and returns the raw structured-JSON
/// text. This seam owns every `firebase_ai` type, so the detector and its tests
/// stay plugin-agnostic.
abstract interface class GeminiClient {
  /// Uploads [jpegBytes] and returns the model's JSON (already constrained to
  /// the rack schema). Throws a typed [Failure] on transport/backend errors.
  Future<String> generateRackJson(Uint8List jpegBytes);
}

/// Firebase AI Logic implementation — the only file that touches `firebase_ai`.
///
/// Constructed only under the `prod` environment (Firebase is initialized just
/// for the prod flavor); the demo flavor uses the seeded fake detector instead.
class FirebaseGeminiClient implements GeminiClient {
  /// Builds the client and its underlying model.
  FirebaseGeminiClient() : _model = _buildModel();

  final GenerativeModel _model;

  static GenerativeModel _buildModel() {
    final ai = GeminiConfig.useVertexBackend
        ? FirebaseAI.vertexAI(location: GeminiConfig.vertexLocation)
        : FirebaseAI.googleAI();
    return ai.generativeModel(
      model: GeminiConfig.modelId,
      systemInstruction: Content.system(GeminiRackSchema.prompt),
      generationConfig: GenerationConfig(
        responseMimeType: 'application/json',
        responseSchema: GeminiRackSchema.schema,
      ),
    );
  }

  static const String _userPrompt =
      'Read every tile on this Okey rack and return them as JSON, grouped by '
      'row (top row first), each row left to right.';

  @override
  Future<String> generateRackJson(Uint8List jpegBytes) async {
    final GenerateContentResponse response;
    try {
      response = await _model
          .generateContent([
            Content.multi([
              const TextPart(_userPrompt),
              InlineDataPart('image/jpeg', jpegBytes),
            ]),
          ])
          .timeout(GeminiConfig.requestTimeout);
    } on TimeoutException {
      throw const Failure.network();
    } on FirebaseAIException catch (e) {
      throw _map(e);
    } on Object catch (e) {
      throw Failure.detectionFailed('gemini-request-failed: $e');
    }

    final text = response.text;
    if (text == null || text.trim().isEmpty) {
      throw const Failure.detectionFailed('gemini-empty-response');
    }
    return text;
  }

  Failure _map(FirebaseAIException e) {
    final message = e.toString().toLowerCase();
    final transient =
        message.contains('network') ||
        message.contains('socket') ||
        message.contains('unavailable') ||
        message.contains('deadline') ||
        message.contains('timeout');
    return transient
        ? const Failure.network()
        : Failure.detectionFailed('gemini: $e');
  }
}
