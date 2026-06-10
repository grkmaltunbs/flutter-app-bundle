// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'camera_bloc.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$CameraEvent {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CameraEvent);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'CameraEvent()';
}


}

/// @nodoc
class $CameraEventCopyWith<$Res>  {
$CameraEventCopyWith(CameraEvent _, $Res Function(CameraEvent) __);
}


/// Adds pattern-matching-related methods to [CameraEvent].
extension CameraEventPatterns on CameraEvent {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( CameraStarted value)?  started,TResult Function( CameraModeChanged value)?  modeChanged,TResult Function( CameraShutterPressed value)?  shutterPressed,TResult Function( CameraRecordingStopped value)?  recordingStopped,TResult Function( CameraGalleryRequested value)?  galleryRequested,TResult Function( CameraFlashToggled value)?  flashToggled,TResult Function( CameraFlipRequested value)?  flipRequested,TResult Function( CameraPermissionRetryRequested value)?  permissionRetryRequested,TResult Function( CameraOpenSettingsRequested value)?  openSettingsRequested,TResult Function( CameraAppBackgrounded value)?  appBackgrounded,TResult Function( CameraAppResumed value)?  appResumed,TResult Function( CameraReturnedFromCapture value)?  returnedFromCapture,required TResult orElse(),}){
final _that = this;
switch (_that) {
case CameraStarted() when started != null:
return started(_that);case CameraModeChanged() when modeChanged != null:
return modeChanged(_that);case CameraShutterPressed() when shutterPressed != null:
return shutterPressed(_that);case CameraRecordingStopped() when recordingStopped != null:
return recordingStopped(_that);case CameraGalleryRequested() when galleryRequested != null:
return galleryRequested(_that);case CameraFlashToggled() when flashToggled != null:
return flashToggled(_that);case CameraFlipRequested() when flipRequested != null:
return flipRequested(_that);case CameraPermissionRetryRequested() when permissionRetryRequested != null:
return permissionRetryRequested(_that);case CameraOpenSettingsRequested() when openSettingsRequested != null:
return openSettingsRequested(_that);case CameraAppBackgrounded() when appBackgrounded != null:
return appBackgrounded(_that);case CameraAppResumed() when appResumed != null:
return appResumed(_that);case CameraReturnedFromCapture() when returnedFromCapture != null:
return returnedFromCapture(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( CameraStarted value)  started,required TResult Function( CameraModeChanged value)  modeChanged,required TResult Function( CameraShutterPressed value)  shutterPressed,required TResult Function( CameraRecordingStopped value)  recordingStopped,required TResult Function( CameraGalleryRequested value)  galleryRequested,required TResult Function( CameraFlashToggled value)  flashToggled,required TResult Function( CameraFlipRequested value)  flipRequested,required TResult Function( CameraPermissionRetryRequested value)  permissionRetryRequested,required TResult Function( CameraOpenSettingsRequested value)  openSettingsRequested,required TResult Function( CameraAppBackgrounded value)  appBackgrounded,required TResult Function( CameraAppResumed value)  appResumed,required TResult Function( CameraReturnedFromCapture value)  returnedFromCapture,}){
final _that = this;
switch (_that) {
case CameraStarted():
return started(_that);case CameraModeChanged():
return modeChanged(_that);case CameraShutterPressed():
return shutterPressed(_that);case CameraRecordingStopped():
return recordingStopped(_that);case CameraGalleryRequested():
return galleryRequested(_that);case CameraFlashToggled():
return flashToggled(_that);case CameraFlipRequested():
return flipRequested(_that);case CameraPermissionRetryRequested():
return permissionRetryRequested(_that);case CameraOpenSettingsRequested():
return openSettingsRequested(_that);case CameraAppBackgrounded():
return appBackgrounded(_that);case CameraAppResumed():
return appResumed(_that);case CameraReturnedFromCapture():
return returnedFromCapture(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( CameraStarted value)?  started,TResult? Function( CameraModeChanged value)?  modeChanged,TResult? Function( CameraShutterPressed value)?  shutterPressed,TResult? Function( CameraRecordingStopped value)?  recordingStopped,TResult? Function( CameraGalleryRequested value)?  galleryRequested,TResult? Function( CameraFlashToggled value)?  flashToggled,TResult? Function( CameraFlipRequested value)?  flipRequested,TResult? Function( CameraPermissionRetryRequested value)?  permissionRetryRequested,TResult? Function( CameraOpenSettingsRequested value)?  openSettingsRequested,TResult? Function( CameraAppBackgrounded value)?  appBackgrounded,TResult? Function( CameraAppResumed value)?  appResumed,TResult? Function( CameraReturnedFromCapture value)?  returnedFromCapture,}){
final _that = this;
switch (_that) {
case CameraStarted() when started != null:
return started(_that);case CameraModeChanged() when modeChanged != null:
return modeChanged(_that);case CameraShutterPressed() when shutterPressed != null:
return shutterPressed(_that);case CameraRecordingStopped() when recordingStopped != null:
return recordingStopped(_that);case CameraGalleryRequested() when galleryRequested != null:
return galleryRequested(_that);case CameraFlashToggled() when flashToggled != null:
return flashToggled(_that);case CameraFlipRequested() when flipRequested != null:
return flipRequested(_that);case CameraPermissionRetryRequested() when permissionRetryRequested != null:
return permissionRetryRequested(_that);case CameraOpenSettingsRequested() when openSettingsRequested != null:
return openSettingsRequested(_that);case CameraAppBackgrounded() when appBackgrounded != null:
return appBackgrounded(_that);case CameraAppResumed() when appResumed != null:
return appResumed(_that);case CameraReturnedFromCapture() when returnedFromCapture != null:
return returnedFromCapture(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function()?  started,TResult Function( CaptureMode mode)?  modeChanged,TResult Function()?  shutterPressed,TResult Function()?  recordingStopped,TResult Function()?  galleryRequested,TResult Function()?  flashToggled,TResult Function()?  flipRequested,TResult Function()?  permissionRetryRequested,TResult Function()?  openSettingsRequested,TResult Function()?  appBackgrounded,TResult Function()?  appResumed,TResult Function()?  returnedFromCapture,required TResult orElse(),}) {final _that = this;
switch (_that) {
case CameraStarted() when started != null:
return started();case CameraModeChanged() when modeChanged != null:
return modeChanged(_that.mode);case CameraShutterPressed() when shutterPressed != null:
return shutterPressed();case CameraRecordingStopped() when recordingStopped != null:
return recordingStopped();case CameraGalleryRequested() when galleryRequested != null:
return galleryRequested();case CameraFlashToggled() when flashToggled != null:
return flashToggled();case CameraFlipRequested() when flipRequested != null:
return flipRequested();case CameraPermissionRetryRequested() when permissionRetryRequested != null:
return permissionRetryRequested();case CameraOpenSettingsRequested() when openSettingsRequested != null:
return openSettingsRequested();case CameraAppBackgrounded() when appBackgrounded != null:
return appBackgrounded();case CameraAppResumed() when appResumed != null:
return appResumed();case CameraReturnedFromCapture() when returnedFromCapture != null:
return returnedFromCapture();case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function()  started,required TResult Function( CaptureMode mode)  modeChanged,required TResult Function()  shutterPressed,required TResult Function()  recordingStopped,required TResult Function()  galleryRequested,required TResult Function()  flashToggled,required TResult Function()  flipRequested,required TResult Function()  permissionRetryRequested,required TResult Function()  openSettingsRequested,required TResult Function()  appBackgrounded,required TResult Function()  appResumed,required TResult Function()  returnedFromCapture,}) {final _that = this;
switch (_that) {
case CameraStarted():
return started();case CameraModeChanged():
return modeChanged(_that.mode);case CameraShutterPressed():
return shutterPressed();case CameraRecordingStopped():
return recordingStopped();case CameraGalleryRequested():
return galleryRequested();case CameraFlashToggled():
return flashToggled();case CameraFlipRequested():
return flipRequested();case CameraPermissionRetryRequested():
return permissionRetryRequested();case CameraOpenSettingsRequested():
return openSettingsRequested();case CameraAppBackgrounded():
return appBackgrounded();case CameraAppResumed():
return appResumed();case CameraReturnedFromCapture():
return returnedFromCapture();}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function()?  started,TResult? Function( CaptureMode mode)?  modeChanged,TResult? Function()?  shutterPressed,TResult? Function()?  recordingStopped,TResult? Function()?  galleryRequested,TResult? Function()?  flashToggled,TResult? Function()?  flipRequested,TResult? Function()?  permissionRetryRequested,TResult? Function()?  openSettingsRequested,TResult? Function()?  appBackgrounded,TResult? Function()?  appResumed,TResult? Function()?  returnedFromCapture,}) {final _that = this;
switch (_that) {
case CameraStarted() when started != null:
return started();case CameraModeChanged() when modeChanged != null:
return modeChanged(_that.mode);case CameraShutterPressed() when shutterPressed != null:
return shutterPressed();case CameraRecordingStopped() when recordingStopped != null:
return recordingStopped();case CameraGalleryRequested() when galleryRequested != null:
return galleryRequested();case CameraFlashToggled() when flashToggled != null:
return flashToggled();case CameraFlipRequested() when flipRequested != null:
return flipRequested();case CameraPermissionRetryRequested() when permissionRetryRequested != null:
return permissionRetryRequested();case CameraOpenSettingsRequested() when openSettingsRequested != null:
return openSettingsRequested();case CameraAppBackgrounded() when appBackgrounded != null:
return appBackgrounded();case CameraAppResumed() when appResumed != null:
return appResumed();case CameraReturnedFromCapture() when returnedFromCapture != null:
return returnedFromCapture();case _:
  return null;

}
}

}

/// @nodoc


class CameraStarted implements CameraEvent {
  const CameraStarted();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CameraStarted);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'CameraEvent.started()';
}


}




