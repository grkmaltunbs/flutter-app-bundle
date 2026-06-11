// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'detected_tile.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$TilePosition {

 int get row; int get index;
/// Create a copy of TilePosition
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TilePositionCopyWith<TilePosition> get copyWith => _$TilePositionCopyWithImpl<TilePosition>(this as TilePosition, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TilePosition&&(identical(other.row, row) || other.row == row)&&(identical(other.index, index) || other.index == index));
}


@override
int get hashCode => Object.hash(runtimeType,row,index);

@override
String toString() {
  return 'TilePosition(row: $row, index: $index)';
}


}

/// @nodoc
abstract mixin class $TilePositionCopyWith<$Res>  {
  factory $TilePositionCopyWith(TilePosition value, $Res Function(TilePosition) _then) = _$TilePositionCopyWithImpl;
@useResult
$Res call({
 int row, int index
});




}
/// @nodoc
class _$TilePositionCopyWithImpl<$Res>
    implements $TilePositionCopyWith<$Res> {
  _$TilePositionCopyWithImpl(this._self, this._then);

  final TilePosition _self;
  final $Res Function(TilePosition) _then;

/// Create a copy of TilePosition
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? row = null,Object? index = null,}) {
  return _then(_self.copyWith(
row: null == row ? _self.row : row // ignore: cast_nullable_to_non_nullable
as int,index: null == index ? _self.index : index // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [TilePosition].
extension TilePositionPatterns on TilePosition {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TilePosition value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TilePosition() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TilePosition value)  $default,){
final _that = this;
switch (_that) {
case _TilePosition():
return $default(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TilePosition value)?  $default,){
final _that = this;
switch (_that) {
case _TilePosition() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int row,  int index)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TilePosition() when $default != null:
return $default(_that.row,_that.index);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int row,  int index)  $default,) {final _that = this;
switch (_that) {
case _TilePosition():
return $default(_that.row,_that.index);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int row,  int index)?  $default,) {final _that = this;
switch (_that) {
case _TilePosition() when $default != null:
return $default(_that.row,_that.index);case _:
  return null;

}
}

}

/// @nodoc


class _TilePosition implements TilePosition {
  const _TilePosition({required this.row, required this.index});
  

@override final  int row;
@override final  int index;

/// Create a copy of TilePosition
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TilePositionCopyWith<_TilePosition> get copyWith => __$TilePositionCopyWithImpl<_TilePosition>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TilePosition&&(identical(other.row, row) || other.row == row)&&(identical(other.index, index) || other.index == index));
}


@override
int get hashCode => Object.hash(runtimeType,row,index);

@override
String toString() {
  return 'TilePosition(row: $row, index: $index)';
}


}

