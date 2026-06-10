// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'failure.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$Failure {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Failure);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'Failure()';
}


}

/// @nodoc
class $FailureCopyWith<$Res>  {
$FailureCopyWith(Failure _, $Res Function(Failure) __);
}


/// Adds pattern-matching-related methods to [Failure].
extension FailurePatterns on Failure {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( NetworkFailure value)?  network,TResult Function( UnexpectedFailure value)?  unexpected,TResult Function( NotFoundFailure value)?  notFound,TResult Function( InvalidCredentialsFailure value)?  invalidCredentials,TResult Function( EmailAlreadyInUseFailure value)?  emailAlreadyInUse,TResult Function( WeakPasswordFailure value)?  weakPassword,TResult Function( RequiresRecentLoginFailure value)?  requiresRecentLogin,TResult Function( SessionExpiredFailure value)?  sessionExpired,TResult Function( TooManyRequestsFailure value)?  tooManyRequests,TResult Function( NoCameraFailure value)?  noCamera,TResult Function( CaptureFailedFailure value)?  captureFailed,TResult Function( PhotoAccessDeniedFailure value)?  photoAccessDenied,required TResult orElse(),}){
final _that = this;
switch (_that) {
case NetworkFailure() when network != null:
return network(_that);case UnexpectedFailure() when unexpected != null:
return unexpected(_that);case NotFoundFailure() when notFound != null:
return notFound(_that);case InvalidCredentialsFailure() when invalidCredentials != null:
return invalidCredentials(_that);case EmailAlreadyInUseFailure() when emailAlreadyInUse != null:
return emailAlreadyInUse(_that);case WeakPasswordFailure() when weakPassword != null:
return weakPassword(_that);case RequiresRecentLoginFailure() when requiresRecentLogin != null:
return requiresRecentLogin(_that);case SessionExpiredFailure() when sessionExpired != null:
return sessionExpired(_that);case TooManyRequestsFailure() when tooManyRequests != null:
return tooManyRequests(_that);case NoCameraFailure() when noCamera != null:
return noCamera(_that);case CaptureFailedFailure() when captureFailed != null:
return captureFailed(_that);case PhotoAccessDeniedFailure() when photoAccessDenied != null:
return photoAccessDenied(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( NetworkFailure value)  network,required TResult Function( UnexpectedFailure value)  unexpected,required TResult Function( NotFoundFailure value)  notFound,required TResult Function( InvalidCredentialsFailure value)  invalidCredentials,required TResult Function( EmailAlreadyInUseFailure value)  emailAlreadyInUse,required TResult Function( WeakPasswordFailure value)  weakPassword,required TResult Function( RequiresRecentLoginFailure value)  requiresRecentLogin,required TResult Function( SessionExpiredFailure value)  sessionExpired,required TResult Function( TooManyRequestsFailure value)  tooManyRequests,required TResult Function( NoCameraFailure value)  noCamera,required TResult Function( CaptureFailedFailure value)  captureFailed,required TResult Function( PhotoAccessDeniedFailure value)  photoAccessDenied,}){
final _that = this;
switch (_that) {
case NetworkFailure():
return network(_that);case UnexpectedFailure():
return unexpected(_that);case NotFoundFailure():
return notFound(_that);case InvalidCredentialsFailure():
return invalidCredentials(_that);case EmailAlreadyInUseFailure():
return emailAlreadyInUse(_that);case WeakPasswordFailure():
return weakPassword(_that);case RequiresRecentLoginFailure():
return requiresRecentLogin(_that);case SessionExpiredFailure():
return sessionExpired(_that);case TooManyRequestsFailure():
return tooManyRequests(_that);case NoCameraFailure():
return noCamera(_that);case CaptureFailedFailure():
return captureFailed(_that);case PhotoAccessDeniedFailure():
return photoAccessDenied(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( NetworkFailure value)?  network,TResult? Function( UnexpectedFailure value)?  unexpected,TResult? Function( NotFoundFailure value)?  notFound,TResult? Function( InvalidCredentialsFailure value)?  invalidCredentials,TResult? Function( EmailAlreadyInUseFailure value)?  emailAlreadyInUse,TResult? Function( WeakPasswordFailure value)?  weakPassword,TResult? Function( RequiresRecentLoginFailure value)?  requiresRecentLogin,TResult? Function( SessionExpiredFailure value)?  sessionExpired,TResult? Function( TooManyRequestsFailure value)?  tooManyRequests,TResult? Function( NoCameraFailure value)?  noCamera,TResult? Function( CaptureFailedFailure value)?  captureFailed,TResult? Function( PhotoAccessDeniedFailure value)?  photoAccessDenied,}){
final _that = this;
switch (_that) {
case NetworkFailure() when network != null:
return network(_that);case UnexpectedFailure() when unexpected != null:
return unexpected(_that);case NotFoundFailure() when notFound != null:
return notFound(_that);case InvalidCredentialsFailure() when invalidCredentials != null:
return invalidCredentials(_that);case EmailAlreadyInUseFailure() when emailAlreadyInUse != null:
return emailAlreadyInUse(_that);case WeakPasswordFailure() when weakPassword != null:
return weakPassword(_that);case RequiresRecentLoginFailure() when requiresRecentLogin != null:
return requiresRecentLogin(_that);case SessionExpiredFailure() when sessionExpired != null:
return sessionExpired(_that);case TooManyRequestsFailure() when tooManyRequests != null:
return tooManyRequests(_that);case NoCameraFailure() when noCamera != null:
return noCamera(_that);case CaptureFailedFailure() when captureFailed != null:
return captureFailed(_that);case PhotoAccessDeniedFailure() when photoAccessDenied != null:
return photoAccessDenied(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function()?  network,TResult Function( String message)?  unexpected,TResult Function()?  notFound,TResult Function()?  invalidCredentials,TResult Function()?  emailAlreadyInUse,TResult Function()?  weakPassword,TResult Function()?  requiresRecentLogin,TResult Function()?  sessionExpired,TResult Function()?  tooManyRequests,TResult Function()?  noCamera,TResult Function( String message)?  captureFailed,TResult Function( bool permanent)?  photoAccessDenied,required TResult orElse(),}) {final _that = this;
switch (_that) {
case NetworkFailure() when network != null:
return network();case UnexpectedFailure() when unexpected != null:
return unexpected(_that.message);case NotFoundFailure() when notFound != null:
return notFound();case InvalidCredentialsFailure() when invalidCredentials != null:
return invalidCredentials();case EmailAlreadyInUseFailure() when emailAlreadyInUse != null:
return emailAlreadyInUse();case WeakPasswordFailure() when weakPassword != null:
return weakPassword();case RequiresRecentLoginFailure() when requiresRecentLogin != null:
return requiresRecentLogin();case SessionExpiredFailure() when sessionExpired != null:
return sessionExpired();case TooManyRequestsFailure() when tooManyRequests != null:
return tooManyRequests();case NoCameraFailure() when noCamera != null:
return noCamera();case CaptureFailedFailure() when captureFailed != null:
return captureFailed(_that.message);case PhotoAccessDeniedFailure() when photoAccessDenied != null:
return photoAccessDenied(_that.permanent);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function()  network,required TResult Function( String message)  unexpected,required TResult Function()  notFound,required TResult Function()  invalidCredentials,required TResult Function()  emailAlreadyInUse,required TResult Function()  weakPassword,required TResult Function()  requiresRecentLogin,required TResult Function()  sessionExpired,required TResult Function()  tooManyRequests,required TResult Function()  noCamera,required TResult Function( String message)  captureFailed,required TResult Function( bool permanent)  photoAccessDenied,}) {final _that = this;
switch (_that) {
case NetworkFailure():
return network();case UnexpectedFailure():
return unexpected(_that.message);case NotFoundFailure():
return notFound();case InvalidCredentialsFailure():
return invalidCredentials();case EmailAlreadyInUseFailure():
return emailAlreadyInUse();case WeakPasswordFailure():
return weakPassword();case RequiresRecentLoginFailure():
return requiresRecentLogin();case SessionExpiredFailure():
return sessionExpired();case TooManyRequestsFailure():
return tooManyRequests();case NoCameraFailure():
return noCamera();case CaptureFailedFailure():
return captureFailed(_that.message);case PhotoAccessDeniedFailure():
return photoAccessDenied(_that.permanent);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function()?  network,TResult? Function( String message)?  unexpected,TResult? Function()?  notFound,TResult? Function()?  invalidCredentials,TResult? Function()?  emailAlreadyInUse,TResult? Function()?  weakPassword,TResult? Function()?  requiresRecentLogin,TResult? Function()?  sessionExpired,TResult? Function()?  tooManyRequests,TResult? Function()?  noCamera,TResult? Function( String message)?  captureFailed,TResult? Function( bool permanent)?  photoAccessDenied,}) {final _that = this;
switch (_that) {
case NetworkFailure() when network != null:
return network();case UnexpectedFailure() when unexpected != null:
return unexpected(_that.message);case NotFoundFailure() when notFound != null:
return notFound();case InvalidCredentialsFailure() when invalidCredentials != null:
return invalidCredentials();case EmailAlreadyInUseFailure() when emailAlreadyInUse != null:
return emailAlreadyInUse();case WeakPasswordFailure() when weakPassword != null:
return weakPassword();case RequiresRecentLoginFailure() when requiresRecentLogin != null:
return requiresRecentLogin();case SessionExpiredFailure() when sessionExpired != null:
return sessionExpired();case TooManyRequestsFailure() when tooManyRequests != null:
return tooManyRequests();case NoCameraFailure() when noCamera != null:
return noCamera();case CaptureFailedFailure() when captureFailed != null:
return captureFailed(_that.message);case PhotoAccessDeniedFailure() when photoAccessDenied != null:
return photoAccessDenied(_that.permanent);case _:
  return null;

}
}

}

/// @nodoc


class NetworkFailure implements Failure {
  const NetworkFailure();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is NetworkFailure);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'Failure.network()';
}


}




