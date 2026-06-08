/// The visual treatment applied to every tile in the app.
///
/// Selected by the user in Settings and threaded through the active palette so
/// widgets can resolve it from theme without an explicit parameter. Ported from
/// the four `style` variants in the design bundle's `tiles.jsx`.
enum TileStyle {
  /// Cream face with a serif numeral in the tile color and a faint seam.
  classic,

  /// Solid color face matching the tile color with a white mono numeral.
  flat,

  /// Surface card with a colored dot above a mono numeral.
  minimal,

  /// Cream face with an oversized italic serif numeral.
  bold,
}
