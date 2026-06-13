import 'dart:convert';

import 'package:okey_acar_mi/core/error/failure.dart';
import 'package:okey_acar_mi/core/game/tile_color.dart';
import 'package:okey_acar_mi/features/detection/domain/entities/detected_tile.dart';

/// Parses Gemini's structured rack JSON into rack-ordered [DetectedTile]s.
///
/// Pure (no Firebase, no I/O) so it is fully unit-testable. The model is
/// constrained by the response schema, but this layer stays defensive: it
/// tolerates omitted fields and never trusts the model to honor the 1–13 /
/// color invariants.
abstract final class GeminiRackParser {
  const GeminiRackParser._();

  /// Confidence used when the model omits the field on a valid tile.
  static const double _defaultConfidence = 0.8;

  /// Confidence stamped on a "numbered" cell whose color/number was missing or
  /// out of range — emitted as a joker candidate so the slot survives for the
  /// user to correct in review (mirrors the legacy pipeline's "unreadable →
  /// joker candidate" behavior, keeping the tile count stable).
  static const double _salvageConfidence = 0.4;

  /// Parses [jsonText] into tiles in rack order (row 0 left→right, then row 1).
  ///
  /// Throws [Failure.detectionFailed] for malformed/ill-shaped JSON and
  /// [Failure.noTilesDetected] when the rack is empty.
  static List<DetectedTile> parse(String jsonText) {
    final Object? decoded;
    try {
      decoded = jsonDecode(jsonText);
    } on FormatException catch (e) {
      throw Failure.detectionFailed('gemini-json-malformed: $e');
    }
    if (decoded is! Map<String, Object?>) {
      throw const Failure.detectionFailed('gemini-json-not-object');
    }
    final rows = decoded['rows'];
    if (rows is! List) {
      throw const Failure.detectionFailed('gemini-json-missing-rows');
    }

    final tiles = <DetectedTile>[];
    for (var row = 0; row < rows.length; row++) {
      final cells = rows[row];
      if (cells is! List) continue;
      for (var index = 0; index < cells.length; index++) {
        final cell = cells[index];
        if (cell is Map) {
          tiles.add(_toTile(cell.cast<String, Object?>(), row, index));
        }
      }
    }

    if (tiles.isEmpty) throw const Failure.noTilesDetected();
    return tiles;
  }

  static DetectedTile _toTile(Map<String, Object?> cell, int row, int index) {
    final position = TilePosition(row: row, index: index);
    final confidence = _confidence(cell['confidence']);

    switch (cell['kind']) {
      case 'false_joker':
      case 'face_down':
        // Both are wild for the solver — a joker carries no number.
        return DetectedTile(
          color: TileColor.joker,
          position: position,
          confidence: confidence,
        );
      case 'numbered':
      default:
        final color = _color(cell['color']);
        final number = _number(cell['number']);
        if (color != null && number != null) {
          return DetectedTile(
            color: color,
            position: position,
            confidence: confidence,
            number: number,
          );
        }
        // Claimed numbered but unusable → joker candidate (low confidence),
        // preserving the slot for review rather than dropping the tile.
        return DetectedTile(
          color: TileColor.joker,
          position: position,
          confidence: _salvageConfidence,
        );
    }
  }

  static TileColor? _color(Object? raw) => switch (raw) {
    'red' => TileColor.red,
    'black' => TileColor.black,
    'yellow' => TileColor.yellow,
    'blue' => TileColor.blue,
    _ => null,
  };

  static int? _number(Object? raw) {
    final value = switch (raw) {
      final int v => v,
      final num v => v.toInt(),
      final String v => int.tryParse(v),
      _ => null,
    };
    if (value == null || value < 1 || value > 13) return null;
    return value;
  }

  static double _confidence(Object? raw) {
    final value = switch (raw) {
      final num v => v.toDouble(),
      final String v => double.tryParse(v),
      _ => null,
    };
    if (value == null) return _defaultConfidence;
    return value.clamp(0.0, 1.0);
  }
}
