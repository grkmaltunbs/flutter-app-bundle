// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $ScansTable extends Scans with TableInfo<$ScansTable, ScanRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ScansTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ownerIdMeta = const VerificationMeta(
    'ownerId',
  );
  @override
  late final GeneratedColumn<String> ownerId = GeneratedColumn<String>(
    'owner_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMsMeta = const VerificationMeta(
    'createdAtMs',
  );
  @override
  late final GeneratedColumn<int> createdAtMs = GeneratedColumn<int>(
    'created_at_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMsMeta = const VerificationMeta(
    'updatedAtMs',
  );
  @override
  late final GeneratedColumn<int> updatedAtMs = GeneratedColumn<int>(
    'updated_at_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _gameModeMeta = const VerificationMeta(
    'gameMode',
  );
  @override
  late final GeneratedColumn<String> gameMode = GeneratedColumn<String>(
    'game_mode',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _indicatorColorMeta = const VerificationMeta(
    'indicatorColor',
  );
  @override
  late final GeneratedColumn<String> indicatorColor = GeneratedColumn<String>(
    'indicator_color',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _indicatorNumberMeta = const VerificationMeta(
    'indicatorNumber',
  );
  @override
  late final GeneratedColumn<int> indicatorNumber = GeneratedColumn<int>(
    'indicator_number',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tilesJsonMeta = const VerificationMeta(
    'tilesJson',
  );
  @override
  late final GeneratedColumn<String> tilesJson = GeneratedColumn<String>(
    'tiles_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _verdictKindMeta = const VerificationMeta(
    'verdictKind',
  );
  @override
  late final GeneratedColumn<String> verdictKind = GeneratedColumn<String>(
    'verdict_kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _openedMeta = const VerificationMeta('opened');
  @override
  late final GeneratedColumn<bool> opened = GeneratedColumn<bool>(
    'opened',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("opened" IN (0, 1))',
    ),
  );
  static const VerificationMeta _scoreMeta = const VerificationMeta('score');
  @override
  late final GeneratedColumn<int> score = GeneratedColumn<int>(
    'score',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _openPathMeta = const VerificationMeta(
    'openPath',
  );
  @override
  late final GeneratedColumn<String> openPath = GeneratedColumn<String>(
    'open_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _pointsShortMeta = const VerificationMeta(
    'pointsShort',
  );
  @override
  late final GeneratedColumn<int> pointsShort = GeneratedColumn<int>(
    'points_short',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _tilesToWinMeta = const VerificationMeta(
    'tilesToWin',
  );
  @override
  late final GeneratedColumn<int> tilesToWin = GeneratedColumn<int>(
    'tiles_to_win',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _okeyPathMeta = const VerificationMeta(
    'okeyPath',
  );
  @override
  late final GeneratedColumn<String> okeyPath = GeneratedColumn<String>(
    'okey_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _syncStateMeta = const VerificationMeta(
    'syncState',
  );
  @override
  late final GeneratedColumn<String> syncState = GeneratedColumn<String>(
    'sync_state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('localOnly'),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    ownerId,
    createdAtMs,
    updatedAtMs,
    gameMode,
    indicatorColor,
    indicatorNumber,
    tilesJson,
    verdictKind,
    opened,
    score,
    openPath,
    pointsShort,
    tilesToWin,
    okeyPath,
    syncState,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'scans';
  @override
  VerificationContext validateIntegrity(
    Insertable<ScanRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('owner_id')) {
      context.handle(
        _ownerIdMeta,
        ownerId.isAcceptableOrUnknown(data['owner_id']!, _ownerIdMeta),
      );
    }
    if (data.containsKey('created_at_ms')) {
      context.handle(
        _createdAtMsMeta,
        createdAtMs.isAcceptableOrUnknown(
          data['created_at_ms']!,
          _createdAtMsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_createdAtMsMeta);
    }
    if (data.containsKey('updated_at_ms')) {
      context.handle(
        _updatedAtMsMeta,
        updatedAtMs.isAcceptableOrUnknown(
          data['updated_at_ms']!,
          _updatedAtMsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMsMeta);
    }
    if (data.containsKey('game_mode')) {
      context.handle(
        _gameModeMeta,
        gameMode.isAcceptableOrUnknown(data['game_mode']!, _gameModeMeta),
      );
    } else if (isInserting) {
      context.missing(_gameModeMeta);
    }
    if (data.containsKey('indicator_color')) {
      context.handle(
        _indicatorColorMeta,
        indicatorColor.isAcceptableOrUnknown(
          data['indicator_color']!,
          _indicatorColorMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_indicatorColorMeta);
    }
    if (data.containsKey('indicator_number')) {
      context.handle(
        _indicatorNumberMeta,
        indicatorNumber.isAcceptableOrUnknown(
          data['indicator_number']!,
          _indicatorNumberMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_indicatorNumberMeta);
    }
    if (data.containsKey('tiles_json')) {
      context.handle(
        _tilesJsonMeta,
        tilesJson.isAcceptableOrUnknown(data['tiles_json']!, _tilesJsonMeta),
      );
    } else if (isInserting) {
      context.missing(_tilesJsonMeta);
    }
    if (data.containsKey('verdict_kind')) {
      context.handle(
        _verdictKindMeta,
        verdictKind.isAcceptableOrUnknown(
          data['verdict_kind']!,
          _verdictKindMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_verdictKindMeta);
    }
    if (data.containsKey('opened')) {
      context.handle(
        _openedMeta,
        opened.isAcceptableOrUnknown(data['opened']!, _openedMeta),
      );
    } else if (isInserting) {
      context.missing(_openedMeta);
    }
    if (data.containsKey('score')) {
      context.handle(
        _scoreMeta,
        score.isAcceptableOrUnknown(data['score']!, _scoreMeta),
      );
    } else if (isInserting) {
      context.missing(_scoreMeta);
    }
    if (data.containsKey('open_path')) {
      context.handle(
        _openPathMeta,
        openPath.isAcceptableOrUnknown(data['open_path']!, _openPathMeta),
      );
    }
    if (data.containsKey('points_short')) {
      context.handle(
        _pointsShortMeta,
        pointsShort.isAcceptableOrUnknown(
          data['points_short']!,
          _pointsShortMeta,
        ),
      );
    }
    if (data.containsKey('tiles_to_win')) {
      context.handle(
        _tilesToWinMeta,
        tilesToWin.isAcceptableOrUnknown(
          data['tiles_to_win']!,
          _tilesToWinMeta,
        ),
      );
    }
    if (data.containsKey('okey_path')) {
      context.handle(
        _okeyPathMeta,
        okeyPath.isAcceptableOrUnknown(data['okey_path']!, _okeyPathMeta),
      );
    }
    if (data.containsKey('sync_state')) {
      context.handle(
        _syncStateMeta,
        syncState.isAcceptableOrUnknown(data['sync_state']!, _syncStateMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ScanRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ScanRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      ownerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}owner_id'],
      ),
      createdAtMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at_ms'],
      )!,
      updatedAtMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at_ms'],
      )!,
      gameMode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}game_mode'],
      )!,
      indicatorColor: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}indicator_color'],
      )!,
      indicatorNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}indicator_number'],
      )!,
      tilesJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tiles_json'],
      )!,
      verdictKind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}verdict_kind'],
      )!,
      opened: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}opened'],
      )!,
      score: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}score'],
      )!,
      openPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}open_path'],
      ),
      pointsShort: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}points_short'],
      ),
      tilesToWin: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}tiles_to_win'],
      ),
      okeyPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}okey_path'],
      ),
      syncState: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sync_state'],
      )!,
    );
  }

  @override
  $ScansTable createAlias(String alias) {
    return $ScansTable(attachedDatabase, alias);
  }
}

