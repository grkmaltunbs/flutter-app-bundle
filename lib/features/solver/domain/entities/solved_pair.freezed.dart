// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'solved_pair.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$SolvedPair {

 GameTile get identity; SolvedSpot get first; SolvedSpot get second;
/// Create a copy of SolvedPair
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SolvedPairCopyWith<SolvedPair> get copyWith => _$SolvedPairCopyWithImpl<SolvedPair>(this as SolvedPair, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SolvedPair&&(identical(other.identity, identity) || other.identity == identity)&&(identical(other.first, first) || other.first == first)&&(identical(other.second, second) || other.second == second));
}


@override
int get hashCode => Object.hash(runtimeType,identity,first,second);

@override
String toString() {
  return 'SolvedPair(identity: $identity, first: $first, second: $second)';
}


}

/// @nodoc
abstract mixin class $SolvedPairCopyWith<$Res>  {
  factory $SolvedPairCopyWith(SolvedPair value, $Res Function(SolvedPair) _then) = _$SolvedPairCopyWithImpl;
@useResult
$Res call({
 GameTile identity, SolvedSpot first, SolvedSpot second
});


$GameTileCopyWith<$Res> get identity;$SolvedSpotCopyWith<$Res> get first;$SolvedSpotCopyWith<$Res> get second;

}
/// @nodoc
class _$SolvedPairCopyWithImpl<$Res>
    implements $SolvedPairCopyWith<$Res> {
  _$SolvedPairCopyWithImpl(this._self, this._then);

  final SolvedPair _self;
  final $Res Function(SolvedPair) _then;

/// Create a copy of SolvedPair
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? identity = null,Object? first = null,Object? second = null,}) {
  return _then(_self.copyWith(
identity: null == identity ? _self.identity : identity // ignore: cast_nullable_to_non_nullable
as GameTile,first: null == first ? _self.first : first // ignore: cast_nullable_to_non_nullable
as SolvedSpot,second: null == second ? _self.second : second // ignore: cast_nullable_to_non_nullable
as SolvedSpot,
  ));
}
/// Create a copy of SolvedPair
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$GameTileCopyWith<$Res> get identity {
  
  return $GameTileCopyWith<$Res>(_self.identity, (value) {
    return _then(_self.copyWith(identity: value));
  });
}/// Create a copy of SolvedPair
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SolvedSpotCopyWith<$Res> get first {
  
  return $SolvedSpotCopyWith<$Res>(_self.first, (value) {
    return _then(_self.copyWith(first: value));
  });
}/// Create a copy of SolvedPair
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SolvedSpotCopyWith<$Res> get second {
  
  return $SolvedSpotCopyWith<$Res>(_self.second, (value) {
    return _then(_self.copyWith(second: value));
  });
}
}


/// Adds pattern-matching-related methods to [SolvedPair].
extension SolvedPairPatterns on SolvedPair {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SolvedPair value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SolvedPair() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SolvedPair value)  $default,){
final _that = this;
switch (_that) {
case _SolvedPair():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SolvedPair value)?  $default,){
final _that = this;
switch (_that) {
case _SolvedPair() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( GameTile identity,  SolvedSpot first,  SolvedSpot second)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SolvedPair() when $default != null:
return $default(_that.identity,_that.first,_that.second);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( GameTile identity,  SolvedSpot first,  SolvedSpot second)  $default,) {final _that = this;
switch (_that) {
case _SolvedPair():
return $default(_that.identity,_that.first,_that.second);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( GameTile identity,  SolvedSpot first,  SolvedSpot second)?  $default,) {final _that = this;
switch (_that) {
case _SolvedPair() when $default != null:
return $default(_that.identity,_that.first,_that.second);case _:
  return null;

}
}

}

/// @nodoc


class _SolvedPair implements SolvedPair {
  const _SolvedPair({required this.identity, required this.first, required this.second});
  

@override final  GameTile identity;
@override final  SolvedSpot first;
@override final  SolvedSpot second;

/// Create a copy of SolvedPair
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SolvedPairCopyWith<_SolvedPair> get copyWith => __$SolvedPairCopyWithImpl<_SolvedPair>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SolvedPair&&(identical(other.identity, identity) || other.identity == identity)&&(identical(other.first, first) || other.first == first)&&(identical(other.second, second) || other.second == second));
}


@override
int get hashCode => Object.hash(runtimeType,identity,first,second);

@override
String toString() {
  return 'SolvedPair(identity: $identity, first: $first, second: $second)';
}


}

/// @nodoc
abstract mixin class _$SolvedPairCopyWith<$Res> implements $SolvedPairCopyWith<$Res> {
  factory _$SolvedPairCopyWith(_SolvedPair value, $Res Function(_SolvedPair) _then) = __$SolvedPairCopyWithImpl;
@override @useResult
$Res call({
 GameTile identity, SolvedSpot first, SolvedSpot second
});


@override $GameTileCopyWith<$Res> get identity;@override $SolvedSpotCopyWith<$Res> get first;@override $SolvedSpotCopyWith<$Res> get second;

}
/// @nodoc
class __$SolvedPairCopyWithImpl<$Res>
    implements _$SolvedPairCopyWith<$Res> {
  __$SolvedPairCopyWithImpl(this._self, this._then);

  final _SolvedPair _self;
  final $Res Function(_SolvedPair) _then;

/// Create a copy of SolvedPair
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? identity = null,Object? first = null,Object? second = null,}) {
  return _then(_SolvedPair(
identity: null == identity ? _self.identity : identity // ignore: cast_nullable_to_non_nullable
as GameTile,first: null == first ? _self.first : first // ignore: cast_nullable_to_non_nullable
as SolvedSpot,second: null == second ? _self.second : second // ignore: cast_nullable_to_non_nullable
as SolvedSpot,
  ));
}

/// Create a copy of SolvedPair
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$GameTileCopyWith<$Res> get identity {
  
  return $GameTileCopyWith<$Res>(_self.identity, (value) {
    return _then(_self.copyWith(identity: value));
  });
}/// Create a copy of SolvedPair
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SolvedSpotCopyWith<$Res> get first {
  
  return $SolvedSpotCopyWith<$Res>(_self.first, (value) {
    return _then(_self.copyWith(first: value));
  });
}/// Create a copy of SolvedPair
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SolvedSpotCopyWith<$Res> get second {
  
  return $SolvedSpotCopyWith<$Res>(_self.second, (value) {
    return _then(_self.copyWith(second: value));
  });
}
}

// dart format on
