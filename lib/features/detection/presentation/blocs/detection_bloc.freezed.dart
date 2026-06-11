// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'detection_bloc.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$DetectionEvent {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DetectionEvent);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'DetectionEvent()';
}


}

/// @nodoc
class $DetectionEventCopyWith<$Res>  {
$DetectionEventCopyWith(DetectionEvent _, $Res Function(DetectionEvent) __);
}


/// Adds pattern-matching-related methods to [DetectionEvent].
extension DetectionEventPatterns on DetectionEvent {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( DetectionStarted value)?  started,TResult Function( DetectionRetryRequested value)?  retryRequested,required TResult orElse(),}){
final _that = this;
switch (_that) {
case DetectionStarted() when started != null:
return started(_that);case DetectionRetryRequested() when retryRequested != null:
return retryRequested(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( DetectionStarted value)  started,required TResult Function( DetectionRetryRequested value)  retryRequested,}){
final _that = this;
switch (_that) {
case DetectionStarted():
return started(_that);case DetectionRetryRequested():
return retryRequested(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( DetectionStarted value)?  started,TResult? Function( DetectionRetryRequested value)?  retryRequested,}){
final _that = this;
switch (_that) {
case DetectionStarted() when started != null:
return started(_that);case DetectionRetryRequested() when retryRequested != null:
return retryRequested(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function()?  started,TResult Function()?  retryRequested,required TResult orElse(),}) {final _that = this;
switch (_that) {
case DetectionStarted() when started != null:
return started();case DetectionRetryRequested() when retryRequested != null:
return retryRequested();case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function()  started,required TResult Function()  retryRequested,}) {final _that = this;
switch (_that) {
case DetectionStarted():
return started();case DetectionRetryRequested():
return retryRequested();}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function()?  started,TResult? Function()?  retryRequested,}) {final _that = this;
switch (_that) {
case DetectionStarted() when started != null:
return started();case DetectionRetryRequested() when retryRequested != null:
return retryRequested();case _:
  return null;

}
}

}

/// @nodoc


class DetectionStarted implements DetectionEvent {
  const DetectionStarted();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DetectionStarted);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'DetectionEvent.started()';
}


}




/// @nodoc


class DetectionRetryRequested implements DetectionEvent {
  const DetectionRetryRequested();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DetectionRetryRequested);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'DetectionEvent.retryRequested()';
}


}




/// @nodoc
mixin _$DetectionState {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DetectionState);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'DetectionState()';
}


}

/// @nodoc
class $DetectionStateCopyWith<$Res>  {
$DetectionStateCopyWith(DetectionState _, $Res Function(DetectionState) __);
}


/// Adds pattern-matching-related methods to [DetectionState].
extension DetectionStatePatterns on DetectionState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( DetectionProcessing value)?  processing,TResult Function( DetectionSuccess value)?  success,TResult Function( DetectionFailure value)?  failure,required TResult orElse(),}){
final _that = this;
switch (_that) {
case DetectionProcessing() when processing != null:
return processing(_that);case DetectionSuccess() when success != null:
return success(_that);case DetectionFailure() when failure != null:
return failure(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( DetectionProcessing value)  processing,required TResult Function( DetectionSuccess value)  success,required TResult Function( DetectionFailure value)  failure,}){
final _that = this;
switch (_that) {
case DetectionProcessing():
return processing(_that);case DetectionSuccess():
return success(_that);case DetectionFailure():
return failure(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( DetectionProcessing value)?  processing,TResult? Function( DetectionSuccess value)?  success,TResult? Function( DetectionFailure value)?  failure,}){
final _that = this;
switch (_that) {
case DetectionProcessing() when processing != null:
return processing(_that);case DetectionSuccess() when success != null:
return success(_that);case DetectionFailure() when failure != null:
return failure(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( DetectionStage stage,  List<DetectedTile> revealed,  int? totalTiles)?  processing,TResult Function( DetectionResult result)?  success,TResult Function( Failure failure)?  failure,required TResult orElse(),}) {final _that = this;
switch (_that) {
case DetectionProcessing() when processing != null:
return processing(_that.stage,_that.revealed,_that.totalTiles);case DetectionSuccess() when success != null:
return success(_that.result);case DetectionFailure() when failure != null:
return failure(_that.failure);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( DetectionStage stage,  List<DetectedTile> revealed,  int? totalTiles)  processing,required TResult Function( DetectionResult result)  success,required TResult Function( Failure failure)  failure,}) {final _that = this;
switch (_that) {
case DetectionProcessing():
return processing(_that.stage,_that.revealed,_that.totalTiles);case DetectionSuccess():
return success(_that.result);case DetectionFailure():
return failure(_that.failure);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( DetectionStage stage,  List<DetectedTile> revealed,  int? totalTiles)?  processing,TResult? Function( DetectionResult result)?  success,TResult? Function( Failure failure)?  failure,}) {final _that = this;
switch (_that) {
case DetectionProcessing() when processing != null:
return processing(_that.stage,_that.revealed,_that.totalTiles);case DetectionSuccess() when success != null:
return success(_that.result);case DetectionFailure() when failure != null:
return failure(_that.failure);case _:
  return null;

}
}

}

/// @nodoc


class DetectionProcessing implements DetectionState {
  const DetectionProcessing({required this.stage, required final  List<DetectedTile> revealed, this.totalTiles}): _revealed = revealed;
  

 final  DetectionStage stage;
 final  List<DetectedTile> _revealed;
 List<DetectedTile> get revealed {
  if (_revealed is EqualUnmodifiableListView) return _revealed;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_revealed);
}

 final  int? totalTiles;

/// Create a copy of DetectionState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DetectionProcessingCopyWith<DetectionProcessing> get copyWith => _$DetectionProcessingCopyWithImpl<DetectionProcessing>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DetectionProcessing&&(identical(other.stage, stage) || other.stage == stage)&&const DeepCollectionEquality().equals(other._revealed, _revealed)&&(identical(other.totalTiles, totalTiles) || other.totalTiles == totalTiles));
}


@override
int get hashCode => Object.hash(runtimeType,stage,const DeepCollectionEquality().hash(_revealed),totalTiles);

@override
String toString() {
  return 'DetectionState.processing(stage: $stage, revealed: $revealed, totalTiles: $totalTiles)';
}


}

