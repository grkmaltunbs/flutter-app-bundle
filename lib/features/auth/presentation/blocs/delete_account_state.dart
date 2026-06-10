part of 'delete_account_cubit.dart';

/// Sealed step state for [DeleteAccountCubit].
@freezed
sealed class DeleteAccountState with _$DeleteAccountState {
  /// Step 1: the irreversible-action warning.
  const factory DeleteAccountState.confirm() = DeleteAccountConfirm;

  /// Step 2: re-authentication. [wrongPassword] flags the password field;
  /// [failure] renders the inline error banner.
  const factory DeleteAccountState.reauth({
    @Default(false) bool inFlight,
    @Default(false) bool wrongPassword,
    Failure? failure,
  }) = DeleteAccountReauth;

  /// Step 3: deletion in progress.
  const factory DeleteAccountState.deleting() = DeleteAccountDeleting;

  /// Step 4: the account is gone.
  const factory DeleteAccountState.done() = DeleteAccountDone;
}
