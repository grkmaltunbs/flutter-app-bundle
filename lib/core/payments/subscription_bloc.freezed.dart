// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'subscription_bloc.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$SubscriptionEvent {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SubscriptionEvent);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'SubscriptionEvent()';
}


}

/// @nodoc
class $SubscriptionEventCopyWith<$Res>  {
$SubscriptionEventCopyWith(SubscriptionEvent _, $Res Function(SubscriptionEvent) __);
}


/// Adds pattern-matching-related methods to [SubscriptionEvent].
extension SubscriptionEventPatterns on SubscriptionEvent {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( SubscriptionStarted value)?  started,TResult Function( SubscriptionRefreshRequested value)?  refreshRequested,TResult Function( SubscriptionOfferingsRequested value)?  offeringsRequested,TResult Function( SubscriptionPurchaseRequested value)?  purchaseRequested,TResult Function( SubscriptionRestoreRequested value)?  restoreRequested,TResult Function( SubscriptionEntitlementChanged value)?  entitlementChanged,required TResult orElse(),}){
final _that = this;
switch (_that) {
case SubscriptionStarted() when started != null:
return started(_that);case SubscriptionRefreshRequested() when refreshRequested != null:
return refreshRequested(_that);case SubscriptionOfferingsRequested() when offeringsRequested != null:
return offeringsRequested(_that);case SubscriptionPurchaseRequested() when purchaseRequested != null:
return purchaseRequested(_that);case SubscriptionRestoreRequested() when restoreRequested != null:
return restoreRequested(_that);case SubscriptionEntitlementChanged() when entitlementChanged != null:
return entitlementChanged(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( SubscriptionStarted value)  started,required TResult Function( SubscriptionRefreshRequested value)  refreshRequested,required TResult Function( SubscriptionOfferingsRequested value)  offeringsRequested,required TResult Function( SubscriptionPurchaseRequested value)  purchaseRequested,required TResult Function( SubscriptionRestoreRequested value)  restoreRequested,required TResult Function( SubscriptionEntitlementChanged value)  entitlementChanged,}){
final _that = this;
switch (_that) {
case SubscriptionStarted():
return started(_that);case SubscriptionRefreshRequested():
return refreshRequested(_that);case SubscriptionOfferingsRequested():
return offeringsRequested(_that);case SubscriptionPurchaseRequested():
return purchaseRequested(_that);case SubscriptionRestoreRequested():
return restoreRequested(_that);case SubscriptionEntitlementChanged():
return entitlementChanged(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( SubscriptionStarted value)?  started,TResult? Function( SubscriptionRefreshRequested value)?  refreshRequested,TResult? Function( SubscriptionOfferingsRequested value)?  offeringsRequested,TResult? Function( SubscriptionPurchaseRequested value)?  purchaseRequested,TResult? Function( SubscriptionRestoreRequested value)?  restoreRequested,TResult? Function( SubscriptionEntitlementChanged value)?  entitlementChanged,}){
final _that = this;
switch (_that) {
case SubscriptionStarted() when started != null:
return started(_that);case SubscriptionRefreshRequested() when refreshRequested != null:
return refreshRequested(_that);case SubscriptionOfferingsRequested() when offeringsRequested != null:
return offeringsRequested(_that);case SubscriptionPurchaseRequested() when purchaseRequested != null:
return purchaseRequested(_that);case SubscriptionRestoreRequested() when restoreRequested != null:
return restoreRequested(_that);case SubscriptionEntitlementChanged() when entitlementChanged != null:
return entitlementChanged(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function()?  started,TResult Function()?  refreshRequested,TResult Function()?  offeringsRequested,TResult Function( SubscriptionPackage package)?  purchaseRequested,TResult Function()?  restoreRequested,TResult Function( Entitlement entitlement)?  entitlementChanged,required TResult orElse(),}) {final _that = this;
switch (_that) {
case SubscriptionStarted() when started != null:
return started();case SubscriptionRefreshRequested() when refreshRequested != null:
return refreshRequested();case SubscriptionOfferingsRequested() when offeringsRequested != null:
return offeringsRequested();case SubscriptionPurchaseRequested() when purchaseRequested != null:
return purchaseRequested(_that.package);case SubscriptionRestoreRequested() when restoreRequested != null:
return restoreRequested();case SubscriptionEntitlementChanged() when entitlementChanged != null:
return entitlementChanged(_that.entitlement);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function()  started,required TResult Function()  refreshRequested,required TResult Function()  offeringsRequested,required TResult Function( SubscriptionPackage package)  purchaseRequested,required TResult Function()  restoreRequested,required TResult Function( Entitlement entitlement)  entitlementChanged,}) {final _that = this;
switch (_that) {
case SubscriptionStarted():
return started();case SubscriptionRefreshRequested():
return refreshRequested();case SubscriptionOfferingsRequested():
return offeringsRequested();case SubscriptionPurchaseRequested():
return purchaseRequested(_that.package);case SubscriptionRestoreRequested():
return restoreRequested();case SubscriptionEntitlementChanged():
return entitlementChanged(_that.entitlement);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function()?  started,TResult? Function()?  refreshRequested,TResult? Function()?  offeringsRequested,TResult? Function( SubscriptionPackage package)?  purchaseRequested,TResult? Function()?  restoreRequested,TResult? Function( Entitlement entitlement)?  entitlementChanged,}) {final _that = this;
switch (_that) {
case SubscriptionStarted() when started != null:
return started();case SubscriptionRefreshRequested() when refreshRequested != null:
return refreshRequested();case SubscriptionOfferingsRequested() when offeringsRequested != null:
return offeringsRequested();case SubscriptionPurchaseRequested() when purchaseRequested != null:
return purchaseRequested(_that.package);case SubscriptionRestoreRequested() when restoreRequested != null:
return restoreRequested();case SubscriptionEntitlementChanged() when entitlementChanged != null:
return entitlementChanged(_that.entitlement);case _:
  return null;

}
}

}

/// @nodoc


class SubscriptionStarted implements SubscriptionEvent {
  const SubscriptionStarted();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SubscriptionStarted);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'SubscriptionEvent.started()';
}


}




