part of 'review_bloc.dart';

/// The review screen state: the editable rack, the active edit, and the
/// indicator pick.
///
/// Has more than three fields — consumers must scope rebuilds with
/// `BlocSelector` / `buildWhen` per the project performance rules.
@freezed
abstract class ReviewState with _$ReviewState {
  /// Creates a [ReviewState].
  const factory ReviewState({
    /// The editable tiles in rack order (unmodifiable).
    required List<ReviewTile> tiles,

    /// The mode this review targets (fixed at screen creation).
    required GameMode gameMode,

    /// Mean per-tile detection confidence (drives the retake banner).
    required double overallConfidence,

    /// The picked indicator, or null while unset.
    Indicator? indicator,

    /// Index of the tile being edited, or null when the panel is closed.
    int? editingIndex,
  }) = _ReviewState;

  const ReviewState._();

  /// Number of tiles currently on the rack.
  int get tileCount => tiles.length;

  /// Whether [tileCount] is within the mode's legal range.
  bool get countValid =>
      tileCount >= gameMode.minTiles && tileCount <= gameMode.maxTiles;

  /// Whether another tile may be added (below the mode's maximum).
  bool get canAdd => tileCount < gameMode.maxTiles;

  /// Whether a tile may be removed (above the mode's minimum).
  bool get canRemove => tileCount > gameMode.minTiles;

  /// Whether every tile is fully defined.
  bool get allTilesComplete => tiles.every((tile) => tile.isComplete);

  /// Whether the capture as a whole read poorly (suggest a retake). Low
  /// confidence never blocks solving (D2).
  bool get lowOverallConfidence => overallConfidence < kLowConfidenceThreshold;

  /// The okey tile derived from [indicator], or null while unset.
  GameTile? get okeyTile => indicator?.okeyTile;

  /// Whether "Hesapla" is allowed: indicator set, legal count, every tile
  /// complete (D2).
  bool get canSolve => indicator != null && countValid && allTilesComplete;

  /// The tile being edited, or null when the panel is closed.
  ReviewTile? get editingTile =>
      editingIndex == null ? null : tiles[editingIndex!];

  /// Builds the `/result` payload. Only call when [canSolve].
  ReviewOutcome outcome() {
    assert(canSolve, 'outcome() is only valid when canSolve');
    return ReviewOutcome(
      tiles: List.unmodifiable([for (final tile in tiles) tile.asGameTile]),
      indicator: indicator!,
      gameMode: gameMode,
    );
  }
}
