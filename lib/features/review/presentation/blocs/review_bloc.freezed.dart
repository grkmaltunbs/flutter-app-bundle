// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'review_bloc.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ReviewEvent {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ReviewEvent);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'ReviewEvent()';
}


}

/// @nodoc
class $ReviewEventCopyWith<$Res>  {
$ReviewEventCopyWith(ReviewEvent _, $Res Function(ReviewEvent) __);
}


/// Adds pattern-matching-related methods to [ReviewEvent].
extension ReviewEventPatterns on ReviewEvent {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( ReviewTileTapped value)?  tileTapped,TResult Function( ReviewEditClosed value)?  editClosed,TResult Function( ReviewTileColorChanged value)?  tileColorChanged,TResult Function( ReviewTileNumberChanged value)?  tileNumberChanged,TResult Function( ReviewTileAdded value)?  tileAdded,TResult Function( ReviewTileRemoved value)?  tileRemoved,TResult Function( ReviewIndicatorPicked value)?  indicatorPicked,required TResult orElse(),}){
final _that = this;
switch (_that) {
case ReviewTileTapped() when tileTapped != null:
return tileTapped(_that);case ReviewEditClosed() when editClosed != null:
return editClosed(_that);case ReviewTileColorChanged() when tileColorChanged != null:
return tileColorChanged(_that);case ReviewTileNumberChanged() when tileNumberChanged != null:
return tileNumberChanged(_that);case ReviewTileAdded() when tileAdded != null:
return tileAdded(_that);case ReviewTileRemoved() when tileRemoved != null:
return tileRemoved(_that);case ReviewIndicatorPicked() when indicatorPicked != null:
return indicatorPicked(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( ReviewTileTapped value)  tileTapped,required TResult Function( ReviewEditClosed value)  editClosed,required TResult Function( ReviewTileColorChanged value)  tileColorChanged,required TResult Function( ReviewTileNumberChanged value)  tileNumberChanged,required TResult Function( ReviewTileAdded value)  tileAdded,required TResult Function( ReviewTileRemoved value)  tileRemoved,required TResult Function( ReviewIndicatorPicked value)  indicatorPicked,}){
final _that = this;
switch (_that) {
case ReviewTileTapped():
return tileTapped(_that);case ReviewEditClosed():
return editClosed(_that);case ReviewTileColorChanged():
return tileColorChanged(_that);case ReviewTileNumberChanged():
return tileNumberChanged(_that);case ReviewTileAdded():
return tileAdded(_that);case ReviewTileRemoved():
return tileRemoved(_that);case ReviewIndicatorPicked():
return indicatorPicked(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( ReviewTileTapped value)?  tileTapped,TResult? Function( ReviewEditClosed value)?  editClosed,TResult? Function( ReviewTileColorChanged value)?  tileColorChanged,TResult? Function( ReviewTileNumberChanged value)?  tileNumberChanged,TResult? Function( ReviewTileAdded value)?  tileAdded,TResult? Function( ReviewTileRemoved value)?  tileRemoved,TResult? Function( ReviewIndicatorPicked value)?  indicatorPicked,}){
final _that = this;
switch (_that) {
case ReviewTileTapped() when tileTapped != null:
return tileTapped(_that);case ReviewEditClosed() when editClosed != null:
return editClosed(_that);case ReviewTileColorChanged() when tileColorChanged != null:
return tileColorChanged(_that);case ReviewTileNumberChanged() when tileNumberChanged != null:
return tileNumberChanged(_that);case ReviewTileAdded() when tileAdded != null:
return tileAdded(_that);case ReviewTileRemoved() when tileRemoved != null:
return tileRemoved(_that);case ReviewIndicatorPicked() when indicatorPicked != null:
return indicatorPicked(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( int index)?  tileTapped,TResult Function()?  editClosed,TResult Function( TileColor color)?  tileColorChanged,TResult Function( int number)?  tileNumberChanged,TResult Function()?  tileAdded,TResult Function()?  tileRemoved,TResult Function( TileColor color,  int number)?  indicatorPicked,required TResult orElse(),}) {final _that = this;
switch (_that) {
case ReviewTileTapped() when tileTapped != null:
return tileTapped(_that.index);case ReviewEditClosed() when editClosed != null:
return editClosed();case ReviewTileColorChanged() when tileColorChanged != null:
return tileColorChanged(_that.color);case ReviewTileNumberChanged() when tileNumberChanged != null:
return tileNumberChanged(_that.number);case ReviewTileAdded() when tileAdded != null:
return tileAdded();case ReviewTileRemoved() when tileRemoved != null:
return tileRemoved();case ReviewIndicatorPicked() when indicatorPicked != null:
return indicatorPicked(_that.color,_that.number);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( int index)  tileTapped,required TResult Function()  editClosed,required TResult Function( TileColor color)  tileColorChanged,required TResult Function( int number)  tileNumberChanged,required TResult Function()  tileAdded,required TResult Function()  tileRemoved,required TResult Function( TileColor color,  int number)  indicatorPicked,}) {final _that = this;
switch (_that) {
case ReviewTileTapped():
return tileTapped(_that.index);case ReviewEditClosed():
return editClosed();case ReviewTileColorChanged():
return tileColorChanged(_that.color);case ReviewTileNumberChanged():
return tileNumberChanged(_that.number);case ReviewTileAdded():
return tileAdded();case ReviewTileRemoved():
return tileRemoved();case ReviewIndicatorPicked():
return indicatorPicked(_that.color,_that.number);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( int index)?  tileTapped,TResult? Function()?  editClosed,TResult? Function( TileColor color)?  tileColorChanged,TResult? Function( int number)?  tileNumberChanged,TResult? Function()?  tileAdded,TResult? Function()?  tileRemoved,TResult? Function( TileColor color,  int number)?  indicatorPicked,}) {final _that = this;
switch (_that) {
case ReviewTileTapped() when tileTapped != null:
return tileTapped(_that.index);case ReviewEditClosed() when editClosed != null:
return editClosed();case ReviewTileColorChanged() when tileColorChanged != null:
return tileColorChanged(_that.color);case ReviewTileNumberChanged() when tileNumberChanged != null:
return tileNumberChanged(_that.number);case ReviewTileAdded() when tileAdded != null:
return tileAdded();case ReviewTileRemoved() when tileRemoved != null:
return tileRemoved();case ReviewIndicatorPicked() when indicatorPicked != null:
return indicatorPicked(_that.color,_that.number);case _:
  return null;

}
}

}

/// @nodoc


class ReviewTileTapped implements ReviewEvent {
  const ReviewTileTapped(this.index);
  

 final  int index;

/// Create a copy of ReviewEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ReviewTileTappedCopyWith<ReviewTileTapped> get copyWith => _$ReviewTileTappedCopyWithImpl<ReviewTileTapped>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ReviewTileTapped&&(identical(other.index, index) || other.index == index));
}


@override
int get hashCode => Object.hash(runtimeType,index);

@override
String toString() {
  return 'ReviewEvent.tileTapped(index: $index)';
}


}

/// @nodoc
abstract mixin class $ReviewTileTappedCopyWith<$Res> implements $ReviewEventCopyWith<$Res> {
  factory $ReviewTileTappedCopyWith(ReviewTileTapped value, $Res Function(ReviewTileTapped) _then) = _$ReviewTileTappedCopyWithImpl;
@useResult
$Res call({
 int index
});




}
/// @nodoc
class _$ReviewTileTappedCopyWithImpl<$Res>
    implements $ReviewTileTappedCopyWith<$Res> {
  _$ReviewTileTappedCopyWithImpl(this._self, this._then);

  final ReviewTileTapped _self;
  final $Res Function(ReviewTileTapped) _then;

/// Create a copy of ReviewEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? index = null,}) {
  return _then(ReviewTileTapped(
null == index ? _self.index : index // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc


class ReviewEditClosed implements ReviewEvent {
  const ReviewEditClosed();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ReviewEditClosed);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'ReviewEvent.editClosed()';
}


}




/// @nodoc


class ReviewTileColorChanged implements ReviewEvent {
  const ReviewTileColorChanged(this.color);
  

 final  TileColor color;

/// Create a copy of ReviewEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ReviewTileColorChangedCopyWith<ReviewTileColorChanged> get copyWith => _$ReviewTileColorChangedCopyWithImpl<ReviewTileColorChanged>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ReviewTileColorChanged&&(identical(other.color, color) || other.color == color));
}


@override
int get hashCode => Object.hash(runtimeType,color);

@override
String toString() {
  return 'ReviewEvent.tileColorChanged(color: $color)';
}


}

/// @nodoc
abstract mixin class $ReviewTileColorChangedCopyWith<$Res> implements $ReviewEventCopyWith<$Res> {
  factory $ReviewTileColorChangedCopyWith(ReviewTileColorChanged value, $Res Function(ReviewTileColorChanged) _then) = _$ReviewTileColorChangedCopyWithImpl;
@useResult
$Res call({
 TileColor color
});




}
/// @nodoc
class _$ReviewTileColorChangedCopyWithImpl<$Res>
    implements $ReviewTileColorChangedCopyWith<$Res> {
  _$ReviewTileColorChangedCopyWithImpl(this._self, this._then);

  final ReviewTileColorChanged _self;
  final $Res Function(ReviewTileColorChanged) _then;

/// Create a copy of ReviewEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? color = null,}) {
  return _then(ReviewTileColorChanged(
null == color ? _self.color : color // ignore: cast_nullable_to_non_nullable
as TileColor,
  ));
}


}

