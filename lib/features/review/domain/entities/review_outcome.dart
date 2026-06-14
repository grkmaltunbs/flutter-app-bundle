import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:okey_acar_mi/core/game/game_mode.dart';
import 'package:okey_acar_mi/core/game/game_tile.dart';
import 'package:okey_acar_mi/core/game/indicator.dart';

part 'review_outcome.freezed.dart';

/// The confirmed review output — the payload handed to the `/result` route
/// (Step 8 consumes it): the corrected rack, the indicator, and the mode the
/// solver should run in.
@freezed
abstract class ReviewOutcome with _$ReviewOutcome {
  /// Creates a [ReviewOutcome].
  const factory ReviewOutcome({
    /// The confirmed tiles in rack order; jokers are `GameTile(joker, null)`.
    required List<GameTile> tiles,

    /// The game the solver should target.
    required GameMode gameMode,

    /// The indicator (gösterge) the user picked, or `null` when a face-down
    /// (blank okey) tile let them skip it.
    Indicator? indicator,
  }) = _ReviewOutcome;

  const ReviewOutcome._();

  /// The okey tile derived from [indicator], or `null` when none was picked.
  GameTile? get okeyTile => indicator?.okeyTile;
}
