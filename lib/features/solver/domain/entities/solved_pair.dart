import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:okey_acar_mi/core/game/game_tile.dart';
import 'package:okey_acar_mi/features/solver/domain/entities/solved_spot.dart';

part 'solved_pair.freezed.dart';

/// A pair (two tiles of identical color + number, possibly completed by a
/// wild or a needed tile) in a pairs-path arrangement.
@freezed
abstract class SolvedPair with _$SolvedPair {
  /// Creates a [SolvedPair].
  const factory SolvedPair({
    required GameTile identity,
    required SolvedSpot first,
    required SolvedSpot second,
  }) = _SolvedPair;
}
