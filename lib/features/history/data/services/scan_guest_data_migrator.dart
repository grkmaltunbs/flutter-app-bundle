import 'package:injectable/injectable.dart';
import 'package:okey_acar_mi/core/logging/app_logger.dart';
import 'package:okey_acar_mi/features/auth/domain/services/guest_data_migrator.dart';
import 'package:okey_acar_mi/features/history/domain/repositories/scan_repository.dart';

/// Real [GuestDataMigrator]: re-owns guest scan history to the freshly
/// signed-in account (registered in BOTH environments — the environment
/// split lives inside [ScanRepository]'s data sources).
///
/// Failures are logged and swallowed: a migration error must never fail the
/// sign-in itself.
@LazySingleton(as: GuestDataMigrator)
class ScanGuestDataMigrator implements GuestDataMigrator {
  /// Creates a [ScanGuestDataMigrator].
  const ScanGuestDataMigrator(this._scans, this._logger);

  final ScanRepository _scans;
  final AppLogger _logger;

  @override
  Future<void> migrateGuestData({required String toUserId}) async {
    try {
      await _scans.adoptGuestScans(toUserId: toUserId);
    } on Object catch (error, stackTrace) {
      _logger.error('Guest scan migration failed', error, stackTrace);
    }
  }
}