/// @nodoc


class SubscriptionRefreshRequested implements SubscriptionEvent {
  const SubscriptionRefreshRequested();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SubscriptionRefreshRequested);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'SubscriptionEvent.refreshRequested()';
}


}




/// @nodoc


class SubscriptionOfferingsRequested implements SubscriptionEvent {
  const SubscriptionOfferingsRequested();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SubscriptionOfferingsRequested);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'SubscriptionEvent.offeringsRequested()';
}


}




/// @nodoc


class SubscriptionPurchaseRequested implements SubscriptionEvent {
  const SubscriptionPurchaseRequested(this.package);
  

 final  SubscriptionPackage package;

/// Create a copy of SubscriptionEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SubscriptionPurchaseRequestedCopyWith<SubscriptionPurchaseRequested> get copyWith => _$SubscriptionPurchaseRequestedCopyWithImpl<SubscriptionPurchaseRequested>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SubscriptionPurchaseRequested&&(identical(other.package, package) || other.package == package));
}


@override
int get hashCode => Object.hash(runtimeType,package);

@override
String toString() {
  return 'SubscriptionEvent.purchaseRequested(package: $package)';
}


}

/// @nodoc
abstract mixin class $SubscriptionPurchaseRequestedCopyWith<$Res> implements $SubscriptionEventCopyWith<$Res> {
  factory $SubscriptionPurchaseRequestedCopyWith(SubscriptionPurchaseRequested value, $Res Function(SubscriptionPurchaseRequested) _then) = _$SubscriptionPurchaseRequestedCopyWithImpl;
@useResult
$Res call({
 SubscriptionPackage package
});


$SubscriptionPackageCopyWith<$Res> get package;

}
/// @nodoc
class _$SubscriptionPurchaseRequestedCopyWithImpl<$Res>
    implements $SubscriptionPurchaseRequestedCopyWith<$Res> {
  _$SubscriptionPurchaseRequestedCopyWithImpl(this._self, this._then);

  final SubscriptionPurchaseRequested _self;
  final $Res Function(SubscriptionPurchaseRequested) _then;

/// Create a copy of SubscriptionEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? package = null,}) {
  return _then(SubscriptionPurchaseRequested(
null == package ? _self.package : package // ignore: cast_nullable_to_non_nullable
as SubscriptionPackage,
  ));
}

