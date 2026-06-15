import 'package:flutter/material.dart';
import 'package:okey_acar_mi/core/extensions/context_extensions.dart';
import 'package:okey_acar_mi/core/payments/domain/entities/subscription_package.dart';
import 'package:okey_acar_mi/core/theme/app_radii.dart';
import 'package:okey_acar_mi/core/theme/app_typography.dart';

/// A selectable subscription plan card (one per offering plan).
///
/// Shows the period label, the store-formatted price (rendered as-is from
/// [SubscriptionPackage.priceString]), an optional trial badge, and an optional
/// "best value" pill. Selection is owned by the paywall page; tapping calls
/// [onTap]. Overflow-safe at textScale 2.0 (price is a [FittedBox], labels
/// flex/wrap).
class PaywallPlanCard extends StatelessWidget {
  /// Creates a [PaywallPlanCard].
  const PaywallPlanCard({
    required this.periodLabel,
    required this.priceString,
    required this.selected,
    required this.onTap,
    this.trialBadge,
    this.bestValueLabel,
    super.key,
  });

  /// The plan cadence label (e.g. "Aylık" / "Yıllık").
  final String periodLabel;

  /// The localized, store-formatted price, rendered verbatim.
  final String priceString;

  /// Whether this card is the active selection (drives the accent ring).
  final bool selected;

  /// Tap handler — selects this plan.
  final VoidCallback onTap;

  /// Trial badge text, shown only when the plan offers a trial.
  final String? trialBadge;

  /// "Best value" pill text, shown only when set (annual plan).
  final String? bestValueLabel;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final ringColor = selected ? palette.accent : palette.line;
    return Semantics(
      button: true,
      selected: selected,
      label: periodLabel,
      child: Material(
        color: selected ? palette.accentSoft : palette.surface,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadii.lg),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadii.lg),
              border: Border.all(
                color: ringColor,
                width: selected ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                _RadioDot(selected: selected),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            periodLabel,
                            style: context.textTheme.titleSmall?.copyWith(
                              color: palette.ink,
                            ),
                          ),
                          if (bestValueLabel != null)
                            _Pill(
                              label: bestValueLabel!,
                              background: palette.accent,
                              foreground: palette.accentInk,
                            ),
                        ],
                      ),
                      if (trialBadge != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          trialBadge!,
                          style: context.textTheme.bodySmall?.copyWith(
                            color: palette.accent,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      priceString,
                      style: AppTypography.monoStyle(
                        fontSize: 18,
                        color: palette.ink,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The leading selection indicator dot.
class _RadioDot extends StatelessWidget {
  const _RadioDot({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? palette.accent : palette.line,
          width: 2,
        ),
      ),
      child: selected
          ? Center(
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: palette.accent,
                  shape: BoxShape.circle,
                ),
              ),
            )
          : null,
    );
  }
}

/// A small rounded label pill.
class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.background,
    required this.foreground,
  });

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadii.sm),
      ),
      child: Text(
        label.toUpperCase(),
        style: AppTypography.monoStyle(
          fontSize: 10,
          color: foreground,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}
