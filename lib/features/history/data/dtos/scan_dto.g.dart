// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'scan_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ScanDto _$ScanDtoFromJson(Map<String, dynamic> json) => ScanDto(
  id: json['id'] as String,
  ownerId: json['ownerId'] as String?,
  createdAtMs: (json['createdAtMs'] as num).toInt(),
  updatedAtMs: (json['updatedAtMs'] as num).toInt(),
  gameMode: json['gameMode'] as String,
  indicator: ScanIndicatorDto.fromJson(
    json['indicator'] as Map<String, dynamic>,
  ),
  tiles: (json['tiles'] as List<dynamic>)
      .map((e) => ScanTileDto.fromJson(e as Map<String, dynamic>))
      .toList(),
  summary: ScanSummaryDto.fromJson(json['summary'] as Map<String, dynamic>),
  schemaVersion: (json['schemaVersion'] as num?)?.toInt() ?? 1,
);

Map<String, dynamic> _$ScanDtoToJson(ScanDto instance) => <String, dynamic>{
  'ownerId': instance.ownerId,
  'createdAtMs': instance.createdAtMs,
  'updatedAtMs': instance.updatedAtMs,
  'gameMode': instance.gameMode,
  'indicator': instance.indicator.toJson(),
  'tiles': instance.tiles.map((e) => e.toJson()).toList(),
  'summary': instance.summary.toJson(),
  'schemaVersion': instance.schemaVersion,
};

ScanIndicatorDto _$ScanIndicatorDtoFromJson(Map<String, dynamic> json) =>
    ScanIndicatorDto(
      color: json['color'] as String,
      number: (json['number'] as num).toInt(),
    );

Map<String, dynamic> _$ScanIndicatorDtoToJson(ScanIndicatorDto instance) =>
    <String, dynamic>{'color': instance.color, 'number': instance.number};

ScanTileDto _$ScanTileDtoFromJson(Map<String, dynamic> json) =>
    ScanTileDto(c: json['c'] as String, n: (json['n'] as num?)?.toInt());

Map<String, dynamic> _$ScanTileDtoToJson(ScanTileDto instance) =>
    <String, dynamic>{'c': instance.c, 'n': ?instance.n};

ScanSummaryDto _$ScanSummaryDtoFromJson(Map<String, dynamic> json) =>
    ScanSummaryDto(
      kind: json['kind'] as String,
      opened: json['opened'] as bool,
      score: (json['score'] as num).toInt(),
      openPath: json['openPath'] as String?,
      pointsShort: (json['pointsShort'] as num?)?.toInt(),
      tilesToWin: (json['tilesToWin'] as num?)?.toInt(),
      okeyPath: json['okeyPath'] as String?,
    );

Map<String, dynamic> _$ScanSummaryDtoToJson(ScanSummaryDto instance) =>
    <String, dynamic>{
      'kind': instance.kind,
      'opened': instance.opened,
      'score': instance.score,
      'openPath': ?instance.openPath,
      'pointsShort': ?instance.pointsShort,
      'tilesToWin': ?instance.tilesToWin,
      'okeyPath': ?instance.okeyPath,
    };
