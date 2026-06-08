import 'package:injectable/injectable.dart';

/// A source of the current wall-clock time.
///
/// Inject this everywhere a timestamp is needed. Never call `DateTime.now()`
/// directly — that makes time-dependent logic untestable.
abstract class Clock {
  /// The current instant.
  DateTime now();
}

/// Production clock backed by the real system time.
@Environment('prod')
@LazySingleton(as: Clock)
class SystemClock implements Clock {
  /// Creates a [SystemClock].
  const SystemClock();

  @override
  DateTime now() => DateTime.now();
}

/// Deterministic clock for the demo flavor and tests.
///
/// Always returns the same seeded instant so flows are reproducible.
@Environment('demo')
@LazySingleton(as: Clock)
class FakeClock implements Clock {
  /// Creates a [FakeClock] pinned to [_seed].
  const FakeClock();

  static final DateTime _seed = DateTime.utc(2026);

  @override
  DateTime now() => _seed;
}