/// @nodoc
abstract mixin class _$TilePositionCopyWith<$Res> implements $TilePositionCopyWith<$Res> {
  factory _$TilePositionCopyWith(_TilePosition value, $Res Function(_TilePosition) _then) = __$TilePositionCopyWithImpl;
@override @useResult
$Res call({
 int row, int index
});




}
/// @nodoc
class __$TilePositionCopyWithImpl<$Res>
    implements _$TilePositionCopyWith<$Res> {
  __$TilePositionCopyWithImpl(this._self, this._then);

  final _TilePosition _self;
  final $Res Function(_TilePosition) _then;

/// Create a copy of TilePosition
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? row = null,Object? index = null,}) {
  return _then(_TilePosition(
row: null == row ? _self.row : row // ignore: cast_nullable_to_non_nullable
as int,index: null == index ? _self.index : index // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc
mixin _$NormalizedRect {

 double get left; double get top; double get width; double get height;
/// Create a copy of NormalizedRect
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$NormalizedRectCopyWith<NormalizedRect> get copyWith => _$NormalizedRectCopyWithImpl<NormalizedRect>(this as NormalizedRect, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is NormalizedRect&&(identical(other.left, left) || other.left == left)&&(identical(other.top, top) || other.top == top)&&(identical(other.width, width) || other.width == width)&&(identical(other.height, height) || other.height == height));
}


@override
int get hashCode => Object.hash(runtimeType,left,top,width,height);

@override
String toString() {
  return 'NormalizedRect(left: $left, top: $top, width: $width, height: $height)';
}


}

/// @nodoc
abstract mixin class $NormalizedRectCopyWith<$Res>  {
  factory $NormalizedRectCopyWith(NormalizedRect value, $Res Function(NormalizedRect) _then) = _$NormalizedRectCopyWithImpl;
@useResult
$Res call({
 double left, double top, double width, double height
});




}
/// @nodoc
class _$NormalizedRectCopyWithImpl<$Res>
    implements $NormalizedRectCopyWith<$Res> {
  _$NormalizedRectCopyWithImpl(this._self, this._then);

  final NormalizedRect _self;
  final $Res Function(NormalizedRect) _then;

/// Create a copy of NormalizedRect
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? left = null,Object? top = null,Object? width = null,Object? height = null,}) {
  return _then(_self.copyWith(
left: null == left ? _self.left : left // ignore: cast_nullable_to_non_nullable
as double,top: null == top ? _self.top : top // ignore: cast_nullable_to_non_nullable
as double,width: null == width ? _self.width : width // ignore: cast_nullable_to_non_nullable
as double,height: null == height ? _self.height : height // ignore: cast_nullable_to_non_nullable
as double,
  ));
}

}


/// Adds pattern-matching-related methods to [NormalizedRect].
extension NormalizedRectPatterns on NormalizedRect {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _NormalizedRect value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _NormalizedRect() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _NormalizedRect value)  $default,){
final _that = this;
switch (_that) {
case _NormalizedRect():
return $default(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _NormalizedRect value)?  $default,){
final _that = this;
switch (_that) {
case _NormalizedRect() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( double left,  double top,  double width,  double height)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _NormalizedRect() when $default != null:
return $default(_that.left,_that.top,_that.width,_that.height);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( double left,  double top,  double width,  double height)  $default,) {final _that = this;
switch (_that) {
case _NormalizedRect():
return $default(_that.left,_that.top,_that.width,_that.height);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( double left,  double top,  double width,  double height)?  $default,) {final _that = this;
switch (_that) {
case _NormalizedRect() when $default != null:
return $default(_that.left,_that.top,_that.width,_that.height);case _:
  return null;

}
}

}

/// @nodoc


class _NormalizedRect implements NormalizedRect {
  const _NormalizedRect({required this.left, required this.top, required this.width, required this.height});
  

@override final  double left;
@override final  double top;
@override final  double width;
@override final  double height;

/// Create a copy of NormalizedRect
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$NormalizedRectCopyWith<_NormalizedRect> get copyWith => __$NormalizedRectCopyWithImpl<_NormalizedRect>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _NormalizedRect&&(identical(other.left, left) || other.left == left)&&(identical(other.top, top) || other.top == top)&&(identical(other.width, width) || other.width == width)&&(identical(other.height, height) || other.height == height));
}


@override
int get hashCode => Object.hash(runtimeType,left,top,width,height);

@override
String toString() {
  return 'NormalizedRect(left: $left, top: $top, width: $width, height: $height)';
}


}

/// @nodoc
abstract mixin class _$NormalizedRectCopyWith<$Res> implements $NormalizedRectCopyWith<$Res> {
  factory _$NormalizedRectCopyWith(_NormalizedRect value, $Res Function(_NormalizedRect) _then) = __$NormalizedRectCopyWithImpl;
@override @useResult
$Res call({
 double left, double top, double width, double height
});




}
/// @nodoc
class __$NormalizedRectCopyWithImpl<$Res>
    implements _$NormalizedRectCopyWith<$Res> {
  __$NormalizedRectCopyWithImpl(this._self, this._then);

  final _NormalizedRect _self;
  final $Res Function(_NormalizedRect) _then;

/// Create a copy of NormalizedRect
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? left = null,Object? top = null,Object? width = null,Object? height = null,}) {
  return _then(_NormalizedRect(
left: null == left ? _self.left : left // ignore: cast_nullable_to_non_nullable
as double,top: null == top ? _self.top : top // ignore: cast_nullable_to_non_nullable
as double,width: null == width ? _self.width : width // ignore: cast_nullable_to_non_nullable
as double,height: null == height ? _self.height : height // ignore: cast_nullable_to_non_nullable
as double,
  ));
}


}

