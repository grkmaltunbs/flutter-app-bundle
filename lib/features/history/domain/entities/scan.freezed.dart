// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'scan.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$Scan {

/// Stable scan id (uuid v4); doubles as the Firestore doc id.
 String get id;/// Creation instant (UTC, from the injected `Clock`).
 DateTime get createdAt;/// Last mutation instant (UTC) — the last-write-wins sync key.
 DateTime get updatedAt;/// The confirmed tiles in rack order.
 List<GameTile> get tiles;/// The game the solver ran in.
 GameMode get gameMode;/// The indicator (gösterge) the user picked, or `null` when a face-down
/// (blank okey) tile let them skip it.
 Indicator? get indicator;/// The solver verdict summary.
 ScanSummary get summary;/// Owning user id, or `null` for a guest-created scan.
 String? get ownerId;
/// Create a copy of Scan
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ScanCopyWith<Scan> get copyWith => _$ScanCopyWithImpl<Scan>(this as Scan, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Scan&&(identical(other.id, id) || other.id == id)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&const DeepCollectionEquality().equals(other.tiles, tiles)&&(identical(other.gameMode, gameMode) || other.gameMode == gameMode)&&(identical(other.indicator, indicator) || other.indicator == indicator)&&(identical(other.summary, summary) || other.summary == summary)&&(identical(other.ownerId, ownerId) || other.ownerId == ownerId));
}


@override
int get hashCode => Object.hash(runtimeType,id,createdAt,updatedAt,const DeepCollectionEquality().hash(tiles),gameMode,indicator,summary,ownerId);

@override
String toString() {
  return 'Scan(id: $id, createdAt: $createdAt, updatedAt: $updatedAt, tiles: $tiles, gameMode: $gameMode, indicator: $indicator, summary: $summary, ownerId: $ownerId)';
}


}

/// @nodoc
abstract mixin class $ScanCopyWith<$Res>  {
  factory $ScanCopyWith(Scan value, $Res Function(Scan) _then) = _$ScanCopyWithImpl;
@useResult
$Res call({
 String id, DateTime createdAt, DateTime updatedAt, List<GameTile> tiles, GameMode gameMode, Indicator? indicator, ScanSummary summary, String? ownerId
});


$IndicatorCopyWith<$Res>? get indicator;$ScanSummaryCopyWith<$Res> get summary;

}
/// @nodoc
class _$ScanCopyWithImpl<$Res>
    implements $ScanCopyWith<$Res> {
  _$ScanCopyWithImpl(this._self, this._then);

  final Scan _self;
  final $Res Function(Scan) _then;

/// Create a copy of Scan
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? createdAt = null,Object? updatedAt = null,Object? tiles = null,Object? gameMode = null,Object? indicator = freezed,Object? summary = null,Object? ownerId = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,tiles: null == tiles ? _self.tiles : tiles // ignore: cast_nullable_to_non_nullable
as List<GameTile>,gameMode: null == gameMode ? _self.gameMode : gameMode // ignore: cast_nullable_to_non_nullable
as GameMode,indicator: freezed == indicator ? _self.indicator : indicator // ignore: cast_nullable_to_non_nullable
as Indicator?,summary: null == summary ? _self.summary : summary // ignore: cast_nullable_to_non_nullable
as ScanSummary,ownerId: freezed == ownerId ? _self.ownerId : ownerId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}
/// Create a copy of Scan
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$IndicatorCopyWith<$Res>? get indicator {
    if (_self.indicator == null) {
    return null;
  }

  return $IndicatorCopyWith<$Res>(_self.indicator!, (value) {
    return _then(_self.copyWith(indicator: value));
  });
}/// Create a copy of Scan
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ScanSummaryCopyWith<$Res> get summary {
  
  return $ScanSummaryCopyWith<$Res>(_self.summary, (value) {
    return _then(_self.copyWith(summary: value));
  });
}
}


/// Adds pattern-matching-related methods to [Scan].
extension ScanPatterns on Scan {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Scan value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Scan() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Scan value)  $default,){
final _that = this;
switch (_that) {
case _Scan():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Scan value)?  $default,){
final _that = this;
switch (_that) {
case _Scan() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  DateTime createdAt,  DateTime updatedAt,  List<GameTile> tiles,  GameMode gameMode,  Indicator? indicator,  ScanSummary summary,  String? ownerId)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Scan() when $default != null:
return $default(_that.id,_that.createdAt,_that.updatedAt,_that.tiles,_that.gameMode,_that.indicator,_that.summary,_that.ownerId);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  DateTime createdAt,  DateTime updatedAt,  List<GameTile> tiles,  GameMode gameMode,  Indicator? indicator,  ScanSummary summary,  String? ownerId)  $default,) {final _that = this;
switch (_that) {
case _Scan():
return $default(_that.id,_that.createdAt,_that.updatedAt,_that.tiles,_that.gameMode,_that.indicator,_that.summary,_that.ownerId);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  DateTime createdAt,  DateTime updatedAt,  List<GameTile> tiles,  GameMode gameMode,  Indicator? indicator,  ScanSummary summary,  String? ownerId)?  $default,) {final _that = this;
switch (_that) {
case _Scan() when $default != null:
return $default(_that.id,_that.createdAt,_that.updatedAt,_that.tiles,_that.gameMode,_that.indicator,_that.summary,_that.ownerId);case _:
  return null;

}
}

}

