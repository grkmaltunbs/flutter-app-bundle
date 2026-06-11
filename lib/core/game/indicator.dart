import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:okey_acar_mi/core/game/game_tile.dart';
import 'package:okey_acar_mi/core/game/tile_color.dart';

part 'indicator.freezed.dart';

/// The indicator (gösterge) tile the user picked.
///
/// The okey for the round is the same color, one number up, wrapping 13 → 1
/// (`(n + 1) mod 13` per the authoritative rules in `PRODUCT_SPEC.md`).
@freezed
abstract class Indicator with _$Indicator {
  /// Creates an [Indicator]. The indicator is always a real numbered tile —
  /// never the joker.
  @Assert(
    'color != TileColor.joker',
    'the indicator is a real tile, never the joker',
  )
  @Assert('number >= 1 && number <= 13', 'number must be 1–13')
  const factory Indicator({
    required TileColor color,
    required int number,
  }) = _Indicator;

  const Indicator._();

  /// The okey numeral derived from this indicator: one up, 13 wraps to 1.
  int get okeyNumber => number % 13 + 1;

  /// The okey tile for the round (same color, [okeyNumber]).
  GameTile get okeyTile => GameTile(color: color, number: okeyNumber);
}
