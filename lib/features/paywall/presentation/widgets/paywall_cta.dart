import 'dart:async';

import 'package:flutter/material.dart';
import 'package:okey_acar_mi/core/constants/legal_links.dart';
import 'package:okey_acar_mi/core/extensions/context_extensions.dart';
import 'package:okey_acar_mi/core/payments/domain/entities/subscription_package.dart';
import 'package:okey_acar_mi/core/widgets/app_buttons.dart';
import 'package:url_launcher/url_launcher.dart';

/// The pinned bottom CTA cluster: subscribe (trial-aware label), restore, and
/// the terms link. Disabled / spinning while a purchase or restore is in
/// flight.
class PaywallCta extends StatelessWidget {
  /// Creates a [PaywallCta].
  const PaywallCta({
    required this.selectedPackage,
    required this.busy,
    required this.onSubscribe,
    required this.onRestore,
    super.key,
  });

  /// The currently selected plan (null disables subscribe).
  final SubscriptionPackage? selectedPackage;

  /// Whether a purchase/restore is in flight (spinner + disabled).
  final bool busy;

  /// Subscribe handler — dispatches the purchase for [selectedPackage].
  final VoidCallback onSubscribe;

  /// Restore handler — dispatches a restore.
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final palette = context.palette;
    final hasTrial = selectedPackage?.hasTrial ?? false;
    final canSubscribe = selectedPackage != null && !busy;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        PrimaryButton(
          key: const ValueKey('paywall-subscribe'),
          label: hasTrial
              ? l10n.paywallSubscribeCta
              : l10n.paywallSubscribeCtaNoTrial,
          icon: Icons.lock_open_outlined,
          fullWidth: true,
          loading: busy,
          onPressed: canSubscribe ? onSubscribe : null,
        ),
        const SizedBox(height: 8),
        TextButton(
          key: const ValueKey('paywall-restore'),
          onPressed: busy ? null : onRestore,
          child: Text(
            l10n.paywallRestore,
            style: context.textTheme.bodyMedium?.copyWith(color: palette.muted),
          ),
        ),
        TextButton(
          onPressed: () =>
              unawaited(_openTerms(context, LegalLinks.termsOfUse)),
          child: Text(
            l10n.paywallTerms,
            textAlign: TextAlign.center,
            style: context.textTheme.bodySmall?.copyWith(color: palette.faint),
          ),
        ),
      ],
    );
  }

  /// Opens [url] in the external browser, mirroring settings' link handler.
  Future<void> _openTerms(BuildContext context, String url) async {
    final messenger = ScaffoldMessenger.of(context);
    final errorText = context.l10n.settingsLinkError;
    var opened = false;
    try {
      opened = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
    } on Exception {
      opened = false;
    }
    if (!opened) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(errorText)));
    }
  }
}