/// Create a copy of SubscriptionEvent
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SubscriptionPackageCopyWith<$Res> get package {
  
  return $SubscriptionPackageCopyWith<$Res>(_self.package, (value) {
    return _then(_self.copyWith(package: value));
  });
}
}

/// @nodoc


class SubscriptionRestoreRequested implements SubscriptionEvent {
  const SubscriptionRestoreRequested();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SubscriptionRestoreRequested);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'SubscriptionEvent.restoreRequested()';
}


}




/// @nodoc


class SubscriptionEntitlementChanged implements SubscriptionEvent {
  const SubscriptionEntitlementChanged(this.entitlement);
  

 final  Entitlement entitlement;

/// Create a copy of SubscriptionEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SubscriptionEntitlementChangedCopyWith<SubscriptionEntitlementChanged> get copyWith => _$SubscriptionEntitlementChangedCopyWithImpl<SubscriptionEntitlementChanged>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SubscriptionEntitlementChanged&&(identical(other.entitlement, entitlement) || other.entitlement == entitlement));
}


@override
int get hashCode => Object.hash(runtimeType,entitlement);

@override
String toString() {
  return 'SubscriptionEvent.entitlementChanged(entitlement: $entitlement)';
}


}

/// @nodoc
abstract mixin class $SubscriptionEntitlementChangedCopyWith<$Res> implements $SubscriptionEventCopyWith<$Res> {
  factory $SubscriptionEntitlementChangedCopyWith(SubscriptionEntitlementChanged value, $Res Function(SubscriptionEntitlementChanged) _then) = _$SubscriptionEntitlementChangedCopyWithImpl;
@useResult
$Res call({
 Entitlement entitlement
});


$EntitlementCopyWith<$Res> get entitlement;

}
/// @nodoc
class _$SubscriptionEntitlementChangedCopyWithImpl<$Res>
    implements $SubscriptionEntitlementChangedCopyWith<$Res> {
  _$SubscriptionEntitlementChangedCopyWithImpl(this._self, this._then);

  final SubscriptionEntitlementChanged _self;
  final $Res Function(SubscriptionEntitlementChanged) _then;

/// Create a copy of SubscriptionEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? entitlement = null,}) {
  return _then(SubscriptionEntitlementChanged(
null == entitlement ? _self.entitlement : entitlement // ignore: cast_nullable_to_non_nullable
as Entitlement,
  ));
}

/// Create a copy of SubscriptionEvent
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$EntitlementCopyWith<$Res> get entitlement {
  
  return $EntitlementCopyWith<$Res>(_self.entitlement, (value) {
    return _then(_self.copyWith(entitlement: value));
  });
}
}

/// @nodoc
mixin _$SubscriptionFlow {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SubscriptionFlow);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'SubscriptionFlow()';
}


}

/// @nodoc
class $SubscriptionFlowCopyWith<$Res>  {
$SubscriptionFlowCopyWith(SubscriptionFlow _, $Res Function(SubscriptionFlow) __);
}


