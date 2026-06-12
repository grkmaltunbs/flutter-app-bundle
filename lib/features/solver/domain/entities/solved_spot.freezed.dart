// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'solved_spot.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$SolvedSpot {

 GameTile get playsAs;
/// Create a copy of SolvedSpot
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SolvedSpotCopyWith<SolvedSpot> get copyWith => _$SolvedSpotCopyWithImpl<SolvedSpot>(this as SolvedSpot, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SolvedSpot&&(identical(other.playsAs, playsAs) || other.playsAs == playsAs));
}


@override
int get hashCode => Object.hash(runtimeType,playsAs);

@override
String toString() {
  return 'SolvedSpot(playsAs: $playsAs)';
}


}

/// @nodoc
abstract mixin class $SolvedSpotCopyWith<$Res>  {
  factory $SolvedSpotCopyWith(SolvedSpot value, $Res Function(SolvedSpot) _then) = _$SolvedSpotCopyWithImpl;
@useResult
$Res call({
 GameTile playsAs
});


$GameTileCopyWith<$Res> get playsAs;

}
/// @nodoc
class _$SolvedSpotCopyWithImpl<$Res>
    implements $SolvedSpotCopyWith<$Res> {
  _$SolvedSpotCopyWithImpl(this._self, this._then);

  final SolvedSpot _self;
  final $Res Function(SolvedSpot) _then;

/// Create a copy of SolvedSpot
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? playsAs = null,}) {
  return _then(_self.copyWith(
playsAs: null == playsAs ? _self.playsAs : playsAs // ignore: cast_nullable_to_non_nullable
as GameTile,
  ));
}
/// Create a copy of SolvedSpot
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$GameTileCopyWith<$Res> get playsAs {
  
  return $GameTileCopyWith<$Res>(_self.playsAs, (value) {
    return _then(_self.copyWith(playsAs: value));
  });
}
}


/// Adds pattern-matching-related methods to [SolvedSpot].
extension SolvedSpotPatterns on SolvedSpot {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( RackSpot value)?  rackTile,TResult Function( WildSpot value)?  wild,TResult Function( NeededSpot value)?  needed,required TResult orElse(),}){
final _that = this;
switch (_that) {
case RackSpot() when rackTile != null:
return rackTile(_that);case WildSpot() when wild != null:
return wild(_that);case NeededSpot() when needed != null:
return needed(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( RackSpot value)  rackTile,required TResult Function( WildSpot value)  wild,required TResult Function( NeededSpot value)  needed,}){
final _that = this;
switch (_that) {
case RackSpot():
return rackTile(_that);case WildSpot():
return wild(_that);case NeededSpot():
return needed(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( RackSpot value)?  rackTile,TResult? Function( WildSpot value)?  wild,TResult? Function( NeededSpot value)?  needed,}){
final _that = this;
switch (_that) {
case RackSpot() when rackTile != null:
return rackTile(_that);case WildSpot() when wild != null:
return wild(_that);case NeededSpot() when needed != null:
return needed(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( GameTile physical,  int rackIndex,  GameTile playsAs)?  rackTile,TResult Function( GameTile physical,  int rackIndex,  GameTile playsAs)?  wild,TResult Function( GameTile playsAs)?  needed,required TResult orElse(),}) {final _that = this;
switch (_that) {
case RackSpot() when rackTile != null:
return rackTile(_that.physical,_that.rackIndex,_that.playsAs);case WildSpot() when wild != null:
return wild(_that.physical,_that.rackIndex,_that.playsAs);case NeededSpot() when needed != null:
return needed(_that.playsAs);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( GameTile physical,  int rackIndex,  GameTile playsAs)  rackTile,required TResult Function( GameTile physical,  int rackIndex,  GameTile playsAs)  wild,required TResult Function( GameTile playsAs)  needed,}) {final _that = this;
switch (_that) {
case RackSpot():
return rackTile(_that.physical,_that.rackIndex,_that.playsAs);case WildSpot():
return wild(_that.physical,_that.rackIndex,_that.playsAs);case NeededSpot():
return needed(_that.playsAs);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( GameTile physical,  int rackIndex,  GameTile playsAs)?  rackTile,TResult? Function( GameTile physical,  int rackIndex,  GameTile playsAs)?  wild,TResult? Function( GameTile playsAs)?  needed,}) {final _that = this;
switch (_that) {
case RackSpot() when rackTile != null:
return rackTile(_that.physical,_that.rackIndex,_that.playsAs);case WildSpot() when wild != null:
return wild(_that.physical,_that.rackIndex,_that.playsAs);case NeededSpot() when needed != null:
return needed(_that.playsAs);case _:
  return null;

}
}

}

/// @nodoc


class RackSpot implements SolvedSpot {
  const RackSpot({required this.physical, required this.rackIndex, required this.playsAs});
  

 final  GameTile physical;
 final  int rackIndex;
@override final  GameTile playsAs;

/// Create a copy of SolvedSpot
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RackSpotCopyWith<RackSpot> get copyWith => _$RackSpotCopyWithImpl<RackSpot>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RackSpot&&(identical(other.physical, physical) || other.physical == physical)&&(identical(other.rackIndex, rackIndex) || other.rackIndex == rackIndex)&&(identical(other.playsAs, playsAs) || other.playsAs == playsAs));
}


@override
int get hashCode => Object.hash(runtimeType,physical,rackIndex,playsAs);

@override
String toString() {
  return 'SolvedSpot.rackTile(physical: $physical, rackIndex: $rackIndex, playsAs: $playsAs)';
}


}

