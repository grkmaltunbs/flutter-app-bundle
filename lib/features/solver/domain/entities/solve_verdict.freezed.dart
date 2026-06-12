// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'solve_verdict.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$SolveVerdict {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SolveVerdict);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'SolveVerdict()';
}


}

/// @nodoc
class $SolveVerdictCopyWith<$Res>  {
$SolveVerdictCopyWith(SolveVerdict _, $Res Function(SolveVerdict) __);
}


/// Adds pattern-matching-related methods to [SolveVerdict].
extension SolveVerdictPatterns on SolveVerdict {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( Opens101 value)?  opens101,TResult Function( DoesNotOpen101 value)?  doesNotOpen101,TResult Function( OkeyOutcome value)?  okeyOutcome,required TResult orElse(),}){
final _that = this;
switch (_that) {
case Opens101() when opens101 != null:
return opens101(_that);case DoesNotOpen101() when doesNotOpen101 != null:
return doesNotOpen101(_that);case OkeyOutcome() when okeyOutcome != null:
return okeyOutcome(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( Opens101 value)  opens101,required TResult Function( DoesNotOpen101 value)  doesNotOpen101,required TResult Function( OkeyOutcome value)  okeyOutcome,}){
final _that = this;
switch (_that) {
case Opens101():
return opens101(_that);case DoesNotOpen101():
return doesNotOpen101(_that);case OkeyOutcome():
return okeyOutcome(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( Opens101 value)?  opens101,TResult? Function( DoesNotOpen101 value)?  doesNotOpen101,TResult? Function( OkeyOutcome value)?  okeyOutcome,}){
final _that = this;
switch (_that) {
case Opens101() when opens101 != null:
return opens101(_that);case DoesNotOpen101() when doesNotOpen101 != null:
return doesNotOpen101(_that);case OkeyOutcome() when okeyOutcome != null:
return okeyOutcome(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( int score,  OpenPath via)?  opens101,TResult Function( int score,  int pointsShort)?  doesNotOpen101,TResult Function( int tilesToWin,  OkeyPath via)?  okeyOutcome,required TResult orElse(),}) {final _that = this;
switch (_that) {
case Opens101() when opens101 != null:
return opens101(_that.score,_that.via);case DoesNotOpen101() when doesNotOpen101 != null:
return doesNotOpen101(_that.score,_that.pointsShort);case OkeyOutcome() when okeyOutcome != null:
return okeyOutcome(_that.tilesToWin,_that.via);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( int score,  OpenPath via)  opens101,required TResult Function( int score,  int pointsShort)  doesNotOpen101,required TResult Function( int tilesToWin,  OkeyPath via)  okeyOutcome,}) {final _that = this;
switch (_that) {
case Opens101():
return opens101(_that.score,_that.via);case DoesNotOpen101():
return doesNotOpen101(_that.score,_that.pointsShort);case OkeyOutcome():
return okeyOutcome(_that.tilesToWin,_that.via);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( int score,  OpenPath via)?  opens101,TResult? Function( int score,  int pointsShort)?  doesNotOpen101,TResult? Function( int tilesToWin,  OkeyPath via)?  okeyOutcome,}) {final _that = this;
switch (_that) {
case Opens101() when opens101 != null:
return opens101(_that.score,_that.via);case DoesNotOpen101() when doesNotOpen101 != null:
return doesNotOpen101(_that.score,_that.pointsShort);case OkeyOutcome() when okeyOutcome != null:
return okeyOutcome(_that.tilesToWin,_that.via);case _:
  return null;

}
}

}

/// @nodoc


class Opens101 implements SolveVerdict {
  const Opens101({required this.score, required this.via});
  

 final  int score;
 final  OpenPath via;

/// Create a copy of SolveVerdict
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$Opens101CopyWith<Opens101> get copyWith => _$Opens101CopyWithImpl<Opens101>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Opens101&&(identical(other.score, score) || other.score == score)&&(identical(other.via, via) || other.via == via));
}


@override
int get hashCode => Object.hash(runtimeType,score,via);

@override
String toString() {
  return 'SolveVerdict.opens101(score: $score, via: $via)';
}


}

