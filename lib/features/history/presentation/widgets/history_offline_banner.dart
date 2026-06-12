import 'package:flutter/material.dart';
import 'package:okey_acar_mi/core/extensions/context_extensions.dart';
import 'package:okey_acar_mi/core/theme/app_radii.dart';

/// Warn-tinted strip shown while offline: history keeps working from the
/// local store, this just says so.
class HistoryOfflineBanner extends StatelessWidget {
  /// Creates a [HistoryOfflineBanner].
  const HistoryOfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final warn = context.palette.warn;
    return Container(
      key: const ValueKey('history-offline-banner'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: warn.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: warn.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(Icons.wifi_off_outlined, size: 18, color: warn),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              context.l10n.historyOfflineBanner,
              style: context.textTheme.bodySmall?.copyWith(
                color: context.palette.ink2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
