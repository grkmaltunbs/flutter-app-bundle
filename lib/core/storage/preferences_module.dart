import 'package:injectable/injectable.dart';
import 'package:okey_acar_mi/core/db/app_database.dart';
import 'package:okey_acar_mi/core/logging/app_logger.dart';
import 'package:okey_acar_mi/core/storage/drift_preferences_store.dart';
import 'package:okey_acar_mi/core/storage/preferences_store.dart';

/// DI module providing the single [PreferencesStore].
///
/// Registered in BOTH environments — like `AppDatabase` itself, the drift
/// store IS the demo store (local persistence has no backend to fake).
/// `@preResolve` loads the snapshot during `configureDependencies`, so
/// consumers get synchronous reads from the first frame.
@module
abstract class PreferencesModule {
  /// The preloaded preferences store singleton.
  @preResolve
  @LazySingleton(as: PreferencesStore)
  Future<DriftPreferencesStore> preferencesStore(
    AppDatabase db,
    AppLogger logger,
  ) => DriftPreferencesStore.load(db, logger);
}
