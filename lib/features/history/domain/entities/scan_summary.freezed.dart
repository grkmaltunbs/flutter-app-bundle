// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'scan_summary.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ScanSummary {

/// The verdict discriminant.
 ScanVerdictKind get kind;/// Denormalized filter bit: opens (101) or winning now (okey).
 bool get opened;/// Best meld total ([SolveResult.totalScore]) — populated for every kind.
 int get score;/// How a 101 hand opened, else `null`.
 OpenPath? get openPath;/// Points short of 101 for a non-opener, else `null`.
 int? get pointsShort;/// Minimum exchanges to an okey win, else `null`.
 int? get tilesToWin;/// The okey winning template, else `null`.
 OkeyPath? get okeyPath;
/// Create a copy of ScanSummary
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ScanSummaryCopyWith<ScanSummary> get copyWith => _$ScanSummaryCopyWithImpl<ScanSummary>(this as ScanSummary, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ScanSummary&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.opened, opened) || other.opened == opened)&&(identical(other.score, score) || other.score == score)&&(identical(other.openPath, openPath) || other.openPath == openPath)&&(identical(other.pointsShort, pointsShort) || other.pointsShort == pointsShort)&&(identical(other.tilesToWin, tilesToWin) || other.tilesToWin == tilesToWin)&&(identical(other.okeyPath, okeyPath) || other.okeyPath == okeyPath));
}


@override
int get hashCode => Object.hash(runtimeType,kind,opened,score,openPath,pointsShort,tilesToWin,okeyPath);

@override
String toString() {
  return 'ScanSummary(kind: $kind, opened: $opened, score: $score, openPath: $openPath, pointsShort: $pointsShort, tilesToWin: $tilesToWin, okeyPath: $okeyPath)';
}


}

/// @nodoc
abstract mixin class $ScanSummaryCopyWith<$Res>  {
  factory $ScanSummaryCopyWith(ScanSummary value, $Res Function(ScanSummary) _then) = _$ScanSummaryCopyWithImpl;
@useResult
$Res call({
 ScanVerdictKind kind, bool opened, int score, OpenPath? openPath, int? pointsShort, int? tilesToWin, OkeyPath? okeyPath
});




}
/// @nodoc
class _$ScanSummaryCopyWithImpl<$Res>
    implements $ScanSummaryCopyWith<$Res> {
  _$ScanSummaryCopyWithImpl(this._self, this._then);

  final ScanSummary _self;
  final $Res Function(ScanSummary) _then;

/// Create a copy of ScanSummary
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? kind = null,Object? opened = null,Object? score = null,Object? openPath = freezed,Object? pointsShort = freezed,Object? tilesToWin = freezed,Object? okeyPath = freezed,}) {
  return _then(_self.copyWith(
kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as ScanVerdictKind,opened: null == opened ? _self.opened : opened // ignore: cast_nullable_to_non_nullable
as bool,score: null == score ? _self.score : score // ignore: cast_nullable_to_non_nullable
as int,openPath: freezed == openPath ? _self.openPath : openPath // ignore: cast_nullable_to_non_nullable
as OpenPath?,pointsShort: freezed == pointsShort ? _self.pointsShort : pointsShort // ignore: cast_nullable_to_non_nullable
as int?,tilesToWin: freezed == tilesToWin ? _self.tilesToWin : tilesToWin // ignore: cast_nullable_to_non_nullable
as int?,okeyPath: freezed == okeyPath ? _self.okeyPath : okeyPath // ignore: cast_nullable_to_non_nullable
as OkeyPath?,
  ));
}

}