/// @nodoc
abstract mixin class $Opens101CopyWith<$Res> implements $SolveVerdictCopyWith<$Res> {
  factory $Opens101CopyWith(Opens101 value, $Res Function(Opens101) _then) = _$Opens101CopyWithImpl;
@useResult
$Res call({
 int score, OpenPath via
});




}
/// @nodoc
class _$Opens101CopyWithImpl<$Res>
    implements $Opens101CopyWith<$Res> {
  _$Opens101CopyWithImpl(this._self, this._then);

  final Opens101 _self;
  final $Res Function(Opens101) _then;

/// Create a copy of SolveVerdict
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? score = null,Object? via = null,}) {
  return _then(Opens101(
score: null == score ? _self.score : score // ignore: cast_nullable_to_non_nullable
as int,via: null == via ? _self.via : via // ignore: cast_nullable_to_non_nullable
as OpenPath,
  ));
}


}

/// @nodoc


class DoesNotOpen101 implements SolveVerdict {
  const DoesNotOpen101({required this.score, required this.pointsShort});
  

 final  int score;
 final  int pointsShort;

/// Create a copy of SolveVerdict
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DoesNotOpen101CopyWith<DoesNotOpen101> get copyWith => _$DoesNotOpen101CopyWithImpl<DoesNotOpen101>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DoesNotOpen101&&(identical(other.score, score) || other.score == score)&&(identical(other.pointsShort, pointsShort) || other.pointsShort == pointsShort));
}


@override
int get hashCode => Object.hash(runtimeType,score,pointsShort);

@override
String toString() {
  return 'SolveVerdict.doesNotOpen101(score: $score, pointsShort: $pointsShort)';
}


}

/// @nodoc
abstract mixin class $DoesNotOpen101CopyWith<$Res> implements $SolveVerdictCopyWith<$Res> {
  factory $DoesNotOpen101CopyWith(DoesNotOpen101 value, $Res Function(DoesNotOpen101) _then) = _$DoesNotOpen101CopyWithImpl;
@useResult
$Res call({
 int score, int pointsShort
});




}
/// @nodoc
class _$DoesNotOpen101CopyWithImpl<$Res>
    implements $DoesNotOpen101CopyWith<$Res> {
  _$DoesNotOpen101CopyWithImpl(this._self, this._then);

  final DoesNotOpen101 _self;
  final $Res Function(DoesNotOpen101) _then;

/// Create a copy of SolveVerdict
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? score = null,Object? pointsShort = null,}) {
  return _then(DoesNotOpen101(
score: null == score ? _self.score : score // ignore: cast_nullable_to_non_nullable
as int,pointsShort: null == pointsShort ? _self.pointsShort : pointsShort // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc


class OkeyOutcome implements SolveVerdict {
  const OkeyOutcome({required this.tilesToWin, required this.via});
  

 final  int tilesToWin;
 final  OkeyPath via;

/// Create a copy of SolveVerdict
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$OkeyOutcomeCopyWith<OkeyOutcome> get copyWith => _$OkeyOutcomeCopyWithImpl<OkeyOutcome>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is OkeyOutcome&&(identical(other.tilesToWin, tilesToWin) || other.tilesToWin == tilesToWin)&&(identical(other.via, via) || other.via == via));
}


@override
int get hashCode => Object.hash(runtimeType,tilesToWin,via);

@override
String toString() {
  return 'SolveVerdict.okeyOutcome(tilesToWin: $tilesToWin, via: $via)';
}


}

/// @nodoc
abstract mixin class $OkeyOutcomeCopyWith<$Res> implements $SolveVerdictCopyWith<$Res> {
  factory $OkeyOutcomeCopyWith(OkeyOutcome value, $Res Function(OkeyOutcome) _then) = _$OkeyOutcomeCopyWithImpl;
@useResult
$Res call({
 int tilesToWin, OkeyPath via
});




}
/// @nodoc
class _$OkeyOutcomeCopyWithImpl<$Res>
    implements $OkeyOutcomeCopyWith<$Res> {
  _$OkeyOutcomeCopyWithImpl(this._self, this._then);

  final OkeyOutcome _self;
  final $Res Function(OkeyOutcome) _then;

/// Create a copy of SolveVerdict
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? tilesToWin = null,Object? via = null,}) {
  return _then(OkeyOutcome(
tilesToWin: null == tilesToWin ? _self.tilesToWin : tilesToWin // ignore: cast_nullable_to_non_nullable
as int,via: null == via ? _self.via : via // ignore: cast_nullable_to_non_nullable
as OkeyPath,
  ));
}


}

// dart format on
