import 'package:injectable/injectable.dart';
import 'package:okey_acar_mi/core/logging/app_logger.dart';
import 'package:okey_acar_mi/features/auth/domain/services/user_data_purger.dart';
import 'package:okey_acar_mi/features/history/domain/repositories/scan_repository.dart';

/// Real [UserDataPurger]: deletes the user's scan history (local + remote)
/// ahead of account deletion (registered in BOTH environments).
///
/// Failures are logged and swallowed per the [UserDataPurger] contract — a
/// purge error must never block the deletion the user explicitly confirmed.
@LazySingleton(as: UserDataPurger)
class ScanUserDataPurger implements UserDataPurger {
  /// Creates a [ScanUserDataPurger].
  const ScanUserDataPurger(this._scans, this._logger);

  final ScanRepository _scans;
  final AppLogger _logger;

  @override
  Future<void> purgeUserData({required String ownerId}) async {
    try {
      await _scans.deleteAllForOwner(ownerId);
    } on Object catch (error, stackTrace) {
      _logger.error('Scan purge before deletion failed', error, stackTrace);
    }
  }
}
