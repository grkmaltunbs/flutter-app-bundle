// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'solve_result.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$SolveResult {

/// Chosen melds in formation order (DP column ascending; within a
/// column runs flush before sets, colors ascending). Stable across
/// solves of equal requests.
 List<SolvedMeld> get melds;/// Chosen pairs: natural pairs by color then number, then wild- or
/// phantom-completed pairs. Okey `meldsAndPair` puts the single final
/// pair here. Deterministic order.
 List<SolvedPair> get pairs;/// Unused rack tiles in rack order (ascending `rackIndex`); only
/// [RackSpot] / [WildSpot], never [NeededSpot].
 List<SolvedSpot> get leftovers;/// Best meld-DP total — populated for every verdict.
 int get totalScore;/// The sealed discriminant; see the class doc for the field contract.
 SolveVerdict get verdict;/// Typed explanation steps in a fixed per-mode sequence:
/// normalization steps first ([OkeyDerivedStep], [WildsCountedStep],
/// [RackCountNotedStep], any [CountsClampedStep]s), then the
/// mode-specific steps in emission order.
 List<ReasoningStep> get reasoning;/// Suggested discard tile — okey-mode 15-tile racks only, else null.
/// Mirrors the [DiscardSuggestedStep] in [reasoning].
 GameTile? get discardSuggested;/// Rack index of [discardSuggested]; null exactly when it is null.
 int? get discardRackIndex;
/// Create a copy of SolveResult
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SolveResultCopyWith<SolveResult> get copyWith => _$SolveResultCopyWithImpl<SolveResult>(this as SolveResult, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SolveResult&&const DeepCollectionEquality().equals(other.melds, melds)&&const DeepCollectionEquality().equals(other.pairs, pairs)&&const DeepCollectionEquality().equals(other.leftovers, leftovers)&&(identical(other.totalScore, totalScore) || other.totalScore == totalScore)&&(identical(other.verdict, verdict) || other.verdict == verdict)&&const DeepCollectionEquality().equals(other.reasoning, reasoning)&&(identical(other.discardSuggested, discardSuggested) || other.discardSuggested == discardSuggested)&&(identical(other.discardRackIndex, discardRackIndex) || other.discardRackIndex == discardRackIndex));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(melds),const DeepCollectionEquality().hash(pairs),const DeepCollectionEquality().hash(leftovers),totalScore,verdict,const DeepCollectionEquality().hash(reasoning),discardSuggested,discardRackIndex);

@override
String toString() {
  return 'SolveResult(melds: $melds, pairs: $pairs, leftovers: $leftovers, totalScore: $totalScore, verdict: $verdict, reasoning: $reasoning, discardSuggested: $discardSuggested, discardRackIndex: $discardRackIndex)';
}


}

