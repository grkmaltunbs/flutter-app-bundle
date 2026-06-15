// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'purchase_failure.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$PurchaseFailure {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PurchaseFailure);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'PurchaseFailure()';
}


}

/// @nodoc
class $PurchaseFailureCopyWith<$Res>  {
$PurchaseFailureCopyWith(PurchaseFailure _, $Res Function(PurchaseFailure) __);
}


/// Adds pattern-matching-related methods to [PurchaseFailure].
extension PurchaseFailurePatterns on PurchaseFailure {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( PurchaseCancelled value)?  cancelled,TResult Function( PurchaseNetwork value)?  network,TResult Function( PurchasePending value)?  pending,TResult Function( PurchasePaymentFailed value)?  paymentFailed,TResult Function( PurchaseRestoreNothing value)?  restoreNothing,TResult Function( PurchaseUnknown value)?  unknown,required TResult orElse(),}){
final _that = this;
switch (_that) {
case PurchaseCancelled() when cancelled != null:
return cancelled(_that);case PurchaseNetwork() when network != null:
return network(_that);case PurchasePending() when pending != null:
return pending(_that);case PurchasePaymentFailed() when paymentFailed != null:
return paymentFailed(_that);case PurchaseRestoreNothing() when restoreNothing != null:
return restoreNothing(_that);case PurchaseUnknown() when unknown != null:
return unknown(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( PurchaseCancelled value)  cancelled,required TResult Function( PurchaseNetwork value)  network,required TResult Function( PurchasePending value)  pending,required TResult Function( PurchasePaymentFailed value)  paymentFailed,required TResult Function( PurchaseRestoreNothing value)  restoreNothing,required TResult Function( PurchaseUnknown value)  unknown,}){
final _that = this;
switch (_that) {
case PurchaseCancelled():
return cancelled(_that);case PurchaseNetwork():
return network(_that);case PurchasePending():
return pending(_that);case PurchasePaymentFailed():
return paymentFailed(_that);case PurchaseRestoreNothing():
return restoreNothing(_that);case PurchaseUnknown():
return unknown(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( PurchaseCancelled value)?  cancelled,TResult? Function( PurchaseNetwork value)?  network,TResult? Function( PurchasePending value)?  pending,TResult? Function( PurchasePaymentFailed value)?  paymentFailed,TResult? Function( PurchaseRestoreNothing value)?  restoreNothing,TResult? Function( PurchaseUnknown value)?  unknown,}){
final _that = this;
switch (_that) {
case PurchaseCancelled() when cancelled != null:
return cancelled(_that);case PurchaseNetwork() when network != null:
return network(_that);case PurchasePending() when pending != null:
return pending(_that);case PurchasePaymentFailed() when paymentFailed != null:
return paymentFailed(_that);case PurchaseRestoreNothing() when restoreNothing != null:
return restoreNothing(_that);case PurchaseUnknown() when unknown != null:
return unknown(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function()?  cancelled,TResult Function()?  network,TResult Function()?  pending,TResult Function( String? message)?  paymentFailed,TResult Function()?  restoreNothing,TResult Function()?  unknown,required TResult orElse(),}) {final _that = this;
switch (_that) {
case PurchaseCancelled() when cancelled != null:
return cancelled();case PurchaseNetwork() when network != null:
return network();case PurchasePending() when pending != null:
return pending();case PurchasePaymentFailed() when paymentFailed != null:
return paymentFailed(_that.message);case PurchaseRestoreNothing() when restoreNothing != null:
return restoreNothing();case PurchaseUnknown() when unknown != null:
return unknown();case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function()  cancelled,required TResult Function()  network,required TResult Function()  pending,required TResult Function( String? message)  paymentFailed,required TResult Function()  restoreNothing,required TResult Function()  unknown,}) {final _that = this;
switch (_that) {
case PurchaseCancelled():
return cancelled();case PurchaseNetwork():
return network();case PurchasePending():
return pending();case PurchasePaymentFailed():
return paymentFailed(_that.message);case PurchaseRestoreNothing():
return restoreNothing();case PurchaseUnknown():
return unknown();}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function()?  cancelled,TResult? Function()?  network,TResult? Function()?  pending,TResult? Function( String? message)?  paymentFailed,TResult? Function()?  restoreNothing,TResult? Function()?  unknown,}) {final _that = this;
switch (_that) {
case PurchaseCancelled() when cancelled != null:
return cancelled();case PurchaseNetwork() when network != null:
return network();case PurchasePending() when pending != null:
return pending();case PurchasePaymentFailed() when paymentFailed != null:
return paymentFailed(_that.message);case PurchaseRestoreNothing() when restoreNothing != null:
return restoreNothing();case PurchaseUnknown() when unknown != null:
return unknown();case _:
  return null;

}
}

}

/// @nodoc


class PurchaseCancelled implements PurchaseFailure {
  const PurchaseCancelled();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PurchaseCancelled);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'PurchaseFailure.cancelled()';
}


}




/// @nodoc


class PurchaseNetwork implements PurchaseFailure {
  const PurchaseNetwork();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PurchaseNetwork);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'PurchaseFailure.network()';
}


}




/// @nodoc


class PurchasePending implements PurchaseFailure {
  const PurchasePending();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PurchasePending);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'PurchaseFailure.pending()';
}


}




/// @nodoc


class PurchasePaymentFailed implements PurchaseFailure {
  const PurchasePaymentFailed([this.message]);
  

 final  String? message;

/// Create a copy of PurchaseFailure
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PurchasePaymentFailedCopyWith<PurchasePaymentFailed> get copyWith => _$PurchasePaymentFailedCopyWithImpl<PurchasePaymentFailed>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PurchasePaymentFailed&&(identical(other.message, message) || other.message == message));
}


@override
int get hashCode => Object.hash(runtimeType,message);

@override
String toString() {
  return 'PurchaseFailure.paymentFailed(message: $message)';
}


}

/// @nodoc
abstract mixin class $PurchasePaymentFailedCopyWith<$Res> implements $PurchaseFailureCopyWith<$Res> {
  factory $PurchasePaymentFailedCopyWith(PurchasePaymentFailed value, $Res Function(PurchasePaymentFailed) _then) = _$PurchasePaymentFailedCopyWithImpl;
@useResult
$Res call({
 String? message
});




}
/// @nodoc
class _$PurchasePaymentFailedCopyWithImpl<$Res>
    implements $PurchasePaymentFailedCopyWith<$Res> {
  _$PurchasePaymentFailedCopyWithImpl(this._self, this._then);

  final PurchasePaymentFailed _self;
  final $Res Function(PurchasePaymentFailed) _then;

/// Create a copy of PurchaseFailure
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? message = freezed,}) {
  return _then(PurchasePaymentFailed(
freezed == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc


class PurchaseRestoreNothing implements PurchaseFailure {
  const PurchaseRestoreNothing();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PurchaseRestoreNothing);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'PurchaseFailure.restoreNothing()';
}


}




/// @nodoc


class PurchaseUnknown implements PurchaseFailure {
  const PurchaseUnknown();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PurchaseUnknown);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'PurchaseFailure.unknown()';
}


}




// dart format on
