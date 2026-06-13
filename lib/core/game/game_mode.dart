/// The game the scan loop targets; drives the solver, the legal rack size,
/// and the result presentation.
///
/// Lives in `core/game` (pure Dart) so the review and solver domains can use
/// it without importing the settings feature; `settings_cubit.dart` re-exports
/// it for its existing call sites.
enum GameMode {
  /// 101 Okey — open by laying down sets/runs totaling ≥101 (or five pairs).
  oneZeroOne,

  /// Plain Okey — complete a winning hand; output tiles-to-win.
  okey
  ;

  /// The minimum legal rack size for this mode (101 → 21, Okey → 14).
  ///
  /// 101 rests on 21 tiles; on your turn you draw a 22nd and must discard one.
  int get minTiles => switch (this) {
    GameMode.oneZeroOne => 21,
    GameMode.okey => 14,
  };

  /// The maximum legal rack size for this mode (101 → 22, Okey → 15).
  ///
  /// The extra tile (22nd for 101, 15th for Okey) is the just-drawn tile that
  /// must be discarded at the end of the turn.
  int get maxTiles => switch (this) {
    GameMode.oneZeroOne => 22,
    GameMode.okey => 15,
  };
}
