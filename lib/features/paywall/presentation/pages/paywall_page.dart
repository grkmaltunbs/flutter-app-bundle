import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:okey_acar_mi/core/extensions/context_extensions.dart';
import 'package:okey_acar_mi/core/payments/domain/entities/subscription_offering.dart';
import 'package:okey_acar_mi/core/payments/domain/entities/subscription_package.dart';
import 'package:okey_acar_mi/core/payments/purchase_failure.dart';
import 'package:okey_acar_mi/core/payments/subscription_bloc.dart';
import 'package:okey_acar_mi/core/theme/app_typography.dart';
import 'package:okey_acar_mi/core/widgets/circle_icon_button.dart';
import 'package:okey_acar_mi/core/widgets/eyebrow.dart';
import 'package:okey_acar_mi/features/paywall/presentation/widgets/paywall_cta.dart';
import 'package:okey_acar_mi/features/paywall/presentation/widgets/paywall_error_view.dart';
import 'package:okey_acar_mi/features/paywall/presentation/widgets/paywall_plan_card.dart';
import 'package:okey_acar_mi/l10n/app_localizations.dart';

/// The remove-ads paywall.
///
/// Consumes the app-scoped [SubscriptionBloc] (no page-local bloc): requests
/// the offering on first build, lets the user pick a plan, and drives the
/// purchase/restore flows. Success pops back to the caller; failures surface as
/// SnackBars and keep the paywall open.
class PaywallPage extends StatefulWidget {
  /// Creates a [PaywallPage].
  const PaywallPage({super.key});

  @override
  State<PaywallPage> createState() => _PaywallPageState();
}

class _PaywallPageState extends State<PaywallPage> {
  SubscriptionPeriod? _selected;

  @override
  void initState() {
    super.initState();
    final bloc = context.read<SubscriptionBloc>();
    if (bloc.state.offering == null) {
      bloc.add(const SubscriptionEvent.offeringsRequested());
    }
  }

  /// Resolves the chosen plan, defaulting to annual (then monthly) when the
  /// user has not explicitly tapped a card yet.
  SubscriptionPackage? _selectedPackage(SubscriptionOffering offering) {
    final chosen = switch (_selected) {
      SubscriptionPeriod.monthly => offering.monthly,
      SubscriptionPeriod.annual => offering.annual,
      null => null,
    };
    return chosen ?? offering.annual ?? offering.monthly;
  }

  void _select(SubscriptionPeriod period) => setState(() => _selected = period);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: BlocConsumer<SubscriptionBloc, SubscriptionState>(
          listenWhen: (a, b) => a.flow != b.flow,
          listener: _onFlowChanged,
          buildWhen: (a, b) => a.flow != b.flow || a.offering != b.offering,
          builder: _buildBody,
        ),
      ),
    );
  }

  void _onFlowChanged(BuildContext context, SubscriptionState state) {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    void snack(String text) => messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));

    switch (state.flow) {
      case SubscriptionFlowPurchaseSucceeded():
        snack(l10n.paywallSuccess);
        context.pop();
      case SubscriptionFlowRestoreSucceeded():
        snack(l10n.restoreSuccess);
        context.pop();
      case SubscriptionFlowError(:final failure):
        snack(_errorText(l10n, failure));
      // idle / loading / purchasing / restoring / offline → no SnackBar
      // (offline is rendered as a full-screen retry view by the builder).
      case SubscriptionFlowIdle():
      case SubscriptionFlowOfferingsLoading():
      case SubscriptionFlowPurchasing():
      case SubscriptionFlowRestoring():
      case SubscriptionFlowOffline():
        break;
    }
  }

  String _errorText(AppLocalizations l10n, PurchaseFailure failure) =>
      switch (failure) {
        PurchasePending() => l10n.paywallErrorPending,
        PurchasePaymentFailed() => l10n.paywallErrorPayment,
        PurchaseRestoreNothing() => l10n.restoreNothingToRestore,
        // cancelled never reaches the error flow; treat any other as generic.
        PurchaseCancelled() ||
        PurchaseNetwork() ||
        PurchaseUnknown() => l10n.paywallErrorGeneric,
      };

  Widget _buildBody(BuildContext context, SubscriptionState state) {
    final offering = state.offering;
    final flow = state.flow;

    final Widget content;
    if (flow is SubscriptionFlowOffline) {
      content = PaywallErrorView(
        title: context.l10n.paywallOfflineTitle,
        body: context.l10n.paywallOfflineBody,
        retryLabel: context.l10n.paywallRetry,
        onRetry: () => context.read<SubscriptionBloc>().add(
          const SubscriptionEvent.offeringsRequested(),
        ),
      );
    } else if (offering == null) {
      content = const Center(child: CircularProgressIndicator());
    } else {
      final busy =
          flow is SubscriptionFlowPurchasing ||
          flow is SubscriptionFlowRestoring;
      content = _PaywallContent(
        offering: offering,
        selectedPackage: _selectedPackage(offering),
        busy: busy,
        onSelect: _select,
      );
    }

    return Column(
      children: [
        _TopBar(onClose: () => context.pop()),
        Expanded(child: content),
      ],
    );
  }
}

