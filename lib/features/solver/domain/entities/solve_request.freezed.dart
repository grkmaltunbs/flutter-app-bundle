// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'solve_request.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$SolveRequest {

 List<GameTile> get tiles; Indicator get indicator; GameMode get mode;
/// Create a copy of SolveRequest
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SolveRequestCopyWith<SolveRequest> get copyWith => _$SolveRequestCopyWithImpl<SolveRequest>(this as SolveRequest, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SolveRequest&&const DeepCollectionEquality().equals(other.tiles, tiles)&&(identical(other.indicator, indicator) || other.indicator == indicator)&&(identical(other.mode, mode) || other.mode == mode));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(tiles),indicator,mode);

@override
String toString() {
  return 'SolveRequest(tiles: $tiles, indicator: $indicator, mode: $mode)';
}


}

/// @nodoc
abstract mixin class $SolveRequestCopyWith<$Res>  {
  factory $SolveRequestCopyWith(SolveRequest value, $Res Function(SolveRequest) _then) = _$SolveRequestCopyWithImpl;
@useResult
$Res call({
 List<GameTile> tiles, Indicator indicator, GameMode mode
});


$IndicatorCopyWith<$Res> get indicator;

}
/// @nodoc
class _$SolveRequestCopyWithImpl<$Res>
    implements $SolveRequestCopyWith<$Res> {
  _$SolveRequestCopyWithImpl(this._self, this._then);

  final SolveRequest _self;
  final $Res Function(SolveRequest) _then;

/// Create a copy of SolveRequest
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? tiles = null,Object? indicator = null,Object? mode = null,}) {
  return _then(_self.copyWith(
tiles: null == tiles ? _self.tiles : tiles // ignore: cast_nullable_to_non_nullable
as List<GameTile>,indicator: null == indicator ? _self.indicator : indicator // ignore: cast_nullable_to_non_nullable
as Indicator,mode: null == mode ? _self.mode : mode // ignore: cast_nullable_to_non_nullable
as GameMode,
  ));
}
/// Create a copy of SolveRequest
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$IndicatorCopyWith<$Res> get indicator {
  
  return $IndicatorCopyWith<$Res>(_self.indicator, (value) {
    return _then(_self.copyWith(indicator: value));
  });
}
}


/// Adds pattern-matching-related methods to [SolveRequest].
extension SolveRequestPatterns on SolveRequest {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SolveRequest value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SolveRequest() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SolveRequest value)  $default,){
final _that = this;
switch (_that) {
case _SolveRequest():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SolveRequest value)?  $default,){
final _that = this;
switch (_that) {
case _SolveRequest() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<GameTile> tiles,  Indicator indicator,  GameMode mode)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SolveRequest() when $default != null:
return $default(_that.tiles,_that.indicator,_that.mode);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<GameTile> tiles,  Indicator indicator,  GameMode mode)  $default,) {final _that = this;
switch (_that) {
case _SolveRequest():
return $default(_that.tiles,_that.indicator,_that.mode);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<GameTile> tiles,  Indicator indicator,  GameMode mode)?  $default,) {final _that = this;
switch (_that) {
case _SolveRequest() when $default != null:
return $default(_that.tiles,_that.indicator,_that.mode);case _:
  return null;

}
}

}

/// @nodoc


class _SolveRequest implements SolveRequest {
  const _SolveRequest({required final  List<GameTile> tiles, required this.indicator, required this.mode}): _tiles = tiles;
  

 final  List<GameTile> _tiles;
@override List<GameTile> get tiles {
  if (_tiles is EqualUnmodifiableListView) return _tiles;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_tiles);
}

@override final  Indicator indicator;
@override final  GameMode mode;

/// Create a copy of SolveRequest
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SolveRequestCopyWith<_SolveRequest> get copyWith => __$SolveRequestCopyWithImpl<_SolveRequest>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SolveRequest&&const DeepCollectionEquality().equals(other._tiles, _tiles)&&(identical(other.indicator, indicator) || other.indicator == indicator)&&(identical(other.mode, mode) || other.mode == mode));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_tiles),indicator,mode);

@override
String toString() {
  return 'SolveRequest(tiles: $tiles, indicator: $indicator, mode: $mode)';
}


}

/// @nodoc
abstract mixin class _$SolveRequestCopyWith<$Res> implements $SolveRequestCopyWith<$Res> {
  factory _$SolveRequestCopyWith(_SolveRequest value, $Res Function(_SolveRequest) _then) = __$SolveRequestCopyWithImpl;
@override @useResult
$Res call({
 List<GameTile> tiles, Indicator indicator, GameMode mode
});


@override $IndicatorCopyWith<$Res> get indicator;

}
/// @nodoc
class __$SolveRequestCopyWithImpl<$Res>
    implements _$SolveRequestCopyWith<$Res> {
  __$SolveRequestCopyWithImpl(this._self, this._then);

  final _SolveRequest _self;
  final $Res Function(_SolveRequest) _then;

/// Create a copy of SolveRequest
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? tiles = null,Object? indicator = null,Object? mode = null,}) {
  return _then(_SolveRequest(
tiles: null == tiles ? _self._tiles : tiles // ignore: cast_nullable_to_non_nullable
as List<GameTile>,indicator: null == indicator ? _self.indicator : indicator // ignore: cast_nullable_to_non_nullable
as Indicator,mode: null == mode ? _self.mode : mode // ignore: cast_nullable_to_non_nullable
as GameMode,
  ));
}

/// Create a copy of SolveRequest
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$IndicatorCopyWith<$Res> get indicator {
  
  return $IndicatorCopyWith<$Res>(_self.indicator, (value) {
    return _then(_self.copyWith(indicator: value));
  });
}
}

// dart format on