class ScanRow extends DataClass implements Insertable<ScanRow> {
  /// Scan id (uuid v4) — doubles as the Firestore document id.
  final String id;

  /// Owning user id; `null` for guest-created scans awaiting adoption.
  final String? ownerId;

  /// Creation instant, epoch milliseconds UTC (via the injected `Clock`).
  final int createdAtMs;

  /// Last mutation instant, epoch milliseconds UTC — the last-write-wins key
  /// for remote/local conflict resolution.
  final int updatedAtMs;

  /// `GameMode.name` of the solved mode (`oneZeroOne` | `okey`).
  final String gameMode;

  /// `TileColor.name` of the indicator (gösterge) tile.
  final String indicatorColor;

  /// Number (1–13) of the indicator tile.
  final int indicatorNumber;

  /// Rack-order tile array as JSON: `[{"c":"red","n":5},{"c":"joker"},…]`
  /// (encoded/decoded by `ScanDto`).
  final String tilesJson;

  /// `ScanVerdictKind.name` of the verdict.
  final String verdictKind;

  /// Denormalized filter/stats column: did the hand open (101) or win (okey)?
  final bool opened;

  /// Best meld total (`SolveResult.totalScore`).
  final int score;

  /// `OpenPath.name` for 101 openers, else `null`.
  final String? openPath;

  /// Points short of 101 for non-openers, else `null`.
  final int? pointsShort;

  /// Minimum exchanges to a winning okey hand, else `null`.
  final int? tilesToWin;

  /// `OkeyPath.name` of the okey winning template, else `null`.
  final String? okeyPath;

  /// Sync lifecycle marker (`localOnly` | `pendingUpload` | `synced`).
  final String syncState;
  const ScanRow({
    required this.id,
    this.ownerId,
    required this.createdAtMs,
    required this.updatedAtMs,
    required this.gameMode,
    required this.indicatorColor,
    required this.indicatorNumber,
    required this.tilesJson,
    required this.verdictKind,
    required this.opened,
    required this.score,
    this.openPath,
    this.pointsShort,
    this.tilesToWin,
    this.okeyPath,
    required this.syncState,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || ownerId != null) {
      map['owner_id'] = Variable<String>(ownerId);
    }
    map['created_at_ms'] = Variable<int>(createdAtMs);
    map['updated_at_ms'] = Variable<int>(updatedAtMs);
    map['game_mode'] = Variable<String>(gameMode);
    map['indicator_color'] = Variable<String>(indicatorColor);
    map['indicator_number'] = Variable<int>(indicatorNumber);
    map['tiles_json'] = Variable<String>(tilesJson);
    map['verdict_kind'] = Variable<String>(verdictKind);
    map['opened'] = Variable<bool>(opened);
    map['score'] = Variable<int>(score);
    if (!nullToAbsent || openPath != null) {
      map['open_path'] = Variable<String>(openPath);
    }
    if (!nullToAbsent || pointsShort != null) {
      map['points_short'] = Variable<int>(pointsShort);
    }
    if (!nullToAbsent || tilesToWin != null) {
      map['tiles_to_win'] = Variable<int>(tilesToWin);
    }
    if (!nullToAbsent || okeyPath != null) {
      map['okey_path'] = Variable<String>(okeyPath);
    }
    map['sync_state'] = Variable<String>(syncState);
    return map;
  }

