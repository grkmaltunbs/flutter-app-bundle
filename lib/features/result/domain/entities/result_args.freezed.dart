// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'result_args.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ResultArgs {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ResultArgs);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'ResultArgs()';
}


}

/// @nodoc
class $ResultArgsCopyWith<$Res>  {
$ResultArgsCopyWith(ResultArgs _, $Res Function(ResultArgs) __);
}


/// Adds pattern-matching-related methods to [ResultArgs].
extension ResultArgsPatterns on ResultArgs {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( ResultArgsFresh value)?  fresh,TResult Function( ResultArgsReplay value)?  replay,required TResult orElse(),}){
final _that = this;
switch (_that) {
case ResultArgsFresh() when fresh != null:
return fresh(_that);case ResultArgsReplay() when replay != null:
return replay(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( ResultArgsFresh value)  fresh,required TResult Function( ResultArgsReplay value)  replay,}){
final _that = this;
switch (_that) {
case ResultArgsFresh():
return fresh(_that);case ResultArgsReplay():
return replay(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( ResultArgsFresh value)?  fresh,TResult? Function( ResultArgsReplay value)?  replay,}){
final _that = this;
switch (_that) {
case ResultArgsFresh() when fresh != null:
return fresh(_that);case ResultArgsReplay() when replay != null:
return replay(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( ReviewOutcome outcome)?  fresh,TResult Function( Scan scan)?  replay,required TResult orElse(),}) {final _that = this;
switch (_that) {
case ResultArgsFresh() when fresh != null:
return fresh(_that.outcome);case ResultArgsReplay() when replay != null:
return replay(_that.scan);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( ReviewOutcome outcome)  fresh,required TResult Function( Scan scan)  replay,}) {final _that = this;
switch (_that) {
case ResultArgsFresh():
return fresh(_that.outcome);case ResultArgsReplay():
return replay(_that.scan);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( ReviewOutcome outcome)?  fresh,TResult? Function( Scan scan)?  replay,}) {final _that = this;
switch (_that) {
case ResultArgsFresh() when fresh != null:
return fresh(_that.outcome);case ResultArgsReplay() when replay != null:
return replay(_that.scan);case _:
  return null;

}
}

}

/// @nodoc


class ResultArgsFresh extends ResultArgs {
  const ResultArgsFresh(this.outcome): super._();
  

 final  ReviewOutcome outcome;

/// Create a copy of ResultArgs
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ResultArgsFreshCopyWith<ResultArgsFresh> get copyWith => _$ResultArgsFreshCopyWithImpl<ResultArgsFresh>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ResultArgsFresh&&(identical(other.outcome, outcome) || other.outcome == outcome));
}


@override
int get hashCode => Object.hash(runtimeType,outcome);

@override
String toString() {
  return 'ResultArgs.fresh(outcome: $outcome)';
}


}

/// @nodoc
abstract mixin class $ResultArgsFreshCopyWith<$Res> implements $ResultArgsCopyWith<$Res> {
  factory $ResultArgsFreshCopyWith(ResultArgsFresh value, $Res Function(ResultArgsFresh) _then) = _$ResultArgsFreshCopyWithImpl;
@useResult
$Res call({
 ReviewOutcome outcome
});


$ReviewOutcomeCopyWith<$Res> get outcome;

}
/// @nodoc
class _$ResultArgsFreshCopyWithImpl<$Res>
    implements $ResultArgsFreshCopyWith<$Res> {
  _$ResultArgsFreshCopyWithImpl(this._self, this._then);

  final ResultArgsFresh _self;
  final $Res Function(ResultArgsFresh) _then;

/// Create a copy of ResultArgs
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? outcome = null,}) {
  return _then(ResultArgsFresh(
null == outcome ? _self.outcome : outcome // ignore: cast_nullable_to_non_nullable
as ReviewOutcome,
  ));
}

/// Create a copy of ResultArgs
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ReviewOutcomeCopyWith<$Res> get outcome {
  
  return $ReviewOutcomeCopyWith<$Res>(_self.outcome, (value) {
    return _then(_self.copyWith(outcome: value));
  });
}
}

/// @nodoc


class ResultArgsReplay extends ResultArgs {
  const ResultArgsReplay(this.scan): super._();
  

 final  Scan scan;

/// Create a copy of ResultArgs
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ResultArgsReplayCopyWith<ResultArgsReplay> get copyWith => _$ResultArgsReplayCopyWithImpl<ResultArgsReplay>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ResultArgsReplay&&(identical(other.scan, scan) || other.scan == scan));
}


@override
int get hashCode => Object.hash(runtimeType,scan);

@override
String toString() {
  return 'ResultArgs.replay(scan: $scan)';
}


}

/// @nodoc
abstract mixin class $ResultArgsReplayCopyWith<$Res> implements $ResultArgsCopyWith<$Res> {
  factory $ResultArgsReplayCopyWith(ResultArgsReplay value, $Res Function(ResultArgsReplay) _then) = _$ResultArgsReplayCopyWithImpl;
@useResult
$Res call({
 Scan scan
});


$ScanCopyWith<$Res> get scan;

}
/// @nodoc
class _$ResultArgsReplayCopyWithImpl<$Res>
    implements $ResultArgsReplayCopyWith<$Res> {
  _$ResultArgsReplayCopyWithImpl(this._self, this._then);

  final ResultArgsReplay _self;
  final $Res Function(ResultArgsReplay) _then;

/// Create a copy of ResultArgs
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? scan = null,}) {
  return _then(ResultArgsReplay(
null == scan ? _self.scan : scan // ignore: cast_nullable_to_non_nullable
as Scan,
  ));
}

/// Create a copy of ResultArgs
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ScanCopyWith<$Res> get scan {
  
  return $ScanCopyWith<$Res>(_self.scan, (value) {
    return _then(_self.copyWith(scan: value));
  });
}
}

// dart format on
