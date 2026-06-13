/// Key→value preference storage with a preloaded in-memory snapshot.
///
/// [read] is synchronous against the snapshot loaded at DI time, so consumers
/// (e.g. `SettingsCubit`) can hydrate their initial state without an async
/// gap. [write] is fire-and-forget durable persistence: it updates the
/// snapshot synchronously and never throws — persistence failures are logged
/// and swallowed (a lost preference write must never break the app).
abstract class PreferencesStore {
  /// Returns the stored value for [key], or null when absent.
  String? read(String key);

  /// Stores [value] under [key].
  ///
  /// The returned future always completes normally; failures are logged.
  Future<void> write(String key, String value);
}
