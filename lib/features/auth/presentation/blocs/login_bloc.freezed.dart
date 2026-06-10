// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'login_bloc.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$LoginEvent {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LoginEvent);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'LoginEvent()';
}


}

/// @nodoc
class $LoginEventCopyWith<$Res>  {
$LoginEventCopyWith(LoginEvent _, $Res Function(LoginEvent) __);
}


/// Adds pattern-matching-related methods to [LoginEvent].
extension LoginEventPatterns on LoginEvent {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( LoginModeToggled value)?  modeToggled,TResult Function( LoginEmailSubmitted value)?  emailSubmitted,TResult Function( LoginGoogleRequested value)?  googleRequested,TResult Function( LoginAppleRequested value)?  appleRequested,TResult Function( LoginPasswordResetRequested value)?  passwordResetRequested,TResult Function( LoginFieldsEdited value)?  fieldsEdited,required TResult orElse(),}){
final _that = this;
switch (_that) {
case LoginModeToggled() when modeToggled != null:
return modeToggled(_that);case LoginEmailSubmitted() when emailSubmitted != null:
return emailSubmitted(_that);case LoginGoogleRequested() when googleRequested != null:
return googleRequested(_that);case LoginAppleRequested() when appleRequested != null:
return appleRequested(_that);case LoginPasswordResetRequested() when passwordResetRequested != null:
return passwordResetRequested(_that);case LoginFieldsEdited() when fieldsEdited != null:
return fieldsEdited(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( LoginModeToggled value)  modeToggled,required TResult Function( LoginEmailSubmitted value)  emailSubmitted,required TResult Function( LoginGoogleRequested value)  googleRequested,required TResult Function( LoginAppleRequested value)  appleRequested,required TResult Function( LoginPasswordResetRequested value)  passwordResetRequested,required TResult Function( LoginFieldsEdited value)  fieldsEdited,}){
final _that = this;
switch (_that) {
case LoginModeToggled():
return modeToggled(_that);case LoginEmailSubmitted():
return emailSubmitted(_that);case LoginGoogleRequested():
return googleRequested(_that);case LoginAppleRequested():
return appleRequested(_that);case LoginPasswordResetRequested():
return passwordResetRequested(_that);case LoginFieldsEdited():
return fieldsEdited(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( LoginModeToggled value)?  modeToggled,TResult? Function( LoginEmailSubmitted value)?  emailSubmitted,TResult? Function( LoginGoogleRequested value)?  googleRequested,TResult? Function( LoginAppleRequested value)?  appleRequested,TResult? Function( LoginPasswordResetRequested value)?  passwordResetRequested,TResult? Function( LoginFieldsEdited value)?  fieldsEdited,}){
final _that = this;
switch (_that) {
case LoginModeToggled() when modeToggled != null:
return modeToggled(_that);case LoginEmailSubmitted() when emailSubmitted != null:
return emailSubmitted(_that);case LoginGoogleRequested() when googleRequested != null:
return googleRequested(_that);case LoginAppleRequested() when appleRequested != null:
return appleRequested(_that);case LoginPasswordResetRequested() when passwordResetRequested != null:
return passwordResetRequested(_that);case LoginFieldsEdited() when fieldsEdited != null:
return fieldsEdited(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function()?  modeToggled,TResult Function( String email,  String password)?  emailSubmitted,TResult Function()?  googleRequested,TResult Function()?  appleRequested,TResult Function( String email)?  passwordResetRequested,TResult Function()?  fieldsEdited,required TResult orElse(),}) {final _that = this;
switch (_that) {
case LoginModeToggled() when modeToggled != null:
return modeToggled();case LoginEmailSubmitted() when emailSubmitted != null:
return emailSubmitted(_that.email,_that.password);case LoginGoogleRequested() when googleRequested != null:
return googleRequested();case LoginAppleRequested() when appleRequested != null:
return appleRequested();case LoginPasswordResetRequested() when passwordResetRequested != null:
return passwordResetRequested(_that.email);case LoginFieldsEdited() when fieldsEdited != null:
return fieldsEdited();case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function()  modeToggled,required TResult Function( String email,  String password)  emailSubmitted,required TResult Function()  googleRequested,required TResult Function()  appleRequested,required TResult Function( String email)  passwordResetRequested,required TResult Function()  fieldsEdited,}) {final _that = this;
switch (_that) {
case LoginModeToggled():
return modeToggled();case LoginEmailSubmitted():
return emailSubmitted(_that.email,_that.password);case LoginGoogleRequested():
return googleRequested();case LoginAppleRequested():
return appleRequested();case LoginPasswordResetRequested():
return passwordResetRequested(_that.email);case LoginFieldsEdited():
return fieldsEdited();}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function()?  modeToggled,TResult? Function( String email,  String password)?  emailSubmitted,TResult? Function()?  googleRequested,TResult? Function()?  appleRequested,TResult? Function( String email)?  passwordResetRequested,TResult? Function()?  fieldsEdited,}) {final _that = this;
switch (_that) {
case LoginModeToggled() when modeToggled != null:
return modeToggled();case LoginEmailSubmitted() when emailSubmitted != null:
return emailSubmitted(_that.email,_that.password);case LoginGoogleRequested() when googleRequested != null:
return googleRequested();case LoginAppleRequested() when appleRequested != null:
return appleRequested();case LoginPasswordResetRequested() when passwordResetRequested != null:
return passwordResetRequested(_that.email);case LoginFieldsEdited() when fieldsEdited != null:
return fieldsEdited();case _:
  return null;

}
}

}

/// @nodoc


class LoginModeToggled implements LoginEvent {
  const LoginModeToggled();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LoginModeToggled);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'LoginEvent.modeToggled()';
}


}




