import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:okey_acar_mi/core/game/game_tile.dart';
import 'package:okey_acar_mi/core/game/tile_color.dart';

part 'review_tile.freezed.dart';

/// One editable tile on the review screen.
///
/// Unlike [GameTile], a [ReviewTile] may be **undefined** ([color] == null —
/// the dashed placeholder a "Taş ekle" adds, distinct from the joker) or
/// **partially defined** (a real color with no [number] yet, e.g. right after
/// switching a joker to a color). Only complete tiles convert to [GameTile]s.
///
/// A **face-down** tile ([faceDown] == true) is a wild (joker color, no number)
/// that renders as a blank tile and is, by tradition, a guaranteed okey — its
/// presence makes picking the indicator optional.
@freezed
abstract class ReviewTile with _$ReviewTile {
  /// Creates a [ReviewTile]. All-default creates an undefined placeholder.
  const factory ReviewTile({
    TileColor? color,
    int? number,
    @Default(false) bool lowConfidence,
    @Default(false) bool faceDown,
  }) = _ReviewTile;

  const ReviewTile._();

  /// Whether the tile is fully defined: a joker (joker color, no number) or a
  /// numbered tile (real color, number 1–13). A face-down tile is a complete
  /// joker.
  bool get isComplete => switch (color) {
    null => false,
    TileColor.joker => number == null,
    _ => number != null && number! >= 1 && number! <= 13,
  };

  /// This tile as a solver input. Only valid when [isComplete]. Preserves
  /// [faceDown] so the solver can tell a face-down (wild) from a false joker
  /// (which plays only as the okey value).
  GameTile get asGameTile {
    assert(isComplete, 'asGameTile is only valid on a complete tile');
    return GameTile(
      color: color!,
      number: color == TileColor.joker ? null : number,
      faceDown: faceDown,
    );
  }
}