/// @nodoc


class CameraModeChanged implements CameraEvent {
  const CameraModeChanged(this.mode);
  

 final  CaptureMode mode;

/// Create a copy of CameraEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CameraModeChangedCopyWith<CameraModeChanged> get copyWith => _$CameraModeChangedCopyWithImpl<CameraModeChanged>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CameraModeChanged&&(identical(other.mode, mode) || other.mode == mode));
}


@override
int get hashCode => Object.hash(runtimeType,mode);

@override
String toString() {
  return 'CameraEvent.modeChanged(mode: $mode)';
}


}

/// @nodoc
abstract mixin class $CameraModeChangedCopyWith<$Res> implements $CameraEventCopyWith<$Res> {
  factory $CameraModeChangedCopyWith(CameraModeChanged value, $Res Function(CameraModeChanged) _then) = _$CameraModeChangedCopyWithImpl;
@useResult
$Res call({
 CaptureMode mode
});




}
/// @nodoc
class _$CameraModeChangedCopyWithImpl<$Res>
    implements $CameraModeChangedCopyWith<$Res> {
  _$CameraModeChangedCopyWithImpl(this._self, this._then);

  final CameraModeChanged _self;
  final $Res Function(CameraModeChanged) _then;

/// Create a copy of CameraEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? mode = null,}) {
  return _then(CameraModeChanged(
null == mode ? _self.mode : mode // ignore: cast_nullable_to_non_nullable
as CaptureMode,
  ));
}


}