/// Adds pattern-matching-related methods to [SubscriptionFlow].
extension SubscriptionFlowPatterns on SubscriptionFlow {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( SubscriptionFlowIdle value)?  idle,TResult Function( SubscriptionFlowOfferingsLoading value)?  offeringsLoading,TResult Function( SubscriptionFlowPurchasing value)?  purchasing,TResult Function( SubscriptionFlowRestoring value)?  restoring,TResult Function( SubscriptionFlowPurchaseSucceeded value)?  purchaseSucceeded,TResult Function( SubscriptionFlowRestoreSucceeded value)?  restoreSucceeded,TResult Function( SubscriptionFlowOffline value)?  offline,TResult Function( SubscriptionFlowError value)?  error,required TResult orElse(),}){
final _that = this;
switch (_that) {
case SubscriptionFlowIdle() when idle != null:
return idle(_that);case SubscriptionFlowOfferingsLoading() when offeringsLoading != null:
return offeringsLoading(_that);case SubscriptionFlowPurchasing() when purchasing != null:
return purchasing(_that);case SubscriptionFlowRestoring() when restoring != null:
return restoring(_that);case SubscriptionFlowPurchaseSucceeded() when purchaseSucceeded != null:
return purchaseSucceeded(_that);case SubscriptionFlowRestoreSucceeded() when restoreSucceeded != null:
return restoreSucceeded(_that);case SubscriptionFlowOffline() when offline != null:
return offline(_that);case SubscriptionFlowError() when error != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( SubscriptionFlowIdle value)  idle,required TResult Function( SubscriptionFlowOfferingsLoading value)  offeringsLoading,required TResult Function( SubscriptionFlowPurchasing value)  purchasing,required TResult Function( SubscriptionFlowRestoring value)  restoring,required TResult Function( SubscriptionFlowPurchaseSucceeded value)  purchaseSucceeded,required TResult Function( SubscriptionFlowRestoreSucceeded value)  restoreSucceeded,required TResult Function( SubscriptionFlowOffline value)  offline,required TResult Function( SubscriptionFlowError value)  error,}){
final _that = this;
switch (_that) {
case SubscriptionFlowIdle():
return idle(_that);case SubscriptionFlowOfferingsLoading():
return offeringsLoading(_that);case SubscriptionFlowPurchasing():
return purchasing(_that);case SubscriptionFlowRestoring():
return restoring(_that);case SubscriptionFlowPurchaseSucceeded():
return purchaseSucceeded(_that);case SubscriptionFlowRestoreSucceeded():
return restoreSucceeded(_that);case SubscriptionFlowOffline():
return offline(_that);case SubscriptionFlowError():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( SubscriptionFlowIdle value)?  idle,TResult? Function( SubscriptionFlowOfferingsLoading value)?  offeringsLoading,TResult? Function( SubscriptionFlowPurchasing value)?  purchasing,TResult? Function( SubscriptionFlowRestoring value)?  restoring,TResult? Function( SubscriptionFlowPurchaseSucceeded value)?  purchaseSucceeded,TResult? Function( SubscriptionFlowRestoreSucceeded value)?  restoreSucceeded,TResult? Function( SubscriptionFlowOffline value)?  offline,TResult? Function( SubscriptionFlowError value)?  error,}){
final _that = this;
switch (_that) {
case SubscriptionFlowIdle() when idle != null:
return idle(_that);case SubscriptionFlowOfferingsLoading() when offeringsLoading != null:
return offeringsLoading(_that);case SubscriptionFlowPurchasing() when purchasing != null:
return purchasing(_that);case SubscriptionFlowRestoring() when restoring != null:
return restoring(_that);case SubscriptionFlowPurchaseSucceeded() when purchaseSucceeded != null:
return purchaseSucceeded(_that);case SubscriptionFlowRestoreSucceeded() when restoreSucceeded != null:
return restoreSucceeded(_that);case SubscriptionFlowOffline() when offline != null:
return offline(_that);case SubscriptionFlowError() when error != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function()?  idle,TResult Function()?  offeringsLoading,TResult Function()?  purchasing,TResult Function()?  restoring,TResult Function()?  purchaseSucceeded,TResult Function()?  restoreSucceeded,TResult Function()?  offline,TResult Function( PurchaseFailure failure)?  error,required TResult orElse(),}) {final _that = this;
switch (_that) {
case SubscriptionFlowIdle() when idle != null:
return idle();case SubscriptionFlowOfferingsLoading() when offeringsLoading != null:
return offeringsLoading();case SubscriptionFlowPurchasing() when purchasing != null:
return purchasing();case SubscriptionFlowRestoring() when restoring != null:
return restoring();case SubscriptionFlowPurchaseSucceeded() when purchaseSucceeded != null:
return purchaseSucceeded();case SubscriptionFlowRestoreSucceeded() when restoreSucceeded != null:
return restoreSucceeded();case SubscriptionFlowOffline() when offline != null:
return offline();case SubscriptionFlowError() when error != null:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function()  idle,required TResult Function()  offeringsLoading,required TResult Function()  purchasing,required TResult Function()  restoring,required TResult Function()  purchaseSucceeded,required TResult Function()  restoreSucceeded,required TResult Function()  offline,required TResult Function( PurchaseFailure failure)  error,}) {final _that = this;
switch (_that) {
case SubscriptionFlowIdle():
return idle();case SubscriptionFlowOfferingsLoading():
return offeringsLoading();case SubscriptionFlowPurchasing():
return purchasing();case SubscriptionFlowRestoring():
return restoring();case SubscriptionFlowPurchaseSucceeded():
return purchaseSucceeded();case SubscriptionFlowRestoreSucceeded():
return restoreSucceeded();case SubscriptionFlowOffline():
return offline();case SubscriptionFlowError():
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function()?  idle,TResult? Function()?  offeringsLoading,TResult? Function()?  purchasing,TResult? Function()?  restoring,TResult? Function()?  purchaseSucceeded,TResult? Function()?  restoreSucceeded,TResult? Function()?  offline,TResult? Function( PurchaseFailure failure)?  error,}) {final _that = this;
switch (_that) {
case SubscriptionFlowIdle() when idle != null:
return idle();case SubscriptionFlowOfferingsLoading() when offeringsLoading != null:
return offeringsLoading();case SubscriptionFlowPurchasing() when purchasing != null:
return purchasing();case SubscriptionFlowRestoring() when restoring != null:
return restoring();case SubscriptionFlowPurchaseSucceeded() when purchaseSucceeded != null:
return purchaseSucceeded();case SubscriptionFlowRestoreSucceeded() when restoreSucceeded != null:
return restoreSucceeded();case SubscriptionFlowOffline() when offline != null:
return offline();case SubscriptionFlowError() when error != null:
return error(_that.failure);case _:
  return null;

}
}

}

