import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:okey_acar_mi/core/game/game_mode.dart';
import 'package:okey_acar_mi/core/game/game_tile.dart';
import 'package:okey_acar_mi/core/game/indicator.dart';

part 'solve_request.freezed.dart';

/// Input bundle for a solve: the rack (in rack order), the indicator the
/// user picked, and the game mode.
///
/// The solver accepts any tile count or composition (garbage-robust); the
/// performance guarantee is documented for mode-legal sizes (up to 22).
///
/// [indicator] may be **null**: when the rack holds a face-down (blank okey)
/// tile the user is not forced to pick one. With no indicator there is no okey
/// identity, so only explicit wilds (jokers / face-down tiles) are wild.
@freezed
abstract class SolveRequest with _$SolveRequest {
  /// Creates a [SolveRequest].
  const factory SolveRequest({
    required List<GameTile> tiles,
    required GameMode mode,
    Indicator? indicator,
  }) = _SolveRequest;
}
