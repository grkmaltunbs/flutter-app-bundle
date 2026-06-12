import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';
import 'package:okey_acar_mi/core/error/error_mapper.dart';
import 'package:okey_acar_mi/core/error/failure.dart';
import 'package:okey_acar_mi/features/auth/domain/repositories/auth_repository.dart';
import 'package:okey_acar_mi/features/auth/domain/services/user_data_purger.dart';

part 'delete_account_cubit.freezed.dart';
part 'delete_account_state.dart';

/// Sheet-scoped cubit driving the destructive account-deletion flow:
/// confirm → re-authenticate → delete → done.
///
/// A cancelled provider re-auth (false) silently returns to the re-auth step;
/// a wrong password flags the field; a stale session after re-auth surfaces
/// `Failure.requiresRecentLogin` inline. Holds no subscriptions, so [close]
/// is not overridden.
@injectable
class DeleteAccountCubit extends Cubit<DeleteAccountState> {
  /// Creates a [DeleteAccountCubit] in the confirm step.
  DeleteAccountCubit(this._repository, this._purger)
    : super(const DeleteAccountState.confirm());

  final AuthRepository _repository;
  final UserDataPurger _purger;

  /// The user confirmed the warning; move to re-authentication.
  void confirmRequested() => emit(const DeleteAccountState.reauth());

  /// Re-authenticates with the account password, then deletes.
  Future<void> reauthWithPassword(String password) =>
      _reauthAndDelete(ReauthMethod.password, password: password);

  /// Re-authenticates via [method]'s provider flow, then deletes.
  Future<void> reauthWithProvider(ReauthMethod method) =>
      _reauthAndDelete(method);

  Future<void> _reauthAndDelete(ReauthMethod method, {String? password}) async {
    emit(const DeleteAccountState.reauth(inFlight: true));
    // The sheet can be dismissed (closing this cubit) while an await is
    // pending, so every emit after an await is guarded against isClosed.
    try {
      final authenticated = await _repository.reauthenticate(
        method,
        password: password,
      );
      if (isClosed) return;
      if (!authenticated) {
        // Cancelled: silently back to the re-auth step.
        emit(const DeleteAccountState.reauth());
        return;
      }
      emit(const DeleteAccountState.deleting());
      // Purge owned data while the auth uid is still valid — remote rules
      // require an authenticated owner. A purge failure must never block
      // the deletion the user explicitly confirmed (the purger logs).
      final user = _repository.currentUser;
      if (user != null) {
        try {
          await _purger.purgeUserData(ownerId: user.id);
        } on Object {
          // Defense in depth: proceed with deletion regardless.
        }
        if (isClosed) return;
      }
      await _repository.deleteAccount();
      if (isClosed) return;
      emit(const DeleteAccountState.done());
    } on InvalidCredentialsFailure {
      if (isClosed) return;
      emit(const DeleteAccountState.reauth(wrongPassword: true));
    } on NetworkFailure {
      if (isClosed) return;
      emit(const DeleteAccountState.reauth(failure: Failure.network()));
    } on Failure catch (failure) {
      if (isClosed) return;
      emit(DeleteAccountState.reauth(failure: failure));
    } on Object catch (error) {
      if (isClosed) return;
      emit(DeleteAccountState.reauth(failure: mapToFailure(error)));
    }
  }
}
