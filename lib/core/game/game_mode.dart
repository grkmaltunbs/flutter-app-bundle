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

  /// The minimum legal rack size for this mode (101 → 20, Okey → 14).
  int get minTiles => switch (this) {
    GameMode.oneZeroOne => 20,
    GameMode.okey => 14,
  };

  /// The maximum legal rack size for this mode (101 → 21, Okey → 15).
  int get maxTiles => switch (this) {
    GameMode.oneZeroOne => 21,
    GameMode.okey => 15,
  };
}
