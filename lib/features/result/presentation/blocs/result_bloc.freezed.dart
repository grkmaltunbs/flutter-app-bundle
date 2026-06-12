// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'result_bloc.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ResultEvent {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ResultEvent);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'ResultEvent()';
}


}

/// @nodoc
class $ResultEventCopyWith<$Res>  {
$ResultEventCopyWith(ResultEvent _, $Res Function(ResultEvent) __);
}


/// Adds pattern-matching-related methods to [ResultEvent].
extension ResultEventPatterns on ResultEvent {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( ResultSolveRequested value)?  solveRequested,TResult Function( ResultLayoutToggled value)?  layoutToggled,TResult Function( ResultDetailUnlockGranted value)?  detailUnlockGranted,required TResult orElse(),}){
final _that = this;
switch (_that) {
case ResultSolveRequested() when solveRequested != null:
return solveRequested(_that);case ResultLayoutToggled() when layoutToggled != null:
return layoutToggled(_that);case ResultDetailUnlockGranted() when detailUnlockGranted != null:
return detailUnlockGranted(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( ResultSolveRequested value)  solveRequested,required TResult Function( ResultLayoutToggled value)  layoutToggled,required TResult Function( ResultDetailUnlockGranted value)  detailUnlockGranted,}){
final _that = this;
switch (_that) {
case ResultSolveRequested():
return solveRequested(_that);case ResultLayoutToggled():
return layoutToggled(_that);case ResultDetailUnlockGranted():
return detailUnlockGranted(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( ResultSolveRequested value)?  solveRequested,TResult? Function( ResultLayoutToggled value)?  layoutToggled,TResult? Function( ResultDetailUnlockGranted value)?  detailUnlockGranted,}){
final _that = this;
switch (_that) {
case ResultSolveRequested() when solveRequested != null:
return solveRequested(_that);case ResultLayoutToggled() when layoutToggled != null:
return layoutToggled(_that);case ResultDetailUnlockGranted() when detailUnlockGranted != null:
return detailUnlockGranted(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function()?  solveRequested,TResult Function( ResultLayout layout)?  layoutToggled,TResult Function()?  detailUnlockGranted,required TResult orElse(),}) {final _that = this;
switch (_that) {
case ResultSolveRequested() when solveRequested != null:
return solveRequested();case ResultLayoutToggled() when layoutToggled != null:
return layoutToggled(_that.layout);case ResultDetailUnlockGranted() when detailUnlockGranted != null:
return detailUnlockGranted();case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function()  solveRequested,required TResult Function( ResultLayout layout)  layoutToggled,required TResult Function()  detailUnlockGranted,}) {final _that = this;
switch (_that) {
case ResultSolveRequested():
return solveRequested();case ResultLayoutToggled():
return layoutToggled(_that.layout);case ResultDetailUnlockGranted():
return detailUnlockGranted();}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function()?  solveRequested,TResult? Function( ResultLayout layout)?  layoutToggled,TResult? Function()?  detailUnlockGranted,}) {final _that = this;
switch (_that) {
case ResultSolveRequested() when solveRequested != null:
return solveRequested();case ResultLayoutToggled() when layoutToggled != null:
return layoutToggled(_that.layout);case ResultDetailUnlockGranted() when detailUnlockGranted != null:
return detailUnlockGranted();case _:
  return null;

}
}

}

/// @nodoc


class ResultSolveRequested implements ResultEvent {
  const ResultSolveRequested();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ResultSolveRequested);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'ResultEvent.solveRequested()';
}


}




/// @nodoc


class ResultLayoutToggled implements ResultEvent {
  const ResultLayoutToggled(this.layout);
  

 final  ResultLayout layout;

/// Create a copy of ResultEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ResultLayoutToggledCopyWith<ResultLayoutToggled> get copyWith => _$ResultLayoutToggledCopyWithImpl<ResultLayoutToggled>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ResultLayoutToggled&&(identical(other.layout, layout) || other.layout == layout));
}


@override
int get hashCode => Object.hash(runtimeType,layout);

@override
String toString() {
  return 'ResultEvent.layoutToggled(layout: $layout)';
}


}