/// @nodoc
abstract mixin class $RackSpotCopyWith<$Res> implements $SolvedSpotCopyWith<$Res> {
  factory $RackSpotCopyWith(RackSpot value, $Res Function(RackSpot) _then) = _$RackSpotCopyWithImpl;
@override @useResult
$Res call({
 GameTile physical, int rackIndex, GameTile playsAs
});


$GameTileCopyWith<$Res> get physical;@override $GameTileCopyWith<$Res> get playsAs;

}
/// @nodoc
class _$RackSpotCopyWithImpl<$Res>
    implements $RackSpotCopyWith<$Res> {
  _$RackSpotCopyWithImpl(this._self, this._then);

  final RackSpot _self;
  final $Res Function(RackSpot) _then;

/// Create a copy of SolvedSpot
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? physical = null,Object? rackIndex = null,Object? playsAs = null,}) {
  return _then(RackSpot(
physical: null == physical ? _self.physical : physical // ignore: cast_nullable_to_non_nullable
as GameTile,rackIndex: null == rackIndex ? _self.rackIndex : rackIndex // ignore: cast_nullable_to_non_nullable
as int,playsAs: null == playsAs ? _self.playsAs : playsAs // ignore: cast_nullable_to_non_nullable
as GameTile,
  ));
}

/// Create a copy of SolvedSpot
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$GameTileCopyWith<$Res> get physical {
  
  return $GameTileCopyWith<$Res>(_self.physical, (value) {
    return _then(_self.copyWith(physical: value));
  });
}/// Create a copy of SolvedSpot
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$GameTileCopyWith<$Res> get playsAs {
  
  return $GameTileCopyWith<$Res>(_self.playsAs, (value) {
    return _then(_self.copyWith(playsAs: value));
  });
}
}

/// @nodoc


class WildSpot implements SolvedSpot {
  const WildSpot({required this.physical, required this.rackIndex, required this.playsAs});
  

 final  GameTile physical;
 final  int rackIndex;
@override final  GameTile playsAs;

/// Create a copy of SolvedSpot
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$WildSpotCopyWith<WildSpot> get copyWith => _$WildSpotCopyWithImpl<WildSpot>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is WildSpot&&(identical(other.physical, physical) || other.physical == physical)&&(identical(other.rackIndex, rackIndex) || other.rackIndex == rackIndex)&&(identical(other.playsAs, playsAs) || other.playsAs == playsAs));
}


