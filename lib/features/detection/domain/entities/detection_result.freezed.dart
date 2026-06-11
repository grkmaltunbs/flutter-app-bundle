// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'detection_result.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$DetectionResult {

/// All detected tiles in rack order: row 0 left→right, then row 1.
 List<DetectedTile> get tiles;/// Mean per-tile confidence; low values drive the "consider retaking"
/// banner on review.
 double get overallConfidence;/// The representative captured image (the still, or a video burst's
/// first frame) shown behind the bounding-box overlay.
 String get sourceImagePath;/// How many frames produced [tiles]: 1 = still; >1 = video aggregation.
 int get frameCount;/// When detection finished — stamped via the injected `Clock`, never a
/// raw `DateTime.now()`.
 DateTime get detectedAt;
/// Create a copy of DetectionResult
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DetectionResultCopyWith<DetectionResult> get copyWith => _$DetectionResultCopyWithImpl<DetectionResult>(this as DetectionResult, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DetectionResult&&const DeepCollectionEquality().equals(other.tiles, tiles)&&(identical(other.overallConfidence, overallConfidence) || other.overallConfidence == overallConfidence)&&(identical(other.sourceImagePath, sourceImagePath) || other.sourceImagePath == sourceImagePath)&&(identical(other.frameCount, frameCount) || other.frameCount == frameCount)&&(identical(other.detectedAt, detectedAt) || other.detectedAt == detectedAt));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(tiles),overallConfidence,sourceImagePath,frameCount,detectedAt);

@override
String toString() {
  return 'DetectionResult(tiles: $tiles, overallConfidence: $overallConfidence, sourceImagePath: $sourceImagePath, frameCount: $frameCount, detectedAt: $detectedAt)';
}


}

/// @nodoc
abstract mixin class $DetectionResultCopyWith<$Res>  {
  factory $DetectionResultCopyWith(DetectionResult value, $Res Function(DetectionResult) _then) = _$DetectionResultCopyWithImpl;
@useResult
$Res call({
 List<DetectedTile> tiles, double overallConfidence, String sourceImagePath, int frameCount, DateTime detectedAt
});




}
/// @nodoc
class _$DetectionResultCopyWithImpl<$Res>
    implements $DetectionResultCopyWith<$Res> {
  _$DetectionResultCopyWithImpl(this._self, this._then);

  final DetectionResult _self;
  final $Res Function(DetectionResult) _then;

/// Create a copy of DetectionResult
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? tiles = null,Object? overallConfidence = null,Object? sourceImagePath = null,Object? frameCount = null,Object? detectedAt = null,}) {
  return _then(_self.copyWith(
tiles: null == tiles ? _self.tiles : tiles // ignore: cast_nullable_to_non_nullable
as List<DetectedTile>,overallConfidence: null == overallConfidence ? _self.overallConfidence : overallConfidence // ignore: cast_nullable_to_non_nullable
as double,sourceImagePath: null == sourceImagePath ? _self.sourceImagePath : sourceImagePath // ignore: cast_nullable_to_non_nullable
as String,frameCount: null == frameCount ? _self.frameCount : frameCount // ignore: cast_nullable_to_non_nullable
as int,detectedAt: null == detectedAt ? _self.detectedAt : detectedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

}


/// Adds pattern-matching-related methods to [DetectionResult].
extension DetectionResultPatterns on DetectionResult {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _DetectionResult value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _DetectionResult() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _DetectionResult value)  $default,){
final _that = this;
switch (_that) {
case _DetectionResult():
return $default(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _DetectionResult value)?  $default,){
final _that = this;
switch (_that) {
case _DetectionResult() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<DetectedTile> tiles,  double overallConfidence,  String sourceImagePath,  int frameCount,  DateTime detectedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _DetectionResult() when $default != null:
return $default(_that.tiles,_that.overallConfidence,_that.sourceImagePath,_that.frameCount,_that.detectedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<DetectedTile> tiles,  double overallConfidence,  String sourceImagePath,  int frameCount,  DateTime detectedAt)  $default,) {final _that = this;
switch (_that) {
case _DetectionResult():
return $default(_that.tiles,_that.overallConfidence,_that.sourceImagePath,_that.frameCount,_that.detectedAt);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<DetectedTile> tiles,  double overallConfidence,  String sourceImagePath,  int frameCount,  DateTime detectedAt)?  $default,) {final _that = this;
switch (_that) {
case _DetectionResult() when $default != null:
return $default(_that.tiles,_that.overallConfidence,_that.sourceImagePath,_that.frameCount,_that.detectedAt);case _:
  return null;

}
}

}

/// @nodoc


class _DetectionResult implements DetectionResult {
  const _DetectionResult({required final  List<DetectedTile> tiles, required this.overallConfidence, required this.sourceImagePath, required this.frameCount, required this.detectedAt}): _tiles = tiles;
  

/// All detected tiles in rack order: row 0 left→right, then row 1.
 final  List<DetectedTile> _tiles;
/// All detected tiles in rack order: row 0 left→right, then row 1.
@override List<DetectedTile> get tiles {
  if (_tiles is EqualUnmodifiableListView) return _tiles;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_tiles);
}

/// Mean per-tile confidence; low values drive the "consider retaking"
/// banner on review.
@override final  double overallConfidence;
/// The representative captured image (the still, or a video burst's
/// first frame) shown behind the bounding-box overlay.
@override final  String sourceImagePath;
/// How many frames produced [tiles]: 1 = still; >1 = video aggregation.
@override final  int frameCount;
/// When detection finished — stamped via the injected `Clock`, never a
/// raw `DateTime.now()`.
@override final  DateTime detectedAt;

/// Create a copy of DetectionResult
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DetectionResultCopyWith<_DetectionResult> get copyWith => __$DetectionResultCopyWithImpl<_DetectionResult>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _DetectionResult&&const DeepCollectionEquality().equals(other._tiles, _tiles)&&(identical(other.overallConfidence, overallConfidence) || other.overallConfidence == overallConfidence)&&(identical(other.sourceImagePath, sourceImagePath) || other.sourceImagePath == sourceImagePath)&&(identical(other.frameCount, frameCount) || other.frameCount == frameCount)&&(identical(other.detectedAt, detectedAt) || other.detectedAt == detectedAt));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_tiles),overallConfidence,sourceImagePath,frameCount,detectedAt);

