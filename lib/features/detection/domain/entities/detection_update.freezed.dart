// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'detection_update.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$DetectionUpdate {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DetectionUpdate);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'DetectionUpdate()';
}


}

/// @nodoc
class $DetectionUpdateCopyWith<$Res>  {
$DetectionUpdateCopyWith(DetectionUpdate _, $Res Function(DetectionUpdate) __);
}


/// Adds pattern-matching-related methods to [DetectionUpdate].
extension DetectionUpdatePatterns on DetectionUpdate {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( DetectionStageUpdate value)?  stage,TResult Function( DetectionTileUpdate value)?  tile,TResult Function( DetectionCompletedUpdate value)?  completed,TResult Function( DetectionFailedUpdate value)?  failed,required TResult orElse(),}){
final _that = this;
switch (_that) {
case DetectionStageUpdate() when stage != null:
return stage(_that);case DetectionTileUpdate() when tile != null:
return tile(_that);case DetectionCompletedUpdate() when completed != null:
return completed(_that);case DetectionFailedUpdate() when failed != null:
return failed(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( DetectionStageUpdate value)  stage,required TResult Function( DetectionTileUpdate value)  tile,required TResult Function( DetectionCompletedUpdate value)  completed,required TResult Function( DetectionFailedUpdate value)  failed,}){
final _that = this;
switch (_that) {
case DetectionStageUpdate():
return stage(_that);case DetectionTileUpdate():
return tile(_that);case DetectionCompletedUpdate():
return completed(_that);case DetectionFailedUpdate():
return failed(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( DetectionStageUpdate value)?  stage,TResult? Function( DetectionTileUpdate value)?  tile,TResult? Function( DetectionCompletedUpdate value)?  completed,TResult? Function( DetectionFailedUpdate value)?  failed,}){
final _that = this;
switch (_that) {
case DetectionStageUpdate() when stage != null:
return stage(_that);case DetectionTileUpdate() when tile != null:
return tile(_that);case DetectionCompletedUpdate() when completed != null:
return completed(_that);case DetectionFailedUpdate() when failed != null:
return failed(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( DetectionStage stage,  int? totalTiles)?  stage,TResult Function( DetectedTile tile)?  tile,TResult Function( DetectionResult result)?  completed,TResult Function( Failure failure)?  failed,required TResult orElse(),}) {final _that = this;
switch (_that) {
case DetectionStageUpdate() when stage != null:
return stage(_that.stage,_that.totalTiles);case DetectionTileUpdate() when tile != null:
return tile(_that.tile);case DetectionCompletedUpdate() when completed != null:
return completed(_that.result);case DetectionFailedUpdate() when failed != null:
return failed(_that.failure);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( DetectionStage stage,  int? totalTiles)  stage,required TResult Function( DetectedTile tile)  tile,required TResult Function( DetectionResult result)  completed,required TResult Function( Failure failure)  failed,}) {final _that = this;
switch (_that) {
case DetectionStageUpdate():
return stage(_that.stage,_that.totalTiles);case DetectionTileUpdate():
return tile(_that.tile);case DetectionCompletedUpdate():
return completed(_that.result);case DetectionFailedUpdate():
return failed(_that.failure);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( DetectionStage stage,  int? totalTiles)?  stage,TResult? Function( DetectedTile tile)?  tile,TResult? Function( DetectionResult result)?  completed,TResult? Function( Failure failure)?  failed,}) {final _that = this;
switch (_that) {
case DetectionStageUpdate() when stage != null:
return stage(_that.stage,_that.totalTiles);case DetectionTileUpdate() when tile != null:
return tile(_that.tile);case DetectionCompletedUpdate() when completed != null:
return completed(_that.result);case DetectionFailedUpdate() when failed != null:
return failed(_that.failure);case _:
  return null;

}
}

}

/// @nodoc


class DetectionStageUpdate implements DetectionUpdate {
  const DetectionStageUpdate(this.stage, {this.totalTiles});
  

 final  DetectionStage stage;
 final  int? totalTiles;

/// Create a copy of DetectionUpdate
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DetectionStageUpdateCopyWith<DetectionStageUpdate> get copyWith => _$DetectionStageUpdateCopyWithImpl<DetectionStageUpdate>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DetectionStageUpdate&&(identical(other.stage, stage) || other.stage == stage)&&(identical(other.totalTiles, totalTiles) || other.totalTiles == totalTiles));
}


@override
int get hashCode => Object.hash(runtimeType,stage,totalTiles);

@override
String toString() {
  return 'DetectionUpdate.stage(stage: $stage, totalTiles: $totalTiles)';
}


}

