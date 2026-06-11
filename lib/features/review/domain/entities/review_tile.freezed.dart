// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'review_tile.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ReviewTile {

 TileColor? get color; int? get number; bool get lowConfidence;
/// Create a copy of ReviewTile
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ReviewTileCopyWith<ReviewTile> get copyWith => _$ReviewTileCopyWithImpl<ReviewTile>(this as ReviewTile, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ReviewTile&&(identical(other.color, color) || other.color == color)&&(identical(other.number, number) || other.number == number)&&(identical(other.lowConfidence, lowConfidence) || other.lowConfidence == lowConfidence));
}


@override
int get hashCode => Object.hash(runtimeType,color,number,lowConfidence);

@override
String toString() {
  return 'ReviewTile(color: $color, number: $number, lowConfidence: $lowConfidence)';
}


}

/// @nodoc
abstract mixin class $ReviewTileCopyWith<$Res>  {
  factory $ReviewTileCopyWith(ReviewTile value, $Res Function(ReviewTile) _then) = _$ReviewTileCopyWithImpl;
@useResult
$Res call({
 TileColor? color, int? number, bool lowConfidence
});




}
/// @nodoc
class _$ReviewTileCopyWithImpl<$Res>
    implements $ReviewTileCopyWith<$Res> {
  _$ReviewTileCopyWithImpl(this._self, this._then);

  final ReviewTile _self;
  final $Res Function(ReviewTile) _then;

/// Create a copy of ReviewTile
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? color = freezed,Object? number = freezed,Object? lowConfidence = null,}) {
  return _then(_self.copyWith(
color: freezed == color ? _self.color : color // ignore: cast_nullable_to_non_nullable
as TileColor?,number: freezed == number ? _self.number : number // ignore: cast_nullable_to_non_nullable
as int?,lowConfidence: null == lowConfidence ? _self.lowConfidence : lowConfidence // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [ReviewTile].
extension ReviewTilePatterns on ReviewTile {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ReviewTile value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ReviewTile() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ReviewTile value)  $default,){
final _that = this;
switch (_that) {
case _ReviewTile():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ReviewTile value)?  $default,){
final _that = this;
switch (_that) {
case _ReviewTile() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( TileColor? color,  int? number,  bool lowConfidence)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ReviewTile() when $default != null:
return $default(_that.color,_that.number,_that.lowConfidence);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( TileColor? color,  int? number,  bool lowConfidence)  $default,) {final _that = this;
switch (_that) {
case _ReviewTile():
return $default(_that.color,_that.number,_that.lowConfidence);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( TileColor? color,  int? number,  bool lowConfidence)?  $default,) {final _that = this;
switch (_that) {
case _ReviewTile() when $default != null:
return $default(_that.color,_that.number,_that.lowConfidence);case _:
  return null;

}
}

}

/// @nodoc


class _ReviewTile extends ReviewTile {
  const _ReviewTile({this.color, this.number, this.lowConfidence = false}): super._();
  

@override final  TileColor? color;
@override final  int? number;
@override@JsonKey() final  bool lowConfidence;

/// Create a copy of ReviewTile
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ReviewTileCopyWith<_ReviewTile> get copyWith => __$ReviewTileCopyWithImpl<_ReviewTile>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ReviewTile&&(identical(other.color, color) || other.color == color)&&(identical(other.number, number) || other.number == number)&&(identical(other.lowConfidence, lowConfidence) || other.lowConfidence == lowConfidence));
}


@override
int get hashCode => Object.hash(runtimeType,color,number,lowConfidence);

@override
String toString() {
  return 'ReviewTile(color: $color, number: $number, lowConfidence: $lowConfidence)';
}


}

/// @nodoc
abstract mixin class _$ReviewTileCopyWith<$Res> implements $ReviewTileCopyWith<$Res> {
  factory _$ReviewTileCopyWith(_ReviewTile value, $Res Function(_ReviewTile) _then) = __$ReviewTileCopyWithImpl;
@override @useResult
$Res call({
 TileColor? color, int? number, bool lowConfidence
});




}
/// @nodoc
class __$ReviewTileCopyWithImpl<$Res>
    implements _$ReviewTileCopyWith<$Res> {
  __$ReviewTileCopyWithImpl(this._self, this._then);

  final _ReviewTile _self;
  final $Res Function(_ReviewTile) _then;

/// Create a copy of ReviewTile
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? color = freezed,Object? number = freezed,Object? lowConfidence = null,}) {
  return _then(_ReviewTile(
color: freezed == color ? _self.color : color // ignore: cast_nullable_to_non_nullable
as TileColor?,number: freezed == number ? _self.number : number // ignore: cast_nullable_to_non_nullable
as int?,lowConfidence: null == lowConfidence ? _self.lowConfidence : lowConfidence // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
