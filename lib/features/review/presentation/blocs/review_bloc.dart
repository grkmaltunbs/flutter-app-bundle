import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';
import 'package:okey_acar_mi/core/game/game_mode.dart';
import 'package:okey_acar_mi/core/game/game_tile.dart';
import 'package:okey_acar_mi/core/game/indicator.dart';
import 'package:okey_acar_mi/core/game/tile_color.dart';
import 'package:okey_acar_mi/features/detection/domain/entities/detected_tile.dart';
import 'package:okey_acar_mi/features/detection/domain/entities/detection_result.dart';
import 'package:okey_acar_mi/features/review/domain/entities/review_outcome.dart';
import 'package:okey_acar_mi/features/review/domain/entities/review_tile.dart';
import 'package:okey_acar_mi/features/review/domain/seed_review_tiles.dart';

part 'review_bloc.freezed.dart';
part 'review_event.dart';
part 'review_state.dart';

/// Screen-scoped bloc for the review screen: holds the editable rack seeded
/// from the detection result, the tile being edited, and the indicator pick.
///
/// All handlers are synchronous reducers; navigation to `/result` happens in
/// the footer widget (reading [ReviewState.outcome]), never in here. Holds no
/// subscriptions, so `close()` is not overridden.
@injectable
class ReviewBloc extends Bloc<ReviewEvent, ReviewState> {
  /// Creates a [ReviewBloc] seeded from [result] for [gameMode] (the mode is
  /// read once when the screen opens — a later settings change does not
  /// retarget an in-flight review).
  ReviewBloc(
    @factoryParam DetectionResult result,
    @factoryParam GameMode gameMode,
  ) : super(
        ReviewState(
          tiles: seedReviewTiles(result),
          gameMode: gameMode,
          overallConfidence: result.overallConfidence,
        ),
      ) {
    on<ReviewTileTapped>(_onTileTapped);
    on<ReviewEditClosed>(_onEditClosed);
    on<ReviewTileColorChanged>(_onTileColorChanged);
    on<ReviewTileNumberChanged>(_onTileNumberChanged);
    on<ReviewTileAdded>(_onTileAdded);
    on<ReviewTileRemoved>(_onTileRemoved);
    on<ReviewIndicatorPicked>(_onIndicatorPicked);
  }

  void _onTileTapped(ReviewTileTapped event, Emitter<ReviewState> emit) {
    if (event.index < 0 || event.index >= state.tiles.length) return;
    emit(
      state.copyWith(
        editingIndex: state.editingIndex == event.index ? null : event.index,
      ),
    );
  }

  void _onEditClosed(ReviewEditClosed event, Emitter<ReviewState> emit) {
    emit(state.copyWith(editingIndex: null));
  }

  void _onTileColorChanged(
    ReviewTileColorChanged event,
    Emitter<ReviewState> emit,
  ) {
    final index = state.editingIndex;
    if (index == null) return;
    final tile = state.tiles[index];
    emit(
      state.copyWith(
        tiles: _replaceAt(
          index,
          tile.copyWith(
            color: event.color,
            // A joker carries no number; joker → real color keeps the
            // existing number (possibly null → still incomplete, D6).
            number: event.color == TileColor.joker ? null : tile.number,
            lowConfidence: false,
          ),
        ),
      ),
    );
  }

  void _onTileNumberChanged(
    ReviewTileNumberChanged event,
    Emitter<ReviewState> emit,
  ) {
    final index = state.editingIndex;
    if (index == null) return;
    if (event.number < 1 || event.number > 13) return;
    emit(
      state.copyWith(
        tiles: _replaceAt(
          index,
          state.tiles[index].copyWith(
            number: event.number,
            lowConfidence: false,
          ),
        ),
      ),
    );
  }

  void _onTileAdded(ReviewTileAdded event, Emitter<ReviewState> emit) {
    if (!state.canAdd) return;
    emit(
      state.copyWith(
        tiles: List.unmodifiable([...state.tiles, const ReviewTile()]),
        // Auto-open the editor on the new undefined placeholder (D3).
        editingIndex: state.tiles.length,
      ),
    );
  }

  void _onTileRemoved(ReviewTileRemoved event, Emitter<ReviewState> emit) {
    final index = state.editingIndex;
    if (!state.canRemove || index == null) return;
    emit(
      state.copyWith(
        tiles: List.unmodifiable([
          ...state.tiles.take(index),
          ...state.tiles.skip(index + 1),
        ]),
        editingIndex: null,
      ),
    );
  }

  void _onIndicatorPicked(
    ReviewIndicatorPicked event,
    Emitter<ReviewState> emit,
  ) {
    // The indicator is a real numbered tile — never the joker (D5).
    if (event.color == TileColor.joker) return;
    if (event.number < 1 || event.number > 13) return;
    emit(
      state.copyWith(
        indicator: Indicator(color: event.color, number: event.number),
      ),
    );
  }

  List<ReviewTile> _replaceAt(int index, ReviewTile tile) {
    return List.unmodifiable([
      for (var i = 0; i < state.tiles.length; i++)
        if (i == index) tile else state.tiles[i],
    ]);
  }
}
