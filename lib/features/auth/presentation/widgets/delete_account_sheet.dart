import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:okey_acar_mi/core/di/injection.dart';
import 'package:okey_acar_mi/core/error/failure.dart';
import 'package:okey_acar_mi/core/extensions/context_extensions.dart';
import 'package:okey_acar_mi/core/theme/app_radii.dart';
import 'package:okey_acar_mi/core/theme/app_typography.dart';
import 'package:okey_acar_mi/core/widgets/app_buttons.dart';
import 'package:okey_acar_mi/core/widgets/app_text_field.dart';
import 'package:okey_acar_mi/features/auth/domain/entities/app_user.dart';
import 'package:okey_acar_mi/features/auth/domain/repositories/auth_repository.dart';
import 'package:okey_acar_mi/features/auth/presentation/blocs/auth_bloc.dart';
import 'package:okey_acar_mi/features/auth/presentation/blocs/delete_account_cubit.dart';
import 'package:okey_acar_mi/features/auth/presentation/widgets/auth_failure_l10n.dart';

/// Opens the destructive account-deletion bottom sheet
/// (confirm → re-auth → deleting → done).
Future<void> showDeleteAccountSheet(BuildContext context) {
  // Re-provide the app-scoped AuthBloc: the sheet lives on the root
  // navigator, potentially above the caller's provider scope.
  final authBloc = context.read<AuthBloc>();
  return showModalBottomSheet<void>(
    context: context,
    // Root navigator: the barrier must cover the bottom nav so the tabs are
    // not tappable mid-deletion.
    useRootNavigator: true,
    // Destructive flow: no swipe/tap-outside dismissal — every step exposes
    // an explicit cancel (or done) action instead.
    isDismissible: false,
    enableDrag: false,
    isScrollControlled: true,
    builder: (_) => MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>.value(value: authBloc),
        BlocProvider<DeleteAccountCubit>(
          create: (_) => getIt<DeleteAccountCubit>(),
        ),
      ],
      child: const DeleteAccountSheet(),
    ),
  );
}

/// The account-deletion sheet body (assumes [AuthBloc] and
/// [DeleteAccountCubit] above it).
class DeleteAccountSheet extends StatefulWidget {
  /// Creates a [DeleteAccountSheet].
  const DeleteAccountSheet({super.key});

  @override
  State<DeleteAccountSheet> createState() => _DeleteAccountSheetState();
}

class _DeleteAccountSheetState extends State<DeleteAccountSheet> {
  final TextEditingController _passwordController = TextEditingController();

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return SafeArea(
      child: SingleChildScrollView(
        key: const ValueKey('delete-sheet'),
        padding: EdgeInsets.fromLTRB(28, 24, 28, 24 + bottomInset),
        child: BlocBuilder<DeleteAccountCubit, DeleteAccountState>(
          builder: (context, state) => switch (state) {
            DeleteAccountConfirm() => const _ConfirmBody(),
            DeleteAccountReauth(
              :final inFlight,
              :final wrongPassword,
              :final failure,
            ) =>
              _ReauthBody(
                passwordController: _passwordController,
                inFlight: inFlight,
                wrongPassword: wrongPassword,
                failure: failure,
              ),
            DeleteAccountDeleting() => const _DeletingBody(),
            DeleteAccountDone() => const _DoneBody(),
          },
        ),
      ),
    );
  }
}

class _ConfirmBody extends StatelessWidget {
  const _ConfirmBody();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final palette = context.palette;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.deleteTitle,
          style: AppTypography.serifStyle(fontSize: 32, color: palette.ink),
        ),
        const SizedBox(height: 8),
        Text(
          l10n.deleteWarning,
          style: context.textTheme.bodyMedium?.copyWith(color: palette.muted),
        ),
        const SizedBox(height: 20),
        DangerButton(
          key: const ValueKey('delete-confirm'),
          label: l10n.deleteConfirmCta,
          fullWidth: true,
          onPressed: () =>
              context.read<DeleteAccountCubit>().confirmRequested(),
        ),
        const SizedBox(height: 8),
        GhostButton(
          key: const ValueKey('delete-cancel'),
          label: l10n.deleteCancel,
          fullWidth: true,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}

