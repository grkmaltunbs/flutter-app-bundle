part of 'review_bloc.dart';

/// Intent events for [ReviewBloc] (past-tense, no `BuildContext`).
@freezed
sealed class ReviewEvent with _$ReviewEvent {
  /// A rack tile was tapped: opens its editor, closes it when it was already
  /// open, or switches the editor to it from another tile.
  const factory ReviewEvent.tileTapped(int index) = ReviewTileTapped;

  /// The edit panel's close button was tapped.
  const factory ReviewEvent.editClosed() = ReviewEditClosed;

  /// A color was picked for the tile being edited. Picking the joker clears
  /// the number; picking a real color keeps it. Always clears the
  /// low-confidence flag.
  const factory ReviewEvent.tileColorChanged(TileColor color) =
      ReviewTileColorChanged;

  /// A numeral was picked for the tile being edited (clears the
  /// low-confidence flag).
  const factory ReviewEvent.tileNumberChanged(int number) =
      ReviewTileNumberChanged;

  /// "Taş ekle" was tapped: appends an undefined placeholder and opens its
  /// editor. Ignored at the mode's maximum rack size.
  const factory ReviewEvent.tileAdded() = ReviewTileAdded;

  /// "Taşı sil" was tapped: removes the tile being edited. Ignored at the
  /// mode's minimum rack size or when no tile is being edited.
  const factory ReviewEvent.tileRemoved() = ReviewTileRemoved;

  /// The indicator (gösterge) was confirmed in the picker sheet. Ignored for
  /// the joker color or an out-of-range number.
  const factory ReviewEvent.indicatorPicked(TileColor color, int number) =
      ReviewIndicatorPicked;
}
