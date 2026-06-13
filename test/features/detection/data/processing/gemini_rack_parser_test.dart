import 'package:flutter_test/flutter_test.dart';
import 'package:okey_acar_mi/core/error/failure.dart';
import 'package:okey_acar_mi/core/game/tile_color.dart';
import 'package:okey_acar_mi/features/detection/data/processing/gemini_rack_parser.dart';
import 'package:okey_acar_mi/features/detection/domain/entities/detected_tile.dart';

void main() {
  group('GeminiRackParser.parse', () {
    test('maps a two-row rack with numbers, false joker, and face-down', () {
      const json =
          '{"rows":['
          '[{"kind":"numbered","color":"red","number":5,"confidence":0.9},'
          '{"kind":"false_joker","confidence":0.8}],'
          '[{"kind":"numbered","color":"blue","number":12,"confidence":0.7},'
          '{"kind":"face_down"}]'
          ']}';

      final tiles = GeminiRackParser.parse(json);
      expect(tiles, hasLength(4));

      // row 0, index 0 — red 5
      expect(tiles[0].color, TileColor.red);
      expect(tiles[0].number, 5);
      expect(tiles[0].position.row, 0);
      expect(tiles[0].position.index, 0);
      expect(tiles[0].confidence, 0.9);
      expect(tiles[0].bounds, isNull);

      // row 0, index 1 — false joker → wild
      expect(tiles[1].color, TileColor.joker);
      expect(tiles[1].number, isNull);
      expect(tiles[1].position.index, 1);

      // row 1, index 0 — blue 12
      expect(tiles[2].color, TileColor.blue);
      expect(tiles[2].number, 12);
      expect(tiles[2].position.row, 1);
      expect(tiles[2].position.index, 0);

      // row 1, index 1 — face-down → wild (okey by tradition)
      expect(tiles[3].color, TileColor.joker);
      expect(tiles[3].number, isNull);
      expect(tiles[3].position.row, 1);
      expect(tiles[3].position.index, 1);
    });

    test('all four colors map correctly', () {
      const json =
          '{"rows":[['
          '{"kind":"numbered","color":"red","number":1},'
          '{"kind":"numbered","color":"black","number":2},'
          '{"kind":"numbered","color":"yellow","number":3},'
          '{"kind":"numbered","color":"blue","number":4}]]}';

      final tiles = GeminiRackParser.parse(json);
      expect(
        tiles.map((t) => t.color),
        [TileColor.red, TileColor.black, TileColor.yellow, TileColor.blue],
      );
    });

    test('out-of-range numbered tile becomes a low-confidence joker', () {
      const json = '{"rows":[[{"kind":"numbered","color":"red","number":14}]]}';

      final tiles = GeminiRackParser.parse(json);
      expect(tiles, hasLength(1));
      expect(tiles.single.color, TileColor.joker);
      expect(tiles.single.number, isNull);
      expect(tiles.single.confidence, lessThan(kLowConfidenceThreshold));
    });

    test('numbered tile missing its color becomes a joker candidate', () {
      const json = '{"rows":[[{"kind":"numbered","number":5}]]}';

      final tiles = GeminiRackParser.parse(json);
      expect(tiles.single.color, TileColor.joker);
      expect(tiles.single.number, isNull);
    });

    test('confidence defaults when the field is omitted', () {
      const json =
          '{"rows":[[{"kind":"numbered","color":"black","number":3}]]}';

      final tiles = GeminiRackParser.parse(json);
      expect(tiles.single.confidence, 0.8);
    });

    test('confidence is clamped to 0..1', () {
      const json = '{"rows":[[{"kind":"face_down","confidence":4}]]}';

      final tiles = GeminiRackParser.parse(json);
      expect(tiles.single.confidence, 1.0);
    });

    test('an empty rack throws noTilesDetected', () {
      expect(
        () => GeminiRackParser.parse('{"rows":[]}'),
        throwsA(isA<NoTilesDetectedFailure>()),
      );
      expect(
        () => GeminiRackParser.parse('{"rows":[[],[]]}'),
        throwsA(isA<NoTilesDetectedFailure>()),
      );
    });

    test('malformed JSON throws detectionFailed', () {
      expect(
        () => GeminiRackParser.parse('not json at all'),
        throwsA(isA<DetectionFailedFailure>()),
      );
    });

    test('a missing rows key throws detectionFailed', () {
      expect(
        () => GeminiRackParser.parse('{"tiles":1}'),
        throwsA(isA<DetectionFailedFailure>()),
      );
    });
  });
}