class _ReauthBody extends StatelessWidget {
  const _ReauthBody({
    required this.passwordController,
    required this.inFlight,
    required this.wrongPassword,
    required this.failure,
  });

  final TextEditingController passwordController;
  final bool inFlight;
  final bool wrongPassword;
  final Failure? failure;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final palette = context.palette;
    final cubit = context.read<DeleteAccountCubit>();
    final user = context.select<AuthBloc, AppUser?>(
      (bloc) => switch (bloc.state) {
        AuthAuthenticated(:final user) => user,
        _ => null,
      },
    );
    final providers = user?.providers ?? const <AuthProvider>[];
    final hasPassword = providers.contains(AuthProvider.password);
    final providerMethod = providers.contains(AuthProvider.apple)
        ? ReauthMethod.apple
        : ReauthMethod.google;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.deleteReauthTitle,
          style: AppTypography.serifStyle(fontSize: 32, color: palette.ink),
        ),
        const SizedBox(height: 20),
        if (failure != null) ...[
          Semantics(
            liveRegion: true,
            child: Container(
              key: const ValueKey('delete-error-banner'),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: palette.bad.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadii.md),
              ),
              child: Text(
                failureText(l10n, failure!),
                style: context.textTheme.bodySmall?.copyWith(
                  color: palette.ink,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (hasPassword) ...[
          AppTextField(
            key: const ValueKey('delete-password'),
            controller: passwordController,
            hintText: l10n.deleteReauthPasswordHint,
            errorText: wrongPassword ? l10n.authErrorInvalidCredentials : null,
            obscurable: true,
            autofillHints: const [AutofillHints.password],
          ),
          const SizedBox(height: 16),
          DangerButton(
            key: const ValueKey('delete-reauth-submit'),
            label: l10n.deleteReauthSubmit,
            fullWidth: true,
            loading: inFlight,
            onPressed: inFlight
                ? null
                : () => cubit.reauthWithPassword(passwordController.text),
          ),
        ] else
          SecondaryButton(
            key: const ValueKey('delete-reauth-provider'),
            label: providerMethod == ReauthMethod.apple
                ? l10n.deleteReauthApple
                : l10n.deleteReauthGoogle,
            fullWidth: true,
            loading: inFlight,
            onPressed: inFlight
                ? null
                : () => cubit.reauthWithProvider(providerMethod),
          ),
        const SizedBox(height: 8),
        // The sheet is non-dismissible, so the re-auth step needs an explicit
        // escape.
        GhostButton(
          key: const ValueKey('delete-reauth-cancel'),
          label: l10n.deleteCancel,
          fullWidth: true,
          // Stays enabled in flight: closing mid-re-auth is safe (the cubit
          // guards every post-await emit against isClosed).
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}

class _DeletingBody extends StatelessWidget {
  const _DeletingBody();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final palette = context.palette;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 8),
        const Center(
          child: SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          l10n.deleteInProgress,
          textAlign: TextAlign.center,
          style: context.textTheme.bodyMedium?.copyWith(color: palette.muted),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _DoneBody extends StatelessWidget {
  const _DoneBody();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final palette = context.palette;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.check_circle_outline, size: 36, color: palette.good),
        const SizedBox(height: 12),
        Text(
          l10n.deleteDoneTitle,
          style: AppTypography.serifStyle(fontSize: 32, color: palette.ink),
        ),
        const SizedBox(height: 8),
        Text(
          l10n.deleteDoneBody,
          style: context.textTheme.bodyMedium?.copyWith(color: palette.muted),
        ),
        const SizedBox(height: 20),
        PrimaryButton(
          key: const ValueKey('delete-done'),
          label: l10n.deleteDoneCta,
          fullWidth: true,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}