/// @nodoc


class UnexpectedFailure implements Failure {
  const UnexpectedFailure(this.message);
  

 final  String message;

/// Create a copy of Failure
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UnexpectedFailureCopyWith<UnexpectedFailure> get copyWith => _$UnexpectedFailureCopyWithImpl<UnexpectedFailure>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UnexpectedFailure&&(identical(other.message, message) || other.message == message));
}


@override
int get hashCode => Object.hash(runtimeType,message);

@override
String toString() {
  return 'Failure.unexpected(message: $message)';
}


}

/// @nodoc
abstract mixin class $UnexpectedFailureCopyWith<$Res> implements $FailureCopyWith<$Res> {
  factory $UnexpectedFailureCopyWith(UnexpectedFailure value, $Res Function(UnexpectedFailure) _then) = _$UnexpectedFailureCopyWithImpl;
@useResult
$Res call({
 String message
});




}
/// @nodoc
class _$UnexpectedFailureCopyWithImpl<$Res>
    implements $UnexpectedFailureCopyWith<$Res> {
  _$UnexpectedFailureCopyWithImpl(this._self, this._then);

  final UnexpectedFailure _self;
  final $Res Function(UnexpectedFailure) _then;

/// Create a copy of Failure
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? message = null,}) {
  return _then(UnexpectedFailure(
null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class NotFoundFailure implements Failure {
  const NotFoundFailure();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is NotFoundFailure);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'Failure.notFound()';
}


}




/// @nodoc


class InvalidCredentialsFailure implements Failure {
  const InvalidCredentialsFailure();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is InvalidCredentialsFailure);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'Failure.invalidCredentials()';
}


}




