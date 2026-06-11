/// The coarse phases of the on-device detection pipeline, surfaced as staged
/// progress messages on the analyzing screen.
enum DetectionStage {
  /// Worker spawn + image decode.
  preparing,

  /// Segmenting the rack and clustering the 2-row baseline.
  locatingRack,

  /// Reading numerals + classifying colors per tile.
  readingTiles,

  /// Combining per-frame readings of a video burst (multi-frame only).
  aggregatingFrames,

  /// Assembling the final result.
  finalizing,
}