/// @nodoc


class ReviewTileNumberChanged implements ReviewEvent {
  const ReviewTileNumberChanged(this.number);
  

 final  int number;

/// Create a copy of ReviewEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ReviewTileNumberChangedCopyWith<ReviewTileNumberChanged> get copyWith => _$ReviewTileNumberChangedCopyWithImpl<ReviewTileNumberChanged>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ReviewTileNumberChanged&&(identical(other.number, number) || other.number == number));
}


@override
int get hashCode => Object.hash(runtimeType,number);

@override
String toString() {
  return 'ReviewEvent.tileNumberChanged(number: $number)';
}


}

/// @nodoc
abstract mixin class $ReviewTileNumberChangedCopyWith<$Res> implements $ReviewEventCopyWith<$Res> {
  factory $ReviewTileNumberChangedCopyWith(ReviewTileNumberChanged value, $Res Function(ReviewTileNumberChanged) _then) = _$ReviewTileNumberChangedCopyWithImpl;
@useResult
$Res call({
 int number
});




}
/// @nodoc
class _$ReviewTileNumberChangedCopyWithImpl<$Res>
    implements $ReviewTileNumberChangedCopyWith<$Res> {
  _$ReviewTileNumberChangedCopyWithImpl(this._self, this._then);

  final ReviewTileNumberChanged _self;
  final $Res Function(ReviewTileNumberChanged) _then;

/// Create a copy of ReviewEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? number = null,}) {
  return _then(ReviewTileNumberChanged(
null == number ? _self.number : number // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc


class ReviewTileAdded implements ReviewEvent {
  const ReviewTileAdded();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ReviewTileAdded);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'ReviewEvent.tileAdded()';
}


}




/// @nodoc


class ReviewTileRemoved implements ReviewEvent {
  const ReviewTileRemoved();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ReviewTileRemoved);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'ReviewEvent.tileRemoved()';
}


}