/// @nodoc
abstract mixin class $ResultLayoutToggledCopyWith<$Res> implements $ResultEventCopyWith<$Res> {
  factory $ResultLayoutToggledCopyWith(ResultLayoutToggled value, $Res Function(ResultLayoutToggled) _then) = _$ResultLayoutToggledCopyWithImpl;
@useResult
$Res call({
 ResultLayout layout
});




}
/// @nodoc
class _$ResultLayoutToggledCopyWithImpl<$Res>
    implements $ResultLayoutToggledCopyWith<$Res> {
  _$ResultLayoutToggledCopyWithImpl(this._self, this._then);

  final ResultLayoutToggled _self;
  final $Res Function(ResultLayoutToggled) _then;

/// Create a copy of ResultEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? layout = null,}) {
  return _then(ResultLayoutToggled(
null == layout ? _self.layout : layout // ignore: cast_nullable_to_non_nullable
as ResultLayout,
  ));
}


}

/// @nodoc


class ResultDetailUnlockGranted implements ResultEvent {
  const ResultDetailUnlockGranted();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ResultDetailUnlockGranted);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'ResultEvent.detailUnlockGranted()';
}


}




/// @nodoc
mixin _$ResultSolveStatus {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ResultSolveStatus);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'ResultSolveStatus()';
}


}

/// @nodoc
class $ResultSolveStatusCopyWith<$Res>  {
$ResultSolveStatusCopyWith(ResultSolveStatus _, $Res Function(ResultSolveStatus) __);
}


/// Adds pattern-matching-related methods to [ResultSolveStatus].
extension ResultSolveStatusPatterns on ResultSolveStatus {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( ResultSolving value)?  solving,TResult Function( ResultSolved value)?  solved,TResult Function( ResultSolveFailed value)?  failed,required TResult orElse(),}){
final _that = this;
switch (_that) {
case ResultSolving() when solving != null:
return solving(_that);case ResultSolved() when solved != null:
return solved(_that);case ResultSolveFailed() when failed != null:
return failed(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( ResultSolving value)  solving,required TResult Function( ResultSolved value)  solved,required TResult Function( ResultSolveFailed value)  failed,}){
final _that = this;
switch (_that) {
case ResultSolving():
return solving(_that);case ResultSolved():
return solved(_that);case ResultSolveFailed():
return failed(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( ResultSolving value)?  solving,TResult? Function( ResultSolved value)?  solved,TResult? Function( ResultSolveFailed value)?  failed,}){
final _that = this;
switch (_that) {
case ResultSolving() when solving != null:
return solving(_that);case ResultSolved() when solved != null:
return solved(_that);case ResultSolveFailed() when failed != null:
return failed(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function()?  solving,TResult Function( SolveResult result)?  solved,TResult Function()?  failed,required TResult orElse(),}) {final _that = this;
switch (_that) {
case ResultSolving() when solving != null:
return solving();case ResultSolved() when solved != null:
return solved(_that.result);case ResultSolveFailed() when failed != null:
return failed();case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function()  solving,required TResult Function( SolveResult result)  solved,required TResult Function()  failed,}) {final _that = this;
switch (_that) {
case ResultSolving():
return solving();case ResultSolved():
return solved(_that.result);case ResultSolveFailed():
return failed();}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function()?  solving,TResult? Function( SolveResult result)?  solved,TResult? Function()?  failed,}) {final _that = this;
switch (_that) {
case ResultSolving() when solving != null:
return solving();case ResultSolved() when solved != null:
return solved(_that.result);case ResultSolveFailed() when failed != null:
return failed();case _:
  return null;

}
}

}

/// @nodoc


class ResultSolving implements ResultSolveStatus {
  const ResultSolving();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ResultSolving);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'ResultSolveStatus.solving()';
}


}




/// @nodoc


class ResultSolved implements ResultSolveStatus {
  const ResultSolved(this.result);
  

 final  SolveResult result;

/// Create a copy of ResultSolveStatus
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ResultSolvedCopyWith<ResultSolved> get copyWith => _$ResultSolvedCopyWithImpl<ResultSolved>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ResultSolved&&(identical(other.result, result) || other.result == result));
}


@override
int get hashCode => Object.hash(runtimeType,result);

@override
String toString() {
  return 'ResultSolveStatus.solved(result: $result)';
}


}

