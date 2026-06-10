/// Migrates locally-stored guest data onto a freshly signed-in account.
///
/// Invoked by the sign-in/up use cases after a successful authentication so
/// guest scan history follows the user onto their account. The real migration
/// lands with history persistence (Step 9); until then a no-op implementation
/// is registered in both environments.
abstract class GuestDataMigrator {
  /// Moves all guest-owned data to the account identified by [toUserId].
  Future<void> migrateGuestData({required String toUserId});
}