/// @nodoc


class SubscriptionFlowIdle implements SubscriptionFlow {
  const SubscriptionFlowIdle();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SubscriptionFlowIdle);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'SubscriptionFlow.idle()';
}


}




/// @nodoc


class SubscriptionFlowOfferingsLoading implements SubscriptionFlow {
  const SubscriptionFlowOfferingsLoading();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SubscriptionFlowOfferingsLoading);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'SubscriptionFlow.offeringsLoading()';
}


}




/// @nodoc


class SubscriptionFlowPurchasing implements SubscriptionFlow {
  const SubscriptionFlowPurchasing();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SubscriptionFlowPurchasing);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'SubscriptionFlow.purchasing()';
}


}




/// @nodoc


class SubscriptionFlowRestoring implements SubscriptionFlow {
  const SubscriptionFlowRestoring();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SubscriptionFlowRestoring);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'SubscriptionFlow.restoring()';
}


}




/// @nodoc


class SubscriptionFlowPurchaseSucceeded implements SubscriptionFlow {
  const SubscriptionFlowPurchaseSucceeded();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SubscriptionFlowPurchaseSucceeded);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'SubscriptionFlow.purchaseSucceeded()';
}


}




/// @nodoc


class SubscriptionFlowRestoreSucceeded implements SubscriptionFlow {
  const SubscriptionFlowRestoreSucceeded();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SubscriptionFlowRestoreSucceeded);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'SubscriptionFlow.restoreSucceeded()';
}


}




/// @nodoc


class SubscriptionFlowOffline implements SubscriptionFlow {
  const SubscriptionFlowOffline();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SubscriptionFlowOffline);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'SubscriptionFlow.offline()';
}


}




/// @nodoc


class SubscriptionFlowError implements SubscriptionFlow {
  const SubscriptionFlowError(this.failure);
  

 final  PurchaseFailure failure;

/// Create a copy of SubscriptionFlow
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SubscriptionFlowErrorCopyWith<SubscriptionFlowError> get copyWith => _$SubscriptionFlowErrorCopyWithImpl<SubscriptionFlowError>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SubscriptionFlowError&&(identical(other.failure, failure) || other.failure == failure));
}


@override
int get hashCode => Object.hash(runtimeType,failure);

@override
String toString() {
  return 'SubscriptionFlow.error(failure: $failure)';
}


}

