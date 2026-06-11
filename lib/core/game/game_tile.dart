import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:okey_acar_mi/core/game/tile_color.dart';

part 'game_tile.freezed.dart';

/// A fully defined Okey tile — the solver's input type.
///
/// Invariant: a [GameTile] is either a **numbered tile** ([number] 1–13,
/// [color] one of the four tile colors) or a **joker** ([color] ==
/// [TileColor.joker], [number] == null).
@freezed
abstract class GameTile with _$GameTile {
  /// Creates a [GameTile].
  @Assert(
    '(color == TileColor.joker) == (number == null)',
    'a joker carries no number; a numbered tile carries a real color',
  )
  @Assert(
    'number == null || (number >= 1 && number <= 13)',
    'number must be 1–13',
  )
  const factory GameTile({
    required TileColor color,
    int? number,
  }) = _GameTile;

  const GameTile._();

  /// Whether this tile is the wild joker.
  bool get isJoker => color == TileColor.joker;
}