  ScansCompanion toCompanion(bool nullToAbsent) {
    return ScansCompanion(
      id: Value(id),
      ownerId: ownerId == null && nullToAbsent
          ? const Value.absent()
          : Value(ownerId),
      createdAtMs: Value(createdAtMs),
      updatedAtMs: Value(updatedAtMs),
      gameMode: Value(gameMode),
      indicatorColor: Value(indicatorColor),
      indicatorNumber: Value(indicatorNumber),
      tilesJson: Value(tilesJson),
      verdictKind: Value(verdictKind),
      opened: Value(opened),
      score: Value(score),
      openPath: openPath == null && nullToAbsent
          ? const Value.absent()
          : Value(openPath),
      pointsShort: pointsShort == null && nullToAbsent
          ? const Value.absent()
          : Value(pointsShort),
      tilesToWin: tilesToWin == null && nullToAbsent
          ? const Value.absent()
          : Value(tilesToWin),
      okeyPath: okeyPath == null && nullToAbsent
          ? const Value.absent()
          : Value(okeyPath),
      syncState: Value(syncState),
    );
  }

  factory ScanRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ScanRow(
      id: serializer.fromJson<String>(json['id']),
      ownerId: serializer.fromJson<String?>(json['ownerId']),
      createdAtMs: serializer.fromJson<int>(json['createdAtMs']),
      updatedAtMs: serializer.fromJson<int>(json['updatedAtMs']),
      gameMode: serializer.fromJson<String>(json['gameMode']),
      indicatorColor: serializer.fromJson<String>(json['indicatorColor']),
      indicatorNumber: serializer.fromJson<int>(json['indicatorNumber']),
      tilesJson: serializer.fromJson<String>(json['tilesJson']),
      verdictKind: serializer.fromJson<String>(json['verdictKind']),
      opened: serializer.fromJson<bool>(json['opened']),
      score: serializer.fromJson<int>(json['score']),
      openPath: serializer.fromJson<String?>(json['openPath']),
      pointsShort: serializer.fromJson<int?>(json['pointsShort']),
      tilesToWin: serializer.fromJson<int?>(json['tilesToWin']),
      okeyPath: serializer.fromJson<String?>(json['okeyPath']),
      syncState: serializer.fromJson<String>(json['syncState']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'ownerId': serializer.toJson<String?>(ownerId),
      'createdAtMs': serializer.toJson<int>(createdAtMs),
      'updatedAtMs': serializer.toJson<int>(updatedAtMs),
      'gameMode': serializer.toJson<String>(gameMode),
      'indicatorColor': serializer.toJson<String>(indicatorColor),
      'indicatorNumber': serializer.toJson<int>(indicatorNumber),
      'tilesJson': serializer.toJson<String>(tilesJson),
      'verdictKind': serializer.toJson<String>(verdictKind),
      'opened': serializer.toJson<bool>(opened),
      'score': serializer.toJson<int>(score),
      'openPath': serializer.toJson<String?>(openPath),
      'pointsShort': serializer.toJson<int?>(pointsShort),
      'tilesToWin': serializer.toJson<int?>(tilesToWin),
      'okeyPath': serializer.toJson<String?>(okeyPath),
      'syncState': serializer.toJson<String>(syncState),
    };
  }

