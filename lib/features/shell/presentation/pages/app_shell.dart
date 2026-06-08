import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:okey_acar_mi/core/extensions/context_extensions.dart';
import 'package:okey_acar_mi/features/shell/presentation/widgets/app_bottom_nav.dart';

/// The persistent shell hosting the three primary tabs (Home / History /
/// Settings) with a bottom navigation bar.
///
/// Driven by go_router's [StatefulNavigationShell]: each tab keeps its own
/// navigation stack and state (IndexedStack), and tapping the active tab again
/// pops it back to its root.
class AppShell extends StatelessWidget {
  /// Creates an [AppShell] around [navigationShell].
  const AppShell({required this.navigationShell, super.key});

  /// The go_router shell controlling the active branch.
  final StatefulNavigationShell navigationShell;

  void _onTap(int index) {
    navigationShell.goBranch(
      index,
      // Re-tapping the current tab returns it to its initial route.
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: AppBottomNav(
        currentIndex: navigationShell.currentIndex,
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
