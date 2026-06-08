import 'package:flutter/material.dart';
import 'package:okey_acar_mi/core/extensions/context_extensions.dart';

/// One destination in the [AppBottomNav].
class AppNavDestination {
  /// Creates an [AppNavDestination].
  const AppNavDestination({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });

  /// Icon shown when the destination is inactive.
  final IconData icon;

  /// Icon shown when the destination is active.
  final IconData activeIcon;

  /// The localized label.
  final String label;
}

/// The app's three-tab bottom navigation bar (Home / History / Settings).
///
/// A custom bar rather than [NavigationBar] so it stays overflow-safe at
/// textScale 2.0: each item flexes (no fixed bar height) and its label is
/// single-line with ellipsis, so growing text only makes the bar taller.
class AppBottomNav extends StatelessWidget {
  /// Creates an [AppBottomNav].
  const AppBottomNav({
    required this.destinations,
    required this.currentIndex,
    required this.onTap,
    super.key,
  });

  /// The ordered destinations.
  final List<AppNavDestination> destinations;

  /// Index of the active destination.
  final int currentIndex;

  /// Called with the tapped destination index.
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border(top: BorderSide(color: palette.line)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            children: [
              for (var i = 0; i < destinations.length; i++)
                Expanded(
                  child: _NavItem(
                    key: ValueKey('app-nav-$i'),
                    destination: destinations[i],
                    selected: i == currentIndex,
                    onTap: () => onTap(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.destination,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final AppNavDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final color = selected ? palette.ink : palette.muted;
    return Semantics(
      button: true,
      selected: selected,
      label: destination.label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                selected ? destination.activeIcon : destination.icon,
                size: 24,
                color: color,
              ),
              const SizedBox(height: 3),
              Text(
                destination.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: context.textTheme.labelSmall?.copyWith(
                  color: color,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
