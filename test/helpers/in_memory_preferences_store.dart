import 'package:okey_acar_mi/core/storage/preferences_store.dart';

/// Map-backed [PreferencesStore] double for host tests.
///
/// Honors the interface contract: [read] is synchronous and [write] always
/// completes normally. [failWrites] simulates a persistence failure — the
/// write is recorded in [writes] but the value is dropped, so a test can
/// assert both "the caller survived" and "nothing was persisted".
class InMemoryPreferencesStore implements PreferencesStore {
  /// Creates a store, optionally seeded with [seed].
  InMemoryPreferencesStore([Map<String, String>? seed]) : _values = {...?seed};

  final Map<String, String> _values;

  /// When true, [write] completes normally but persists nothing (the real
  /// store's never-throws contract under infrastructure failure).
  bool failWrites = false;

  /// Every `(key, value)` pair passed to [write], in call order — including
  /// the ones dropped by [failWrites].
  final List<(String, String)> writes = [];

  /// The currently persisted values (read-only view).
  Map<String, String> get values => Map.unmodifiable(_values);

  @override
  String? read(String key) => _values[key];

  @override
  Future<void> write(String key, String value) async {
    writes.add((key, value));
    if (failWrites) return;
    _values[key] = value;
  }
}