/// @nodoc


class LoginEmailSubmitted implements LoginEvent {
  const LoginEmailSubmitted({required this.email, required this.password});
  

 final  String email;
 final  String password;

/// Create a copy of LoginEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LoginEmailSubmittedCopyWith<LoginEmailSubmitted> get copyWith => _$LoginEmailSubmittedCopyWithImpl<LoginEmailSubmitted>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LoginEmailSubmitted&&(identical(other.email, email) || other.email == email)&&(identical(other.password, password) || other.password == password));
}


@override
int get hashCode => Object.hash(runtimeType,email,password);

@override
String toString() {
  return 'LoginEvent.emailSubmitted(email: $email, password: $password)';
}


}

/// @nodoc
abstract mixin class $LoginEmailSubmittedCopyWith<$Res> implements $LoginEventCopyWith<$Res> {
  factory $LoginEmailSubmittedCopyWith(LoginEmailSubmitted value, $Res Function(LoginEmailSubmitted) _then) = _$LoginEmailSubmittedCopyWithImpl;
@useResult
$Res call({
 String email, String password
});




}
/// @nodoc
class _$LoginEmailSubmittedCopyWithImpl<$Res>
    implements $LoginEmailSubmittedCopyWith<$Res> {
  _$LoginEmailSubmittedCopyWithImpl(this._self, this._then);

  final LoginEmailSubmitted _self;
  final $Res Function(LoginEmailSubmitted) _then;

/// Create a copy of LoginEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? email = null,Object? password = null,}) {
  return _then(LoginEmailSubmitted(
email: null == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String,password: null == password ? _self.password : password // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class LoginGoogleRequested implements LoginEvent {
  const LoginGoogleRequested();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LoginGoogleRequested);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'LoginEvent.googleRequested()';
}


}




/// @nodoc


class LoginAppleRequested implements LoginEvent {
  const LoginAppleRequested();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LoginAppleRequested);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'LoginEvent.appleRequested()';
}


}




/// @nodoc


class LoginPasswordResetRequested implements LoginEvent {
  const LoginPasswordResetRequested({required this.email});
  

 final  String email;

/// Create a copy of LoginEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LoginPasswordResetRequestedCopyWith<LoginPasswordResetRequested> get copyWith => _$LoginPasswordResetRequestedCopyWithImpl<LoginPasswordResetRequested>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LoginPasswordResetRequested&&(identical(other.email, email) || other.email == email));
}


@override
int get hashCode => Object.hash(runtimeType,email);

@override
String toString() {
  return 'LoginEvent.passwordResetRequested(email: $email)';
}


}

