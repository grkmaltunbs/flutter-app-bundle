// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'template_bloc.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$TemplateState {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TemplateState);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'TemplateState()';
}


}

/// @nodoc
class $TemplateStateCopyWith<$Res>  {
$TemplateStateCopyWith(TemplateState _, $Res Function(TemplateState) __);
}


/// Adds pattern-matching-related methods to [TemplateState].
extension TemplateStatePatterns on TemplateState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( TemplateInitial value)?  initial,TResult Function( TemplateLoading value)?  loading,TResult Function( TemplateLoaded value)?  loaded,TResult Function( TemplateError value)?  error,required TResult orElse(),}){
final _that = this;
switch (_that) {
case TemplateInitial() when initial != null:
return initial(_that);case TemplateLoading() when loading != null:
return loading(_that);case TemplateLoaded() when loaded != null:
return loaded(_that);case TemplateError() when error != null:
return error(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( TemplateInitial value)  initial,required TResult Function( TemplateLoading value)  loading,required TResult Function( TemplateLoaded value)  loaded,required TResult Function( TemplateError value)  error,}){
final _that = this;
switch (_that) {
case TemplateInitial():
return initial(_that);case TemplateLoading():
return loading(_that);case TemplateLoaded():
return loaded(_that);case TemplateError():
return error(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( TemplateInitial value)?  initial,TResult? Function( TemplateLoading value)?  loading,TResult? Function( TemplateLoaded value)?  loaded,TResult? Function( TemplateError value)?  error,}){
final _that = this;
switch (_that) {
case TemplateInitial() when initial != null:
return initial(_that);case TemplateLoading() when loading != null:
return loading(_that);case TemplateLoaded() when loaded != null:
return loaded(_that);case TemplateError() when error != null:
return error(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function()?  initial,TResult Function()?  loading,TResult Function( List<TemplateItem> items)?  loaded,TResult Function( Failure failure)?  error,required TResult orElse(),}) {final _that = this;
switch (_that) {
case TemplateInitial() when initial != null:
return initial();case TemplateLoading() when loading != null:
return loading();case TemplateLoaded() when loaded != null:
return loaded(_that.items);case TemplateError() when error != null:
return error(_that.failure);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function()  initial,required TResult Function()  loading,required TResult Function( List<TemplateItem> items)  loaded,required TResult Function( Failure failure)  error,}) {final _that = this;
switch (_that) {
case TemplateInitial():
return initial();case TemplateLoading():
return loading();case TemplateLoaded():
return loaded(_that.items);case TemplateError():
return error(_that.failure);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function()?  initial,TResult? Function()?  loading,TResult? Function( List<TemplateItem> items)?  loaded,TResult? Function( Failure failure)?  error,}) {final _that = this;
switch (_that) {
case TemplateInitial() when initial != null:
return initial();case TemplateLoading() when loading != null:
return loading();case TemplateLoaded() when loaded != null:
return loaded(_that.items);case TemplateError() when error != null:
return error(_that.failure);case _:
  return null;

}
}

}

/// @nodoc


class TemplateInitial implements TemplateState {
  const TemplateInitial();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TemplateInitial);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'TemplateState.initial()';
}


}




/// @nodoc


class TemplateLoading implements TemplateState {
  const TemplateLoading();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TemplateLoading);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'TemplateState.loading()';
}


}




/// @nodoc


class TemplateLoaded implements TemplateState {
  const TemplateLoaded(final  List<TemplateItem> items): _items = items;
  

 final  List<TemplateItem> _items;
 List<TemplateItem> get items {
  if (_items is EqualUnmodifiableListView) return _items;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_items);
}


/// Create a copy of TemplateState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TemplateLoadedCopyWith<TemplateLoaded> get copyWith => _$TemplateLoadedCopyWithImpl<TemplateLoaded>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TemplateLoaded&&const DeepCollectionEquality().equals(other._items, _items));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_items));

@override
String toString() {
  return 'TemplateState.loaded(items: $items)';
}


}

/// @nodoc
abstract mixin class $TemplateLoadedCopyWith<$Res> implements $TemplateStateCopyWith<$Res> {
  factory $TemplateLoadedCopyWith(TemplateLoaded value, $Res Function(TemplateLoaded) _then) = _$TemplateLoadedCopyWithImpl;
@useResult
$Res call({
 List<TemplateItem> items
});




}
/// @nodoc
class _$TemplateLoadedCopyWithImpl<$Res>
    implements $TemplateLoadedCopyWith<$Res> {
  _$TemplateLoadedCopyWithImpl(this._self, this._then);

  final TemplateLoaded _self;
  final $Res Function(TemplateLoaded) _then;

/// Create a copy of TemplateState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? items = null,}) {
  return _then(TemplateLoaded(
null == items ? _self._items : items // ignore: cast_nullable_to_non_nullable
as List<TemplateItem>,
  ));
}


}

/// @nodoc


class TemplateError implements TemplateState {
  const TemplateError(this.failure);
  

 final  Failure failure;

/// Create a copy of TemplateState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TemplateErrorCopyWith<TemplateError> get copyWith => _$TemplateErrorCopyWithImpl<TemplateError>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TemplateError&&(identical(other.failure, failure) || other.failure == failure));
}


@override
int get hashCode => Object.hash(runtimeType,failure);

@override
String toString() {
  return 'TemplateState.error(failure: $failure)';
}


}

/// @nodoc
abstract mixin class $TemplateErrorCopyWith<$Res> implements $TemplateStateCopyWith<$Res> {
  factory $TemplateErrorCopyWith(TemplateError value, $Res Function(TemplateError) _then) = _$TemplateErrorCopyWithImpl;
@useResult
$Res call({
 Failure failure
});


$FailureCopyWith<$Res> get failure;

}
/// @nodoc
class _$TemplateErrorCopyWithImpl<$Res>
    implements $TemplateErrorCopyWith<$Res> {
  _$TemplateErrorCopyWithImpl(this._self, this._then);

  final TemplateError _self;
  final $Res Function(TemplateError) _then;

/// Create a copy of TemplateState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? failure = null,}) {
  return _then(TemplateError(
null == failure ? _self.failure : failure // ignore: cast_nullable_to_non_nullable
as Failure,
  ));
}

/// Create a copy of TemplateState
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