/// @nodoc
mixin _$DetectedTile {

 TileColor get color; TilePosition get position; double get confidence; int? get number; NormalizedRect? get bounds;
/// Create a copy of DetectedTile
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DetectedTileCopyWith<DetectedTile> get copyWith => _$DetectedTileCopyWithImpl<DetectedTile>(this as DetectedTile, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DetectedTile&&(identical(other.color, color) || other.color == color)&&(identical(other.position, position) || other.position == position)&&(identical(other.confidence, confidence) || other.confidence == confidence)&&(identical(other.number, number) || other.number == number)&&(identical(other.bounds, bounds) || other.bounds == bounds));
}


@override
int get hashCode => Object.hash(runtimeType,color,position,confidence,number,bounds);

@override
String toString() {
  return 'DetectedTile(color: $color, position: $position, confidence: $confidence, number: $number, bounds: $bounds)';
}


}

/// @nodoc
abstract mixin class $DetectedTileCopyWith<$Res>  {
  factory $DetectedTileCopyWith(DetectedTile value, $Res Function(DetectedTile) _then) = _$DetectedTileCopyWithImpl;
@useResult
$Res call({
 TileColor color, TilePosition position, double confidence, int? number, NormalizedRect? bounds
});


$TilePositionCopyWith<$Res> get position;$NormalizedRectCopyWith<$Res>? get bounds;

}
/// @nodoc
class _$DetectedTileCopyWithImpl<$Res>
    implements $DetectedTileCopyWith<$Res> {
  _$DetectedTileCopyWithImpl(this._self, this._then);

  final DetectedTile _self;
  final $Res Function(DetectedTile) _then;

/// Create a copy of DetectedTile
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? color = null,Object? position = null,Object? confidence = null,Object? number = freezed,Object? bounds = freezed,}) {
  return _then(_self.copyWith(
color: null == color ? _self.color : color // ignore: cast_nullable_to_non_nullable
as TileColor,position: null == position ? _self.position : position // ignore: cast_nullable_to_non_nullable
as TilePosition,confidence: null == confidence ? _self.confidence : confidence // ignore: cast_nullable_to_non_nullable
as double,number: freezed == number ? _self.number : number // ignore: cast_nullable_to_non_nullable
as int?,bounds: freezed == bounds ? _self.bounds : bounds // ignore: cast_nullable_to_non_nullable
as NormalizedRect?,
  ));
}
/// Create a copy of DetectedTile
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TilePositionCopyWith<$Res> get position {
  
  return $TilePositionCopyWith<$Res>(_self.position, (value) {
    return _then(_self.copyWith(position: value));
  });
}/// Create a copy of DetectedTile
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$NormalizedRectCopyWith<$Res>? get bounds {
    if (_self.bounds == null) {
    return null;
  }

  return $NormalizedRectCopyWith<$Res>(_self.bounds!, (value) {
    return _then(_self.copyWith(bounds: value));
  });
}
}