/// @nodoc


class CameraShutterPressed implements CameraEvent {
  const CameraShutterPressed();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CameraShutterPressed);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'CameraEvent.shutterPressed()';
}


}




/// @nodoc


class CameraRecordingStopped implements CameraEvent {
  const CameraRecordingStopped();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CameraRecordingStopped);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'CameraEvent.recordingStopped()';
}


}




/// @nodoc


class CameraGalleryRequested implements CameraEvent {
  const CameraGalleryRequested();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CameraGalleryRequested);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'CameraEvent.galleryRequested()';
}


}




/// @nodoc


class CameraFlashToggled implements CameraEvent {
  const CameraFlashToggled();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CameraFlashToggled);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'CameraEvent.flashToggled()';
}


}




/// @nodoc


class CameraFlipRequested implements CameraEvent {
  const CameraFlipRequested();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CameraFlipRequested);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'CameraEvent.flipRequested()';
}


}




/// @nodoc


class CameraPermissionRetryRequested implements CameraEvent {
  const CameraPermissionRetryRequested();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CameraPermissionRetryRequested);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'CameraEvent.permissionRetryRequested()';
}


}




/// @nodoc


class CameraOpenSettingsRequested implements CameraEvent {
  const CameraOpenSettingsRequested();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CameraOpenSettingsRequested);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'CameraEvent.openSettingsRequested()';
}


}




