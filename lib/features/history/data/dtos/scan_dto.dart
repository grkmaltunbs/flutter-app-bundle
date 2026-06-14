import 'dart:convert';

import 'package:json_annotation/json_annotation.dart';
import 'package:okey_acar_mi/core/game/game_mode.dart';
import 'package:okey_acar_mi/core/game/game_tile.dart';
import 'package:okey_acar_mi/core/game/indicator.dart';
import 'package:okey_acar_mi/core/game/tile_color.dart';
import 'package:okey_acar_mi/features/history/domain/entities/scan.dart';
import 'package:okey_acar_mi/features/history/domain/entities/scan_summary.dart';
import 'package:okey_acar_mi/features/solver/domain/entities/solve_verdict.dart';

part 'scan_dto.g.dart';

/// Resolves [name] in [values] or throws a [FormatException] — DTO parsing
/// must surface malformed input as [FormatException] so callers can
/// log + skip the record.
T _enumByName<T extends Enum>(List<T> values, String name) {
  for (final value in values) {
    if (value.name == name) return value;
  }
  throw FormatException('Unknown $T value: $name');
}

/// Wire/storage shape of one scan — the Firestore `scans/{id}` doc body and
/// (via [encodeTiles]/[decodeTiles]) the drift `tilesJson` column.
///
/// The document id is the scan [id], carried alongside the body: [toJson]
/// never writes it, and [ScanDto.fromJson] expects callers to inject the doc
/// id under the `id` key (see [ScanDto.fromDocument]). Malformed input
/// throws [FormatException]; callers log + skip.
@JsonSerializable(explicitToJson: true)
class ScanDto {
  /// Creates a [ScanDto].
  const ScanDto({
    required this.id,
    required this.ownerId,
    required this.createdAtMs,
    required this.updatedAtMs,
    required this.gameMode,
    required this.tiles,
    required this.summary,
    this.indicator,
    this.schemaVersion = 1,
  });

  /// Decodes a doc body [json] that already carries the `id` key.
  factory ScanDto.fromJson(Map<String, dynamic> json) =>
      _$ScanDtoFromJson(json);

  /// Decodes a Firestore document: [id] is the doc id, [data] the body.
  ///
  /// Throws [FormatException] on any malformed content (including wrong
  /// field types, which json_serializable reports as other error types).
  factory ScanDto.fromDocument(String id, Map<String, dynamic> data) {
    try {
      return ScanDto.fromJson(<String, dynamic>{...data, 'id': id});
    } on FormatException {
      rethrow;
    } on Object catch (error) {
      throw FormatException('Malformed scan doc $id: $error');
    }
  }

  /// Maps a domain [Scan] to its wire shape.
  factory ScanDto.fromEntity(Scan scan) {
    final summary = scan.summary;
    return ScanDto(
      id: scan.id,
      ownerId: scan.ownerId,
      createdAtMs: scan.createdAt.toUtc().millisecondsSinceEpoch,
      updatedAtMs: scan.updatedAt.toUtc().millisecondsSinceEpoch,
      gameMode: scan.gameMode.name,
      indicator: switch (scan.indicator) {
        final indicator? => ScanIndicatorDto(
          color: indicator.color.name,
          number: indicator.number,
        ),
        null => null,
      },
      tiles: [for (final tile in scan.tiles) ScanTileDto.fromTile(tile)],
      summary: ScanSummaryDto.fromSummary(summary),
    );
  }

  /// The scan id — the Firestore document id, never stored in the doc body.
  @JsonKey(includeToJson: false)
  final String id;

  /// Owning user id (`null` only for local guest rows; guest scans are
  /// never uploaded).
  final String? ownerId;

  /// Creation instant, epoch milliseconds UTC.
  final int createdAtMs;

  /// Last mutation instant, epoch milliseconds UTC (LWW key).
  final int updatedAtMs;

  /// `GameMode.name` (`oneZeroOne` | `okey`).
  final String gameMode;

  /// The indicator tile, or `null` when none was picked (a face-down tile let
  /// the user skip it).
  @JsonKey(includeIfNull: false)
  final ScanIndicatorDto? indicator;

  /// The rack tiles, in rack order.
  final List<ScanTileDto> tiles;

  /// The solver verdict summary.
  final ScanSummaryDto summary;

  /// Doc schema version, for forward migrations.
  final int schemaVersion;

  /// Encodes [tiles] as the compact JSON array stored in the drift
  /// `tilesJson` column (`[{"c":"red","n":5},{"c":"joker"},…]`).
  static String encodeTiles(List<GameTile> tiles) => jsonEncode([
    for (final tile in tiles) ScanTileDto.fromTile(tile).toJson(),
  ]);

  /// Decodes a [encodeTiles]-produced [json] back into rack tiles.
  ///
  /// Throws [FormatException] on malformed input.
  static List<GameTile> decodeTiles(String json) {
    final Object? decoded;
    try {
      decoded = jsonDecode(json);
    } on FormatException {
      rethrow;
    }
    if (decoded is! List) {
      throw const FormatException('tilesJson is not a JSON array');
    }
    return [
      for (final entry in decoded)
        if (entry is Map<String, dynamic>)
          _tileDtoToTile(ScanTileDto.fromJson(entry))
        else
          throw const FormatException('tilesJson entry is not an object'),
    ];
  }

