import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:okey_acar_mi/core/extensions/context_extensions.dart';
import 'package:okey_acar_mi/core/router/app_router.dart';
import 'package:okey_acar_mi/features/auth/presentation/blocs/auth_bloc.dart';

/// The "session expired" banner shown across all tabs when a persisted
/// session failed to restore at startup (D6/D7).
///
/// "Sign in" pushes the login screen; the X dismisses the banner via
/// [AuthEvent.sessionExpiredDismissed].
class SessionExpiredBanner extends StatelessWidget {
  /// Creates a [SessionExpiredBanner].
  const SessionExpiredBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final palette = context.palette;

    // The banner owns the top inset: the SafeArea sits INSIDE the Material so
    // the warn tint fills the status-bar region instead of leaving a gap.
    return Material(
      key: const ValueKey('session-expired-banner'),
      color: palette.warn.withValues(alpha: 0.14),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 4, 4, 4),
          child: Row(
            children: [
              Icon(Icons.info_outline, size: 18, color: palette.warn),
              const SizedBox(width: 10),
              // Wrap (not a fixed row): at large text scales on narrow
              // screens the actions flow to their own run instead of
              // overflowing horizontally.
              Expanded(
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      l10n.sessionExpiredBanner,
                      style: context.textTheme.bodySmall?.copyWith(
                        color: palette.ink,
                      ),
                    ),
                    TextButton(
                      onPressed: () => context.push(AppRoutes.login),
                      child: Text(l10n.sessionExpiredSignIn),
                    ),
                    IconButton(
                      tooltip: l10n.sessionExpiredDismiss,
                      onPressed: () => context.read<AuthBloc>().add(
                        const AuthEvent.sessionExpiredDismissed(),
                      ),
                      icon: Icon(Icons.close, size: 18, color: palette.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