/// @nodoc


class CameraAppBackgrounded implements CameraEvent {
  const CameraAppBackgrounded();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CameraAppBackgrounded);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'CameraEvent.appBackgrounded()';
}


}




/// @nodoc


class CameraAppResumed implements CameraEvent {
  const CameraAppResumed();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CameraAppResumed);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'CameraEvent.appResumed()';
}


}




/// @nodoc


class CameraReturnedFromCapture implements CameraEvent {
  const CameraReturnedFromCapture();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CameraReturnedFromCapture);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'CameraEvent.returnedFromCapture()';
}


}




/// @nodoc
mixin _$CameraState {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CameraState);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'CameraState()';
}


}

/// @nodoc
class $CameraStateCopyWith<$Res>  {
$CameraStateCopyWith(CameraState _, $Res Function(CameraState) __);
}


/// Adds pattern-matching-related methods to [CameraState].
extension CameraStatePatterns on CameraState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( CameraInitializing value)?  initializing,TResult Function( CameraReady value)?  ready,TResult Function( CameraDenied value)?  cameraDenied,TResult Function( CameraGalleryDenied value)?  galleryDenied,TResult Function( CameraUnavailable value)?  unavailable,TResult Function( CameraCapturing value)?  capturing,TResult Function( CameraRecording value)?  recording,TResult Function( CameraPickingGallery value)?  pickingGallery,TResult Function( CameraSuspended value)?  suspended,TResult Function( CameraSuccess value)?  success,required TResult orElse(),}){
final _that = this;
switch (_that) {
case CameraInitializing() when initializing != null:
return initializing(_that);case CameraReady() when ready != null:
return ready(_that);case CameraDenied() when cameraDenied != null:
return cameraDenied(_that);case CameraGalleryDenied() when galleryDenied != null:
return galleryDenied(_that);case CameraUnavailable() when unavailable != null:
return unavailable(_that);case CameraCapturing() when capturing != null:
return capturing(_that);case CameraRecording() when recording != null:
return recording(_that);case CameraPickingGallery() when pickingGallery != null:
return pickingGallery(_that);case CameraSuspended() when suspended != null:
return suspended(_that);case CameraSuccess() when success != null:
return success(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( CameraInitializing value)  initializing,required TResult Function( CameraReady value)  ready,required TResult Function( CameraDenied value)  cameraDenied,required TResult Function( CameraGalleryDenied value)  galleryDenied,required TResult Function( CameraUnavailable value)  unavailable,required TResult Function( CameraCapturing value)  capturing,required TResult Function( CameraRecording value)  recording,required TResult Function( CameraPickingGallery value)  pickingGallery,required TResult Function( CameraSuspended value)  suspended,required TResult Function( CameraSuccess value)  success,}){
final _that = this;
switch (_that) {
case CameraInitializing():
return initializing(_that);case CameraReady():
return ready(_that);case CameraDenied():
return cameraDenied(_that);case CameraGalleryDenied():
return galleryDenied(_that);case CameraUnavailable():
return unavailable(_that);case CameraCapturing():
return capturing(_that);case CameraRecording():
return recording(_that);case CameraPickingGallery():
return pickingGallery(_that);case CameraSuspended():
return suspended(_that);case CameraSuccess():
return success(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( CameraInitializing value)?  initializing,TResult? Function( CameraReady value)?  ready,TResult? Function( CameraDenied value)?  cameraDenied,TResult? Function( CameraGalleryDenied value)?  galleryDenied,TResult? Function( CameraUnavailable value)?  unavailable,TResult? Function( CameraCapturing value)?  capturing,TResult? Function( CameraRecording value)?  recording,TResult? Function( CameraPickingGallery value)?  pickingGallery,TResult? Function( CameraSuspended value)?  suspended,TResult? Function( CameraSuccess value)?  success,}){
final _that = this;
switch (_that) {
case CameraInitializing() when initializing != null:
return initializing(_that);case CameraReady() when ready != null:
return ready(_that);case CameraDenied() when cameraDenied != null:
return cameraDenied(_that);case CameraGalleryDenied() when galleryDenied != null:
return galleryDenied(_that);case CameraUnavailable() when unavailable != null:
return unavailable(_that);case CameraCapturing() when capturing != null:
return capturing(_that);case CameraRecording() when recording != null:
return recording(_that);case CameraPickingGallery() when pickingGallery != null:
return pickingGallery(_that);case CameraSuspended() when suspended != null:
return suspended(_that);case CameraSuccess() when success != null:
return success(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function()?  initializing,TResult Function( CaptureMode mode,  bool flashOn,  bool frontCamera,  bool flashAvailable,  Failure? failure)?  ready,TResult Function( bool permanent)?  cameraDenied,TResult Function( bool permanent)?  galleryDenied,TResult Function()?  unavailable,TResult Function()?  capturing,TResult Function( int framesCaptured,  int frameTarget)?  recording,TResult Function()?  pickingGallery,TResult Function()?  suspended,TResult Function( CapturePayload payload)?  success,required TResult orElse(),}) {final _that = this;
switch (_that) {
case CameraInitializing() when initializing != null:
return initializing();case CameraReady() when ready != null:
return ready(_that.mode,_that.flashOn,_that.frontCamera,_that.flashAvailable,_that.failure);case CameraDenied() when cameraDenied != null:
return cameraDenied(_that.permanent);case CameraGalleryDenied() when galleryDenied != null:
return galleryDenied(_that.permanent);case CameraUnavailable() when unavailable != null:
return unavailable();case CameraCapturing() when capturing != null:
return capturing();case CameraRecording() when recording != null:
return recording(_that.framesCaptured,_that.frameTarget);case CameraPickingGallery() when pickingGallery != null:
return pickingGallery();case CameraSuspended() when suspended != null:
return suspended();case CameraSuccess() when success != null:
return success(_that.payload);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function()  initializing,required TResult Function( CaptureMode mode,  bool flashOn,  bool frontCamera,  bool flashAvailable,  Failure? failure)  ready,required TResult Function( bool permanent)  cameraDenied,required TResult Function( bool permanent)  galleryDenied,required TResult Function()  unavailable,required TResult Function()  capturing,required TResult Function( int framesCaptured,  int frameTarget)  recording,required TResult Function()  pickingGallery,required TResult Function()  suspended,required TResult Function( CapturePayload payload)  success,}) {final _that = this;
switch (_that) {
case CameraInitializing():
return initializing();case CameraReady():
return ready(_that.mode,_that.flashOn,_that.frontCamera,_that.flashAvailable,_that.failure);case CameraDenied():
return cameraDenied(_that.permanent);case CameraGalleryDenied():
return galleryDenied(_that.permanent);case CameraUnavailable():
return unavailable();case CameraCapturing():
return capturing();case CameraRecording():
return recording(_that.framesCaptured,_that.frameTarget);case CameraPickingGallery():
return pickingGallery();case CameraSuspended():
return suspended();case CameraSuccess():
return success(_that.payload);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function()?  initializing,TResult? Function( CaptureMode mode,  bool flashOn,  bool frontCamera,  bool flashAvailable,  Failure? failure)?  ready,TResult? Function( bool permanent)?  cameraDenied,TResult? Function( bool permanent)?  galleryDenied,TResult? Function()?  unavailable,TResult? Function()?  capturing,TResult? Function( int framesCaptured,  int frameTarget)?  recording,TResult? Function()?  pickingGallery,TResult? Function()?  suspended,TResult? Function( CapturePayload payload)?  success,}) {final _that = this;
switch (_that) {
case CameraInitializing() when initializing != null:
return initializing();case CameraReady() when ready != null:
return ready(_that.mode,_that.flashOn,_that.frontCamera,_that.flashAvailable,_that.failure);case CameraDenied() when cameraDenied != null:
return cameraDenied(_that.permanent);case CameraGalleryDenied() when galleryDenied != null:
return galleryDenied(_that.permanent);case CameraUnavailable() when unavailable != null:
return unavailable();case CameraCapturing() when capturing != null:
return capturing();case CameraRecording() when recording != null:
return recording(_that.framesCaptured,_that.frameTarget);case CameraPickingGallery() when pickingGallery != null:
return pickingGallery();case CameraSuspended() when suspended != null:
return suspended();case CameraSuccess() when success != null:
return success(_that.payload);case _:
  return null;

}
}

}

/// @nodoc


class CameraInitializing implements CameraState {
  const CameraInitializing();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CameraInitializing);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'CameraState.initializing()';
}


}




