// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'scan_counts.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ScanCounts {

/// Every scan of the current owner.
 int get all;/// Scans whose hand opened / was winning.
 int get opened;/// Scans whose hand did not open / was not winning.
 int get closed;
/// Create a copy of ScanCounts
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ScanCountsCopyWith<ScanCounts> get copyWith => _$ScanCountsCopyWithImpl<ScanCounts>(this as ScanCounts, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ScanCounts&&(identical(other.all, all) || other.all == all)&&(identical(other.opened, opened) || other.opened == opened)&&(identical(other.closed, closed) || other.closed == closed));
}


@override
int get hashCode => Object.hash(runtimeType,all,opened,closed);

@override
String toString() {
  return 'ScanCounts(all: $all, opened: $opened, closed: $closed)';
}


}

/// @nodoc
abstract mixin class $ScanCountsCopyWith<$Res>  {
  factory $ScanCountsCopyWith(ScanCounts value, $Res Function(ScanCounts) _then) = _$ScanCountsCopyWithImpl;
@useResult
$Res call({
 int all, int opened, int closed
});




}
/// @nodoc
class _$ScanCountsCopyWithImpl<$Res>
    implements $ScanCountsCopyWith<$Res> {
  _$ScanCountsCopyWithImpl(this._self, this._then);

  final ScanCounts _self;
  final $Res Function(ScanCounts) _then;

/// Create a copy of ScanCounts
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? all = null,Object? opened = null,Object? closed = null,}) {
  return _then(_self.copyWith(
all: null == all ? _self.all : all // ignore: cast_nullable_to_non_nullable
as int,opened: null == opened ? _self.opened : opened // ignore: cast_nullable_to_non_nullable
as int,closed: null == closed ? _self.closed : closed // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [ScanCounts].
extension ScanCountsPatterns on ScanCounts {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ScanCounts value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ScanCounts() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ScanCounts value)  $default,){
final _that = this;
switch (_that) {
case _ScanCounts():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ScanCounts value)?  $default,){
final _that = this;
switch (_that) {
case _ScanCounts() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int all,  int opened,  int closed)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ScanCounts() when $default != null:
return $default(_that.all,_that.opened,_that.closed);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int all,  int opened,  int closed)  $default,) {final _that = this;
switch (_that) {
case _ScanCounts():
return $default(_that.all,_that.opened,_that.closed);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int all,  int opened,  int closed)?  $default,) {final _that = this;
switch (_that) {
case _ScanCounts() when $default != null:
return $default(_that.all,_that.opened,_that.closed);case _:
  return null;

}
}

}

/// @nodoc


class _ScanCounts implements ScanCounts {
  const _ScanCounts({required this.all, required this.opened, required this.closed});
  

/// Every scan of the current owner.
@override final  int all;
/// Scans whose hand opened / was winning.
@override final  int opened;
/// Scans whose hand did not open / was not winning.
@override final  int closed;

/// Create a copy of ScanCounts
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ScanCountsCopyWith<_ScanCounts> get copyWith => __$ScanCountsCopyWithImpl<_ScanCounts>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ScanCounts&&(identical(other.all, all) || other.all == all)&&(identical(other.opened, opened) || other.opened == opened)&&(identical(other.closed, closed) || other.closed == closed));
}


@override
int get hashCode => Object.hash(runtimeType,all,opened,closed);

@override
String toString() {
  return 'ScanCounts(all: $all, opened: $opened, closed: $closed)';
}


}

/// @nodoc
abstract mixin class _$ScanCountsCopyWith<$Res> implements $ScanCountsCopyWith<$Res> {
  factory _$ScanCountsCopyWith(_ScanCounts value, $Res Function(_ScanCounts) _then) = __$ScanCountsCopyWithImpl;
@override @useResult
$Res call({
 int all, int opened, int closed
});




}
/// @nodoc
class __$ScanCountsCopyWithImpl<$Res>
    implements _$ScanCountsCopyWith<$Res> {
  __$ScanCountsCopyWithImpl(this._self, this._then);

  final _ScanCounts _self;
  final $Res Function(_ScanCounts) _then;

/// Create a copy of ScanCounts
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? all = null,Object? opened = null,Object? closed = null,}) {
  return _then(_ScanCounts(
all: null == all ? _self.all : all // ignore: cast_nullable_to_non_nullable
as int,opened: null == opened ? _self.opened : opened // ignore: cast_nullable_to_non_nullable
as int,closed: null == closed ? _self.closed : closed // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
