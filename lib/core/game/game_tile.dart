import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:okey_acar_mi/core/game/tile_color.dart';

part 'game_tile.freezed.dart';

/// A fully defined Okey tile — the solver's input type.
///
/// Invariant: a [GameTile] is either a **numbered tile** ([number] 1–13,
/// [color] one of the four tile colors) or a **joker** ([color] ==
/// [TileColor.joker], [number] == null).
///
/// A joker is one of two kinds, distinguished by [faceDown]:
/// - **false joker / sahte okey** ([faceDown] == false) — plays *only* as the
///   okey-value tile (indicator + 1, same color); it is **not** wild.
/// - **face-down** ([faceDown] == true) — a hidden okey; it **is** wild and
///   substitutes for any tile.
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
  @Assert(
    '!faceDown || color == TileColor.joker',
    'only a joker tile can be face-down',
  )
  const factory GameTile({
    required TileColor color,
    int? number,
    @Default(false) bool faceDown,
  }) = _GameTile;

  const GameTile._();

  /// Whether this tile is a joker (false joker or face-down).
  bool get isJoker => color == TileColor.joker;
}