/// @nodoc


class CameraReady implements CameraState {
  const CameraReady({required this.mode, required this.flashOn, required this.frontCamera, required this.flashAvailable, this.failure});
  

 final  CaptureMode mode;
 final  bool flashOn;
 final  bool frontCamera;
 final  bool flashAvailable;
 final  Failure? failure;

/// Create a copy of CameraState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CameraReadyCopyWith<CameraReady> get copyWith => _$CameraReadyCopyWithImpl<CameraReady>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CameraReady&&(identical(other.mode, mode) || other.mode == mode)&&(identical(other.flashOn, flashOn) || other.flashOn == flashOn)&&(identical(other.frontCamera, frontCamera) || other.frontCamera == frontCamera)&&(identical(other.flashAvailable, flashAvailable) || other.flashAvailable == flashAvailable)&&(identical(other.failure, failure) || other.failure == failure));
}


@override
int get hashCode => Object.hash(runtimeType,mode,flashOn,frontCamera,flashAvailable,failure);

@override
String toString() {
  return 'CameraState.ready(mode: $mode, flashOn: $flashOn, frontCamera: $frontCamera, flashAvailable: $flashAvailable, failure: $failure)';
}


}

/// @nodoc
abstract mixin class $CameraReadyCopyWith<$Res> implements $CameraStateCopyWith<$Res> {
  factory $CameraReadyCopyWith(CameraReady value, $Res Function(CameraReady) _then) = _$CameraReadyCopyWithImpl;
@useResult
$Res call({
 CaptureMode mode, bool flashOn, bool frontCamera, bool flashAvailable, Failure? failure
});


$FailureCopyWith<$Res>? get failure;

}
/// @nodoc
class _$CameraReadyCopyWithImpl<$Res>
    implements $CameraReadyCopyWith<$Res> {
  _$CameraReadyCopyWithImpl(this._self, this._then);

  final CameraReady _self;
  final $Res Function(CameraReady) _then;

/// Create a copy of CameraState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? mode = null,Object? flashOn = null,Object? frontCamera = null,Object? flashAvailable = null,Object? failure = freezed,}) {
  return _then(CameraReady(
mode: null == mode ? _self.mode : mode // ignore: cast_nullable_to_non_nullable
as CaptureMode,flashOn: null == flashOn ? _self.flashOn : flashOn // ignore: cast_nullable_to_non_nullable
as bool,frontCamera: null == frontCamera ? _self.frontCamera : frontCamera // ignore: cast_nullable_to_non_nullable
as bool,flashAvailable: null == flashAvailable ? _self.flashAvailable : flashAvailable // ignore: cast_nullable_to_non_nullable
as bool,failure: freezed == failure ? _self.failure : failure // ignore: cast_nullable_to_non_nullable
as Failure?,
  ));
}

