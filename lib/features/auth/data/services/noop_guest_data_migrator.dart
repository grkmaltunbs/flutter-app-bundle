import 'package:injectable/injectable.dart';
import 'package:okey_acar_mi/features/auth/domain/services/guest_data_migrator.dart';

/// No-op [GuestDataMigrator], registered in BOTH environments (no
/// `@Environment` annotation) until guest history exists.
@LazySingleton(as: GuestDataMigrator)
class NoopGuestDataMigrator implements GuestDataMigrator {
  /// Creates a [NoopGuestDataMigrator].
  const NoopGuestDataMigrator();

  // TODO(step-9): Replace with a real migrator that moves guest-owned drift
  // rows / Firestore docs onto the new account (multi-doc writes in a
  // WriteBatch).
  @override
  Future<void> migrateGuestData({required String toUserId}) async {
    // Nothing to migrate before Step 9 (history persistence).
  }
}
