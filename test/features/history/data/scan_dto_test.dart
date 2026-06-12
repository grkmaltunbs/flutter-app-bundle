import 'dart:convert';

import 'package:checks/checks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:okey_acar_mi/core/game/game_mode.dart';
import 'package:okey_acar_mi/core/game/game_tile.dart';
import 'package:okey_acar_mi/core/game/indicator.dart';
import 'package:okey_acar_mi/core/game/tile_color.dart';
import 'package:okey_acar_mi/features/history/data/dtos/scan_dto.dart';
import 'package:okey_acar_mi/features/history/domain/entities/scan.dart';
import 'package:okey_acar_mi/features/history/domain/entities/scan_summary.dart';
import 'package:okey_acar_mi/features/solver/domain/entities/solve_verdict.dart';

const GameTile _joker = GameTile(color: TileColor.joker);

GameTile _t(TileColor color, int number) =>
    GameTile(color: color, number: number);

Scan _scan({
  required ScanSummary summary,
  GameMode mode = GameMode.oneZeroOne,
}) => Scan(
  id: 'scan-1',
  ownerId: 'demo-oyuncu',
  createdAt: DateTime.utc(2026, 6, 11, 14, 30),
  updatedAt: DateTime.utc(2026, 6, 11, 15),
  tiles: [_t(TileColor.red, 5), _t(TileColor.blue, 13), _joker],
  indicator: const Indicator(color: TileColor.yellow, number: 13),
  gameMode: mode,
  summary: summary,
);

const ScanSummary _opens = ScanSummary(
  kind: ScanVerdictKind.opens101,
  opened: true,
  score: 104,
  openPath: OpenPath.melds,
);

const ScanSummary _closes = ScanSummary(
  kind: ScanVerdictKind.doesNotOpen101,
  opened: false,
  score: 60,
  pointsShort: 41,
);

const ScanSummary _okey = ScanSummary(
  kind: ScanVerdictKind.okeyOutcome,
  opened: true,
  score: 24,
  tilesToWin: 0,
  okeyPath: OkeyPath.sevenPairs,
);

/// Full wire cycle: entity → dto → doc json → (string) → dto → entity.
Scan _roundTrip(Scan scan) {
  final dto = ScanDto.fromEntity(scan);
  final body = jsonDecode(jsonEncode(dto.toJson())) as Map<String, dynamic>;
  return ScanDto.fromDocument(scan.id, body).toEntity();
}