/// @nodoc
abstract mixin class $LoginPasswordResetRequestedCopyWith<$Res> implements $LoginEventCopyWith<$Res> {
  factory $LoginPasswordResetRequestedCopyWith(LoginPasswordResetRequested value, $Res Function(LoginPasswordResetRequested) _then) = _$LoginPasswordResetRequestedCopyWithImpl;
@useResult
$Res call({
 String email
});




}
/// @nodoc
class _$LoginPasswordResetRequestedCopyWithImpl<$Res>
    implements $LoginPasswordResetRequestedCopyWith<$Res> {
  _$LoginPasswordResetRequestedCopyWithImpl(this._self, this._then);

  final LoginPasswordResetRequested _self;
  final $Res Function(LoginPasswordResetRequested) _then;

/// Create a copy of LoginEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? email = null,}) {
  return _then(LoginPasswordResetRequested(
email: null == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class LoginFieldsEdited implements LoginEvent {
  const LoginFieldsEdited();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LoginFieldsEdited);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'LoginEvent.fieldsEdited()';
}


}




/// @nodoc
mixin _$LoginState {

 LoginMode get mode; LoginInFlight get inFlight; EmailFieldError? get emailError; PasswordFieldError? get passwordError; Failure? get failure; bool get resetEmailSent;
/// Create a copy of LoginState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LoginStateCopyWith<LoginState> get copyWith => _$LoginStateCopyWithImpl<LoginState>(this as LoginState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LoginState&&(identical(other.mode, mode) || other.mode == mode)&&(identical(other.inFlight, inFlight) || other.inFlight == inFlight)&&(identical(other.emailError, emailError) || other.emailError == emailError)&&(identical(other.passwordError, passwordError) || other.passwordError == passwordError)&&(identical(other.failure, failure) || other.failure == failure)&&(identical(other.resetEmailSent, resetEmailSent) || other.resetEmailSent == resetEmailSent));
}


@override
int get hashCode => Object.hash(runtimeType,mode,inFlight,emailError,passwordError,failure,resetEmailSent);

@override
String toString() {
  return 'LoginState(mode: $mode, inFlight: $inFlight, emailError: $emailError, passwordError: $passwordError, failure: $failure, resetEmailSent: $resetEmailSent)';
}


}

/// @nodoc
abstract mixin class $LoginStateCopyWith<$Res>  {
  factory $LoginStateCopyWith(LoginState value, $Res Function(LoginState) _then) = _$LoginStateCopyWithImpl;
@useResult
$Res call({
 LoginMode mode, LoginInFlight inFlight, EmailFieldError? emailError, PasswordFieldError? passwordError, Failure? failure, bool resetEmailSent
});


$FailureCopyWith<$Res>? get failure;

}
/// @nodoc
class _$LoginStateCopyWithImpl<$Res>
    implements $LoginStateCopyWith<$Res> {
  _$LoginStateCopyWithImpl(this._self, this._then);

  final LoginState _self;
  final $Res Function(LoginState) _then;

/// Create a copy of LoginState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? mode = null,Object? inFlight = null,Object? emailError = freezed,Object? passwordError = freezed,Object? failure = freezed,Object? resetEmailSent = null,}) {
  return _then(_self.copyWith(
mode: null == mode ? _self.mode : mode // ignore: cast_nullable_to_non_nullable
as LoginMode,inFlight: null == inFlight ? _self.inFlight : inFlight // ignore: cast_nullable_to_non_nullable
as LoginInFlight,emailError: freezed == emailError ? _self.emailError : emailError // ignore: cast_nullable_to_non_nullable
as EmailFieldError?,passwordError: freezed == passwordError ? _self.passwordError : passwordError // ignore: cast_nullable_to_non_nullable
as PasswordFieldError?,failure: freezed == failure ? _self.failure : failure // ignore: cast_nullable_to_non_nullable
as Failure?,resetEmailSent: null == resetEmailSent ? _self.resetEmailSent : resetEmailSent // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}
/// Create a copy of LoginState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$FailureCopyWith<$Res>? get failure {
    if (_self.failure == null) {
    return null;
  }

  return $FailureCopyWith<$Res>(_self.failure!, (value) {
    return _then(_self.copyWith(failure: value));
  });
}
}


/// Adds pattern-matching-related methods to [LoginState].
extension LoginStatePatterns on LoginState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LoginState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LoginState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LoginState value)  $default,){
final _that = this;
switch (_that) {
case _LoginState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LoginState value)?  $default,){
final _that = this;
switch (_that) {
case _LoginState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( LoginMode mode,  LoginInFlight inFlight,  EmailFieldError? emailError,  PasswordFieldError? passwordError,  Failure? failure,  bool resetEmailSent)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LoginState() when $default != null:
return $default(_that.mode,_that.inFlight,_that.emailError,_that.passwordError,_that.failure,_that.resetEmailSent);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( LoginMode mode,  LoginInFlight inFlight,  EmailFieldError? emailError,  PasswordFieldError? passwordError,  Failure? failure,  bool resetEmailSent)  $default,) {final _that = this;
switch (_that) {
case _LoginState():
return $default(_that.mode,_that.inFlight,_that.emailError,_that.passwordError,_that.failure,_that.resetEmailSent);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( LoginMode mode,  LoginInFlight inFlight,  EmailFieldError? emailError,  PasswordFieldError? passwordError,  Failure? failure,  bool resetEmailSent)?  $default,) {final _that = this;
switch (_that) {
case _LoginState() when $default != null:
return $default(_that.mode,_that.inFlight,_that.emailError,_that.passwordError,_that.failure,_that.resetEmailSent);case _:
  return null;

}
}

}

/// @nodoc


class _LoginState implements LoginState {
  const _LoginState({this.mode = LoginMode.signIn, this.inFlight = LoginInFlight.none, this.emailError, this.passwordError, this.failure, this.resetEmailSent = false});
  

@override@JsonKey() final  LoginMode mode;
@override@JsonKey() final  LoginInFlight inFlight;
@override final  EmailFieldError? emailError;
@override final  PasswordFieldError? passwordError;
@override final  Failure? failure;
@override@JsonKey() final  bool resetEmailSent;

/// Create a copy of LoginState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LoginStateCopyWith<_LoginState> get copyWith => __$LoginStateCopyWithImpl<_LoginState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _LoginState&&(identical(other.mode, mode) || other.mode == mode)&&(identical(other.inFlight, inFlight) || other.inFlight == inFlight)&&(identical(other.emailError, emailError) || other.emailError == emailError)&&(identical(other.passwordError, passwordError) || other.passwordError == passwordError)&&(identical(other.failure, failure) || other.failure == failure)&&(identical(other.resetEmailSent, resetEmailSent) || other.resetEmailSent == resetEmailSent));
}


@override
int get hashCode => Object.hash(runtimeType,mode,inFlight,emailError,passwordError,failure,resetEmailSent);

@override
String toString() {
  return 'LoginState(mode: $mode, inFlight: $inFlight, emailError: $emailError, passwordError: $passwordError, failure: $failure, resetEmailSent: $resetEmailSent)';
}


}

