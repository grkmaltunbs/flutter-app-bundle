import 'package:flutter/material.dart';
import 'package:okey_acar_mi/core/extensions/context_extensions.dart';

/// The global offline strip shown above the tab content while the device has
/// no network: local data keeps the app working, this just says so.
///
/// Mirrors `SessionExpiredBanner`'s structure: when [applyTopInset] is true
/// the banner is the topmost element, so the SafeArea sits INSIDE the
/// Material and the warn tint fills the status-bar region. When another
/// banner above it already owns the inset, pass false so the gap never
/// doubles.
class OfflineBanner extends StatelessWidget {
  /// Creates an [OfflineBanner]; [applyTopInset] iff it renders topmost.
  const OfflineBanner({required this.applyTopInset, super.key});

  /// Whether this banner owns the status-bar inset.
  final bool applyTopInset;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final content = Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 8),
      child: Row(
        children: [
          Icon(Icons.wifi_off_outlined, size: 18, color: palette.warn),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              context.l10n.offlineBanner,
              style: context.textTheme.bodySmall?.copyWith(color: palette.ink2),
            ),
          ),
        ],
      ),
    );
    return Material(
      key: const ValueKey('offline-banner'),
      color: palette.warn.withValues(alpha: 0.14),
      child: applyTopInset ? SafeArea(bottom: false, child: content) : content,
    );
  }
}