/// Create a copy of CameraState
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

/// @nodoc


class CameraDenied implements CameraState {
  const CameraDenied({required this.permanent});
  

 final  bool permanent;

/// Create a copy of CameraState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CameraDeniedCopyWith<CameraDenied> get copyWith => _$CameraDeniedCopyWithImpl<CameraDenied>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CameraDenied&&(identical(other.permanent, permanent) || other.permanent == permanent));
}


@override
int get hashCode => Object.hash(runtimeType,permanent);

@override
String toString() {
  return 'CameraState.cameraDenied(permanent: $permanent)';
}


}

/// @nodoc
abstract mixin class $CameraDeniedCopyWith<$Res> implements $CameraStateCopyWith<$Res> {
  factory $CameraDeniedCopyWith(CameraDenied value, $Res Function(CameraDenied) _then) = _$CameraDeniedCopyWithImpl;
@useResult
$Res call({
 bool permanent
});




}
/// @nodoc
class _$CameraDeniedCopyWithImpl<$Res>
    implements $CameraDeniedCopyWith<$Res> {
  _$CameraDeniedCopyWithImpl(this._self, this._then);

  final CameraDenied _self;
  final $Res Function(CameraDenied) _then;

/// Create a copy of CameraState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? permanent = null,}) {
  return _then(CameraDenied(
permanent: null == permanent ? _self.permanent : permanent // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

/// @nodoc


class CameraGalleryDenied implements CameraState {
  const CameraGalleryDenied({required this.permanent});
  

 final  bool permanent;

/// Create a copy of CameraState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CameraGalleryDeniedCopyWith<CameraGalleryDenied> get copyWith => _$CameraGalleryDeniedCopyWithImpl<CameraGalleryDenied>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CameraGalleryDenied&&(identical(other.permanent, permanent) || other.permanent == permanent));
}


@override
int get hashCode => Object.hash(runtimeType,permanent);

@override
String toString() {
  return 'CameraState.galleryDenied(permanent: $permanent)';
}


}

/// @nodoc
abstract mixin class $CameraGalleryDeniedCopyWith<$Res> implements $CameraStateCopyWith<$Res> {
  factory $CameraGalleryDeniedCopyWith(CameraGalleryDenied value, $Res Function(CameraGalleryDenied) _then) = _$CameraGalleryDeniedCopyWithImpl;
@useResult
$Res call({
 bool permanent
});




}
/// @nodoc
class _$CameraGalleryDeniedCopyWithImpl<$Res>
    implements $CameraGalleryDeniedCopyWith<$Res> {
  _$CameraGalleryDeniedCopyWithImpl(this._self, this._then);

  final CameraGalleryDenied _self;
  final $Res Function(CameraGalleryDenied) _then;

/// Create a copy of CameraState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? permanent = null,}) {
  return _then(CameraGalleryDenied(
permanent: null == permanent ? _self.permanent : permanent // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

/// @nodoc


class CameraUnavailable implements CameraState {
  const CameraUnavailable();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CameraUnavailable);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'CameraState.unavailable()';
}


}




/// @nodoc


class CameraCapturing implements CameraState {
  const CameraCapturing();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CameraCapturing);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'CameraState.capturing()';
}


}




/// @nodoc


class CameraRecording implements CameraState {
  const CameraRecording({required this.framesCaptured, required this.frameTarget});
  

 final  int framesCaptured;
 final  int frameTarget;

/// Create a copy of CameraState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CameraRecordingCopyWith<CameraRecording> get copyWith => _$CameraRecordingCopyWithImpl<CameraRecording>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CameraRecording&&(identical(other.framesCaptured, framesCaptured) || other.framesCaptured == framesCaptured)&&(identical(other.frameTarget, frameTarget) || other.frameTarget == frameTarget));
}


@override
int get hashCode => Object.hash(runtimeType,framesCaptured,frameTarget);

@override
String toString() {
  return 'CameraState.recording(framesCaptured: $framesCaptured, frameTarget: $frameTarget)';
}


}

