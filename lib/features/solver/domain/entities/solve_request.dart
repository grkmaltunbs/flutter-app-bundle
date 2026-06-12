import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:okey_acar_mi/core/game/game_mode.dart';
import 'package:okey_acar_mi/core/game/game_tile.dart';
import 'package:okey_acar_mi/core/game/indicator.dart';

part 'solve_request.freezed.dart';

/// Input bundle for a solve: the rack (in rack order), the indicator the
/// user picked, and the game mode.
///
/// The solver accepts any tile count or composition (garbage-robust); the
/// performance guarantee is documented for mode-legal sizes (up to 21).
@freezed
abstract class SolveRequest with _$SolveRequest {
  /// Creates a [SolveRequest].
  const factory SolveRequest({
    required List<GameTile> tiles,
    required Indicator indicator,
    required GameMode mode,
  }) = _SolveRequest;
}