/// @nodoc
abstract mixin class $ResultSolvedCopyWith<$Res> implements $ResultSolveStatusCopyWith<$Res> {
  factory $ResultSolvedCopyWith(ResultSolved value, $Res Function(ResultSolved) _then) = _$ResultSolvedCopyWithImpl;
@useResult
$Res call({
 SolveResult result
});


$SolveResultCopyWith<$Res> get result;

}
/// @nodoc
class _$ResultSolvedCopyWithImpl<$Res>
    implements $ResultSolvedCopyWith<$Res> {
  _$ResultSolvedCopyWithImpl(this._self, this._then);

  final ResultSolved _self;
  final $Res Function(ResultSolved) _then;

/// Create a copy of ResultSolveStatus
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? result = null,}) {
  return _then(ResultSolved(
null == result ? _self.result : result // ignore: cast_nullable_to_non_nullable
as SolveResult,
  ));
}

/// Create a copy of ResultSolveStatus
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SolveResultCopyWith<$Res> get result {
  
  return $SolveResultCopyWith<$Res>(_self.result, (value) {
    return _then(_self.copyWith(result: value));
  });
}
}

/// @nodoc


class ResultSolveFailed implements ResultSolveStatus {
  const ResultSolveFailed();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ResultSolveFailed);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'ResultSolveStatus.failed()';
}


}




/// @nodoc
mixin _$ResultState {

/// The confirmed review outcome this screen solves (fixed at creation).
 ReviewOutcome get outcome;/// The solve phase (solving / solved / failed).
 ResultSolveStatus get status;/// The chosen body layout; survives a retry.
 ResultLayout get layout;/// Whether the step-by-step reasoning is unlocked; survives a retry.
 bool get detailUnlocked;
/// Create a copy of ResultState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ResultStateCopyWith<ResultState> get copyWith => _$ResultStateCopyWithImpl<ResultState>(this as ResultState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ResultState&&(identical(other.outcome, outcome) || other.outcome == outcome)&&(identical(other.status, status) || other.status == status)&&(identical(other.layout, layout) || other.layout == layout)&&(identical(other.detailUnlocked, detailUnlocked) || other.detailUnlocked == detailUnlocked));
}


@override
int get hashCode => Object.hash(runtimeType,outcome,status,layout,detailUnlocked);

@override
String toString() {
  return 'ResultState(outcome: $outcome, status: $status, layout: $layout, detailUnlocked: $detailUnlocked)';
}


}

/// @nodoc
abstract mixin class $ResultStateCopyWith<$Res>  {
  factory $ResultStateCopyWith(ResultState value, $Res Function(ResultState) _then) = _$ResultStateCopyWithImpl;
@useResult
$Res call({
 ReviewOutcome outcome, ResultSolveStatus status, ResultLayout layout, bool detailUnlocked
});


$ReviewOutcomeCopyWith<$Res> get outcome;$ResultSolveStatusCopyWith<$Res> get status;

}
/// @nodoc
class _$ResultStateCopyWithImpl<$Res>
    implements $ResultStateCopyWith<$Res> {
  _$ResultStateCopyWithImpl(this._self, this._then);

  final ResultState _self;
  final $Res Function(ResultState) _then;

/// Create a copy of ResultState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? outcome = null,Object? status = null,Object? layout = null,Object? detailUnlocked = null,}) {
  return _then(_self.copyWith(
outcome: null == outcome ? _self.outcome : outcome // ignore: cast_nullable_to_non_nullable
as ReviewOutcome,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as ResultSolveStatus,layout: null == layout ? _self.layout : layout // ignore: cast_nullable_to_non_nullable
as ResultLayout,detailUnlocked: null == detailUnlocked ? _self.detailUnlocked : detailUnlocked // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}
/// Create a copy of ResultState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ReviewOutcomeCopyWith<$Res> get outcome {
  
  return $ReviewOutcomeCopyWith<$Res>(_self.outcome, (value) {
    return _then(_self.copyWith(outcome: value));
  });
}/// Create a copy of ResultState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ResultSolveStatusCopyWith<$Res> get status {
  
  return $ResultSolveStatusCopyWith<$Res>(_self.status, (value) {
    return _then(_self.copyWith(status: value));
  });
}
}


