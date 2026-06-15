// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'consent_status.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ConsentStatus {

 bool get personalizedAds; bool get analytics; AttStatus get att;
/// Create a copy of ConsentStatus
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ConsentStatusCopyWith<ConsentStatus> get copyWith => _$ConsentStatusCopyWithImpl<ConsentStatus>(this as ConsentStatus, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ConsentStatus&&(identical(other.personalizedAds, personalizedAds) || other.personalizedAds == personalizedAds)&&(identical(other.analytics, analytics) || other.analytics == analytics)&&(identical(other.att, att) || other.att == att));
}


@override
int get hashCode => Object.hash(runtimeType,personalizedAds,analytics,att);

@override
String toString() {
  return 'ConsentStatus(personalizedAds: $personalizedAds, analytics: $analytics, att: $att)';
}


}

/// @nodoc
abstract mixin class $ConsentStatusCopyWith<$Res>  {
  factory $ConsentStatusCopyWith(ConsentStatus value, $Res Function(ConsentStatus) _then) = _$ConsentStatusCopyWithImpl;
@useResult
$Res call({
 bool personalizedAds, bool analytics, AttStatus att
});




}
/// @nodoc
class _$ConsentStatusCopyWithImpl<$Res>
    implements $ConsentStatusCopyWith<$Res> {
  _$ConsentStatusCopyWithImpl(this._self, this._then);

  final ConsentStatus _self;
  final $Res Function(ConsentStatus) _then;

/// Create a copy of ConsentStatus
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? personalizedAds = null,Object? analytics = null,Object? att = null,}) {
  return _then(_self.copyWith(
personalizedAds: null == personalizedAds ? _self.personalizedAds : personalizedAds // ignore: cast_nullable_to_non_nullable
as bool,analytics: null == analytics ? _self.analytics : analytics // ignore: cast_nullable_to_non_nullable
as bool,att: null == att ? _self.att : att // ignore: cast_nullable_to_non_nullable
as AttStatus,
  ));
}

}


/// Adds pattern-matching-related methods to [ConsentStatus].
extension ConsentStatusPatterns on ConsentStatus {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ConsentStatus value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ConsentStatus() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ConsentStatus value)  $default,){
final _that = this;
switch (_that) {
case _ConsentStatus():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ConsentStatus value)?  $default,){
final _that = this;
switch (_that) {
case _ConsentStatus() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool personalizedAds,  bool analytics,  AttStatus att)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ConsentStatus() when $default != null:
return $default(_that.personalizedAds,_that.analytics,_that.att);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool personalizedAds,  bool analytics,  AttStatus att)  $default,) {final _that = this;
switch (_that) {
case _ConsentStatus():
return $default(_that.personalizedAds,_that.analytics,_that.att);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool personalizedAds,  bool analytics,  AttStatus att)?  $default,) {final _that = this;
switch (_that) {
case _ConsentStatus() when $default != null:
return $default(_that.personalizedAds,_that.analytics,_that.att);case _:
  return null;

}
}

}

/// @nodoc


class _ConsentStatus extends ConsentStatus {
  const _ConsentStatus({required this.personalizedAds, required this.analytics, required this.att}): super._();
  

@override final  bool personalizedAds;
@override final  bool analytics;
@override final  AttStatus att;

/// Create a copy of ConsentStatus
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ConsentStatusCopyWith<_ConsentStatus> get copyWith => __$ConsentStatusCopyWithImpl<_ConsentStatus>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ConsentStatus&&(identical(other.personalizedAds, personalizedAds) || other.personalizedAds == personalizedAds)&&(identical(other.analytics, analytics) || other.analytics == analytics)&&(identical(other.att, att) || other.att == att));
}


@override
int get hashCode => Object.hash(runtimeType,personalizedAds,analytics,att);

@override
String toString() {
  return 'ConsentStatus(personalizedAds: $personalizedAds, analytics: $analytics, att: $att)';
}


}

/// @nodoc
abstract mixin class _$ConsentStatusCopyWith<$Res> implements $ConsentStatusCopyWith<$Res> {
  factory _$ConsentStatusCopyWith(_ConsentStatus value, $Res Function(_ConsentStatus) _then) = __$ConsentStatusCopyWithImpl;
@override @useResult
$Res call({
 bool personalizedAds, bool analytics, AttStatus att
});




}
/// @nodoc
class __$ConsentStatusCopyWithImpl<$Res>
    implements _$ConsentStatusCopyWith<$Res> {
  __$ConsentStatusCopyWithImpl(this._self, this._then);

  final _ConsentStatus _self;
  final $Res Function(_ConsentStatus) _then;

/// Create a copy of ConsentStatus
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? personalizedAds = null,Object? analytics = null,Object? att = null,}) {
  return _then(_ConsentStatus(
personalizedAds: null == personalizedAds ? _self.personalizedAds : personalizedAds // ignore: cast_nullable_to_non_nullable
as bool,analytics: null == analytics ? _self.analytics : analytics // ignore: cast_nullable_to_non_nullable
as bool,att: null == att ? _self.att : att // ignore: cast_nullable_to_non_nullable
as AttStatus,
  ));
}


}

// dart format on