@override
int get hashCode => Object.hash(runtimeType,physical,rackIndex,playsAs);

@override
String toString() {
  return 'SolvedSpot.wild(physical: $physical, rackIndex: $rackIndex, playsAs: $playsAs)';
}


}

/// @nodoc
abstract mixin class $WildSpotCopyWith<$Res> implements $SolvedSpotCopyWith<$Res> {
  factory $WildSpotCopyWith(WildSpot value, $Res Function(WildSpot) _then) = _$WildSpotCopyWithImpl;
@override @useResult
$Res call({
 GameTile physical, int rackIndex, GameTile playsAs
});


$GameTileCopyWith<$Res> get physical;@override $GameTileCopyWith<$Res> get playsAs;

}
/// @nodoc
class _$WildSpotCopyWithImpl<$Res>
    implements $WildSpotCopyWith<$Res> {
  _$WildSpotCopyWithImpl(this._self, this._then);

  final WildSpot _self;
  final $Res Function(WildSpot) _then;

/// Create a copy of SolvedSpot
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? physical = null,Object? rackIndex = null,Object? playsAs = null,}) {
  return _then(WildSpot(
physical: null == physical ? _self.physical : physical // ignore: cast_nullable_to_non_nullable
as GameTile,rackIndex: null == rackIndex ? _self.rackIndex : rackIndex // ignore: cast_nullable_to_non_nullable
as int,playsAs: null == playsAs ? _self.playsAs : playsAs // ignore: cast_nullable_to_non_nullable
as GameTile,
  ));
}

/// Create a copy of SolvedSpot
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$GameTileCopyWith<$Res> get physical {
  
  return $GameTileCopyWith<$Res>(_self.physical, (value) {
    return _then(_self.copyWith(physical: value));
  });
}/// Create a copy of SolvedSpot
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$GameTileCopyWith<$Res> get playsAs {
  
  return $GameTileCopyWith<$Res>(_self.playsAs, (value) {
    return _then(_self.copyWith(playsAs: value));
  });
}
}

/// @nodoc


class NeededSpot implements SolvedSpot {
  const NeededSpot({required this.playsAs});
  

@override final  GameTile playsAs;

/// Create a copy of SolvedSpot
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$NeededSpotCopyWith<NeededSpot> get copyWith => _$NeededSpotCopyWithImpl<NeededSpot>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is NeededSpot&&(identical(other.playsAs, playsAs) || other.playsAs == playsAs));
}


@override
int get hashCode => Object.hash(runtimeType,playsAs);

@override
String toString() {
  return 'SolvedSpot.needed(playsAs: $playsAs)';
}


}

/// @nodoc
abstract mixin class $NeededSpotCopyWith<$Res> implements $SolvedSpotCopyWith<$Res> {
  factory $NeededSpotCopyWith(NeededSpot value, $Res Function(NeededSpot) _then) = _$NeededSpotCopyWithImpl;
@override @useResult
$Res call({
 GameTile playsAs
});


@override $GameTileCopyWith<$Res> get playsAs;

}
/// @nodoc
class _$NeededSpotCopyWithImpl<$Res>
    implements $NeededSpotCopyWith<$Res> {
  _$NeededSpotCopyWithImpl(this._self, this._then);

  final NeededSpot _self;
  final $Res Function(NeededSpot) _then;

/// Create a copy of SolvedSpot
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? playsAs = null,}) {
  return _then(NeededSpot(
playsAs: null == playsAs ? _self.playsAs : playsAs // ignore: cast_nullable_to_non_nullable
as GameTile,
  ));
}

/// Create a copy of SolvedSpot
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$GameTileCopyWith<$Res> get playsAs {
  
  return $GameTileCopyWith<$Res>(_self.playsAs, (value) {
    return _then(_self.copyWith(playsAs: value));
  });
}
}

// dart format on