/// Adds pattern-matching-related methods to [ScanSummary].
extension ScanSummaryPatterns on ScanSummary {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ScanSummary value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ScanSummary() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ScanSummary value)  $default,){
final _that = this;
switch (_that) {
case _ScanSummary():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ScanSummary value)?  $default,){
final _that = this;
switch (_that) {
case _ScanSummary() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( ScanVerdictKind kind,  bool opened,  int score,  OpenPath? openPath,  int? pointsShort,  int? tilesToWin,  OkeyPath? okeyPath)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ScanSummary() when $default != null:
return $default(_that.kind,_that.opened,_that.score,_that.openPath,_that.pointsShort,_that.tilesToWin,_that.okeyPath);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( ScanVerdictKind kind,  bool opened,  int score,  OpenPath? openPath,  int? pointsShort,  int? tilesToWin,  OkeyPath? okeyPath)  $default,) {final _that = this;
switch (_that) {
case _ScanSummary():
return $default(_that.kind,_that.opened,_that.score,_that.openPath,_that.pointsShort,_that.tilesToWin,_that.okeyPath);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( ScanVerdictKind kind,  bool opened,  int score,  OpenPath? openPath,  int? pointsShort,  int? tilesToWin,  OkeyPath? okeyPath)?  $default,) {final _that = this;
switch (_that) {
case _ScanSummary() when $default != null:
return $default(_that.kind,_that.opened,_that.score,_that.openPath,_that.pointsShort,_that.tilesToWin,_that.okeyPath);case _:
  return null;

}
}

}

/// @nodoc


class _ScanSummary implements ScanSummary {
  const _ScanSummary({required this.kind, required this.opened, required this.score, this.openPath, this.pointsShort, this.tilesToWin, this.okeyPath});
  

/// The verdict discriminant.
@override final  ScanVerdictKind kind;
/// Denormalized filter bit: opens (101) or winning now (okey).
@override final  bool opened;
/// Best meld total ([SolveResult.totalScore]) — populated for every kind.
@override final  int score;
/// How a 101 hand opened, else `null`.
@override final  OpenPath? openPath;
/// Points short of 101 for a non-opener, else `null`.
@override final  int? pointsShort;
/// Minimum exchanges to an okey win, else `null`.
@override final  int? tilesToWin;
/// The okey winning template, else `null`.
@override final  OkeyPath? okeyPath;

/// Create a copy of ScanSummary
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ScanSummaryCopyWith<_ScanSummary> get copyWith => __$ScanSummaryCopyWithImpl<_ScanSummary>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ScanSummary&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.opened, opened) || other.opened == opened)&&(identical(other.score, score) || other.score == score)&&(identical(other.openPath, openPath) || other.openPath == openPath)&&(identical(other.pointsShort, pointsShort) || other.pointsShort == pointsShort)&&(identical(other.tilesToWin, tilesToWin) || other.tilesToWin == tilesToWin)&&(identical(other.okeyPath, okeyPath) || other.okeyPath == okeyPath));
}


@override
int get hashCode => Object.hash(runtimeType,kind,opened,score,openPath,pointsShort,tilesToWin,okeyPath);

@override
String toString() {
  return 'ScanSummary(kind: $kind, opened: $opened, score: $score, openPath: $openPath, pointsShort: $pointsShort, tilesToWin: $tilesToWin, okeyPath: $okeyPath)';
}


}

/// @nodoc
abstract mixin class _$ScanSummaryCopyWith<$Res> implements $ScanSummaryCopyWith<$Res> {
  factory _$ScanSummaryCopyWith(_ScanSummary value, $Res Function(_ScanSummary) _then) = __$ScanSummaryCopyWithImpl;
@override @useResult
$Res call({
 ScanVerdictKind kind, bool opened, int score, OpenPath? openPath, int? pointsShort, int? tilesToWin, OkeyPath? okeyPath
});




}
/// @nodoc
class __$ScanSummaryCopyWithImpl<$Res>
    implements _$ScanSummaryCopyWith<$Res> {
  __$ScanSummaryCopyWithImpl(this._self, this._then);

  final _ScanSummary _self;
  final $Res Function(_ScanSummary) _then;

/// Create a copy of ScanSummary
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? kind = null,Object? opened = null,Object? score = null,Object? openPath = freezed,Object? pointsShort = freezed,Object? tilesToWin = freezed,Object? okeyPath = freezed,}) {
  return _then(_ScanSummary(
kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as ScanVerdictKind,opened: null == opened ? _self.opened : opened // ignore: cast_nullable_to_non_nullable
as bool,score: null == score ? _self.score : score // ignore: cast_nullable_to_non_nullable
as int,openPath: freezed == openPath ? _self.openPath : openPath // ignore: cast_nullable_to_non_nullable
as OpenPath?,pointsShort: freezed == pointsShort ? _self.pointsShort : pointsShort // ignore: cast_nullable_to_non_nullable
as int?,tilesToWin: freezed == tilesToWin ? _self.tilesToWin : tilesToWin // ignore: cast_nullable_to_non_nullable
as int?,okeyPath: freezed == okeyPath ? _self.okeyPath : okeyPath // ignore: cast_nullable_to_non_nullable
as OkeyPath?,
  ));
}


}

// dart format on
