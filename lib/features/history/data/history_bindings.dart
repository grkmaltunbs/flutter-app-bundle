import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:injectable/injectable.dart';
import 'package:okey_acar_mi/core/logging/app_logger.dart';
import 'package:okey_acar_mi/features/history/data/datasources/firestore_scan_remote_data_source.dart';
import 'package:okey_acar_mi/features/history/data/datasources/scan_remote_data_source.dart';
import 'package:okey_acar_mi/features/history/data/fakes/fake_scan_remote_data_source.dart';

/// Restores the [FakeScanRemoteDataSource]'s seeded state when the DI
/// container resets (`getIt.reset()`), so consecutive test configurations
/// never see leaked toggles/uploads.
void disposeFakeScanRemoteDataSource(FakeScanRemoteDataSource instance) =>
    instance.reset();

/// DI module for the history feature's remote scan storage: one concrete
/// data source per environment, registered as itself, with
/// [ScanRemoteDataSource] aliased to that single instance (mirrors
/// `capture_bindings.dart`).
@module
abstract class HistoryBindings {
  /// The production Firestore instance (prod only — demo never touches
  /// Firebase).
  @Environment('prod')
  @lazySingleton
  FirebaseFirestore get firebaseFirestore => FirebaseFirestore.instance;

  /// The production remote data source over Firestore.
  @Environment('prod')
  @lazySingleton
  FirestoreScanRemoteDataSource firestoreScanRemoteDataSource(
    FirebaseFirestore firestore,
    AppLogger logger,
  ) => FirestoreScanRemoteDataSource(firestore, logger);

  /// Aliases the prod [ScanRemoteDataSource] to the Firestore impl.
  @Environment('prod')
  @lazySingleton
  ScanRemoteDataSource prodScanRemoteDataSource(
    FirestoreScanRemoteDataSource dataSource,
  ) => dataSource;

  /// The seeded demo fake (in-memory, deterministic, instant).
  @Environment('demo')
  @LazySingleton(dispose: disposeFakeScanRemoteDataSource)
  FakeScanRemoteDataSource get fakeScanRemoteDataSource =>
      FakeScanRemoteDataSource();

  /// Aliases the demo [ScanRemoteDataSource] to the fake.
  @Environment('demo')
  @lazySingleton
  ScanRemoteDataSource demoScanRemoteDataSource(
    FakeScanRemoteDataSource dataSource,
  ) => dataSource;
}
