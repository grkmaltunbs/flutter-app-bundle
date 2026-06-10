import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:okey_acar_mi/core/extensions/context_extensions.dart';
import 'package:okey_acar_mi/core/router/app_router.dart';
import 'package:okey_acar_mi/core/widgets/app_buttons.dart';
import 'package:okey_acar_mi/core/widgets/app_pill.dart';
import 'package:okey_acar_mi/features/auth/domain/entities/app_user.dart';
import 'package:okey_acar_mi/features/auth/presentation/blocs/auth_bloc.dart';
import 'package:okey_acar_mi/features/auth/presentation/widgets/delete_account_sheet.dart';

/// The ACCOUNT section of Settings: a sign-up CTA for guests; the account
/// email, verification status, sign-out, and account-deletion entry for
/// signed-in users.
class AccountSection extends StatelessWidget {
  /// Creates an [AccountSection].
  const AccountSection({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) => switch (state) {
        AuthAuthenticated(:final user) => _SignedInView(user: user),
        AuthUnknown() || AuthGuest() => const _GuestView(),
      },
    );
  }
}

class _GuestView extends StatelessWidget {
  const _GuestView();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final palette = context.palette;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.settingsAccountGuestLabel,
          style: context.textTheme.bodyMedium?.copyWith(color: palette.muted),
        ),
        const SizedBox(height: 12),
        SecondaryButton(
          key: const ValueKey('settings-signup'),
          label: l10n.settingsAccountSignUpCta,
          fullWidth: true,
          onPressed: () => context.push(AppRoutes.login),
        ),
      ],
    );
  }
}

class _SignedInView extends StatefulWidget {
  const _SignedInView({required this.user});

  final AppUser user;

  @override
  State<_SignedInView> createState() => _SignedInViewState();
}

class _SignedInViewState extends State<_SignedInView> {
  bool _verificationSent = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final palette = context.palette;
    final user = widget.user;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (user.displayName != null) ...[
          Text(user.displayName!, style: context.textTheme.titleSmall),
          const SizedBox(height: 2),
        ],
        Text(
          user.email,
          style: context.textTheme.bodyMedium?.copyWith(color: palette.muted),
        ),
        if (!user.emailVerified) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              AppPill(
                label: l10n.settingsAccountUnverifiedPill,
                variant: PillVariant.bad,
              ),
              TextButton(
                key: const ValueKey('settings-resend-verification'),
                onPressed: _verificationSent
                    ? null
                    : () {
                        context.read<AuthBloc>().add(
                          const AuthEvent.verificationEmailResendRequested(),
                        );
                        setState(() => _verificationSent = true);
                      },
                child: Text(
                  _verificationSent
                      ? l10n.settingsAccountVerificationSent
                      : l10n.settingsAccountResendVerification,
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 12),
        SecondaryButton(
          key: const ValueKey('settings-signout'),
          label: l10n.settingsSignOut,
          fullWidth: true,
          onPressed: () =>
              context.read<AuthBloc>().add(const AuthEvent.signOutRequested()),
        ),
        const SizedBox(height: 4),
        GhostButton(
          key: const ValueKey('settings-delete-account'),
          label: l10n.settingsDeleteAccount,
          fullWidth: true,
          foregroundColor: palette.bad,
          onPressed: () => showDeleteAccountSheet(context),
        ),
      ],
    );
  }
}
