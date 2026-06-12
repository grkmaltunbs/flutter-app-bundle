// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'history_bloc.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$HistoryEvent {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is HistoryEvent);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'HistoryEvent()';
}


}

/// @nodoc
class $HistoryEventCopyWith<$Res>  {
$HistoryEventCopyWith(HistoryEvent _, $Res Function(HistoryEvent) __);
}



/// @nodoc


class HistoryStarted implements HistoryEvent {
  const HistoryStarted();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is HistoryStarted);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'HistoryEvent.started()';
}


}




/// @nodoc


class HistoryFilterChanged implements HistoryEvent {
  const HistoryFilterChanged(this.filter);
  

 final  HistoryFilter filter;

/// Create a copy of HistoryEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$HistoryFilterChangedCopyWith<HistoryFilterChanged> get copyWith => _$HistoryFilterChangedCopyWithImpl<HistoryFilterChanged>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is HistoryFilterChanged&&(identical(other.filter, filter) || other.filter == filter));
}


@override
int get hashCode => Object.hash(runtimeType,filter);

@override
String toString() {
  return 'HistoryEvent.filterChanged(filter: $filter)';
}


}

/// @nodoc
abstract mixin class $HistoryFilterChangedCopyWith<$Res> implements $HistoryEventCopyWith<$Res> {
  factory $HistoryFilterChangedCopyWith(HistoryFilterChanged value, $Res Function(HistoryFilterChanged) _then) = _$HistoryFilterChangedCopyWithImpl;
@useResult
$Res call({
 HistoryFilter filter
});




}
/// @nodoc
class _$HistoryFilterChangedCopyWithImpl<$Res>
    implements $HistoryFilterChangedCopyWith<$Res> {
  _$HistoryFilterChangedCopyWithImpl(this._self, this._then);

  final HistoryFilterChanged _self;
  final $Res Function(HistoryFilterChanged) _then;

/// Create a copy of HistoryEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? filter = null,}) {
  return _then(HistoryFilterChanged(
null == filter ? _self.filter : filter // ignore: cast_nullable_to_non_nullable
as HistoryFilter,
  ));
}


}

/// @nodoc


class HistoryLoadMoreRequested implements HistoryEvent {
  const HistoryLoadMoreRequested();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is HistoryLoadMoreRequested);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'HistoryEvent.loadMoreRequested()';
}


}




/// @nodoc


class HistoryRetryRequested implements HistoryEvent {
  const HistoryRetryRequested();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is HistoryRetryRequested);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'HistoryEvent.retryRequested()';
}


}




/// @nodoc


class _HistoryScansEmitted implements HistoryEvent {
  const _HistoryScansEmitted(final  List<Scan> scans): _scans = scans;
  

 final  List<Scan> _scans;
 List<Scan> get scans {
  if (_scans is EqualUnmodifiableListView) return _scans;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_scans);
}


/// Create a copy of HistoryEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$HistoryScansEmittedCopyWith<_HistoryScansEmitted> get copyWith => __$HistoryScansEmittedCopyWithImpl<_HistoryScansEmitted>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _HistoryScansEmitted&&const DeepCollectionEquality().equals(other._scans, _scans));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_scans));

@override
String toString() {
  return 'HistoryEvent._scansEmitted(scans: $scans)';
}


}

/// @nodoc
abstract mixin class _$HistoryScansEmittedCopyWith<$Res> implements $HistoryEventCopyWith<$Res> {
  factory _$HistoryScansEmittedCopyWith(_HistoryScansEmitted value, $Res Function(_HistoryScansEmitted) _then) = __$HistoryScansEmittedCopyWithImpl;
@useResult
$Res call({
 List<Scan> scans
});




}
/// @nodoc
class __$HistoryScansEmittedCopyWithImpl<$Res>
    implements _$HistoryScansEmittedCopyWith<$Res> {
  __$HistoryScansEmittedCopyWithImpl(this._self, this._then);

  final _HistoryScansEmitted _self;
  final $Res Function(_HistoryScansEmitted) _then;

/// Create a copy of HistoryEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? scans = null,}) {
  return _then(_HistoryScansEmitted(
null == scans ? _self._scans : scans // ignore: cast_nullable_to_non_nullable
as List<Scan>,
  ));
}


}

/// @nodoc


class _HistoryCountsEmitted implements HistoryEvent {
  const _HistoryCountsEmitted(this.counts);
  

