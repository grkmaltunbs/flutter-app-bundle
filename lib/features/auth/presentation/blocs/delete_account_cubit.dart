import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';
import 'package:okey_acar_mi/core/error/error_mapper.dart';
import 'package:okey_acar_mi/core/error/failure.dart';
import 'package:okey_acar_mi/features/auth/domain/repositories/auth_repository.dart';

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
  DeleteAccountCubit(this._repository)
    : super(const DeleteAccountState.confirm());

  final AuthRepository _repository;

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