/// @nodoc
abstract mixin class $CameraRecordingCopyWith<$Res> implements $CameraStateCopyWith<$Res> {
  factory $CameraRecordingCopyWith(CameraRecording value, $Res Function(CameraRecording) _then) = _$CameraRecordingCopyWithImpl;
@useResult
$Res call({
 int framesCaptured, int frameTarget
});




}
/// @nodoc
class _$CameraRecordingCopyWithImpl<$Res>
    implements $CameraRecordingCopyWith<$Res> {
  _$CameraRecordingCopyWithImpl(this._self, this._then);

  final CameraRecording _self;
  final $Res Function(CameraRecording) _then;

/// Create a copy of CameraState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? framesCaptured = null,Object? frameTarget = null,}) {
  return _then(CameraRecording(
framesCaptured: null == framesCaptured ? _self.framesCaptured : framesCaptured // ignore: cast_nullable_to_non_nullable
as int,frameTarget: null == frameTarget ? _self.frameTarget : frameTarget // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc


class CameraPickingGallery implements CameraState {
  const CameraPickingGallery();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CameraPickingGallery);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'CameraState.pickingGallery()';
}


}




/// @nodoc


class CameraSuspended implements CameraState {
  const CameraSuspended();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CameraSuspended);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'CameraState.suspended()';
}


}