  ScanRow copyWith({
    String? id,
    Value<String?> ownerId = const Value.absent(),
    int? createdAtMs,
    int? updatedAtMs,
    String? gameMode,
    String? indicatorColor,
    int? indicatorNumber,
    String? tilesJson,
    String? verdictKind,
    bool? opened,
    int? score,
    Value<String?> openPath = const Value.absent(),
    Value<int?> pointsShort = const Value.absent(),
    Value<int?> tilesToWin = const Value.absent(),
    Value<String?> okeyPath = const Value.absent(),
    String? syncState,
  }) => ScanRow(
    id: id ?? this.id,
    ownerId: ownerId.present ? ownerId.value : this.ownerId,
    createdAtMs: createdAtMs ?? this.createdAtMs,
    updatedAtMs: updatedAtMs ?? this.updatedAtMs,
    gameMode: gameMode ?? this.gameMode,
    indicatorColor: indicatorColor ?? this.indicatorColor,
    indicatorNumber: indicatorNumber ?? this.indicatorNumber,
    tilesJson: tilesJson ?? this.tilesJson,
    verdictKind: verdictKind ?? this.verdictKind,
    opened: opened ?? this.opened,
    score: score ?? this.score,
    openPath: openPath.present ? openPath.value : this.openPath,
    pointsShort: pointsShort.present ? pointsShort.value : this.pointsShort,
    tilesToWin: tilesToWin.present ? tilesToWin.value : this.tilesToWin,
    okeyPath: okeyPath.present ? okeyPath.value : this.okeyPath,
    syncState: syncState ?? this.syncState,
  );
  ScanRow copyWithCompanion(ScansCompanion data) {
    return ScanRow(
      id: data.id.present ? data.id.value : this.id,
      ownerId: data.ownerId.present ? data.ownerId.value : this.ownerId,
      createdAtMs: data.createdAtMs.present
          ? data.createdAtMs.value
          : this.createdAtMs,
      updatedAtMs: data.updatedAtMs.present
          ? data.updatedAtMs.value
          : this.updatedAtMs,
      gameMode: data.gameMode.present ? data.gameMode.value : this.gameMode,
      indicatorColor: data.indicatorColor.present
          ? data.indicatorColor.value
          : this.indicatorColor,
      indicatorNumber: data.indicatorNumber.present
          ? data.indicatorNumber.value
          : this.indicatorNumber,
      tilesJson: data.tilesJson.present ? data.tilesJson.value : this.tilesJson,
      verdictKind: data.verdictKind.present
          ? data.verdictKind.value
          : this.verdictKind,
      opened: data.opened.present ? data.opened.value : this.opened,
      score: data.score.present ? data.score.value : this.score,
      openPath: data.openPath.present ? data.openPath.value : this.openPath,
      pointsShort: data.pointsShort.present
          ? data.pointsShort.value
          : this.pointsShort,
      tilesToWin: data.tilesToWin.present
          ? data.tilesToWin.value
          : this.tilesToWin,
      okeyPath: data.okeyPath.present ? data.okeyPath.value : this.okeyPath,
      syncState: data.syncState.present ? data.syncState.value : this.syncState,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ScanRow(')
          ..write('id: $id, ')
          ..write('ownerId: $ownerId, ')
          ..write('createdAtMs: $createdAtMs, ')
          ..write('updatedAtMs: $updatedAtMs, ')
          ..write('gameMode: $gameMode, ')
          ..write('indicatorColor: $indicatorColor, ')
          ..write('indicatorNumber: $indicatorNumber, ')
          ..write('tilesJson: $tilesJson, ')
          ..write('verdictKind: $verdictKind, ')
          ..write('opened: $opened, ')
          ..write('score: $score, ')
          ..write('openPath: $openPath, ')
          ..write('pointsShort: $pointsShort, ')
          ..write('tilesToWin: $tilesToWin, ')
          ..write('okeyPath: $okeyPath, ')
          ..write('syncState: $syncState')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    ownerId,
    createdAtMs,
    updatedAtMs,
    gameMode,
    indicatorColor,
    indicatorNumber,
    tilesJson,
    verdictKind,
    opened,
    score,
    openPath,
    pointsShort,
    tilesToWin,
    okeyPath,
    syncState,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ScanRow &&
          other.id == this.id &&
          other.ownerId == this.ownerId &&
          other.createdAtMs == this.createdAtMs &&
          other.updatedAtMs == this.updatedAtMs &&
          other.gameMode == this.gameMode &&
          other.indicatorColor == this.indicatorColor &&
          other.indicatorNumber == this.indicatorNumber &&
          other.tilesJson == this.tilesJson &&
          other.verdictKind == this.verdictKind &&
          other.opened == this.opened &&
          other.score == this.score &&
          other.openPath == this.openPath &&
          other.pointsShort == this.pointsShort &&
          other.tilesToWin == this.tilesToWin &&
          other.okeyPath == this.okeyPath &&
          other.syncState == this.syncState);
}

class ScansCompanion extends UpdateCompanion<ScanRow> {
  final Value<String> id;
  final Value<String?> ownerId;
  final Value<int> createdAtMs;
  final Value<int> updatedAtMs;
  final Value<String> gameMode;
  final Value<String> indicatorColor;
  final Value<int> indicatorNumber;
  final Value<String> tilesJson;
  final Value<String> verdictKind;
  final Value<bool> opened;
  final Value<int> score;
  final Value<String?> openPath;
  final Value<int?> pointsShort;
  final Value<int?> tilesToWin;
  final Value<String?> okeyPath;
  final Value<String> syncState;
  final Value<int> rowid;
  const ScansCompanion({
    this.id = const Value.absent(),
    this.ownerId = const Value.absent(),
    this.createdAtMs = const Value.absent(),
    this.updatedAtMs = const Value.absent(),
    this.gameMode = const Value.absent(),
    this.indicatorColor = const Value.absent(),
    this.indicatorNumber = const Value.absent(),
    this.tilesJson = const Value.absent(),
    this.verdictKind = const Value.absent(),
    this.opened = const Value.absent(),
    this.score = const Value.absent(),
    this.openPath = const Value.absent(),
    this.pointsShort = const Value.absent(),
    this.tilesToWin = const Value.absent(),
    this.okeyPath = const Value.absent(),
    this.syncState = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ScansCompanion.insert({
    required String id,
    this.ownerId = const Value.absent(),
    required int createdAtMs,
    required int updatedAtMs,
    required String gameMode,
    required String indicatorColor,
    required int indicatorNumber,
    required String tilesJson,
    required String verdictKind,
    required bool opened,
    required int score,
    this.openPath = const Value.absent(),
    this.pointsShort = const Value.absent(),
    this.tilesToWin = const Value.absent(),
    this.okeyPath = const Value.absent(),
    this.syncState = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       createdAtMs = Value(createdAtMs),
       updatedAtMs = Value(updatedAtMs),
       gameMode = Value(gameMode),
       indicatorColor = Value(indicatorColor),
       indicatorNumber = Value(indicatorNumber),
       tilesJson = Value(tilesJson),
       verdictKind = Value(verdictKind),
       opened = Value(opened),
       score = Value(score);
  static Insertable<ScanRow> custom({
    Expression<String>? id,
    Expression<String>? ownerId,
    Expression<int>? createdAtMs,
    Expression<int>? updatedAtMs,
    Expression<String>? gameMode,
    Expression<String>? indicatorColor,
    Expression<int>? indicatorNumber,
    Expression<String>? tilesJson,
    Expression<String>? verdictKind,
    Expression<bool>? opened,
    Expression<int>? score,
    Expression<String>? openPath,
    Expression<int>? pointsShort,
    Expression<int>? tilesToWin,
    Expression<String>? okeyPath,
    Expression<String>? syncState,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (ownerId != null) 'owner_id': ownerId,
      if (createdAtMs != null) 'created_at_ms': createdAtMs,
      if (updatedAtMs != null) 'updated_at_ms': updatedAtMs,
      if (gameMode != null) 'game_mode': gameMode,
      if (indicatorColor != null) 'indicator_color': indicatorColor,
      if (indicatorNumber != null) 'indicator_number': indicatorNumber,
      if (tilesJson != null) 'tiles_json': tilesJson,
      if (verdictKind != null) 'verdict_kind': verdictKind,
      if (opened != null) 'opened': opened,
      if (score != null) 'score': score,
      if (openPath != null) 'open_path': openPath,
      if (pointsShort != null) 'points_short': pointsShort,
      if (tilesToWin != null) 'tiles_to_win': tilesToWin,
      if (okeyPath != null) 'okey_path': okeyPath,
      if (syncState != null) 'sync_state': syncState,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ScansCompanion copyWith({
    Value<String>? id,
    Value<String?>? ownerId,
    Value<int>? createdAtMs,
    Value<int>? updatedAtMs,
    Value<String>? gameMode,
    Value<String>? indicatorColor,
    Value<int>? indicatorNumber,
    Value<String>? tilesJson,
    Value<String>? verdictKind,
    Value<bool>? opened,
    Value<int>? score,
    Value<String?>? openPath,
    Value<int?>? pointsShort,
    Value<int?>? tilesToWin,
    Value<String?>? okeyPath,
    Value<String>? syncState,
    Value<int>? rowid,
  }) {
    return ScansCompanion(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      createdAtMs: createdAtMs ?? this.createdAtMs,
      updatedAtMs: updatedAtMs ?? this.updatedAtMs,
      gameMode: gameMode ?? this.gameMode,
      indicatorColor: indicatorColor ?? this.indicatorColor,
      indicatorNumber: indicatorNumber ?? this.indicatorNumber,
      tilesJson: tilesJson ?? this.tilesJson,
      verdictKind: verdictKind ?? this.verdictKind,
      opened: opened ?? this.opened,
      score: score ?? this.score,
      openPath: openPath ?? this.openPath,
      pointsShort: pointsShort ?? this.pointsShort,
      tilesToWin: tilesToWin ?? this.tilesToWin,
      okeyPath: okeyPath ?? this.okeyPath,
      syncState: syncState ?? this.syncState,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (ownerId.present) {
      map['owner_id'] = Variable<String>(ownerId.value);
    }
    if (createdAtMs.present) {
      map['created_at_ms'] = Variable<int>(createdAtMs.value);
    }
    if (updatedAtMs.present) {
      map['updated_at_ms'] = Variable<int>(updatedAtMs.value);
    }
    if (gameMode.present) {
      map['game_mode'] = Variable<String>(gameMode.value);
    }
    if (indicatorColor.present) {
      map['indicator_color'] = Variable<String>(indicatorColor.value);
    }
    if (indicatorNumber.present) {
      map['indicator_number'] = Variable<int>(indicatorNumber.value);
    }
    if (tilesJson.present) {
      map['tiles_json'] = Variable<String>(tilesJson.value);
    }
    if (verdictKind.present) {
      map['verdict_kind'] = Variable<String>(verdictKind.value);
    }
    if (opened.present) {
      map['opened'] = Variable<bool>(opened.value);
    }
    if (score.present) {
      map['score'] = Variable<int>(score.value);
    }
    if (openPath.present) {
      map['open_path'] = Variable<String>(openPath.value);
    }
    if (pointsShort.present) {
      map['points_short'] = Variable<int>(pointsShort.value);
    }
    if (tilesToWin.present) {
      map['tiles_to_win'] = Variable<int>(tilesToWin.value);
    }
    if (okeyPath.present) {
      map['okey_path'] = Variable<String>(okeyPath.value);
    }
    if (syncState.present) {
      map['sync_state'] = Variable<String>(syncState.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ScansCompanion(')
          ..write('id: $id, ')
          ..write('ownerId: $ownerId, ')
          ..write('createdAtMs: $createdAtMs, ')
          ..write('updatedAtMs: $updatedAtMs, ')
          ..write('gameMode: $gameMode, ')
          ..write('indicatorColor: $indicatorColor, ')
          ..write('indicatorNumber: $indicatorNumber, ')
          ..write('tilesJson: $tilesJson, ')
          ..write('verdictKind: $verdictKind, ')
          ..write('opened: $opened, ')
          ..write('score: $score, ')
          ..write('openPath: $openPath, ')
          ..write('pointsShort: $pointsShort, ')
          ..write('tilesToWin: $tilesToWin, ')
          ..write('okeyPath: $okeyPath, ')
          ..write('syncState: $syncState, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PreferencesTable extends Preferences
    with TableInfo<$PreferencesTable, Preference> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PreferencesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueJsonMeta = const VerificationMeta(
    'valueJson',
  );
  @override
  late final GeneratedColumn<String> valueJson = GeneratedColumn<String>(
    'value_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, valueJson];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'preferences';
  @override
  VerificationContext validateIntegrity(
    Insertable<Preference> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value_json')) {
      context.handle(
        _valueJsonMeta,
        valueJson.isAcceptableOrUnknown(data['value_json']!, _valueJsonMeta),
      );
    } else if (isInserting) {
      context.missing(_valueJsonMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  Preference map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Preference(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      valueJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value_json'],
      )!,
    );
  }

  @override
  $PreferencesTable createAlias(String alias) {
    return $PreferencesTable(attachedDatabase, alias);
  }
}

class Preference extends DataClass implements Insertable<Preference> {
  /// Preference key.
  final String key;

  /// JSON-encoded preference value.
  final String valueJson;
  const Preference({required this.key, required this.valueJson});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value_json'] = Variable<String>(valueJson);
    return map;
  }

  PreferencesCompanion toCompanion(bool nullToAbsent) {
    return PreferencesCompanion(key: Value(key), valueJson: Value(valueJson));
  }

  factory Preference.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Preference(
      key: serializer.fromJson<String>(json['key']),
      valueJson: serializer.fromJson<String>(json['valueJson']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'valueJson': serializer.toJson<String>(valueJson),
    };
  }

  Preference copyWith({String? key, String? valueJson}) =>
      Preference(key: key ?? this.key, valueJson: valueJson ?? this.valueJson);
  Preference copyWithCompanion(PreferencesCompanion data) {
    return Preference(
      key: data.key.present ? data.key.value : this.key,
      valueJson: data.valueJson.present ? data.valueJson.value : this.valueJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Preference(')
          ..write('key: $key, ')
          ..write('valueJson: $valueJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, valueJson);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Preference &&
          other.key == this.key &&
          other.valueJson == this.valueJson);
}

class PreferencesCompanion extends UpdateCompanion<Preference> {
  final Value<String> key;
  final Value<String> valueJson;
  final Value<int> rowid;
  const PreferencesCompanion({
    this.key = const Value.absent(),
    this.valueJson = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PreferencesCompanion.insert({
    required String key,
    required String valueJson,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       valueJson = Value(valueJson);
  static Insertable<Preference> custom({
    Expression<String>? key,
    Expression<String>? valueJson,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (valueJson != null) 'value_json': valueJson,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PreferencesCompanion copyWith({
    Value<String>? key,
    Value<String>? valueJson,
    Value<int>? rowid,
  }) {
    return PreferencesCompanion(
      key: key ?? this.key,
      valueJson: valueJson ?? this.valueJson,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (valueJson.present) {
      map['value_json'] = Variable<String>(valueJson.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PreferencesCompanion(')
          ..write('key: $key, ')
          ..write('valueJson: $valueJson, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $ScansTable scans = $ScansTable(this);
  late final $PreferencesTable preferences = $PreferencesTable(this);
  late final Index idxScansOwnerCreated = Index(
    'idx_scans_owner_created',
    'CREATE INDEX idx_scans_owner_created ON scans (owner_id, created_at_ms)',
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    scans,
    preferences,
    idxScansOwnerCreated,
  ];
}

typedef $$ScansTableCreateCompanionBuilder =
    ScansCompanion Function({
      required String id,
      Value<String?> ownerId,
      required int createdAtMs,
      required int updatedAtMs,
      required String gameMode,
      required String indicatorColor,
      required int indicatorNumber,
      required String tilesJson,
      required String verdictKind,
      required bool opened,
      required int score,
      Value<String?> openPath,
      Value<int?> pointsShort,
      Value<int?> tilesToWin,
      Value<String?> okeyPath,
      Value<String> syncState,
      Value<int> rowid,
    });
typedef $$ScansTableUpdateCompanionBuilder =
    ScansCompanion Function({
      Value<String> id,
      Value<String?> ownerId,
      Value<int> createdAtMs,
      Value<int> updatedAtMs,
      Value<String> gameMode,
      Value<String> indicatorColor,
      Value<int> indicatorNumber,
      Value<String> tilesJson,
      Value<String> verdictKind,
      Value<bool> opened,
      Value<int> score,
      Value<String?> openPath,
      Value<int?> pointsShort,
      Value<int?> tilesToWin,
      Value<String?> okeyPath,
      Value<String> syncState,
      Value<int> rowid,
    });

class $$ScansTableFilterComposer extends Composer<_$AppDatabase, $ScansTable> {
  $$ScansTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ownerId => $composableBuilder(
    column: $table.ownerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAtMs => $composableBuilder(
    column: $table.createdAtMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAtMs => $composableBuilder(
    column: $table.updatedAtMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get gameMode => $composableBuilder(
    column: $table.gameMode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get indicatorColor => $composableBuilder(
    column: $table.indicatorColor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get indicatorNumber => $composableBuilder(
    column: $table.indicatorNumber,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tilesJson => $composableBuilder(
    column: $table.tilesJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get verdictKind => $composableBuilder(
    column: $table.verdictKind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get opened => $composableBuilder(
    column: $table.opened,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get score => $composableBuilder(
    column: $table.score,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get openPath => $composableBuilder(
    column: $table.openPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get pointsShort => $composableBuilder(
    column: $table.pointsShort,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get tilesToWin => $composableBuilder(
    column: $table.tilesToWin,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get okeyPath => $composableBuilder(
    column: $table.okeyPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get syncState => $composableBuilder(
    column: $table.syncState,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ScansTableOrderingComposer
    extends Composer<_$AppDatabase, $ScansTable> {
  $$ScansTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ownerId => $composableBuilder(
    column: $table.ownerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAtMs => $composableBuilder(
    column: $table.createdAtMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAtMs => $composableBuilder(
    column: $table.updatedAtMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get gameMode => $composableBuilder(
    column: $table.gameMode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get indicatorColor => $composableBuilder(
    column: $table.indicatorColor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get indicatorNumber => $composableBuilder(
    column: $table.indicatorNumber,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tilesJson => $composableBuilder(
    column: $table.tilesJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get verdictKind => $composableBuilder(
    column: $table.verdictKind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get opened => $composableBuilder(
    column: $table.opened,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get score => $composableBuilder(
    column: $table.score,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get openPath => $composableBuilder(
    column: $table.openPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get pointsShort => $composableBuilder(
    column: $table.pointsShort,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get tilesToWin => $composableBuilder(
    column: $table.tilesToWin,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get okeyPath => $composableBuilder(
    column: $table.okeyPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get syncState => $composableBuilder(
    column: $table.syncState,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ScansTableAnnotationComposer
    extends Composer<_$AppDatabase, $ScansTable> {
  $$ScansTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get ownerId =>
      $composableBuilder(column: $table.ownerId, builder: (column) => column);

  GeneratedColumn<int> get createdAtMs => $composableBuilder(
    column: $table.createdAtMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get updatedAtMs => $composableBuilder(
    column: $table.updatedAtMs,
    builder: (column) => column,
  );

  GeneratedColumn<String> get gameMode =>
      $composableBuilder(column: $table.gameMode, builder: (column) => column);

  GeneratedColumn<String> get indicatorColor => $composableBuilder(
    column: $table.indicatorColor,
    builder: (column) => column,
  );

  GeneratedColumn<int> get indicatorNumber => $composableBuilder(
    column: $table.indicatorNumber,
    builder: (column) => column,
  );

  GeneratedColumn<String> get tilesJson =>
      $composableBuilder(column: $table.tilesJson, builder: (column) => column);

  GeneratedColumn<String> get verdictKind => $composableBuilder(
    column: $table.verdictKind,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get opened =>
      $composableBuilder(column: $table.opened, builder: (column) => column);

  GeneratedColumn<int> get score =>
      $composableBuilder(column: $table.score, builder: (column) => column);

  GeneratedColumn<String> get openPath =>
      $composableBuilder(column: $table.openPath, builder: (column) => column);

  GeneratedColumn<int> get pointsShort => $composableBuilder(
    column: $table.pointsShort,
    builder: (column) => column,
  );

  GeneratedColumn<int> get tilesToWin => $composableBuilder(
    column: $table.tilesToWin,
    builder: (column) => column,
  );

  GeneratedColumn<String> get okeyPath =>
      $composableBuilder(column: $table.okeyPath, builder: (column) => column);

  GeneratedColumn<String> get syncState =>
      $composableBuilder(column: $table.syncState, builder: (column) => column);
}

class $$ScansTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ScansTable,
          ScanRow,
          $$ScansTableFilterComposer,
          $$ScansTableOrderingComposer,
          $$ScansTableAnnotationComposer,
          $$ScansTableCreateCompanionBuilder,
          $$ScansTableUpdateCompanionBuilder,
          (ScanRow, BaseReferences<_$AppDatabase, $ScansTable, ScanRow>),
          ScanRow,
          PrefetchHooks Function()
        > {
  $$ScansTableTableManager(_$AppDatabase db, $ScansTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ScansTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ScansTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ScansTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String?> ownerId = const Value.absent(),
                Value<int> createdAtMs = const Value.absent(),
                Value<int> updatedAtMs = const Value.absent(),
                Value<String> gameMode = const Value.absent(),
                Value<String> indicatorColor = const Value.absent(),
                Value<int> indicatorNumber = const Value.absent(),
                Value<String> tilesJson = const Value.absent(),
                Value<String> verdictKind = const Value.absent(),
                Value<bool> opened = const Value.absent(),
                Value<int> score = const Value.absent(),
                Value<String?> openPath = const Value.absent(),
                Value<int?> pointsShort = const Value.absent(),
                Value<int?> tilesToWin = const Value.absent(),
                Value<String?> okeyPath = const Value.absent(),
                Value<String> syncState = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ScansCompanion(
                id: id,
                ownerId: ownerId,
                createdAtMs: createdAtMs,
                updatedAtMs: updatedAtMs,
                gameMode: gameMode,
                indicatorColor: indicatorColor,
                indicatorNumber: indicatorNumber,
                tilesJson: tilesJson,
                verdictKind: verdictKind,
                opened: opened,
                score: score,
                openPath: openPath,
                pointsShort: pointsShort,
                tilesToWin: tilesToWin,
                okeyPath: okeyPath,
                syncState: syncState,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String?> ownerId = const Value.absent(),
                required int createdAtMs,
                required int updatedAtMs,
                required String gameMode,
                required String indicatorColor,
                required int indicatorNumber,
                required String tilesJson,
                required String verdictKind,
                required bool opened,
                required int score,
                Value<String?> openPath = const Value.absent(),
                Value<int?> pointsShort = const Value.absent(),
                Value<int?> tilesToWin = const Value.absent(),
                Value<String?> okeyPath = const Value.absent(),
                Value<String> syncState = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ScansCompanion.insert(
                id: id,
                ownerId: ownerId,
                createdAtMs: createdAtMs,
                updatedAtMs: updatedAtMs,
                gameMode: gameMode,
                indicatorColor: indicatorColor,
                indicatorNumber: indicatorNumber,
                tilesJson: tilesJson,
                verdictKind: verdictKind,
                opened: opened,
                score: score,
                openPath: openPath,
                pointsShort: pointsShort,
                tilesToWin: tilesToWin,
                okeyPath: okeyPath,
                syncState: syncState,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ScansTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ScansTable,
      ScanRow,
      $$ScansTableFilterComposer,
      $$ScansTableOrderingComposer,
      $$ScansTableAnnotationComposer,
      $$ScansTableCreateCompanionBuilder,
      $$ScansTableUpdateCompanionBuilder,
      (ScanRow, BaseReferences<_$AppDatabase, $ScansTable, ScanRow>),
      ScanRow,
      PrefetchHooks Function()
    >;
typedef $$PreferencesTableCreateCompanionBuilder =
    PreferencesCompanion Function({
      required String key,
      required String valueJson,
      Value<int> rowid,
    });
typedef $$PreferencesTableUpdateCompanionBuilder =
    PreferencesCompanion Function({
      Value<String> key,
      Value<String> valueJson,
      Value<int> rowid,
    });

class $$PreferencesTableFilterComposer
    extends Composer<_$AppDatabase, $PreferencesTable> {
  $$PreferencesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get valueJson => $composableBuilder(
    column: $table.valueJson,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PreferencesTableOrderingComposer
    extends Composer<_$AppDatabase, $PreferencesTable> {
  $$PreferencesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get valueJson => $composableBuilder(
    column: $table.valueJson,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PreferencesTableAnnotationComposer
    extends Composer<_$AppDatabase, $PreferencesTable> {
  $$PreferencesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get valueJson =>
      $composableBuilder(column: $table.valueJson, builder: (column) => column);
}

class $$PreferencesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PreferencesTable,
          Preference,
          $$PreferencesTableFilterComposer,
          $$PreferencesTableOrderingComposer,
          $$PreferencesTableAnnotationComposer,
          $$PreferencesTableCreateCompanionBuilder,
          $$PreferencesTableUpdateCompanionBuilder,
          (
            Preference,
            BaseReferences<_$AppDatabase, $PreferencesTable, Preference>,
          ),
          Preference,
          PrefetchHooks Function()
        > {
  $$PreferencesTableTableManager(_$AppDatabase db, $PreferencesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PreferencesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PreferencesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PreferencesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> valueJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PreferencesCompanion(
                key: key,
                valueJson: valueJson,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String key,
                required String valueJson,
                Value<int> rowid = const Value.absent(),
              }) => PreferencesCompanion.insert(
                key: key,
                valueJson: valueJson,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PreferencesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PreferencesTable,
      Preference,
      $$PreferencesTableFilterComposer,
      $$PreferencesTableOrderingComposer,
      $$PreferencesTableAnnotationComposer,
      $$PreferencesTableCreateCompanionBuilder,
      $$PreferencesTableUpdateCompanionBuilder,
      (
        Preference,
        BaseReferences<_$AppDatabase, $PreferencesTable, Preference>,
      ),
      Preference,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$ScansTableTableManager get scans =>
      $$ScansTableTableManager(_db, _db.scans);
  $$PreferencesTableTableManager get preferences =>
      $$PreferencesTableTableManager(_db, _db.preferences);
}