 final  ScanCounts counts;

/// Create a copy of HistoryEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$HistoryCountsEmittedCopyWith<_HistoryCountsEmitted> get copyWith => __$HistoryCountsEmittedCopyWithImpl<_HistoryCountsEmitted>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _HistoryCountsEmitted&&(identical(other.counts, counts) || other.counts == counts));
}


@override
int get hashCode => Object.hash(runtimeType,counts);

@override
String toString() {
  return 'HistoryEvent._countsEmitted(counts: $counts)';
}


}

/// @nodoc
abstract mixin class _$HistoryCountsEmittedCopyWith<$Res> implements $HistoryEventCopyWith<$Res> {
  factory _$HistoryCountsEmittedCopyWith(_HistoryCountsEmitted value, $Res Function(_HistoryCountsEmitted) _then) = __$HistoryCountsEmittedCopyWithImpl;
@useResult
$Res call({
 ScanCounts counts
});


$ScanCountsCopyWith<$Res> get counts;

}
/// @nodoc
class __$HistoryCountsEmittedCopyWithImpl<$Res>
    implements _$HistoryCountsEmittedCopyWith<$Res> {
  __$HistoryCountsEmittedCopyWithImpl(this._self, this._then);

  final _HistoryCountsEmitted _self;
  final $Res Function(_HistoryCountsEmitted) _then;

/// Create a copy of HistoryEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? counts = null,}) {
  return _then(_HistoryCountsEmitted(
null == counts ? _self.counts : counts // ignore: cast_nullable_to_non_nullable
as ScanCounts,
  ));
}

/// Create a copy of HistoryEvent
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ScanCountsCopyWith<$Res> get counts {
  
  return $ScanCountsCopyWith<$Res>(_self.counts, (value) {
    return _then(_self.copyWith(counts: value));
  });
}
}

/// @nodoc


class _HistoryOnlineChanged implements HistoryEvent {
  const _HistoryOnlineChanged({required this.online});
  

 final  bool online;

/// Create a copy of HistoryEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$HistoryOnlineChangedCopyWith<_HistoryOnlineChanged> get copyWith => __$HistoryOnlineChangedCopyWithImpl<_HistoryOnlineChanged>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _HistoryOnlineChanged&&(identical(other.online, online) || other.online == online));
}


@override
int get hashCode => Object.hash(runtimeType,online);

@override
String toString() {
  return 'HistoryEvent._onlineChanged(online: $online)';
}


}

/// @nodoc
abstract mixin class _$HistoryOnlineChangedCopyWith<$Res> implements $HistoryEventCopyWith<$Res> {
  factory _$HistoryOnlineChangedCopyWith(_HistoryOnlineChanged value, $Res Function(_HistoryOnlineChanged) _then) = __$HistoryOnlineChangedCopyWithImpl;
@useResult
$Res call({
 bool online
});




}
/// @nodoc
class __$HistoryOnlineChangedCopyWithImpl<$Res>
    implements _$HistoryOnlineChangedCopyWith<$Res> {
  __$HistoryOnlineChangedCopyWithImpl(this._self, this._then);

  final _HistoryOnlineChanged _self;
  final $Res Function(_HistoryOnlineChanged) _then;

/// Create a copy of HistoryEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? online = null,}) {
  return _then(_HistoryOnlineChanged(
online: null == online ? _self.online : online // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

/// @nodoc


class _HistoryStreamFailed implements HistoryEvent {
  const _HistoryStreamFailed();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _HistoryStreamFailed);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'HistoryEvent._streamFailed()';
}


}




/// @nodoc
mixin _$HistoryState {

/// The load phase.
 HistoryStatus get status;/// The active verdict filter.
 HistoryFilter get filter;/// The visible scans (newest first, capped at the page window).
 List<Scan> get scans;/// Per-filter row counts for the chips.
 ScanCounts get counts;/// How many [HistoryBloc.pageSize] pages the window spans.
 int get pagesRequested;/// Whether another page may exist beyond the window.
 bool get hasMore;/// Whether a grow-the-window request is in flight.
 bool get loadingMore;/// Whether the device is online (offline shows the local-history banner).
 bool get online;
/// Create a copy of HistoryState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$HistoryStateCopyWith<HistoryState> get copyWith => _$HistoryStateCopyWithImpl<HistoryState>(this as HistoryState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is HistoryState&&(identical(other.status, status) || other.status == status)&&(identical(other.filter, filter) || other.filter == filter)&&const DeepCollectionEquality().equals(other.scans, scans)&&(identical(other.counts, counts) || other.counts == counts)&&(identical(other.pagesRequested, pagesRequested) || other.pagesRequested == pagesRequested)&&(identical(other.hasMore, hasMore) || other.hasMore == hasMore)&&(identical(other.loadingMore, loadingMore) || other.loadingMore == loadingMore)&&(identical(other.online, online) || other.online == online));
}


@override
int get hashCode => Object.hash(runtimeType,status,filter,const DeepCollectionEquality().hash(scans),counts,pagesRequested,hasMore,loadingMore,online);

@override
String toString() {
  return 'HistoryState(status: $status, filter: $filter, scans: $scans, counts: $counts, pagesRequested: $pagesRequested, hasMore: $hasMore, loadingMore: $loadingMore, online: $online)';
}


}

