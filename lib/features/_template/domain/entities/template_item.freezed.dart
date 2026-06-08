// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'template_item.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$TemplateItem {

 String get id; String get label;
/// Create a copy of TemplateItem
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TemplateItemCopyWith<TemplateItem> get copyWith => _$TemplateItemCopyWithImpl<TemplateItem>(this as TemplateItem, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TemplateItem&&(identical(other.id, id) || other.id == id)&&(identical(other.label, label) || other.label == label));
}


@override
int get hashCode => Object.hash(runtimeType,id,label);

@override
String toString() {
  return 'TemplateItem(id: $id, label: $label)';
}


}

/// @nodoc
abstract mixin class $TemplateItemCopyWith<$Res>  {
  factory $TemplateItemCopyWith(TemplateItem value, $Res Function(TemplateItem) _then) = _$TemplateItemCopyWithImpl;
@useResult
$Res call({
 String id, String label
});




}
/// @nodoc
class _$TemplateItemCopyWithImpl<$Res>
    implements $TemplateItemCopyWith<$Res> {
  _$TemplateItemCopyWithImpl(this._self, this._then);

  final TemplateItem _self;
  final $Res Function(TemplateItem) _then;

/// Create a copy of TemplateItem
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? label = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,label: null == label ? _self.label : label // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [TemplateItem].
extension TemplateItemPatterns on TemplateItem {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TemplateItem value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TemplateItem() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TemplateItem value)  $default,){
final _that = this;
switch (_that) {
case _TemplateItem():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TemplateItem value)?  $default,){
final _that = this;
switch (_that) {
case _TemplateItem() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String label)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TemplateItem() when $default != null:
return $default(_that.id,_that.label);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String label)  $default,) {final _that = this;
switch (_that) {
case _TemplateItem():
return $default(_that.id,_that.label);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String label)?  $default,) {final _that = this;
switch (_that) {
case _TemplateItem() when $default != null:
return $default(_that.id,_that.label);case _:
  return null;

}
}

}

/// @nodoc


class _TemplateItem implements TemplateItem {
  const _TemplateItem({required this.id, required this.label});
  

@override final  String id;
@override final  String label;

/// Create a copy of TemplateItem
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TemplateItemCopyWith<_TemplateItem> get copyWith => __$TemplateItemCopyWithImpl<_TemplateItem>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TemplateItem&&(identical(other.id, id) || other.id == id)&&(identical(other.label, label) || other.label == label));
}


@override
int get hashCode => Object.hash(runtimeType,id,label);

@override
String toString() {
  return 'TemplateItem(id: $id, label: $label)';
}


}

/// @nodoc
abstract mixin class _$TemplateItemCopyWith<$Res> implements $TemplateItemCopyWith<$Res> {
  factory _$TemplateItemCopyWith(_TemplateItem value, $Res Function(_TemplateItem) _then) = __$TemplateItemCopyWithImpl;
@override @useResult
$Res call({
 String id, String label
});




}
/// @nodoc
class __$TemplateItemCopyWithImpl<$Res>
    implements _$TemplateItemCopyWith<$Res> {
  __$TemplateItemCopyWithImpl(this._self, this._then);

  final _TemplateItem _self;
  final $Res Function(_TemplateItem) _then;

/// Create a copy of TemplateItem
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? label = null,}) {
  return _then(_TemplateItem(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,label: null == label ? _self.label : label // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