/// @nodoc
abstract mixin class $SubscriptionFlowErrorCopyWith<$Res> implements $SubscriptionFlowCopyWith<$Res> {
  factory $SubscriptionFlowErrorCopyWith(SubscriptionFlowError value, $Res Function(SubscriptionFlowError) _then) = _$SubscriptionFlowErrorCopyWithImpl;
@useResult
$Res call({
 PurchaseFailure failure
});


$PurchaseFailureCopyWith<$Res> get failure;

}
/// @nodoc
class _$SubscriptionFlowErrorCopyWithImpl<$Res>
    implements $SubscriptionFlowErrorCopyWith<$Res> {
  _$SubscriptionFlowErrorCopyWithImpl(this._self, this._then);

  final SubscriptionFlowError _self;
  final $Res Function(SubscriptionFlowError) _then;

/// Create a copy of SubscriptionFlow
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? failure = null,}) {
  return _then(SubscriptionFlowError(
null == failure ? _self.failure : failure // ignore: cast_nullable_to_non_nullable
as PurchaseFailure,
  ));
}

/// Create a copy of SubscriptionFlow
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PurchaseFailureCopyWith<$Res> get failure {
  
  return $PurchaseFailureCopyWith<$Res>(_self.failure, (value) {
    return _then(_self.copyWith(failure: value));
  });
}
}

/// @nodoc
mixin _$SubscriptionState {

 Entitlement get entitlement; SubscriptionOffering? get offering; SubscriptionFlow get flow;
/// Create a copy of SubscriptionState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SubscriptionStateCopyWith<SubscriptionState> get copyWith => _$SubscriptionStateCopyWithImpl<SubscriptionState>(this as SubscriptionState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SubscriptionState&&(identical(other.entitlement, entitlement) || other.entitlement == entitlement)&&(identical(other.offering, offering) || other.offering == offering)&&(identical(other.flow, flow) || other.flow == flow));
}


@override
int get hashCode => Object.hash(runtimeType,entitlement,offering,flow);

@override
String toString() {
  return 'SubscriptionState(entitlement: $entitlement, offering: $offering, flow: $flow)';
}


}

/// @nodoc
abstract mixin class $SubscriptionStateCopyWith<$Res>  {
  factory $SubscriptionStateCopyWith(SubscriptionState value, $Res Function(SubscriptionState) _then) = _$SubscriptionStateCopyWithImpl;
@useResult
$Res call({
 Entitlement entitlement, SubscriptionOffering? offering, SubscriptionFlow flow
});


$EntitlementCopyWith<$Res> get entitlement;$SubscriptionOfferingCopyWith<$Res>? get offering;$SubscriptionFlowCopyWith<$Res> get flow;

}
/// @nodoc
class _$SubscriptionStateCopyWithImpl<$Res>
    implements $SubscriptionStateCopyWith<$Res> {
  _$SubscriptionStateCopyWithImpl(this._self, this._then);

  final SubscriptionState _self;
  final $Res Function(SubscriptionState) _then;

/// Create a copy of SubscriptionState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? entitlement = null,Object? offering = freezed,Object? flow = null,}) {
  return _then(_self.copyWith(
entitlement: null == entitlement ? _self.entitlement : entitlement // ignore: cast_nullable_to_non_nullable
as Entitlement,offering: freezed == offering ? _self.offering : offering // ignore: cast_nullable_to_non_nullable
as SubscriptionOffering?,flow: null == flow ? _self.flow : flow // ignore: cast_nullable_to_non_nullable
as SubscriptionFlow,
  ));
}
/// Create a copy of SubscriptionState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$EntitlementCopyWith<$Res> get entitlement {
  
  return $EntitlementCopyWith<$Res>(_self.entitlement, (value) {
    return _then(_self.copyWith(entitlement: value));
  });
}/// Create a copy of SubscriptionState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SubscriptionOfferingCopyWith<$Res>? get offering {
    if (_self.offering == null) {
    return null;
  }

  return $SubscriptionOfferingCopyWith<$Res>(_self.offering!, (value) {
    return _then(_self.copyWith(offering: value));
  });
}/// Create a copy of SubscriptionState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SubscriptionFlowCopyWith<$Res> get flow {
  
  return $SubscriptionFlowCopyWith<$Res>(_self.flow, (value) {
    return _then(_self.copyWith(flow: value));
  });
}
}