/// Adds pattern-matching-related methods to [DetectedTile].
extension DetectedTilePatterns on DetectedTile {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _DetectedTile value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _DetectedTile() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _DetectedTile value)  $default,){
final _that = this;
switch (_that) {
case _DetectedTile():
return $default(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _DetectedTile value)?  $default,){
final _that = this;
switch (_that) {
case _DetectedTile() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( TileColor color,  TilePosition position,  double confidence,  int? number,  NormalizedRect? bounds)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _DetectedTile() when $default != null:
return $default(_that.color,_that.position,_that.confidence,_that.number,_that.bounds);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( TileColor color,  TilePosition position,  double confidence,  int? number,  NormalizedRect? bounds)  $default,) {final _that = this;
switch (_that) {
case _DetectedTile():
return $default(_that.color,_that.position,_that.confidence,_that.number,_that.bounds);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( TileColor color,  TilePosition position,  double confidence,  int? number,  NormalizedRect? bounds)?  $default,) {final _that = this;
switch (_that) {
case _DetectedTile() when $default != null:
return $default(_that.color,_that.position,_that.confidence,_that.number,_that.bounds);case _:
  return null;

}
}

}

/// @nodoc


class _DetectedTile implements DetectedTile {
  const _DetectedTile({required this.color, required this.position, required this.confidence, this.number, this.bounds});
  

@override final  TileColor color;
@override final  TilePosition position;
@override final  double confidence;
@override final  int? number;
@override final  NormalizedRect? bounds;

/// Create a copy of DetectedTile
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DetectedTileCopyWith<_DetectedTile> get copyWith => __$DetectedTileCopyWithImpl<_DetectedTile>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _DetectedTile&&(identical(other.color, color) || other.color == color)&&(identical(other.position, position) || other.position == position)&&(identical(other.confidence, confidence) || other.confidence == confidence)&&(identical(other.number, number) || other.number == number)&&(identical(other.bounds, bounds) || other.bounds == bounds));
}


@override
int get hashCode => Object.hash(runtimeType,color,position,confidence,number,bounds);

@override
String toString() {
  return 'DetectedTile(color: $color, position: $position, confidence: $confidence, number: $number, bounds: $bounds)';
}


}

/// @nodoc
abstract mixin class _$DetectedTileCopyWith<$Res> implements $DetectedTileCopyWith<$Res> {
  factory _$DetectedTileCopyWith(_DetectedTile value, $Res Function(_DetectedTile) _then) = __$DetectedTileCopyWithImpl;
@override @useResult
$Res call({
 TileColor color, TilePosition position, double confidence, int? number, NormalizedRect? bounds
});


@override $TilePositionCopyWith<$Res> get position;@override $NormalizedRectCopyWith<$Res>? get bounds;

}
/// @nodoc
class __$DetectedTileCopyWithImpl<$Res>
    implements _$DetectedTileCopyWith<$Res> {
  __$DetectedTileCopyWithImpl(this._self, this._then);

  final _DetectedTile _self;
  final $Res Function(_DetectedTile) _then;

/// Create a copy of DetectedTile
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? color = null,Object? position = null,Object? confidence = null,Object? number = freezed,Object? bounds = freezed,}) {
  return _then(_DetectedTile(
color: null == color ? _self.color : color // ignore: cast_nullable_to_non_nullable
as TileColor,position: null == position ? _self.position : position // ignore: cast_nullable_to_non_nullable
as TilePosition,confidence: null == confidence ? _self.confidence : confidence // ignore: cast_nullable_to_non_nullable
as double,number: freezed == number ? _self.number : number // ignore: cast_nullable_to_non_nullable
as int?,bounds: freezed == bounds ? _self.bounds : bounds // ignore: cast_nullable_to_non_nullable
as NormalizedRect?,
  ));
}

/// Create a copy of DetectedTile
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TilePositionCopyWith<$Res> get position {
  
  return $TilePositionCopyWith<$Res>(_self.position, (value) {
    return _then(_self.copyWith(position: value));
  });
}/// Create a copy of DetectedTile
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$NormalizedRectCopyWith<$Res>? get bounds {
    if (_self.bounds == null) {
    return null;
  }

  return $NormalizedRectCopyWith<$Res>(_self.bounds!, (value) {
    return _then(_self.copyWith(bounds: value));
  });
}
}

// dart format on