/// The close-button top bar.
class _TopBar extends StatelessWidget {
  const _TopBar({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Align(
        alignment: Alignment.centerRight,
        child: CircleIconButton(
          key: const ValueKey('paywall-close'),
          icon: Icons.close,
          semanticLabel: context.l10n.paywallCloseSemantics,
          onPressed: onClose,
        ),
      ),
    );
  }
}

/// The loaded paywall body: editorial header, the scrollable plan cards, and a
/// pinned CTA cluster.
class _PaywallContent extends StatelessWidget {
  const _PaywallContent({
    required this.offering,
    required this.selectedPackage,
    required this.busy,
    required this.onSelect,
  });

  final SubscriptionOffering offering;
  final SubscriptionPackage? selectedPackage;
  final bool busy;
  final ValueChanged<SubscriptionPeriod> onSelect;

  /// Whether [period] is the effectively selected one (explicit tap, or the
  /// default that [selectedPackage] resolved to).
  bool _isSelected(SubscriptionPeriod period) =>
      selectedPackage?.period == period;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Eyebrow(l10n.paywallEyebrow),
                const SizedBox(height: 8),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    l10n.paywallHeadline,
                    style: AppTypography.serifStyle(
                      fontSize: 40,
                      color: context.palette.ink,
                      letterSpacing: -0.8,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  l10n.paywallSubtitle,
                  style: context.textTheme.bodyMedium?.copyWith(
                    color: context.palette.muted,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),
                if (offering.monthly != null) ...[
                  PaywallPlanCard(
                    key: const ValueKey('paywall-plan-monthly'),
                    periodLabel: l10n.paywallPlanMonthly,
                    priceString: offering.monthly!.priceString,
                    selected: _isSelected(SubscriptionPeriod.monthly),
                    trialBadge: offering.monthly!.hasTrial
                        ? l10n.paywallTrialBadge
                        : null,
                    onTap: () => onSelect(SubscriptionPeriod.monthly),
                  ),
                  const SizedBox(height: 12),
                ],
                if (offering.annual != null)
                  PaywallPlanCard(
                    key: const ValueKey('paywall-plan-annual'),
                    periodLabel: l10n.paywallPlanAnnual,
                    priceString: offering.annual!.priceString,
                    selected: _isSelected(SubscriptionPeriod.annual),
                    bestValueLabel: l10n.paywallBestValue,
                    trialBadge: offering.annual!.hasTrial
                        ? l10n.paywallTrialBadge
                        : null,
                    onTap: () => onSelect(SubscriptionPeriod.annual),
                  ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
          child: PaywallCta(
            selectedPackage: selectedPackage,
            busy: busy,
            onSubscribe: () {
              final pkg = selectedPackage;
              if (pkg == null) return;
              context.read<SubscriptionBloc>().add(
                SubscriptionEvent.purchaseRequested(pkg),
              );
            },
            onRestore: () => context.read<SubscriptionBloc>().add(
              const SubscriptionEvent.restoreRequested(),
            ),
          ),
        ),
      ],
    );
  }
}