/// @nodoc


class EmailAlreadyInUseFailure implements Failure {
  const EmailAlreadyInUseFailure();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is EmailAlreadyInUseFailure);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'Failure.emailAlreadyInUse()';
}


}




/// @nodoc


class WeakPasswordFailure implements Failure {
  const WeakPasswordFailure();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is WeakPasswordFailure);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'Failure.weakPassword()';
}


}




/// @nodoc


class RequiresRecentLoginFailure implements Failure {
  const RequiresRecentLoginFailure();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RequiresRecentLoginFailure);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'Failure.requiresRecentLogin()';
}


}




/// @nodoc


class SessionExpiredFailure implements Failure {
  const SessionExpiredFailure();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SessionExpiredFailure);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'Failure.sessionExpired()';
}


}




/// @nodoc


class TooManyRequestsFailure implements Failure {
  const TooManyRequestsFailure();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TooManyRequestsFailure);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'Failure.tooManyRequests()';
}


}




/// @nodoc


class NoCameraFailure implements Failure {
  const NoCameraFailure();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is NoCameraFailure);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'Failure.noCamera()';
}


}




/// @nodoc


class CaptureFailedFailure implements Failure {
  const CaptureFailedFailure(this.message);
  

 final  String message;

/// Create a copy of Failure
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CaptureFailedFailureCopyWith<CaptureFailedFailure> get copyWith => _$CaptureFailedFailureCopyWithImpl<CaptureFailedFailure>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CaptureFailedFailure&&(identical(other.message, message) || other.message == message));
}


