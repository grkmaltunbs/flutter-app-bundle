// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'scan_stats.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ScanStats {

/// Total scans of the current owner.
 int get total;/// How many opened / were winning.
 int get opened;/// The best score across all scans (0 when there are none).
 int get best;
/// Create a copy of ScanStats
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ScanStatsCopyWith<ScanStats> get copyWith => _$ScanStatsCopyWithImpl<ScanStats>(this as ScanStats, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ScanStats&&(identical(other.total, total) || other.total == total)&&(identical(other.opened, opened) || other.opened == opened)&&(identical(other.best, best) || other.best == best));
}


@override
int get hashCode => Object.hash(runtimeType,total,opened,best);

@override
String toString() {
  return 'ScanStats(total: $total, opened: $opened, best: $best)';
}


}

/// @nodoc
abstract mixin class $ScanStatsCopyWith<$Res>  {
  factory $ScanStatsCopyWith(ScanStats value, $Res Function(ScanStats) _then) = _$ScanStatsCopyWithImpl;
@useResult
$Res call({
 int total, int opened, int best
});




}
/// @nodoc
class _$ScanStatsCopyWithImpl<$Res>
    implements $ScanStatsCopyWith<$Res> {
  _$ScanStatsCopyWithImpl(this._self, this._then);

  final ScanStats _self;
  final $Res Function(ScanStats) _then;

/// Create a copy of ScanStats
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? total = null,Object? opened = null,Object? best = null,}) {
  return _then(_self.copyWith(
total: null == total ? _self.total : total // ignore: cast_nullable_to_non_nullable
as int,opened: null == opened ? _self.opened : opened // ignore: cast_nullable_to_non_nullable
as int,best: null == best ? _self.best : best // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [ScanStats].
extension ScanStatsPatterns on ScanStats {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ScanStats value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ScanStats() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ScanStats value)  $default,){
final _that = this;
switch (_that) {
case _ScanStats():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ScanStats value)?  $default,){
final _that = this;
switch (_that) {
case _ScanStats() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int total,  int opened,  int best)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ScanStats() when $default != null:
return $default(_that.total,_that.opened,_that.best);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int total,  int opened,  int best)  $default,) {final _that = this;
switch (_that) {
case _ScanStats():
return $default(_that.total,_that.opened,_that.best);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int total,  int opened,  int best)?  $default,) {final _that = this;
switch (_that) {
case _ScanStats() when $default != null:
return $default(_that.total,_that.opened,_that.best);case _:
  return null;

}
}

}

/// @nodoc


class _ScanStats extends ScanStats {
  const _ScanStats({required this.total, required this.opened, required this.best}): super._();
  

/// Total scans of the current owner.
@override final  int total;
/// How many opened / were winning.
@override final  int opened;
/// The best score across all scans (0 when there are none).
@override final  int best;

/// Create a copy of ScanStats
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ScanStatsCopyWith<_ScanStats> get copyWith => __$ScanStatsCopyWithImpl<_ScanStats>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ScanStats&&(identical(other.total, total) || other.total == total)&&(identical(other.opened, opened) || other.opened == opened)&&(identical(other.best, best) || other.best == best));
}


@override
int get hashCode => Object.hash(runtimeType,total,opened,best);

@override
String toString() {
  return 'ScanStats(total: $total, opened: $opened, best: $best)';
}


}

/// @nodoc
abstract mixin class _$ScanStatsCopyWith<$Res> implements $ScanStatsCopyWith<$Res> {
  factory _$ScanStatsCopyWith(_ScanStats value, $Res Function(_ScanStats) _then) = __$ScanStatsCopyWithImpl;
@override @useResult
$Res call({
 int total, int opened, int best
});




}
/// @nodoc
class __$ScanStatsCopyWithImpl<$Res>
    implements _$ScanStatsCopyWith<$Res> {
  __$ScanStatsCopyWithImpl(this._self, this._then);

  final _ScanStats _self;
  final $Res Function(_ScanStats) _then;

/// Create a copy of ScanStats
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? total = null,Object? opened = null,Object? best = null,}) {
  return _then(_ScanStats(
total: null == total ? _self.total : total // ignore: cast_nullable_to_non_nullable
as int,opened: null == opened ? _self.opened : opened // ignore: cast_nullable_to_non_nullable
as int,best: null == best ? _self.best : best // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