/// @nodoc
abstract mixin class $HistoryStateCopyWith<$Res>  {
  factory $HistoryStateCopyWith(HistoryState value, $Res Function(HistoryState) _then) = _$HistoryStateCopyWithImpl;
@useResult
$Res call({
 HistoryStatus status, HistoryFilter filter, List<Scan> scans, ScanCounts counts, int pagesRequested, bool hasMore, bool loadingMore, bool online
});


$ScanCountsCopyWith<$Res> get counts;

}
/// @nodoc
class _$HistoryStateCopyWithImpl<$Res>
    implements $HistoryStateCopyWith<$Res> {
  _$HistoryStateCopyWithImpl(this._self, this._then);

  final HistoryState _self;
  final $Res Function(HistoryState) _then;

/// Create a copy of HistoryState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? status = null,Object? filter = null,Object? scans = null,Object? counts = null,Object? pagesRequested = null,Object? hasMore = null,Object? loadingMore = null,Object? online = null,}) {
  return _then(_self.copyWith(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as HistoryStatus,filter: null == filter ? _self.filter : filter // ignore: cast_nullable_to_non_nullable
as HistoryFilter,scans: null == scans ? _self.scans : scans // ignore: cast_nullable_to_non_nullable
as List<Scan>,counts: null == counts ? _self.counts : counts // ignore: cast_nullable_to_non_nullable
as ScanCounts,pagesRequested: null == pagesRequested ? _self.pagesRequested : pagesRequested // ignore: cast_nullable_to_non_nullable
as int,hasMore: null == hasMore ? _self.hasMore : hasMore // ignore: cast_nullable_to_non_nullable
as bool,loadingMore: null == loadingMore ? _self.loadingMore : loadingMore // ignore: cast_nullable_to_non_nullable
as bool,online: null == online ? _self.online : online // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}
/// Create a copy of HistoryState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ScanCountsCopyWith<$Res> get counts {
  
  return $ScanCountsCopyWith<$Res>(_self.counts, (value) {
    return _then(_self.copyWith(counts: value));
  });
}
}


/// Adds pattern-matching-related methods to [HistoryState].
extension HistoryStatePatterns on HistoryState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _HistoryState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _HistoryState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _HistoryState value)  $default,){
final _that = this;
switch (_that) {
case _HistoryState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _HistoryState value)?  $default,){
final _that = this;
switch (_that) {
case _HistoryState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( HistoryStatus status,  HistoryFilter filter,  List<Scan> scans,  ScanCounts counts,  int pagesRequested,  bool hasMore,  bool loadingMore,  bool online)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _HistoryState() when $default != null:
return $default(_that.status,_that.filter,_that.scans,_that.counts,_that.pagesRequested,_that.hasMore,_that.loadingMore,_that.online);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( HistoryStatus status,  HistoryFilter filter,  List<Scan> scans,  ScanCounts counts,  int pagesRequested,  bool hasMore,  bool loadingMore,  bool online)  $default,) {final _that = this;
switch (_that) {
case _HistoryState():
return $default(_that.status,_that.filter,_that.scans,_that.counts,_that.pagesRequested,_that.hasMore,_that.loadingMore,_that.online);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( HistoryStatus status,  HistoryFilter filter,  List<Scan> scans,  ScanCounts counts,  int pagesRequested,  bool hasMore,  bool loadingMore,  bool online)?  $default,) {final _that = this;
switch (_that) {
case _HistoryState() when $default != null:
return $default(_that.status,_that.filter,_that.scans,_that.counts,_that.pagesRequested,_that.hasMore,_that.loadingMore,_that.online);case _:
  return null;

}
}

}

/// @nodoc


class _HistoryState extends HistoryState {
  const _HistoryState({this.status = HistoryStatus.loading, this.filter = HistoryFilter.all, final  List<Scan> scans = const <Scan>[], this.counts = const ScanCounts(all: 0, opened: 0, closed: 0), this.pagesRequested = 1, this.hasMore = true, this.loadingMore = false, this.online = true}): _scans = scans,super._();
  

/// The load phase.
@override@JsonKey() final  HistoryStatus status;
/// The active verdict filter.
@override@JsonKey() final  HistoryFilter filter;
/// The visible scans (newest first, capped at the page window).
 final  List<Scan> _scans;
/// The visible scans (newest first, capped at the page window).
@override@JsonKey() List<Scan> get scans {
  if (_scans is EqualUnmodifiableListView) return _scans;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_scans);
}

/// Per-filter row counts for the chips.
@override@JsonKey() final  ScanCounts counts;
/// How many [HistoryBloc.pageSize] pages the window spans.
@override@JsonKey() final  int pagesRequested;
/// Whether another page may exist beyond the window.
@override@JsonKey() final  bool hasMore;
/// Whether a grow-the-window request is in flight.
@override@JsonKey() final  bool loadingMore;
/// Whether the device is online (offline shows the local-history banner).
@override@JsonKey() final  bool online;

/// Create a copy of HistoryState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$HistoryStateCopyWith<_HistoryState> get copyWith => __$HistoryStateCopyWithImpl<_HistoryState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _HistoryState&&(identical(other.status, status) || other.status == status)&&(identical(other.filter, filter) || other.filter == filter)&&const DeepCollectionEquality().equals(other._scans, _scans)&&(identical(other.counts, counts) || other.counts == counts)&&(identical(other.pagesRequested, pagesRequested) || other.pagesRequested == pagesRequested)&&(identical(other.hasMore, hasMore) || other.hasMore == hasMore)&&(identical(other.loadingMore, loadingMore) || other.loadingMore == loadingMore)&&(identical(other.online, online) || other.online == online));
}


