part of 'home_cubit.dart';

/// The home dashboard state: the newest scan (or null when there is none)
/// and the aggregate stats.
@freezed
abstract class HomeState with _$HomeState {
  /// Creates a [HomeState].
  const factory HomeState({
    /// The owner's newest scan; null while loading or when none exist.
    Scan? lastScan,

    /// The owner's aggregate stats; null until the first delivery.
    ScanStats? stats,

    /// True once both streams have delivered at least once.
    @Default(false) bool ready,
  }) = _HomeState;
}