/// @nodoc


class ReviewIndicatorPicked implements ReviewEvent {
  const ReviewIndicatorPicked(this.color, this.number);
  

 final  TileColor color;
 final  int number;

/// Create a copy of ReviewEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ReviewIndicatorPickedCopyWith<ReviewIndicatorPicked> get copyWith => _$ReviewIndicatorPickedCopyWithImpl<ReviewIndicatorPicked>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ReviewIndicatorPicked&&(identical(other.color, color) || other.color == color)&&(identical(other.number, number) || other.number == number));
}


@override
int get hashCode => Object.hash(runtimeType,color,number);

@override
String toString() {
  return 'ReviewEvent.indicatorPicked(color: $color, number: $number)';
}


}

/// @nodoc
abstract mixin class $ReviewIndicatorPickedCopyWith<$Res> implements $ReviewEventCopyWith<$Res> {
  factory $ReviewIndicatorPickedCopyWith(ReviewIndicatorPicked value, $Res Function(ReviewIndicatorPicked) _then) = _$ReviewIndicatorPickedCopyWithImpl;
@useResult
$Res call({
 TileColor color, int number
});




}
/// @nodoc
class _$ReviewIndicatorPickedCopyWithImpl<$Res>
    implements $ReviewIndicatorPickedCopyWith<$Res> {
  _$ReviewIndicatorPickedCopyWithImpl(this._self, this._then);

  final ReviewIndicatorPicked _self;
  final $Res Function(ReviewIndicatorPicked) _then;

/// Create a copy of ReviewEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? color = null,Object? number = null,}) {
  return _then(ReviewIndicatorPicked(
null == color ? _self.color : color // ignore: cast_nullable_to_non_nullable
as TileColor,null == number ? _self.number : number // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc
mixin _$ReviewState {

/// The editable tiles in rack order (unmodifiable).
 List<ReviewTile> get tiles;/// The mode this review targets (fixed at screen creation).
 GameMode get gameMode;/// Mean per-tile detection confidence (drives the retake banner).
 double get overallConfidence;/// The picked indicator, or null while unset.
 Indicator? get indicator;/// Index of the tile being edited, or null when the panel is closed.
 int? get editingIndex;
/// Create a copy of ReviewState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ReviewStateCopyWith<ReviewState> get copyWith => _$ReviewStateCopyWithImpl<ReviewState>(this as ReviewState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ReviewState&&const DeepCollectionEquality().equals(other.tiles, tiles)&&(identical(other.gameMode, gameMode) || other.gameMode == gameMode)&&(identical(other.overallConfidence, overallConfidence) || other.overallConfidence == overallConfidence)&&(identical(other.indicator, indicator) || other.indicator == indicator)&&(identical(other.editingIndex, editingIndex) || other.editingIndex == editingIndex));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(tiles),gameMode,overallConfidence,indicator,editingIndex);

@override
String toString() {
  return 'ReviewState(tiles: $tiles, gameMode: $gameMode, overallConfidence: $overallConfidence, indicator: $indicator, editingIndex: $editingIndex)';
}


}

/// @nodoc
abstract mixin class $ReviewStateCopyWith<$Res>  {
  factory $ReviewStateCopyWith(ReviewState value, $Res Function(ReviewState) _then) = _$ReviewStateCopyWithImpl;
@useResult
$Res call({
 List<ReviewTile> tiles, GameMode gameMode, double overallConfidence, Indicator? indicator, int? editingIndex
});


$IndicatorCopyWith<$Res>? get indicator;

}
/// @nodoc
class _$ReviewStateCopyWithImpl<$Res>
    implements $ReviewStateCopyWith<$Res> {
  _$ReviewStateCopyWithImpl(this._self, this._then);

  final ReviewState _self;
  final $Res Function(ReviewState) _then;

/// Create a copy of ReviewState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? tiles = null,Object? gameMode = null,Object? overallConfidence = null,Object? indicator = freezed,Object? editingIndex = freezed,}) {
  return _then(_self.copyWith(
tiles: null == tiles ? _self.tiles : tiles // ignore: cast_nullable_to_non_nullable
as List<ReviewTile>,gameMode: null == gameMode ? _self.gameMode : gameMode // ignore: cast_nullable_to_non_nullable
as GameMode,overallConfidence: null == overallConfidence ? _self.overallConfidence : overallConfidence // ignore: cast_nullable_to_non_nullable
as double,indicator: freezed == indicator ? _self.indicator : indicator // ignore: cast_nullable_to_non_nullable
as Indicator?,editingIndex: freezed == editingIndex ? _self.editingIndex : editingIndex // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}
/// Create a copy of ReviewState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$IndicatorCopyWith<$Res>? get indicator {
    if (_self.indicator == null) {
    return null;
  }

  return $IndicatorCopyWith<$Res>(_self.indicator!, (value) {
    return _then(_self.copyWith(indicator: value));
  });
}
}


/// Adds pattern-matching-related methods to [ReviewState].
extension ReviewStatePatterns on ReviewState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ReviewState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ReviewState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ReviewState value)  $default,){
final _that = this;
switch (_that) {
case _ReviewState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ReviewState value)?  $default,){
final _that = this;
switch (_that) {
case _ReviewState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<ReviewTile> tiles,  GameMode gameMode,  double overallConfidence,  Indicator? indicator,  int? editingIndex)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ReviewState() when $default != null:
return $default(_that.tiles,_that.gameMode,_that.overallConfidence,_that.indicator,_that.editingIndex);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<ReviewTile> tiles,  GameMode gameMode,  double overallConfidence,  Indicator? indicator,  int? editingIndex)  $default,) {final _that = this;
switch (_that) {
case _ReviewState():
return $default(_that.tiles,_that.gameMode,_that.overallConfidence,_that.indicator,_that.editingIndex);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<ReviewTile> tiles,  GameMode gameMode,  double overallConfidence,  Indicator? indicator,  int? editingIndex)?  $default,) {final _that = this;
switch (_that) {
case _ReviewState() when $default != null:
return $default(_that.tiles,_that.gameMode,_that.overallConfidence,_that.indicator,_that.editingIndex);case _:
  return null;

}
}

}

