/// Purges a user's stored data ahead of account deletion.
///
/// Invoked by the delete-account flow **after** a successful re-auth and
/// **before** `AuthRepository.deleteAccount()`, while the auth uid is still
/// valid (remote rules require an authenticated owner). A purge failure must
/// never block the deletion the user explicitly confirmed — implementations
/// log failures; the caller proceeds regardless.
abstract class UserDataPurger {
  /// Deletes all data owned by [ownerId], locally and remotely.
  Future<void> purgeUserData({required String ownerId});
}