/// Adds pattern-matching-related methods to [ResultState].
extension ResultStatePatterns on ResultState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ResultState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ResultState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ResultState value)  $default,){
final _that = this;
switch (_that) {
case _ResultState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ResultState value)?  $default,){
final _that = this;
switch (_that) {
case _ResultState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( ReviewOutcome outcome,  ResultSolveStatus status,  ResultLayout layout,  bool detailUnlocked)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ResultState() when $default != null:
return $default(_that.outcome,_that.status,_that.layout,_that.detailUnlocked);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( ReviewOutcome outcome,  ResultSolveStatus status,  ResultLayout layout,  bool detailUnlocked)  $default,) {final _that = this;
switch (_that) {
case _ResultState():
return $default(_that.outcome,_that.status,_that.layout,_that.detailUnlocked);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( ReviewOutcome outcome,  ResultSolveStatus status,  ResultLayout layout,  bool detailUnlocked)?  $default,) {final _that = this;
switch (_that) {
case _ResultState() when $default != null:
return $default(_that.outcome,_that.status,_that.layout,_that.detailUnlocked);case _:
  return null;

}
}

}

/// @nodoc


class _ResultState implements ResultState {
  const _ResultState({required this.outcome, required this.status, this.layout = ResultLayout.rack, this.detailUnlocked = false});
  

/// The confirmed review outcome this screen solves (fixed at creation).
@override final  ReviewOutcome outcome;
/// The solve phase (solving / solved / failed).
@override final  ResultSolveStatus status;
/// The chosen body layout; survives a retry.
@override@JsonKey() final  ResultLayout layout;
/// Whether the step-by-step reasoning is unlocked; survives a retry.
@override@JsonKey() final  bool detailUnlocked;

/// Create a copy of ResultState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ResultStateCopyWith<_ResultState> get copyWith => __$ResultStateCopyWithImpl<_ResultState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ResultState&&(identical(other.outcome, outcome) || other.outcome == outcome)&&(identical(other.status, status) || other.status == status)&&(identical(other.layout, layout) || other.layout == layout)&&(identical(other.detailUnlocked, detailUnlocked) || other.detailUnlocked == detailUnlocked));
}


@override
int get hashCode => Object.hash(runtimeType,outcome,status,layout,detailUnlocked);

@override
String toString() {
  return 'ResultState(outcome: $outcome, status: $status, layout: $layout, detailUnlocked: $detailUnlocked)';
}


}

/// @nodoc
abstract mixin class _$ResultStateCopyWith<$Res> implements $ResultStateCopyWith<$Res> {
  factory _$ResultStateCopyWith(_ResultState value, $Res Function(_ResultState) _then) = __$ResultStateCopyWithImpl;
@override @useResult
$Res call({
 ReviewOutcome outcome, ResultSolveStatus status, ResultLayout layout, bool detailUnlocked
});


@override $ReviewOutcomeCopyWith<$Res> get outcome;@override $ResultSolveStatusCopyWith<$Res> get status;

}
/// @nodoc
class __$ResultStateCopyWithImpl<$Res>
    implements _$ResultStateCopyWith<$Res> {
  __$ResultStateCopyWithImpl(this._self, this._then);

  final _ResultState _self;
  final $Res Function(_ResultState) _then;

/// Create a copy of ResultState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? outcome = null,Object? status = null,Object? layout = null,Object? detailUnlocked = null,}) {
  return _then(_ResultState(
outcome: null == outcome ? _self.outcome : outcome // ignore: cast_nullable_to_non_nullable
as ReviewOutcome,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as ResultSolveStatus,layout: null == layout ? _self.layout : layout // ignore: cast_nullable_to_non_nullable
as ResultLayout,detailUnlocked: null == detailUnlocked ? _self.detailUnlocked : detailUnlocked // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

/// Create a copy of ResultState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ReviewOutcomeCopyWith<$Res> get outcome {
  
  return $ReviewOutcomeCopyWith<$Res>(_self.outcome, (value) {
    return _then(_self.copyWith(outcome: value));
  });
}/// Create a copy of ResultState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ResultSolveStatusCopyWith<$Res> get status {
  
  return $ResultSolveStatusCopyWith<$Res>(_self.status, (value) {
    return _then(_self.copyWith(status: value));
  });
}
}

// dart format on
