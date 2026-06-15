// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'subscription_package.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$SubscriptionPackage {

 String get id; SubscriptionPeriod get period; String get priceString; bool get hasTrial; int get trialDays;
/// Create a copy of SubscriptionPackage
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SubscriptionPackageCopyWith<SubscriptionPackage> get copyWith => _$SubscriptionPackageCopyWithImpl<SubscriptionPackage>(this as SubscriptionPackage, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SubscriptionPackage&&(identical(other.id, id) || other.id == id)&&(identical(other.period, period) || other.period == period)&&(identical(other.priceString, priceString) || other.priceString == priceString)&&(identical(other.hasTrial, hasTrial) || other.hasTrial == hasTrial)&&(identical(other.trialDays, trialDays) || other.trialDays == trialDays));
}


@override
int get hashCode => Object.hash(runtimeType,id,period,priceString,hasTrial,trialDays);

@override
String toString() {
  return 'SubscriptionPackage(id: $id, period: $period, priceString: $priceString, hasTrial: $hasTrial, trialDays: $trialDays)';
}


}

/// @nodoc
abstract mixin class $SubscriptionPackageCopyWith<$Res>  {
  factory $SubscriptionPackageCopyWith(SubscriptionPackage value, $Res Function(SubscriptionPackage) _then) = _$SubscriptionPackageCopyWithImpl;
@useResult
$Res call({
 String id, SubscriptionPeriod period, String priceString, bool hasTrial, int trialDays
});




}
/// @nodoc
class _$SubscriptionPackageCopyWithImpl<$Res>
    implements $SubscriptionPackageCopyWith<$Res> {
  _$SubscriptionPackageCopyWithImpl(this._self, this._then);

  final SubscriptionPackage _self;
  final $Res Function(SubscriptionPackage) _then;

/// Create a copy of SubscriptionPackage
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? period = null,Object? priceString = null,Object? hasTrial = null,Object? trialDays = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,period: null == period ? _self.period : period // ignore: cast_nullable_to_non_nullable
as SubscriptionPeriod,priceString: null == priceString ? _self.priceString : priceString // ignore: cast_nullable_to_non_nullable
as String,hasTrial: null == hasTrial ? _self.hasTrial : hasTrial // ignore: cast_nullable_to_non_nullable
as bool,trialDays: null == trialDays ? _self.trialDays : trialDays // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [SubscriptionPackage].
extension SubscriptionPackagePatterns on SubscriptionPackage {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SubscriptionPackage value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SubscriptionPackage() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SubscriptionPackage value)  $default,){
final _that = this;
switch (_that) {
case _SubscriptionPackage():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SubscriptionPackage value)?  $default,){
final _that = this;
switch (_that) {
case _SubscriptionPackage() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  SubscriptionPeriod period,  String priceString,  bool hasTrial,  int trialDays)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SubscriptionPackage() when $default != null:
return $default(_that.id,_that.period,_that.priceString,_that.hasTrial,_that.trialDays);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  SubscriptionPeriod period,  String priceString,  bool hasTrial,  int trialDays)  $default,) {final _that = this;
switch (_that) {
case _SubscriptionPackage():
return $default(_that.id,_that.period,_that.priceString,_that.hasTrial,_that.trialDays);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  SubscriptionPeriod period,  String priceString,  bool hasTrial,  int trialDays)?  $default,) {final _that = this;
switch (_that) {
case _SubscriptionPackage() when $default != null:
return $default(_that.id,_that.period,_that.priceString,_that.hasTrial,_that.trialDays);case _:
  return null;

}
}

}

/// @nodoc


class _SubscriptionPackage implements SubscriptionPackage {
  const _SubscriptionPackage({required this.id, required this.period, required this.priceString, this.hasTrial = false, this.trialDays = 0});
  

@override final  String id;
@override final  SubscriptionPeriod period;
@override final  String priceString;
@override@JsonKey() final  bool hasTrial;
@override@JsonKey() final  int trialDays;

/// Create a copy of SubscriptionPackage
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SubscriptionPackageCopyWith<_SubscriptionPackage> get copyWith => __$SubscriptionPackageCopyWithImpl<_SubscriptionPackage>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SubscriptionPackage&&(identical(other.id, id) || other.id == id)&&(identical(other.period, period) || other.period == period)&&(identical(other.priceString, priceString) || other.priceString == priceString)&&(identical(other.hasTrial, hasTrial) || other.hasTrial == hasTrial)&&(identical(other.trialDays, trialDays) || other.trialDays == trialDays));
}


@override
int get hashCode => Object.hash(runtimeType,id,period,priceString,hasTrial,trialDays);

@override
String toString() {
  return 'SubscriptionPackage(id: $id, period: $period, priceString: $priceString, hasTrial: $hasTrial, trialDays: $trialDays)';
}


}

/// @nodoc
abstract mixin class _$SubscriptionPackageCopyWith<$Res> implements $SubscriptionPackageCopyWith<$Res> {
  factory _$SubscriptionPackageCopyWith(_SubscriptionPackage value, $Res Function(_SubscriptionPackage) _then) = __$SubscriptionPackageCopyWithImpl;
@override @useResult
$Res call({
 String id, SubscriptionPeriod period, String priceString, bool hasTrial, int trialDays
});




}
/// @nodoc
class __$SubscriptionPackageCopyWithImpl<$Res>
    implements _$SubscriptionPackageCopyWith<$Res> {
  __$SubscriptionPackageCopyWithImpl(this._self, this._then);

  final _SubscriptionPackage _self;
  final $Res Function(_SubscriptionPackage) _then;

/// Create a copy of SubscriptionPackage
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? period = null,Object? priceString = null,Object? hasTrial = null,Object? trialDays = null,}) {
  return _then(_SubscriptionPackage(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,period: null == period ? _self.period : period // ignore: cast_nullable_to_non_nullable
as SubscriptionPeriod,priceString: null == priceString ? _self.priceString : priceString // ignore: cast_nullable_to_non_nullable
as String,hasTrial: null == hasTrial ? _self.hasTrial : hasTrial // ignore: cast_nullable_to_non_nullable
as bool,trialDays: null == trialDays ? _self.trialDays : trialDays // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