/// @nodoc


class _ReviewState extends ReviewState {
  const _ReviewState({required final  List<ReviewTile> tiles, required this.gameMode, required this.overallConfidence, this.indicator, this.editingIndex}): _tiles = tiles,super._();
  

/// The editable tiles in rack order (unmodifiable).
 final  List<ReviewTile> _tiles;
/// The editable tiles in rack order (unmodifiable).
@override List<ReviewTile> get tiles {
  if (_tiles is EqualUnmodifiableListView) return _tiles;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_tiles);
}

/// The mode this review targets (fixed at screen creation).
@override final  GameMode gameMode;
/// Mean per-tile detection confidence (drives the retake banner).
@override final  double overallConfidence;
/// The picked indicator, or null while unset.
@override final  Indicator? indicator;
/// Index of the tile being edited, or null when the panel is closed.
@override final  int? editingIndex;

/// Create a copy of ReviewState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ReviewStateCopyWith<_ReviewState> get copyWith => __$ReviewStateCopyWithImpl<_ReviewState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ReviewState&&const DeepCollectionEquality().equals(other._tiles, _tiles)&&(identical(other.gameMode, gameMode) || other.gameMode == gameMode)&&(identical(other.overallConfidence, overallConfidence) || other.overallConfidence == overallConfidence)&&(identical(other.indicator, indicator) || other.indicator == indicator)&&(identical(other.editingIndex, editingIndex) || other.editingIndex == editingIndex));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_tiles),gameMode,overallConfidence,indicator,editingIndex);

