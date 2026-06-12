import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:okey_acar_mi/core/game/game_tile.dart';

part 'solved_spot.freezed.dart';

/// One cell of a solved arrangement: which physical tile occupies it (if
/// any) and the identity it plays as.
@freezed
sealed class SolvedSpot with _$SolvedSpot {
  /// A regular rack tile playing as itself.
  const factory SolvedSpot.rackTile({
    required GameTile physical,
    required int rackIndex,
    required GameTile playsAs,
  }) = RackSpot;

  /// A wild (joker or okey copy) from the rack standing in for [playsAs].
  ///
  /// A wild standing as the okey identity itself is just a [WildSpot] whose
  /// [playsAs] equals the okey tile — no special case.
  const factory SolvedSpot.wild({
    required GameTile physical,
    required int rackIndex,
    required GameTile playsAs,
  }) = WildSpot;

  /// A tile still needed to complete the arrangement (okey mode only).
  const factory SolvedSpot.needed({
    required GameTile playsAs,
  }) = NeededSpot;
}