@override
int get hashCode => Object.hash(runtimeType,message);

@override
String toString() {
  return 'Failure.captureFailed(message: $message)';
}


}

/// @nodoc
abstract mixin class $CaptureFailedFailureCopyWith<$Res> implements $FailureCopyWith<$Res> {
  factory $CaptureFailedFailureCopyWith(CaptureFailedFailure value, $Res Function(CaptureFailedFailure) _then) = _$CaptureFailedFailureCopyWithImpl;
@useResult
$Res call({
 String message
});




}
/// @nodoc
class _$CaptureFailedFailureCopyWithImpl<$Res>
    implements $CaptureFailedFailureCopyWith<$Res> {
  _$CaptureFailedFailureCopyWithImpl(this._self, this._then);

  final CaptureFailedFailure _self;
  final $Res Function(CaptureFailedFailure) _then;

/// Create a copy of Failure
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? message = null,}) {
  return _then(CaptureFailedFailure(
null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class PhotoAccessDeniedFailure implements Failure {
  const PhotoAccessDeniedFailure({required this.permanent});
  

 final  bool permanent;

/// Create a copy of Failure
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PhotoAccessDeniedFailureCopyWith<PhotoAccessDeniedFailure> get copyWith => _$PhotoAccessDeniedFailureCopyWithImpl<PhotoAccessDeniedFailure>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PhotoAccessDeniedFailure&&(identical(other.permanent, permanent) || other.permanent == permanent));
}


@override
int get hashCode => Object.hash(runtimeType,permanent);

@override
String toString() {
  return 'Failure.photoAccessDenied(permanent: $permanent)';
}


}

/// @nodoc
abstract mixin class $PhotoAccessDeniedFailureCopyWith<$Res> implements $FailureCopyWith<$Res> {
  factory $PhotoAccessDeniedFailureCopyWith(PhotoAccessDeniedFailure value, $Res Function(PhotoAccessDeniedFailure) _then) = _$PhotoAccessDeniedFailureCopyWithImpl;
@useResult
$Res call({
 bool permanent
});




}
/// @nodoc
class _$PhotoAccessDeniedFailureCopyWithImpl<$Res>
    implements $PhotoAccessDeniedFailureCopyWith<$Res> {
  _$PhotoAccessDeniedFailureCopyWithImpl(this._self, this._then);

  final PhotoAccessDeniedFailure _self;
  final $Res Function(PhotoAccessDeniedFailure) _then;

/// Create a copy of Failure
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? permanent = null,}) {
  return _then(PhotoAccessDeniedFailure(
permanent: null == permanent ? _self.permanent : permanent // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
