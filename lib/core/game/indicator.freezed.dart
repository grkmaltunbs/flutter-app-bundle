// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'indicator.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$Indicator {

 TileColor get color; int get number;
/// Create a copy of Indicator
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$IndicatorCopyWith<Indicator> get copyWith => _$IndicatorCopyWithImpl<Indicator>(this as Indicator, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Indicator&&(identical(other.color, color) || other.color == color)&&(identical(other.number, number) || other.number == number));
}


@override
int get hashCode => Object.hash(runtimeType,color,number);

@override
String toString() {
  return 'Indicator(color: $color, number: $number)';
}


}

/// @nodoc
abstract mixin class $IndicatorCopyWith<$Res>  {
  factory $IndicatorCopyWith(Indicator value, $Res Function(Indicator) _then) = _$IndicatorCopyWithImpl;
@useResult
$Res call({
 TileColor color, int number
});




}
/// @nodoc
class _$IndicatorCopyWithImpl<$Res>
    implements $IndicatorCopyWith<$Res> {
  _$IndicatorCopyWithImpl(this._self, this._then);

  final Indicator _self;
  final $Res Function(Indicator) _then;

/// Create a copy of Indicator
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? color = null,Object? number = null,}) {
  return _then(_self.copyWith(
color: null == color ? _self.color : color // ignore: cast_nullable_to_non_nullable
as TileColor,number: null == number ? _self.number : number // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [Indicator].
extension IndicatorPatterns on Indicator {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Indicator value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Indicator() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Indicator value)  $default,){
final _that = this;
switch (_that) {
case _Indicator():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Indicator value)?  $default,){
final _that = this;
switch (_that) {
case _Indicator() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( TileColor color,  int number)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Indicator() when $default != null:
return $default(_that.color,_that.number);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( TileColor color,  int number)  $default,) {final _that = this;
switch (_that) {
case _Indicator():
return $default(_that.color,_that.number);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( TileColor color,  int number)?  $default,) {final _that = this;
switch (_that) {
case _Indicator() when $default != null:
return $default(_that.color,_that.number);case _:
  return null;

}
}

}

/// @nodoc


class _Indicator extends Indicator {
  const _Indicator({required this.color, required this.number}): assert(color != TileColor.joker, 'the indicator is a real tile, never the joker'),assert(number >= 1 && number <= 13, 'number must be 1–13'),super._();
  

@override final  TileColor color;
@override final  int number;

/// Create a copy of Indicator
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$IndicatorCopyWith<_Indicator> get copyWith => __$IndicatorCopyWithImpl<_Indicator>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Indicator&&(identical(other.color, color) || other.color == color)&&(identical(other.number, number) || other.number == number));
}


@override
int get hashCode => Object.hash(runtimeType,color,number);

@override
String toString() {
  return 'Indicator(color: $color, number: $number)';
}


}

/// @nodoc
abstract mixin class _$IndicatorCopyWith<$Res> implements $IndicatorCopyWith<$Res> {
  factory _$IndicatorCopyWith(_Indicator value, $Res Function(_Indicator) _then) = __$IndicatorCopyWithImpl;
@override @useResult
$Res call({
 TileColor color, int number
});




}
/// @nodoc
class __$IndicatorCopyWithImpl<$Res>
    implements _$IndicatorCopyWith<$Res> {
  __$IndicatorCopyWithImpl(this._self, this._then);

  final _Indicator _self;
  final $Res Function(_Indicator) _then;

/// Create a copy of Indicator
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? color = null,Object? number = null,}) {
  return _then(_Indicator(
color: null == color ? _self.color : color // ignore: cast_nullable_to_non_nullable
as TileColor,number: null == number ? _self.number : number // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