@override
int get hashCode => Object.hash(runtimeType,status,filter,const DeepCollectionEquality().hash(_scans),counts,pagesRequested,hasMore,loadingMore,online);

@override
String toString() {
  return 'HistoryState(status: $status, filter: $filter, scans: $scans, counts: $counts, pagesRequested: $pagesRequested, hasMore: $hasMore, loadingMore: $loadingMore, online: $online)';
}


}

/// @nodoc
abstract mixin class _$HistoryStateCopyWith<$Res> implements $HistoryStateCopyWith<$Res> {
  factory _$HistoryStateCopyWith(_HistoryState value, $Res Function(_HistoryState) _then) = __$HistoryStateCopyWithImpl;
@override @useResult
$Res call({
 HistoryStatus status, HistoryFilter filter, List<Scan> scans, ScanCounts counts, int pagesRequested, bool hasMore, bool loadingMore, bool online
});


@override $ScanCountsCopyWith<$Res> get counts;

}
/// @nodoc
class __$HistoryStateCopyWithImpl<$Res>
    implements _$HistoryStateCopyWith<$Res> {
  __$HistoryStateCopyWithImpl(this._self, this._then);

  final _HistoryState _self;
  final $Res Function(_HistoryState) _then;

/// Create a copy of HistoryState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? status = null,Object? filter = null,Object? scans = null,Object? counts = null,Object? pagesRequested = null,Object? hasMore = null,Object? loadingMore = null,Object? online = null,}) {
  return _then(_HistoryState(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as HistoryStatus,filter: null == filter ? _self.filter : filter // ignore: cast_nullable_to_non_nullable
as HistoryFilter,scans: null == scans ? _self._scans : scans // ignore: cast_nullable_to_non_nullable
as List<Scan>,counts: null == counts ? _self.counts : counts // ignore: cast_nullable_to_non_nullable
as ScanCounts,pagesRequested: null == pagesRequested ? _self.pagesRequested : pagesRequested // ignore: cast_nullable_to_non_nullable
as int,hasMore: null == hasMore ? _self.hasMore : hasMore // ignore: cast_nullable_to_non_nullable
as bool,loadingMore: null == loadingMore ? _self.loadingMore : loadingMore // ignore: cast_nullable_to_non_nullable
as bool,online: null == online ? _self.online : online // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

/// Create a copy of HistoryState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ScanCountsCopyWith<$Res> get counts {
  
  return $ScanCountsCopyWith<$Res>(_self.counts, (value) {
    return _then(_self.copyWith(counts: value));
  });
}
}

// dart format on
