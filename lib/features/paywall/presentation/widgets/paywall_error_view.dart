import 'package:flutter/material.dart';
import 'package:okey_acar_mi/core/extensions/context_extensions.dart';
import 'package:okey_acar_mi/core/widgets/app_buttons.dart';

/// The paywall's offline / load-error state: an icon, a title + body, and a
/// retry that re-requests the offering.
class PaywallErrorView extends StatelessWidget {
  /// Creates a [PaywallErrorView].
  const PaywallErrorView({
    required this.title,
    required this.body,
    required this.retryLabel,
    required this.onRetry,
    super.key,
  });

  /// The headline (e.g. the offline title).
  final String title;

  /// The supporting copy.
  final String body;

  /// The retry button label.
  final String retryLabel;

  /// Retry handler — re-dispatches the offering request.
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wifi_off_outlined, size: 44, color: palette.faint),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: context.textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              body,
              textAlign: TextAlign.center,
              style: context.textTheme.bodyMedium?.copyWith(
                color: palette.muted,
              ),
            ),
            const SizedBox(height: 24),
            PrimaryButton(
              key: const ValueKey('paywall-retry'),
              label: retryLabel,
              icon: Icons.refresh,
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}