void main() {
  group('entity ↔ dto ↔ json round-trips', () {
    test('opens101: every field survives, incl. the joker tile', () {
      final scan = _scan(summary: _opens);
      check(_roundTrip(scan)).equals(scan);
    });

    test('doesNotOpen101: pointsShort survives, path fields stay null', () {
      final scan = _scan(summary: _closes);
      final back = _roundTrip(scan);
      check(back).equals(scan);
      check(back.summary.pointsShort).equals(41);
      check(back.summary.openPath).isNull();
      check(back.summary.tilesToWin).isNull();
      check(back.summary.okeyPath).isNull();
    });

    test('okeyOutcome: tilesToWin + okeyPath survive', () {
      final scan = _scan(summary: _okey, mode: GameMode.okey);
      final back = _roundTrip(scan);
      check(back).equals(scan);
      check(back.summary.tilesToWin).equals(0);
      check(back.summary.okeyPath).equals(OkeyPath.sevenPairs);
    });

    test('the doc body carries schemaVersion and never the id', () {
      final json = ScanDto.fromEntity(_scan(summary: _opens)).toJson();

      check(json['schemaVersion']).equals(1);
      check(json.containsKey('id')).isFalse();
    });

    test('a joker tile is encoded without an "n" key; null summary fields '
        'are omitted from the doc body', () {
      final json = ScanDto.fromEntity(_scan(summary: _opens)).toJson();

      final tiles = json['tiles'] as List<dynamic>;
      check((tiles[2] as Map<String, dynamic>).containsKey('n')).isFalse();
      check((tiles[0] as Map<String, dynamic>)['n']).equals(5);

      final summary = json['summary'] as Map<String, dynamic>;
      check(summary.containsKey('openPath')).isTrue();
      check(summary.containsKey('pointsShort')).isFalse();
      check(summary.containsKey('tilesToWin')).isFalse();
      check(summary.containsKey('okeyPath')).isFalse();
    });

    test('timestamps round-trip as epoch ms UTC', () {
      final dto = ScanDto.fromEntity(_scan(summary: _opens));
      check(
        dto.createdAtMs,
      ).equals(DateTime.utc(2026, 6, 11, 14, 30).millisecondsSinceEpoch);
      final back = dto.toEntity();
      check(back.createdAt.isUtc).isTrue();
      check(back.updatedAt).equals(DateTime.utc(2026, 6, 11, 15));
    });
  });

  group('encodeTiles / decodeTiles', () {
    test('round-trips a mixed rack incl. the joker', () {
      final tiles = [
        _t(TileColor.red, 1),
        _t(TileColor.black, 13),
        _joker,
        _t(TileColor.yellow, 7),
      ];

      check(ScanDto.decodeTiles(ScanDto.encodeTiles(tiles))).deepEquals(tiles);
    });

    test('encodes the documented compact shape', () {
      check(
        ScanDto.encodeTiles([_t(TileColor.red, 5), _joker]),
      ).equals('[{"c":"red","n":5},{"c":"joker"}]');
    });
  });

  group('malformed input → FormatException', () {
    test('decodeTiles: invalid JSON', () {
      check(() => ScanDto.decodeTiles('not-json')).throws<FormatException>();
    });

    test('decodeTiles: a JSON object instead of an array', () {
      check(() => ScanDto.decodeTiles('{"c":"red"}')).throws<FormatException>();
    });

    test('decodeTiles: a non-object array entry', () {
      check(() => ScanDto.decodeTiles('[5]')).throws<FormatException>();
    });

    test('decodeTiles: a numbered color without a number', () {
      check(
        () => ScanDto.decodeTiles('[{"c":"red"}]'),
      ).throws<FormatException>();
    });

    test('decodeTiles: a joker carrying a number', () {
      check(
        () => ScanDto.decodeTiles('[{"c":"joker","n":3}]'),
      ).throws<FormatException>();
    });

    test('decodeTiles: a number out of the 1–13 range', () {
      check(
        () => ScanDto.decodeTiles('[{"c":"red","n":14}]'),
      ).throws<FormatException>();
      check(
        () => ScanDto.decodeTiles('[{"c":"red","n":0}]'),
      ).throws<FormatException>();
    });

    test('decodeTiles: an unknown color name', () {
      check(
        () => ScanDto.decodeTiles('[{"c":"purple","n":3}]'),
      ).throws<FormatException>();
    });

    Map<String, dynamic> validBody() =>
        ScanDto.fromEntity(_scan(summary: _opens)).toJson();

    test('toEntity: an unknown gameMode name', () {
      final dto = ScanDto.fromDocument(
        'x',
        validBody()..['gameMode'] = 'chess',
      );
      check(dto.toEntity).throws<FormatException>();
    });

    test('toEntity: a joker indicator is rejected', () {
      final dto = ScanDto.fromDocument(
        'x',
        validBody()..['indicator'] = {'color': 'joker', 'number': 5},
      );
      check(dto.toEntity).throws<FormatException>();
    });

    test('toEntity: an indicator number out of range', () {
      final dto = ScanDto.fromDocument(
        'x',
        validBody()..['indicator'] = {'color': 'red', 'number': 0},
      );
      check(dto.toEntity).throws<FormatException>();
    });

    test('toEntity: an unknown verdict kind', () {
      final body = validBody();
      (body['summary'] as Map<String, dynamic>)['kind'] = 'wins';
      check(ScanDto.fromDocument('x', body).toEntity).throws<FormatException>();
    });

    test('toEntity: an unknown openPath name', () {
      final body = validBody();
      (body['summary'] as Map<String, dynamic>)['openPath'] = 'magic';
      check(ScanDto.fromDocument('x', body).toEntity).throws<FormatException>();
    });

    test('fromDocument wraps non-FormatException decode errors (wrong field '
        'type) into FormatException', () {
      check(
        () => ScanDto.fromDocument(
          'x',
          validBody()..['createdAtMs'] = 'yesterday',
        ),
      ).throws<FormatException>();
    });

    test(
      'fromDocument surfaces a missing required field as FormatException',
      () {
        check(
          () => ScanDto.fromDocument('x', validBody()..remove('summary')),
        ).throws<FormatException>();
      },
    );
  });
}
