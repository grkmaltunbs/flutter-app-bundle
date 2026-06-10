// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'capture_payload.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$CapturePayload {

 DateTime get capturedAt;
/// Create a copy of CapturePayload
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CapturePayloadCopyWith<CapturePayload> get copyWith => _$CapturePayloadCopyWithImpl<CapturePayload>(this as CapturePayload, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CapturePayload&&(identical(other.capturedAt, capturedAt) || other.capturedAt == capturedAt));
}


@override
int get hashCode => Object.hash(runtimeType,capturedAt);

@override
String toString() {
  return 'CapturePayload(capturedAt: $capturedAt)';
}


}

/// @nodoc
abstract mixin class $CapturePayloadCopyWith<$Res>  {
  factory $CapturePayloadCopyWith(CapturePayload value, $Res Function(CapturePayload) _then) = _$CapturePayloadCopyWithImpl;
@useResult
$Res call({
 DateTime capturedAt
});




}
/// @nodoc
class _$CapturePayloadCopyWithImpl<$Res>
    implements $CapturePayloadCopyWith<$Res> {
  _$CapturePayloadCopyWithImpl(this._self, this._then);

  final CapturePayload _self;
  final $Res Function(CapturePayload) _then;

/// Create a copy of CapturePayload
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? capturedAt = null,}) {
  return _then(_self.copyWith(
capturedAt: null == capturedAt ? _self.capturedAt : capturedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

}


/// Adds pattern-matching-related methods to [CapturePayload].
extension CapturePayloadPatterns on CapturePayload {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( StillCapture value)?  still,TResult Function( FramesCapture value)?  frames,required TResult orElse(),}){
final _that = this;
switch (_that) {
case StillCapture() when still != null:
return still(_that);case FramesCapture() when frames != null:
return frames(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( StillCapture value)  still,required TResult Function( FramesCapture value)  frames,}){
final _that = this;
switch (_that) {
case StillCapture():
return still(_that);case FramesCapture():
return frames(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( StillCapture value)?  still,TResult? Function( FramesCapture value)?  frames,}){
final _that = this;
switch (_that) {
case StillCapture() when still != null:
return still(_that);case FramesCapture() when frames != null:
return frames(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( String imagePath,  CaptureSource source,  DateTime capturedAt)?  still,TResult Function( List<String> framePaths,  DateTime capturedAt)?  frames,required TResult orElse(),}) {final _that = this;
switch (_that) {
case StillCapture() when still != null:
return still(_that.imagePath,_that.source,_that.capturedAt);case FramesCapture() when frames != null:
return frames(_that.framePaths,_that.capturedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( String imagePath,  CaptureSource source,  DateTime capturedAt)  still,required TResult Function( List<String> framePaths,  DateTime capturedAt)  frames,}) {final _that = this;
switch (_that) {
case StillCapture():
return still(_that.imagePath,_that.source,_that.capturedAt);case FramesCapture():
return frames(_that.framePaths,_that.capturedAt);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( String imagePath,  CaptureSource source,  DateTime capturedAt)?  still,TResult? Function( List<String> framePaths,  DateTime capturedAt)?  frames,}) {final _that = this;
switch (_that) {
case StillCapture() when still != null:
return still(_that.imagePath,_that.source,_that.capturedAt);case FramesCapture() when frames != null:
return frames(_that.framePaths,_that.capturedAt);case _:
  return null;

}
}

}

/// @nodoc


class StillCapture implements CapturePayload {
  const StillCapture({required this.imagePath, required this.source, required this.capturedAt});
  

 final  String imagePath;
 final  CaptureSource source;
@override final  DateTime capturedAt;

/// Create a copy of CapturePayload
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$StillCaptureCopyWith<StillCapture> get copyWith => _$StillCaptureCopyWithImpl<StillCapture>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is StillCapture&&(identical(other.imagePath, imagePath) || other.imagePath == imagePath)&&(identical(other.source, source) || other.source == source)&&(identical(other.capturedAt, capturedAt) || other.capturedAt == capturedAt));
}


@override
int get hashCode => Object.hash(runtimeType,imagePath,source,capturedAt);

@override
String toString() {
  return 'CapturePayload.still(imagePath: $imagePath, source: $source, capturedAt: $capturedAt)';
}


}

/// @nodoc
abstract mixin class $StillCaptureCopyWith<$Res> implements $CapturePayloadCopyWith<$Res> {
  factory $StillCaptureCopyWith(StillCapture value, $Res Function(StillCapture) _then) = _$StillCaptureCopyWithImpl;
@override @useResult
$Res call({
 String imagePath, CaptureSource source, DateTime capturedAt
});




}
/// @nodoc
class _$StillCaptureCopyWithImpl<$Res>
    implements $StillCaptureCopyWith<$Res> {
  _$StillCaptureCopyWithImpl(this._self, this._then);

  final StillCapture _self;
  final $Res Function(StillCapture) _then;

/// Create a copy of CapturePayload
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? imagePath = null,Object? source = null,Object? capturedAt = null,}) {
  return _then(StillCapture(
imagePath: null == imagePath ? _self.imagePath : imagePath // ignore: cast_nullable_to_non_nullable
as String,source: null == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as CaptureSource,capturedAt: null == capturedAt ? _self.capturedAt : capturedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}

/// @nodoc


class FramesCapture implements CapturePayload {
  const FramesCapture({required final  List<String> framePaths, required this.capturedAt}): _framePaths = framePaths;
  

 final  List<String> _framePaths;
 List<String> get framePaths {
  if (_framePaths is EqualUnmodifiableListView) return _framePaths;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_framePaths);
}

@override final  DateTime capturedAt;

/// Create a copy of CapturePayload
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FramesCaptureCopyWith<FramesCapture> get copyWith => _$FramesCaptureCopyWithImpl<FramesCapture>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FramesCapture&&const DeepCollectionEquality().equals(other._framePaths, _framePaths)&&(identical(other.capturedAt, capturedAt) || other.capturedAt == capturedAt));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_framePaths),capturedAt);

@override
String toString() {
  return 'CapturePayload.frames(framePaths: $framePaths, capturedAt: $capturedAt)';
}


}

/// @nodoc
abstract mixin class $FramesCaptureCopyWith<$Res> implements $CapturePayloadCopyWith<$Res> {
  factory $FramesCaptureCopyWith(FramesCapture value, $Res Function(FramesCapture) _then) = _$FramesCaptureCopyWithImpl;
@override @useResult
$Res call({
 List<String> framePaths, DateTime capturedAt
});




}
/// @nodoc
class _$FramesCaptureCopyWithImpl<$Res>
    implements $FramesCaptureCopyWith<$Res> {
  _$FramesCaptureCopyWithImpl(this._self, this._then);

  final FramesCapture _self;
  final $Res Function(FramesCapture) _then;

/// Create a copy of CapturePayload
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? framePaths = null,Object? capturedAt = null,}) {
  return _then(FramesCapture(
framePaths: null == framePaths ? _self._framePaths : framePaths // ignore: cast_nullable_to_non_nullable
as List<String>,capturedAt: null == capturedAt ? _self.capturedAt : capturedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}

// dart format on