/// @nodoc
abstract mixin class $SolveResultCopyWith<$Res>  {
  factory $SolveResultCopyWith(SolveResult value, $Res Function(SolveResult) _then) = _$SolveResultCopyWithImpl;
@useResult
$Res call({
 List<SolvedMeld> melds, List<SolvedPair> pairs, List<SolvedSpot> leftovers, int totalScore, SolveVerdict verdict, List<ReasoningStep> reasoning, GameTile? discardSuggested, int? discardRackIndex
});


$SolveVerdictCopyWith<$Res> get verdict;$GameTileCopyWith<$Res>? get discardSuggested;

}
/// @nodoc
class _$SolveResultCopyWithImpl<$Res>
    implements $SolveResultCopyWith<$Res> {
  _$SolveResultCopyWithImpl(this._self, this._then);

  final SolveResult _self;
  final $Res Function(SolveResult) _then;

/// Create a copy of SolveResult
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? melds = null,Object? pairs = null,Object? leftovers = null,Object? totalScore = null,Object? verdict = null,Object? reasoning = null,Object? discardSuggested = freezed,Object? discardRackIndex = freezed,}) {
  return _then(_self.copyWith(
melds: null == melds ? _self.melds : melds // ignore: cast_nullable_to_non_nullable
as List<SolvedMeld>,pairs: null == pairs ? _self.pairs : pairs // ignore: cast_nullable_to_non_nullable
as List<SolvedPair>,leftovers: null == leftovers ? _self.leftovers : leftovers // ignore: cast_nullable_to_non_nullable
as List<SolvedSpot>,totalScore: null == totalScore ? _self.totalScore : totalScore // ignore: cast_nullable_to_non_nullable
as int,verdict: null == verdict ? _self.verdict : verdict // ignore: cast_nullable_to_non_nullable
as SolveVerdict,reasoning: null == reasoning ? _self.reasoning : reasoning // ignore: cast_nullable_to_non_nullable
as List<ReasoningStep>,discardSuggested: freezed == discardSuggested ? _self.discardSuggested : discardSuggested // ignore: cast_nullable_to_non_nullable
as GameTile?,discardRackIndex: freezed == discardRackIndex ? _self.discardRackIndex : discardRackIndex // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}
/// Create a copy of SolveResult
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SolveVerdictCopyWith<$Res> get verdict {
  
  return $SolveVerdictCopyWith<$Res>(_self.verdict, (value) {
    return _then(_self.copyWith(verdict: value));
  });
}/// Create a copy of SolveResult
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$GameTileCopyWith<$Res>? get discardSuggested {
    if (_self.discardSuggested == null) {
    return null;
  }

  return $GameTileCopyWith<$Res>(_self.discardSuggested!, (value) {
    return _then(_self.copyWith(discardSuggested: value));
  });
}
}


/// Adds pattern-matching-related methods to [SolveResult].
extension SolveResultPatterns on SolveResult {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SolveResult value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SolveResult() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SolveResult value)  $default,){
final _that = this;
switch (_that) {
case _SolveResult():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SolveResult value)?  $default,){
final _that = this;
switch (_that) {
case _SolveResult() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<SolvedMeld> melds,  List<SolvedPair> pairs,  List<SolvedSpot> leftovers,  int totalScore,  SolveVerdict verdict,  List<ReasoningStep> reasoning,  GameTile? discardSuggested,  int? discardRackIndex)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SolveResult() when $default != null:
return $default(_that.melds,_that.pairs,_that.leftovers,_that.totalScore,_that.verdict,_that.reasoning,_that.discardSuggested,_that.discardRackIndex);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<SolvedMeld> melds,  List<SolvedPair> pairs,  List<SolvedSpot> leftovers,  int totalScore,  SolveVerdict verdict,  List<ReasoningStep> reasoning,  GameTile? discardSuggested,  int? discardRackIndex)  $default,) {final _that = this;
switch (_that) {
case _SolveResult():
return $default(_that.melds,_that.pairs,_that.leftovers,_that.totalScore,_that.verdict,_that.reasoning,_that.discardSuggested,_that.discardRackIndex);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<SolvedMeld> melds,  List<SolvedPair> pairs,  List<SolvedSpot> leftovers,  int totalScore,  SolveVerdict verdict,  List<ReasoningStep> reasoning,  GameTile? discardSuggested,  int? discardRackIndex)?  $default,) {final _that = this;
switch (_that) {
case _SolveResult() when $default != null:
return $default(_that.melds,_that.pairs,_that.leftovers,_that.totalScore,_that.verdict,_that.reasoning,_that.discardSuggested,_that.discardRackIndex);case _:
  return null;

}
}

}

/// @nodoc


class _SolveResult implements SolveResult {
  const _SolveResult({required final  List<SolvedMeld> melds, required final  List<SolvedPair> pairs, required final  List<SolvedSpot> leftovers, required this.totalScore, required this.verdict, required final  List<ReasoningStep> reasoning, this.discardSuggested, this.discardRackIndex}): _melds = melds,_pairs = pairs,_leftovers = leftovers,_reasoning = reasoning;
  

/// Chosen melds in formation order (DP column ascending; within a
/// column runs flush before sets, colors ascending). Stable across
/// solves of equal requests.
 final  List<SolvedMeld> _melds;
/// Chosen melds in formation order (DP column ascending; within a
/// column runs flush before sets, colors ascending). Stable across
/// solves of equal requests.
@override List<SolvedMeld> get melds {
  if (_melds is EqualUnmodifiableListView) return _melds;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_melds);
}

/// Chosen pairs: natural pairs by color then number, then wild- or
/// phantom-completed pairs. Okey `meldsAndPair` puts the single final
/// pair here. Deterministic order.
 final  List<SolvedPair> _pairs;
/// Chosen pairs: natural pairs by color then number, then wild- or
/// phantom-completed pairs. Okey `meldsAndPair` puts the single final
/// pair here. Deterministic order.
@override List<SolvedPair> get pairs {
  if (_pairs is EqualUnmodifiableListView) return _pairs;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_pairs);
}

/// Unused rack tiles in rack order (ascending `rackIndex`); only
/// [RackSpot] / [WildSpot], never [NeededSpot].
 final  List<SolvedSpot> _leftovers;
/// Unused rack tiles in rack order (ascending `rackIndex`); only
/// [RackSpot] / [WildSpot], never [NeededSpot].
@override List<SolvedSpot> get leftovers {
  if (_leftovers is EqualUnmodifiableListView) return _leftovers;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_leftovers);
}

/// Best meld-DP total — populated for every verdict.
@override final  int totalScore;
/// The sealed discriminant; see the class doc for the field contract.
@override final  SolveVerdict verdict;
/// Typed explanation steps in a fixed per-mode sequence:
/// normalization steps first ([OkeyDerivedStep], [WildsCountedStep],
/// [RackCountNotedStep], any [CountsClampedStep]s), then the
/// mode-specific steps in emission order.
 final  List<ReasoningStep> _reasoning;