/// Adds pattern-matching-related methods to [SubscriptionState].
extension SubscriptionStatePatterns on SubscriptionState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SubscriptionState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SubscriptionState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SubscriptionState value)  $default,){
final _that = this;
switch (_that) {
case _SubscriptionState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SubscriptionState value)?  $default,){
final _that = this;
switch (_that) {
case _SubscriptionState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( Entitlement entitlement,  SubscriptionOffering? offering,  SubscriptionFlow flow)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SubscriptionState() when $default != null:
return $default(_that.entitlement,_that.offering,_that.flow);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( Entitlement entitlement,  SubscriptionOffering? offering,  SubscriptionFlow flow)  $default,) {final _that = this;
switch (_that) {
case _SubscriptionState():
return $default(_that.entitlement,_that.offering,_that.flow);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( Entitlement entitlement,  SubscriptionOffering? offering,  SubscriptionFlow flow)?  $default,) {final _that = this;
switch (_that) {
case _SubscriptionState() when $default != null:
return $default(_that.entitlement,_that.offering,_that.flow);case _:
  return null;

}
}

}

/// @nodoc


class _SubscriptionState extends SubscriptionState {
  const _SubscriptionState({required this.entitlement, this.offering, this.flow = const SubscriptionFlow.idle()}): super._();
  

@override final  Entitlement entitlement;
@override final  SubscriptionOffering? offering;
@override@JsonKey() final  SubscriptionFlow flow;

/// Create a copy of SubscriptionState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SubscriptionStateCopyWith<_SubscriptionState> get copyWith => __$SubscriptionStateCopyWithImpl<_SubscriptionState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SubscriptionState&&(identical(other.entitlement, entitlement) || other.entitlement == entitlement)&&(identical(other.offering, offering) || other.offering == offering)&&(identical(other.flow, flow) || other.flow == flow));
}


@override
int get hashCode => Object.hash(runtimeType,entitlement,offering,flow);

@override
String toString() {
  return 'SubscriptionState(entitlement: $entitlement, offering: $offering, flow: $flow)';
}


}

/// @nodoc
abstract mixin class _$SubscriptionStateCopyWith<$Res> implements $SubscriptionStateCopyWith<$Res> {
  factory _$SubscriptionStateCopyWith(_SubscriptionState value, $Res Function(_SubscriptionState) _then) = __$SubscriptionStateCopyWithImpl;
@override @useResult
$Res call({
 Entitlement entitlement, SubscriptionOffering? offering, SubscriptionFlow flow
});


@override $EntitlementCopyWith<$Res> get entitlement;@override $SubscriptionOfferingCopyWith<$Res>? get offering;@override $SubscriptionFlowCopyWith<$Res> get flow;

}
/// @nodoc
class __$SubscriptionStateCopyWithImpl<$Res>
    implements _$SubscriptionStateCopyWith<$Res> {
  __$SubscriptionStateCopyWithImpl(this._self, this._then);

  final _SubscriptionState _self;
  final $Res Function(_SubscriptionState) _then;

/// Create a copy of SubscriptionState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? entitlement = null,Object? offering = freezed,Object? flow = null,}) {
  return _then(_SubscriptionState(
entitlement: null == entitlement ? _self.entitlement : entitlement // ignore: cast_nullable_to_non_nullable
as Entitlement,offering: freezed == offering ? _self.offering : offering // ignore: cast_nullable_to_non_nullable
as SubscriptionOffering?,flow: null == flow ? _self.flow : flow // ignore: cast_nullable_to_non_nullable
as SubscriptionFlow,
  ));
}

/// Create a copy of SubscriptionState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$EntitlementCopyWith<$Res> get entitlement {
  
  return $EntitlementCopyWith<$Res>(_self.entitlement, (value) {
    return _then(_self.copyWith(entitlement: value));
  });
}/// Create a copy of SubscriptionState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SubscriptionOfferingCopyWith<$Res>? get offering {
    if (_self.offering == null) {
    return null;
  }

  return $SubscriptionOfferingCopyWith<$Res>(_self.offering!, (value) {
    return _then(_self.copyWith(offering: value));
  });
}/// Create a copy of SubscriptionState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SubscriptionFlowCopyWith<$Res> get flow {
  
  return $SubscriptionFlowCopyWith<$Res>(_self.flow, (value) {
    return _then(_self.copyWith(flow: value));
  });
}
}

// dart format on