@override
String toString() {
  return 'ReviewState(tiles: $tiles, gameMode: $gameMode, overallConfidence: $overallConfidence, indicator: $indicator, editingIndex: $editingIndex)';
}


}

/// @nodoc
abstract mixin class _$ReviewStateCopyWith<$Res> implements $ReviewStateCopyWith<$Res> {
  factory _$ReviewStateCopyWith(_ReviewState value, $Res Function(_ReviewState) _then) = __$ReviewStateCopyWithImpl;
@override @useResult
$Res call({
 List<ReviewTile> tiles, GameMode gameMode, double overallConfidence, Indicator? indicator, int? editingIndex
});


@override $IndicatorCopyWith<$Res>? get indicator;

}
/// @nodoc
class __$ReviewStateCopyWithImpl<$Res>
    implements _$ReviewStateCopyWith<$Res> {
  __$ReviewStateCopyWithImpl(this._self, this._then);

  final _ReviewState _self;
  final $Res Function(_ReviewState) _then;

/// Create a copy of ReviewState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? tiles = null,Object? gameMode = null,Object? overallConfidence = null,Object? indicator = freezed,Object? editingIndex = freezed,}) {
  return _then(_ReviewState(
tiles: null == tiles ? _self._tiles : tiles // ignore: cast_nullable_to_non_nullable
as List<ReviewTile>,gameMode: null == gameMode ? _self.gameMode : gameMode // ignore: cast_nullable_to_non_nullable
as GameMode,overallConfidence: null == overallConfidence ? _self.overallConfidence : overallConfidence // ignore: cast_nullable_to_non_nullable
as double,indicator: freezed == indicator ? _self.indicator : indicator // ignore: cast_nullable_to_non_nullable
as Indicator?,editingIndex: freezed == editingIndex ? _self.editingIndex : editingIndex // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

/// Create a copy of ReviewState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$IndicatorCopyWith<$Res>? get indicator {
    if (_self.indicator == null) {
    return null;
  }

  return $IndicatorCopyWith<$Res>(_self.indicator!, (value) {
    return _then(_self.copyWith(indicator: value));
  });
}
}

// dart format on
