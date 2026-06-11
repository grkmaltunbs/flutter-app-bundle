// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'review_outcome.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ReviewOutcome {

/// The confirmed tiles in rack order; jokers are `GameTile(joker, null)`.
 List<GameTile> get tiles;/// The indicator (gösterge) the user picked.
 Indicator get indicator;/// The game the solver should target.
 GameMode get gameMode;
/// Create a copy of ReviewOutcome
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ReviewOutcomeCopyWith<ReviewOutcome> get copyWith => _$ReviewOutcomeCopyWithImpl<ReviewOutcome>(this as ReviewOutcome, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ReviewOutcome&&const DeepCollectionEquality().equals(other.tiles, tiles)&&(identical(other.indicator, indicator) || other.indicator == indicator)&&(identical(other.gameMode, gameMode) || other.gameMode == gameMode));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(tiles),indicator,gameMode);

@override
String toString() {
  return 'ReviewOutcome(tiles: $tiles, indicator: $indicator, gameMode: $gameMode)';
}


}

/// @nodoc
abstract mixin class $ReviewOutcomeCopyWith<$Res>  {
  factory $ReviewOutcomeCopyWith(ReviewOutcome value, $Res Function(ReviewOutcome) _then) = _$ReviewOutcomeCopyWithImpl;
@useResult
$Res call({
 List<GameTile> tiles, Indicator indicator, GameMode gameMode
});


$IndicatorCopyWith<$Res> get indicator;

}
/// @nodoc
class _$ReviewOutcomeCopyWithImpl<$Res>
    implements $ReviewOutcomeCopyWith<$Res> {
  _$ReviewOutcomeCopyWithImpl(this._self, this._then);

  final ReviewOutcome _self;
  final $Res Function(ReviewOutcome) _then;

/// Create a copy of ReviewOutcome
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? tiles = null,Object? indicator = null,Object? gameMode = null,}) {
  return _then(_self.copyWith(
tiles: null == tiles ? _self.tiles : tiles // ignore: cast_nullable_to_non_nullable
as List<GameTile>,indicator: null == indicator ? _self.indicator : indicator // ignore: cast_nullable_to_non_nullable
as Indicator,gameMode: null == gameMode ? _self.gameMode : gameMode // ignore: cast_nullable_to_non_nullable
as GameMode,
  ));
}
/// Create a copy of ReviewOutcome
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$IndicatorCopyWith<$Res> get indicator {
  
  return $IndicatorCopyWith<$Res>(_self.indicator, (value) {
    return _then(_self.copyWith(indicator: value));
  });
}
}


/// Adds pattern-matching-related methods to [ReviewOutcome].
extension ReviewOutcomePatterns on ReviewOutcome {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ReviewOutcome value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ReviewOutcome() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ReviewOutcome value)  $default,){
final _that = this;
switch (_that) {
case _ReviewOutcome():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ReviewOutcome value)?  $default,){
final _that = this;
switch (_that) {
case _ReviewOutcome() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<GameTile> tiles,  Indicator indicator,  GameMode gameMode)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ReviewOutcome() when $default != null:
return $default(_that.tiles,_that.indicator,_that.gameMode);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<GameTile> tiles,  Indicator indicator,  GameMode gameMode)  $default,) {final _that = this;
switch (_that) {
case _ReviewOutcome():
return $default(_that.tiles,_that.indicator,_that.gameMode);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<GameTile> tiles,  Indicator indicator,  GameMode gameMode)?  $default,) {final _that = this;
switch (_that) {
case _ReviewOutcome() when $default != null:
return $default(_that.tiles,_that.indicator,_that.gameMode);case _:
  return null;

}
}

}

/// @nodoc


class _ReviewOutcome extends ReviewOutcome {
  const _ReviewOutcome({required final  List<GameTile> tiles, required this.indicator, required this.gameMode}): _tiles = tiles,super._();
  

/// The confirmed tiles in rack order; jokers are `GameTile(joker, null)`.
 final  List<GameTile> _tiles;
/// The confirmed tiles in rack order; jokers are `GameTile(joker, null)`.
@override List<GameTile> get tiles {
  if (_tiles is EqualUnmodifiableListView) return _tiles;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_tiles);
}

/// The indicator (gösterge) the user picked.
@override final  Indicator indicator;
/// The game the solver should target.
@override final  GameMode gameMode;

/// Create a copy of ReviewOutcome
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ReviewOutcomeCopyWith<_ReviewOutcome> get copyWith => __$ReviewOutcomeCopyWithImpl<_ReviewOutcome>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ReviewOutcome&&const DeepCollectionEquality().equals(other._tiles, _tiles)&&(identical(other.indicator, indicator) || other.indicator == indicator)&&(identical(other.gameMode, gameMode) || other.gameMode == gameMode));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_tiles),indicator,gameMode);

@override
String toString() {
  return 'ReviewOutcome(tiles: $tiles, indicator: $indicator, gameMode: $gameMode)';
}


}

/// @nodoc
abstract mixin class _$ReviewOutcomeCopyWith<$Res> implements $ReviewOutcomeCopyWith<$Res> {
  factory _$ReviewOutcomeCopyWith(_ReviewOutcome value, $Res Function(_ReviewOutcome) _then) = __$ReviewOutcomeCopyWithImpl;
@override @useResult
$Res call({
 List<GameTile> tiles, Indicator indicator, GameMode gameMode
});


@override $IndicatorCopyWith<$Res> get indicator;

}
/// @nodoc
class __$ReviewOutcomeCopyWithImpl<$Res>
    implements _$ReviewOutcomeCopyWith<$Res> {
  __$ReviewOutcomeCopyWithImpl(this._self, this._then);

  final _ReviewOutcome _self;
  final $Res Function(_ReviewOutcome) _then;

/// Create a copy of ReviewOutcome
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? tiles = null,Object? indicator = null,Object? gameMode = null,}) {
  return _then(_ReviewOutcome(
tiles: null == tiles ? _self._tiles : tiles // ignore: cast_nullable_to_non_nullable
as List<GameTile>,indicator: null == indicator ? _self.indicator : indicator // ignore: cast_nullable_to_non_nullable
as Indicator,gameMode: null == gameMode ? _self.gameMode : gameMode // ignore: cast_nullable_to_non_nullable
as GameMode,
  ));
}

/// Create a copy of ReviewOutcome
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