/// Typed explanation steps in a fixed per-mode sequence:
/// normalization steps first ([OkeyDerivedStep], [WildsCountedStep],
/// [RackCountNotedStep], any [CountsClampedStep]s), then the
/// mode-specific steps in emission order.
@override List<ReasoningStep> get reasoning {
  if (_reasoning is EqualUnmodifiableListView) return _reasoning;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_reasoning);
}

/// Suggested discard tile — okey-mode 15-tile racks only, else null.
/// Mirrors the [DiscardSuggestedStep] in [reasoning].
@override final  GameTile? discardSuggested;
/// Rack index of [discardSuggested]; null exactly when it is null.
@override final  int? discardRackIndex;

/// Create a copy of SolveResult
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SolveResultCopyWith<_SolveResult> get copyWith => __$SolveResultCopyWithImpl<_SolveResult>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SolveResult&&const DeepCollectionEquality().equals(other._melds, _melds)&&const DeepCollectionEquality().equals(other._pairs, _pairs)&&const DeepCollectionEquality().equals(other._leftovers, _leftovers)&&(identical(other.totalScore, totalScore) || other.totalScore == totalScore)&&(identical(other.verdict, verdict) || other.verdict == verdict)&&const DeepCollectionEquality().equals(other._reasoning, _reasoning)&&(identical(other.discardSuggested, discardSuggested) || other.discardSuggested == discardSuggested)&&(identical(other.discardRackIndex, discardRackIndex) || other.discardRackIndex == discardRackIndex));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_melds),const DeepCollectionEquality().hash(_pairs),const DeepCollectionEquality().hash(_leftovers),totalScore,verdict,const DeepCollectionEquality().hash(_reasoning),discardSuggested,discardRackIndex);

@override
String toString() {
  return 'SolveResult(melds: $melds, pairs: $pairs, leftovers: $leftovers, totalScore: $totalScore, verdict: $verdict, reasoning: $reasoning, discardSuggested: $discardSuggested, discardRackIndex: $discardRackIndex)';
}


}

/// @nodoc
abstract mixin class _$SolveResultCopyWith<$Res> implements $SolveResultCopyWith<$Res> {
  factory _$SolveResultCopyWith(_SolveResult value, $Res Function(_SolveResult) _then) = __$SolveResultCopyWithImpl;
@override @useResult
$Res call({
 List<SolvedMeld> melds, List<SolvedPair> pairs, List<SolvedSpot> leftovers, int totalScore, SolveVerdict verdict, List<ReasoningStep> reasoning, GameTile? discardSuggested, int? discardRackIndex
});


@override $SolveVerdictCopyWith<$Res> get verdict;@override $GameTileCopyWith<$Res>? get discardSuggested;

}
/// @nodoc
class __$SolveResultCopyWithImpl<$Res>
    implements _$SolveResultCopyWith<$Res> {
  __$SolveResultCopyWithImpl(this._self, this._then);

  final _SolveResult _self;
  final $Res Function(_SolveResult) _then;

/// Create a copy of SolveResult
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? melds = null,Object? pairs = null,Object? leftovers = null,Object? totalScore = null,Object? verdict = null,Object? reasoning = null,Object? discardSuggested = freezed,Object? discardRackIndex = freezed,}) {
  return _then(_SolveResult(
melds: null == melds ? _self._melds : melds // ignore: cast_nullable_to_non_nullable
as List<SolvedMeld>,pairs: null == pairs ? _self._pairs : pairs // ignore: cast_nullable_to_non_nullable
as List<SolvedPair>,leftovers: null == leftovers ? _self._leftovers : leftovers // ignore: cast_nullable_to_non_nullable
as List<SolvedSpot>,totalScore: null == totalScore ? _self.totalScore : totalScore // ignore: cast_nullable_to_non_nullable
as int,verdict: null == verdict ? _self.verdict : verdict // ignore: cast_nullable_to_non_nullable
as SolveVerdict,reasoning: null == reasoning ? _self._reasoning : reasoning // ignore: cast_nullable_to_non_nullable
as List<ReasoningStep>,discardSuggested: freezed == discardSuggested ? _self.discardSuggested : discardSuggested // ignore: cast_nullable_to_non_nullable
as GameTile?,discardRackIndex: freezed == discardRackIndex ? _self.discardRackIndex : discardRackIndex // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

/// Create a copy of SolveResult
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SolveVerdictCopyWith<$Res> get verdict {
  
  return $SolveVerdictCopyWith<$Res>(_self.verdict, (value) {
    return _then(_self.copyWith(verdict: value));
  });
}/// Create a copy of SolveResult
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$GameTileCopyWith<$Res>? get discardSuggested {
    if (_self.discardSuggested == null) {
    return null;
  }

  return $GameTileCopyWith<$Res>(_self.discardSuggested!, (value) {
    return _then(_self.copyWith(discardSuggested: value));
  });
}
}

// dart format on
