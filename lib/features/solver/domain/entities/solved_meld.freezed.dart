// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'solved_meld.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$SolvedMeld {

 MeldKind get kind; List<SolvedSpot> get spots; int get points;
/// Create a copy of SolvedMeld
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SolvedMeldCopyWith<SolvedMeld> get copyWith => _$SolvedMeldCopyWithImpl<SolvedMeld>(this as SolvedMeld, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SolvedMeld&&(identical(other.kind, kind) || other.kind == kind)&&const DeepCollectionEquality().equals(other.spots, spots)&&(identical(other.points, points) || other.points == points));
}


@override
int get hashCode => Object.hash(runtimeType,kind,const DeepCollectionEquality().hash(spots),points);

@override
String toString() {
  return 'SolvedMeld(kind: $kind, spots: $spots, points: $points)';
}


}

/// @nodoc
abstract mixin class $SolvedMeldCopyWith<$Res>  {
  factory $SolvedMeldCopyWith(SolvedMeld value, $Res Function(SolvedMeld) _then) = _$SolvedMeldCopyWithImpl;
@useResult
$Res call({
 MeldKind kind, List<SolvedSpot> spots, int points
});




}
/// @nodoc
class _$SolvedMeldCopyWithImpl<$Res>
    implements $SolvedMeldCopyWith<$Res> {
  _$SolvedMeldCopyWithImpl(this._self, this._then);

  final SolvedMeld _self;
  final $Res Function(SolvedMeld) _then;

/// Create a copy of SolvedMeld
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? kind = null,Object? spots = null,Object? points = null,}) {
  return _then(_self.copyWith(
kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as MeldKind,spots: null == spots ? _self.spots : spots // ignore: cast_nullable_to_non_nullable
as List<SolvedSpot>,points: null == points ? _self.points : points // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [SolvedMeld].
extension SolvedMeldPatterns on SolvedMeld {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SolvedMeld value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SolvedMeld() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SolvedMeld value)  $default,){
final _that = this;
switch (_that) {
case _SolvedMeld():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SolvedMeld value)?  $default,){
final _that = this;
switch (_that) {
case _SolvedMeld() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( MeldKind kind,  List<SolvedSpot> spots,  int points)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SolvedMeld() when $default != null:
return $default(_that.kind,_that.spots,_that.points);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( MeldKind kind,  List<SolvedSpot> spots,  int points)  $default,) {final _that = this;
switch (_that) {
case _SolvedMeld():
return $default(_that.kind,_that.spots,_that.points);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( MeldKind kind,  List<SolvedSpot> spots,  int points)?  $default,) {final _that = this;
switch (_that) {
case _SolvedMeld() when $default != null:
return $default(_that.kind,_that.spots,_that.points);case _:
  return null;

}
}

}

/// @nodoc


class _SolvedMeld implements SolvedMeld {
  const _SolvedMeld({required this.kind, required final  List<SolvedSpot> spots, required this.points}): _spots = spots;
  

@override final  MeldKind kind;
 final  List<SolvedSpot> _spots;
@override List<SolvedSpot> get spots {
  if (_spots is EqualUnmodifiableListView) return _spots;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_spots);
}

@override final  int points;

/// Create a copy of SolvedMeld
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SolvedMeldCopyWith<_SolvedMeld> get copyWith => __$SolvedMeldCopyWithImpl<_SolvedMeld>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SolvedMeld&&(identical(other.kind, kind) || other.kind == kind)&&const DeepCollectionEquality().equals(other._spots, _spots)&&(identical(other.points, points) || other.points == points));
}


@override
int get hashCode => Object.hash(runtimeType,kind,const DeepCollectionEquality().hash(_spots),points);

@override
String toString() {
  return 'SolvedMeld(kind: $kind, spots: $spots, points: $points)';
}


}

/// @nodoc
abstract mixin class _$SolvedMeldCopyWith<$Res> implements $SolvedMeldCopyWith<$Res> {
  factory _$SolvedMeldCopyWith(_SolvedMeld value, $Res Function(_SolvedMeld) _then) = __$SolvedMeldCopyWithImpl;
@override @useResult
$Res call({
 MeldKind kind, List<SolvedSpot> spots, int points
});




}
/// @nodoc
class __$SolvedMeldCopyWithImpl<$Res>
    implements _$SolvedMeldCopyWith<$Res> {
  __$SolvedMeldCopyWithImpl(this._self, this._then);

  final _SolvedMeld _self;
  final $Res Function(_SolvedMeld) _then;

/// Create a copy of SolvedMeld
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? kind = null,Object? spots = null,Object? points = null,}) {
  return _then(_SolvedMeld(
kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as MeldKind,spots: null == spots ? _self._spots : spots // ignore: cast_nullable_to_non_nullable
as List<SolvedSpot>,points: null == points ? _self.points : points // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