/// @nodoc


class CameraSuccess implements CameraState {
  const CameraSuccess({required this.payload});
  

 final  CapturePayload payload;

/// Create a copy of CameraState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CameraSuccessCopyWith<CameraSuccess> get copyWith => _$CameraSuccessCopyWithImpl<CameraSuccess>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CameraSuccess&&(identical(other.payload, payload) || other.payload == payload));
}


@override
int get hashCode => Object.hash(runtimeType,payload);

@override
String toString() {
  return 'CameraState.success(payload: $payload)';
}


}

/// @nodoc
abstract mixin class $CameraSuccessCopyWith<$Res> implements $CameraStateCopyWith<$Res> {
  factory $CameraSuccessCopyWith(CameraSuccess value, $Res Function(CameraSuccess) _then) = _$CameraSuccessCopyWithImpl;
@useResult
$Res call({
 CapturePayload payload
});


$CapturePayloadCopyWith<$Res> get payload;

}
/// @nodoc
class _$CameraSuccessCopyWithImpl<$Res>
    implements $CameraSuccessCopyWith<$Res> {
  _$CameraSuccessCopyWithImpl(this._self, this._then);

  final CameraSuccess _self;
  final $Res Function(CameraSuccess) _then;

/// Create a copy of CameraState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? payload = null,}) {
  return _then(CameraSuccess(
payload: null == payload ? _self.payload : payload // ignore: cast_nullable_to_non_nullable
as CapturePayload,
  ));
}

/// Create a copy of CameraState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$CapturePayloadCopyWith<$Res> get payload {
  
  return $CapturePayloadCopyWith<$Res>(_self.payload, (value) {
    return _then(_self.copyWith(payload: value));
  });
}
}

// dart format on
