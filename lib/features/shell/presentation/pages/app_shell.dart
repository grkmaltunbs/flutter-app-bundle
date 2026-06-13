import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:okey_acar_mi/core/di/injection.dart';
import 'package:okey_acar_mi/core/extensions/context_extensions.dart';
import 'package:okey_acar_mi/core/network/connectivity_cubit.dart';
import 'package:okey_acar_mi/core/widgets/offline_banner.dart';
import 'package:okey_acar_mi/features/auth/presentation/blocs/auth_bloc.dart';
import 'package:okey_acar_mi/features/auth/presentation/widgets/session_expired_banner.dart';
import 'package:okey_acar_mi/features/shell/presentation/widgets/app_bottom_nav.dart';

/// The persistent shell hosting the three primary tabs (Home / History /
/// Settings) with a bottom navigation bar.
///
/// Driven by go_router's [StatefulNavigationShell]: each tab keeps its own
/// navigation stack and state (IndexedStack), and tapping the active tab again
/// pops it back to its root. Two global banners stack above the active tab:
/// the [SessionExpiredBanner] (persisted session failed to restore) and the
/// [OfflineBanner] (driven by the shell-scoped [ConnectivityCubit], refreshed
/// on app resume).
class AppShell extends StatelessWidget {
  /// Creates an [AppShell] around [navigationShell].
  const AppShell({required this.navigationShell, super.key});

  /// The go_router shell controlling the active branch.
  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<ConnectivityCubit>(
      create: (_) => getIt<ConnectivityCubit>(),
      child: _ShellView(navigationShell: navigationShell),
    );
  }
}

/// The shell body (assumes a [ConnectivityCubit] is provided above it).
///
/// Stateful only for the [AppLifecycleListener] that re-probes connectivity
/// when the app regains the foreground (a transport change while backgrounded
/// may never reach the change stream).
class _ShellView extends StatefulWidget {
  const _ShellView({required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  State<_ShellView> createState() => _ShellViewState();
}

class _ShellViewState extends State<_ShellView> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    final connectivity = context.read<ConnectivityCubit>();
    _lifecycle = AppLifecycleListener(
      onResume: () => unawaited(connectivity.refresh()),
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  void _onTap(int index) {
    widget.navigationShell.goBranch(
      index,
      // Re-tapping the current tab returns it to its initial route.
      initialLocation: index == widget.navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      body: BlocSelector<AuthBloc, AuthState, bool>(
        selector: (state) => switch (state) {
          AuthGuest(:final sessionExpired) => sessionExpired,
          _ => false,
        },
        builder: (context, expired) => BlocBuilder<ConnectivityCubit, bool>(
          builder: (context, online) {
            // Exactly one element owns the top inset: the topmost banner (via
            // its inner SafeArea) or, with no banner, the tab content itself.
            // The content below a banner must NOT re-apply the inset, or the
            // status-bar gap doubles.
            final banners = expired || !online;
            return Column(
              children: [
                if (expired) const SessionExpiredBanner(),
                if (!online) OfflineBanner(applyTopInset: !expired),
                Expanded(
                  child: banners
                      ? MediaQuery.removePadding(
                          context: context,
                          removeTop: true,
                          child: widget.navigationShell,
                        )
                      : widget.navigationShell,
                ),
              ],
            );
          },
        ),
      ),
      bottomNavigationBar: AppBottomNav(
        currentIndex: widget.navigationShell.currentIndex,
        onTap: _onTap,
        destinations: [
          AppNavDestination(
            icon: Icons.home_outlined,
            activeIcon: Icons.home,
            label: l10n.navHome,
          ),
          AppNavDestination(
            icon: Icons.history_outlined,
            activeIcon: Icons.history,
            label: l10n.navHistory,
          ),
          AppNavDestination(
            icon: Icons.settings_outlined,
            activeIcon: Icons.settings,
            label: l10n.navSettings,
          ),
        ],
      ),
    );
  }
}