/// @nodoc


class _Scan extends Scan {
  const _Scan({required this.id, required this.createdAt, required this.updatedAt, required final  List<GameTile> tiles, required this.gameMode, this.indicator, required this.summary, this.ownerId}): _tiles = tiles,super._();
  

/// Stable scan id (uuid v4); doubles as the Firestore doc id.
@override final  String id;
/// Creation instant (UTC, from the injected `Clock`).
@override final  DateTime createdAt;
/// Last mutation instant (UTC) — the last-write-wins sync key.
@override final  DateTime updatedAt;
/// The confirmed tiles in rack order.
 final  List<GameTile> _tiles;
/// The confirmed tiles in rack order.
@override List<GameTile> get tiles {
  if (_tiles is EqualUnmodifiableListView) return _tiles;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_tiles);
}

/// The game the solver ran in.
@override final  GameMode gameMode;
/// The indicator (gösterge) the user picked, or `null` when a face-down
/// (blank okey) tile let them skip it.
@override final  Indicator? indicator;
/// The solver verdict summary.
@override final  ScanSummary summary;
/// Owning user id, or `null` for a guest-created scan.
@override final  String? ownerId;

/// Create a copy of Scan
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ScanCopyWith<_Scan> get copyWith => __$ScanCopyWithImpl<_Scan>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Scan&&(identical(other.id, id) || other.id == id)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&const DeepCollectionEquality().equals(other._tiles, _tiles)&&(identical(other.gameMode, gameMode) || other.gameMode == gameMode)&&(identical(other.indicator, indicator) || other.indicator == indicator)&&(identical(other.summary, summary) || other.summary == summary)&&(identical(other.ownerId, ownerId) || other.ownerId == ownerId));
}


@override
int get hashCode => Object.hash(runtimeType,id,createdAt,updatedAt,const DeepCollectionEquality().hash(_tiles),gameMode,indicator,summary,ownerId);

@override
String toString() {
  return 'Scan(id: $id, createdAt: $createdAt, updatedAt: $updatedAt, tiles: $tiles, gameMode: $gameMode, indicator: $indicator, summary: $summary, ownerId: $ownerId)';
}


}

/// @nodoc
abstract mixin class _$ScanCopyWith<$Res> implements $ScanCopyWith<$Res> {
  factory _$ScanCopyWith(_Scan value, $Res Function(_Scan) _then) = __$ScanCopyWithImpl;
@override @useResult
$Res call({
 String id, DateTime createdAt, DateTime updatedAt, List<GameTile> tiles, GameMode gameMode, Indicator? indicator, ScanSummary summary, String? ownerId
});


@override $IndicatorCopyWith<$Res>? get indicator;@override $ScanSummaryCopyWith<$Res> get summary;

}
/// @nodoc
class __$ScanCopyWithImpl<$Res>
    implements _$ScanCopyWith<$Res> {
  __$ScanCopyWithImpl(this._self, this._then);

  final _Scan _self;
  final $Res Function(_Scan) _then;

/// Create a copy of Scan
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? createdAt = null,Object? updatedAt = null,Object? tiles = null,Object? gameMode = null,Object? indicator = freezed,Object? summary = null,Object? ownerId = freezed,}) {
  return _then(_Scan(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,tiles: null == tiles ? _self._tiles : tiles // ignore: cast_nullable_to_non_nullable
as List<GameTile>,gameMode: null == gameMode ? _self.gameMode : gameMode // ignore: cast_nullable_to_non_nullable
as GameMode,indicator: freezed == indicator ? _self.indicator : indicator // ignore: cast_nullable_to_non_nullable
as Indicator?,summary: null == summary ? _self.summary : summary // ignore: cast_nullable_to_non_nullable
as ScanSummary,ownerId: freezed == ownerId ? _self.ownerId : ownerId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

/// Create a copy of Scan
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$IndicatorCopyWith<$Res>? get indicator {
    if (_self.indicator == null) {
    return null;
  }

  return $IndicatorCopyWith<$Res>(_self.indicator!, (value) {
    return _then(_self.copyWith(indicator: value));
  });
}/// Create a copy of Scan
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ScanSummaryCopyWith<$Res> get summary {
  
  return $ScanSummaryCopyWith<$Res>(_self.summary, (value) {
    return _then(_self.copyWith(summary: value));
  });
}
}

// dart format on