  /// Maps this DTO back to the domain entity.
  ///
  /// Throws [FormatException] when enum names, numbers, or the tile/joker
  /// invariants are out of range.
  Scan toEntity() {
    final indicatorDto = indicator;
    Indicator? parsedIndicator;
    if (indicatorDto != null) {
      final indicatorColor = _enumByName(TileColor.values, indicatorDto.color);
      if (indicatorColor == TileColor.joker ||
          indicatorDto.number < 1 ||
          indicatorDto.number > 13) {
        throw FormatException(
          'Malformed indicator: ${indicatorDto.color} ${indicatorDto.number}',
        );
      }
      parsedIndicator = Indicator(
        color: indicatorColor,
        number: indicatorDto.number,
      );
    }
    return Scan(
      id: id,
      ownerId: ownerId,
      createdAt: DateTime.fromMillisecondsSinceEpoch(createdAtMs, isUtc: true),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(updatedAtMs, isUtc: true),
      tiles: [for (final tile in tiles) _tileDtoToTile(tile)],
      indicator: parsedIndicator,
      gameMode: _enumByName(GameMode.values, gameMode),
      summary: summary.toSummary(),
    );
  }

  /// Encodes the doc body (without the id).
  Map<String, dynamic> toJson() => _$ScanDtoToJson(this);

  static GameTile _tileDtoToTile(ScanTileDto dto) {
    final color = _enumByName(TileColor.values, dto.c);
    final number = dto.n;
    final faceDown = dto.faceDown ?? false;
    if ((color == TileColor.joker) != (number == null) ||
        (number != null && (number < 1 || number > 13)) ||
        (faceDown && color != TileColor.joker)) {
      throw FormatException('Malformed tile: ${dto.c} ${dto.n}');
    }
    return GameTile(color: color, number: number, faceDown: faceDown);
  }
}

/// Wire shape of the indicator tile.
@JsonSerializable()
class ScanIndicatorDto {
  /// Creates a [ScanIndicatorDto].
  const ScanIndicatorDto({required this.color, required this.number});

  /// Decodes [json].
  factory ScanIndicatorDto.fromJson(Map<String, dynamic> json) =>
      _$ScanIndicatorDtoFromJson(json);

  /// `TileColor.name` of the indicator.
  final String color;

  /// Indicator number (1–13).
  final int number;

  /// Encodes this indicator.
  Map<String, dynamic> toJson() => _$ScanIndicatorDtoToJson(this);
}

/// Wire shape of one rack tile: `c` = `TileColor.name`, `n` = number or
/// absent for the joker.
@JsonSerializable()
class ScanTileDto {
  /// Creates a [ScanTileDto].
  const ScanTileDto({required this.c, this.n, this.faceDown});

  /// Decodes [json].
  factory ScanTileDto.fromJson(Map<String, dynamic> json) =>
      _$ScanTileDtoFromJson(json);

  /// Maps a domain tile to its wire shape. Only a face-down joker writes the
  /// `fd` flag (omitted otherwise, keeping the array compact).
  factory ScanTileDto.fromTile(GameTile tile) => ScanTileDto(
    c: tile.color.name,
    n: tile.number,
    faceDown: tile.faceDown ? true : null,
  );

  /// `TileColor.name` of the tile.
  final String c;

  /// Tile number (1–13), or `null` for the joker.
  @JsonKey(includeIfNull: false)
  final int? n;

  /// Whether this is a face-down (wild) joker; `null`/absent means a regular
  /// tile or a sahte okey (false joker).
  @JsonKey(name: 'fd', includeIfNull: false)
  final bool? faceDown;

  /// Encodes this tile.
  Map<String, dynamic> toJson() => _$ScanTileDtoToJson(this);
}

/// Wire shape of a [ScanSummary].
@JsonSerializable()
class ScanSummaryDto {
  /// Creates a [ScanSummaryDto].
  const ScanSummaryDto({
    required this.kind,
    required this.opened,
    required this.score,
    this.openPath,
    this.pointsShort,
    this.tilesToWin,
    this.okeyPath,
  });

  /// Decodes [json].
  factory ScanSummaryDto.fromJson(Map<String, dynamic> json) =>
      _$ScanSummaryDtoFromJson(json);

  /// Maps a domain [summary] to its wire shape.
  factory ScanSummaryDto.fromSummary(ScanSummary summary) => ScanSummaryDto(
    kind: summary.kind.name,
    opened: summary.opened,
    score: summary.score,
    openPath: summary.openPath?.name,
    pointsShort: summary.pointsShort,
    tilesToWin: summary.tilesToWin,
    okeyPath: summary.okeyPath?.name,
  );

  /// `ScanVerdictKind.name` of the verdict.
  final String kind;

  /// Whether the hand opened / was winning.
  final bool opened;

  /// Best meld total.
  final int score;

  /// `OpenPath.name`, when the 101 hand opened.
  @JsonKey(includeIfNull: false)
  final String? openPath;

  /// Points short of 101, when it did not open.
  @JsonKey(includeIfNull: false)
  final int? pointsShort;

  /// Minimum exchanges to an okey win.
  @JsonKey(includeIfNull: false)
  final int? tilesToWin;

  /// `OkeyPath.name` of the okey template.
  @JsonKey(includeIfNull: false)
  final String? okeyPath;

  /// Maps this DTO back to the domain summary.
  ///
  /// Throws [FormatException] on unknown enum names.
  ScanSummary toSummary() => ScanSummary(
    kind: _enumByName(ScanVerdictKind.values, kind),
    opened: opened,
    score: score,
    openPath: openPath == null ? null : _enumByName(OpenPath.values, openPath!),
    pointsShort: pointsShort,
    tilesToWin: tilesToWin,
    okeyPath: okeyPath == null ? null : _enumByName(OkeyPath.values, okeyPath!),
  );

  /// Encodes this summary.
  Map<String, dynamic> toJson() => _$ScanSummaryDtoToJson(this);
}