/// @nodoc
abstract mixin class _$LoginStateCopyWith<$Res> implements $LoginStateCopyWith<$Res> {
  factory _$LoginStateCopyWith(_LoginState value, $Res Function(_LoginState) _then) = __$LoginStateCopyWithImpl;
@override @useResult
$Res call({
 LoginMode mode, LoginInFlight inFlight, EmailFieldError? emailError, PasswordFieldError? passwordError, Failure? failure, bool resetEmailSent
});


@override $FailureCopyWith<$Res>? get failure;

}
/// @nodoc
class __$LoginStateCopyWithImpl<$Res>
    implements _$LoginStateCopyWith<$Res> {
  __$LoginStateCopyWithImpl(this._self, this._then);

  final _LoginState _self;
  final $Res Function(_LoginState) _then;

/// Create a copy of LoginState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? mode = null,Object? inFlight = null,Object? emailError = freezed,Object? passwordError = freezed,Object? failure = freezed,Object? resetEmailSent = null,}) {
  return _then(_LoginState(
mode: null == mode ? _self.mode : mode // ignore: cast_nullable_to_non_nullable
as LoginMode,inFlight: null == inFlight ? _self.inFlight : inFlight // ignore: cast_nullable_to_non_nullable
as LoginInFlight,emailError: freezed == emailError ? _self.emailError : emailError // ignore: cast_nullable_to_non_nullable
as EmailFieldError?,passwordError: freezed == passwordError ? _self.passwordError : passwordError // ignore: cast_nullable_to_non_nullable
as PasswordFieldError?,failure: freezed == failure ? _self.failure : failure // ignore: cast_nullable_to_non_nullable
as Failure?,resetEmailSent: null == resetEmailSent ? _self.resetEmailSent : resetEmailSent // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

/// Create a copy of LoginState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$FailureCopyWith<$Res>? get failure {
    if (_self.failure == null) {
    return null;
  }

  return $FailureCopyWith<$Res>(_self.failure!, (value) {
    return _then(_self.copyWith(failure: value));
  });
}
}

// dart format on