@override
String toString() {
  return 'DetectionResult(tiles: $tiles, overallConfidence: $overallConfidence, sourceImagePath: $sourceImagePath, frameCount: $frameCount, detectedAt: $detectedAt)';
}


}

/// @nodoc
abstract mixin class _$DetectionResultCopyWith<$Res> implements $DetectionResultCopyWith<$Res> {
  factory _$DetectionResultCopyWith(_DetectionResult value, $Res Function(_DetectionResult) _then) = __$DetectionResultCopyWithImpl;
@override @useResult
$Res call({
 List<DetectedTile> tiles, double overallConfidence, String sourceImagePath, int frameCount, DateTime detectedAt
});




}
/// @nodoc
class __$DetectionResultCopyWithImpl<$Res>
    implements _$DetectionResultCopyWith<$Res> {
  __$DetectionResultCopyWithImpl(this._self, this._then);

  final _DetectionResult _self;
  final $Res Function(_DetectionResult) _then;

/// Create a copy of DetectionResult
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? tiles = null,Object? overallConfidence = null,Object? sourceImagePath = null,Object? frameCount = null,Object? detectedAt = null,}) {
  return _then(_DetectionResult(
tiles: null == tiles ? _self._tiles : tiles // ignore: cast_nullable_to_non_nullable
as List<DetectedTile>,overallConfidence: null == overallConfidence ? _self.overallConfidence : overallConfidence // ignore: cast_nullable_to_non_nullable
as double,sourceImagePath: null == sourceImagePath ? _self.sourceImagePath : sourceImagePath // ignore: cast_nullable_to_non_nullable
as String,frameCount: null == frameCount ? _self.frameCount : frameCount // ignore: cast_nullable_to_non_nullable
as int,detectedAt: null == detectedAt ? _self.detectedAt : detectedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}

// dart format on