/// @nodoc
abstract mixin class $DetectionProcessingCopyWith<$Res> implements $DetectionStateCopyWith<$Res> {
  factory $DetectionProcessingCopyWith(DetectionProcessing value, $Res Function(DetectionProcessing) _then) = _$DetectionProcessingCopyWithImpl;
@useResult
$Res call({
 DetectionStage stage, List<DetectedTile> revealed, int? totalTiles
});




}
/// @nodoc
class _$DetectionProcessingCopyWithImpl<$Res>
    implements $DetectionProcessingCopyWith<$Res> {
  _$DetectionProcessingCopyWithImpl(this._self, this._then);

  final DetectionProcessing _self;
  final $Res Function(DetectionProcessing) _then;

/// Create a copy of DetectionState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? stage = null,Object? revealed = null,Object? totalTiles = freezed,}) {
  return _then(DetectionProcessing(
stage: null == stage ? _self.stage : stage // ignore: cast_nullable_to_non_nullable
as DetectionStage,revealed: null == revealed ? _self._revealed : revealed // ignore: cast_nullable_to_non_nullable
as List<DetectedTile>,totalTiles: freezed == totalTiles ? _self.totalTiles : totalTiles // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}

/// @nodoc


class DetectionSuccess implements DetectionState {
  const DetectionSuccess({required this.result});
  

 final  DetectionResult result;

/// Create a copy of DetectionState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DetectionSuccessCopyWith<DetectionSuccess> get copyWith => _$DetectionSuccessCopyWithImpl<DetectionSuccess>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DetectionSuccess&&(identical(other.result, result) || other.result == result));
}


@override
int get hashCode => Object.hash(runtimeType,result);

@override
String toString() {
  return 'DetectionState.success(result: $result)';
}


}

/// @nodoc
abstract mixin class $DetectionSuccessCopyWith<$Res> implements $DetectionStateCopyWith<$Res> {
  factory $DetectionSuccessCopyWith(DetectionSuccess value, $Res Function(DetectionSuccess) _then) = _$DetectionSuccessCopyWithImpl;
@useResult
$Res call({
 DetectionResult result
});


$DetectionResultCopyWith<$Res> get result;

}
/// @nodoc
class _$DetectionSuccessCopyWithImpl<$Res>
    implements $DetectionSuccessCopyWith<$Res> {
  _$DetectionSuccessCopyWithImpl(this._self, this._then);

  final DetectionSuccess _self;
  final $Res Function(DetectionSuccess) _then;

/// Create a copy of DetectionState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? result = null,}) {
  return _then(DetectionSuccess(
result: null == result ? _self.result : result // ignore: cast_nullable_to_non_nullable
as DetectionResult,
  ));
}

/// Create a copy of DetectionState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$DetectionResultCopyWith<$Res> get result {
  
  return $DetectionResultCopyWith<$Res>(_self.result, (value) {
    return _then(_self.copyWith(result: value));
  });
}
}

/// @nodoc


class DetectionFailure implements DetectionState {
  const DetectionFailure({required this.failure});
  

 final  Failure failure;

/// Create a copy of DetectionState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DetectionFailureCopyWith<DetectionFailure> get copyWith => _$DetectionFailureCopyWithImpl<DetectionFailure>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DetectionFailure&&(identical(other.failure, failure) || other.failure == failure));
}


@override
int get hashCode => Object.hash(runtimeType,failure);

@override
String toString() {
  return 'DetectionState.failure(failure: $failure)';
}


}

/// @nodoc
abstract mixin class $DetectionFailureCopyWith<$Res> implements $DetectionStateCopyWith<$Res> {
  factory $DetectionFailureCopyWith(DetectionFailure value, $Res Function(DetectionFailure) _then) = _$DetectionFailureCopyWithImpl;
@useResult
$Res call({
 Failure failure
});


$FailureCopyWith<$Res> get failure;

}
/// @nodoc
class _$DetectionFailureCopyWithImpl<$Res>
    implements $DetectionFailureCopyWith<$Res> {
  _$DetectionFailureCopyWithImpl(this._self, this._then);

  final DetectionFailure _self;
  final $Res Function(DetectionFailure) _then;

/// Create a copy of DetectionState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? failure = null,}) {
  return _then(DetectionFailure(
failure: null == failure ? _self.failure : failure // ignore: cast_nullable_to_non_nullable
as Failure,
  ));
}

/// Create a copy of DetectionState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$FailureCopyWith<$Res> get failure {
  
  return $FailureCopyWith<$Res>(_self.failure, (value) {
    return _then(_self.copyWith(failure: value));
  });
}
}

// dart format on
