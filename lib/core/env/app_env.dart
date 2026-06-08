/// Application environment flavor.
///
/// Selected at compile time via `--dart-define=APP_ENV=demo|prod`.
/// The [name] values must match the strings passed to `injectable`'s
/// `@Environment(...)` annotations so DI registration resolves correctly.
enum AppEnv {
  /// In-memory, seeded fakes. Offline, deterministic. Default flavor used for
  /// all simulator verification. Never touches Firebase.
  demo,

  /// Real implementations (Firebase, RevenueCat, network).
  prod
  ;

  /// The environment for the current build, read from `APP_ENV`.
  ///
  /// Defaults to [AppEnv.demo] when unset or unrecognized.
  static AppEnv get current {
    const raw = String.fromEnvironment('APP_ENV', defaultValue: 'demo');
    return switch (raw) {
      'prod' => AppEnv.prod,
      _ => AppEnv.demo,
    };
  }

  /// The injectable environment name (`'demo'` or `'prod'`).
  String get name => switch (this) {
    AppEnv.demo => 'demo',
    AppEnv.prod => 'prod',
  };
}