/// @nodoc
abstract mixin class $DetectionStageUpdateCopyWith<$Res> implements $DetectionUpdateCopyWith<$Res> {
  factory $DetectionStageUpdateCopyWith(DetectionStageUpdate value, $Res Function(DetectionStageUpdate) _then) = _$DetectionStageUpdateCopyWithImpl;
@useResult
$Res call({
 DetectionStage stage, int? totalTiles
});




}
/// @nodoc
class _$DetectionStageUpdateCopyWithImpl<$Res>
    implements $DetectionStageUpdateCopyWith<$Res> {
  _$DetectionStageUpdateCopyWithImpl(this._self, this._then);

  final DetectionStageUpdate _self;
  final $Res Function(DetectionStageUpdate) _then;

/// Create a copy of DetectionUpdate
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? stage = null,Object? totalTiles = freezed,}) {
  return _then(DetectionStageUpdate(
null == stage ? _self.stage : stage // ignore: cast_nullable_to_non_nullable
as DetectionStage,totalTiles: freezed == totalTiles ? _self.totalTiles : totalTiles // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}

/// @nodoc


class DetectionTileUpdate implements DetectionUpdate {
  const DetectionTileUpdate(this.tile);
  

 final  DetectedTile tile;

/// Create a copy of DetectionUpdate
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DetectionTileUpdateCopyWith<DetectionTileUpdate> get copyWith => _$DetectionTileUpdateCopyWithImpl<DetectionTileUpdate>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DetectionTileUpdate&&(identical(other.tile, tile) || other.tile == tile));
}


@override
int get hashCode => Object.hash(runtimeType,tile);

@override
String toString() {
  return 'DetectionUpdate.tile(tile: $tile)';
}


}

/// @nodoc
abstract mixin class $DetectionTileUpdateCopyWith<$Res> implements $DetectionUpdateCopyWith<$Res> {
  factory $DetectionTileUpdateCopyWith(DetectionTileUpdate value, $Res Function(DetectionTileUpdate) _then) = _$DetectionTileUpdateCopyWithImpl;
@useResult
$Res call({
 DetectedTile tile
});


$DetectedTileCopyWith<$Res> get tile;

}
/// @nodoc
class _$DetectionTileUpdateCopyWithImpl<$Res>
    implements $DetectionTileUpdateCopyWith<$Res> {
  _$DetectionTileUpdateCopyWithImpl(this._self, this._then);

  final DetectionTileUpdate _self;
  final $Res Function(DetectionTileUpdate) _then;

/// Create a copy of DetectionUpdate
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? tile = null,}) {
  return _then(DetectionTileUpdate(
null == tile ? _self.tile : tile // ignore: cast_nullable_to_non_nullable
as DetectedTile,
  ));
}

/// Create a copy of DetectionUpdate
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$DetectedTileCopyWith<$Res> get tile {
  
  return $DetectedTileCopyWith<$Res>(_self.tile, (value) {
    return _then(_self.copyWith(tile: value));
  });
}
}

/// @nodoc


class DetectionCompletedUpdate implements DetectionUpdate {
  const DetectionCompletedUpdate(this.result);
  

 final  DetectionResult result;

/// Create a copy of DetectionUpdate
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DetectionCompletedUpdateCopyWith<DetectionCompletedUpdate> get copyWith => _$DetectionCompletedUpdateCopyWithImpl<DetectionCompletedUpdate>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DetectionCompletedUpdate&&(identical(other.result, result) || other.result == result));
}


@override
int get hashCode => Object.hash(runtimeType,result);

@override
String toString() {
  return 'DetectionUpdate.completed(result: $result)';
}


}

/// @nodoc
abstract mixin class $DetectionCompletedUpdateCopyWith<$Res> implements $DetectionUpdateCopyWith<$Res> {
  factory $DetectionCompletedUpdateCopyWith(DetectionCompletedUpdate value, $Res Function(DetectionCompletedUpdate) _then) = _$DetectionCompletedUpdateCopyWithImpl;
@useResult
$Res call({
 DetectionResult result
});


$DetectionResultCopyWith<$Res> get result;

}
/// @nodoc
class _$DetectionCompletedUpdateCopyWithImpl<$Res>
    implements $DetectionCompletedUpdateCopyWith<$Res> {
  _$DetectionCompletedUpdateCopyWithImpl(this._self, this._then);

  final DetectionCompletedUpdate _self;
  final $Res Function(DetectionCompletedUpdate) _then;

/// Create a copy of DetectionUpdate
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? result = null,}) {
  return _then(DetectionCompletedUpdate(
null == result ? _self.result : result // ignore: cast_nullable_to_non_nullable
as DetectionResult,
  ));
}

/// Create a copy of DetectionUpdate
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$DetectionResultCopyWith<$Res> get result {
  
  return $DetectionResultCopyWith<$Res>(_self.result, (value) {
    return _then(_self.copyWith(result: value));
  });
}
}

/// @nodoc


class DetectionFailedUpdate implements DetectionUpdate {
  const DetectionFailedUpdate(this.failure);
  

 final  Failure failure;

/// Create a copy of DetectionUpdate
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DetectionFailedUpdateCopyWith<DetectionFailedUpdate> get copyWith => _$DetectionFailedUpdateCopyWithImpl<DetectionFailedUpdate>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DetectionFailedUpdate&&(identical(other.failure, failure) || other.failure == failure));
}


@override
int get hashCode => Object.hash(runtimeType,failure);

@override
String toString() {
  return 'DetectionUpdate.failed(failure: $failure)';
}


}

/// @nodoc
abstract mixin class $DetectionFailedUpdateCopyWith<$Res> implements $DetectionUpdateCopyWith<$Res> {
  factory $DetectionFailedUpdateCopyWith(DetectionFailedUpdate value, $Res Function(DetectionFailedUpdate) _then) = _$DetectionFailedUpdateCopyWithImpl;
@useResult
$Res call({
 Failure failure
});


$FailureCopyWith<$Res> get failure;

}
/// @nodoc
class _$DetectionFailedUpdateCopyWithImpl<$Res>
    implements $DetectionFailedUpdateCopyWith<$Res> {
  _$DetectionFailedUpdateCopyWithImpl(this._self, this._then);

  final DetectionFailedUpdate _self;
  final $Res Function(DetectionFailedUpdate) _then;

/// Create a copy of DetectionUpdate
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? failure = null,}) {
  return _then(DetectionFailedUpdate(
null == failure ? _self.failure : failure // ignore: cast_nullable_to_non_nullable
as Failure,
  ));
}

/// Create a copy of DetectionUpdate
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$FailureCopyWith<$Res> get failure {
  
  return $FailureCopyWith<$Res>(_self.failure, (value) {
    return _then(_self.copyWith(failure: value));
  });
}
}

// dart format on
