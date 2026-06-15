import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:okey_acar_mi/core/ads/ads_service.dart';
import 'package:okey_acar_mi/core/di/injection.dart';
import 'package:okey_acar_mi/core/extensions/context_extensions.dart';
import 'package:okey_acar_mi/core/network/connectivity_service.dart';
import 'package:okey_acar_mi/core/payments/subscription_bloc.dart';
import 'package:okey_acar_mi/core/router/app_router.dart';
import 'package:okey_acar_mi/core/theme/app_typography.dart';
import 'package:okey_acar_mi/core/widgets/app_buttons.dart';
import 'package:okey_acar_mi/core/widgets/app_card.dart';
import 'package:okey_acar_mi/core/widgets/eyebrow.dart';
import 'package:okey_acar_mi/features/result/presentation/blocs/result_bloc.dart';
import 'package:okey_acar_mi/features/result/presentation/reasoning_step_localizer.dart';
import 'package:okey_acar_mi/features/solver/domain/entities/reasoning_step.dart';
import 'package:okey_acar_mi/l10n/app_localizations.dart';

/// "NEDEN BÖYLE?": the step-by-step reasoning. Always shown for premium users;
/// otherwise a locked teaser until unlocked (via the rewarded-ad / premium
/// gate), then the numbered localized steps.
class ResultDetailSection extends StatelessWidget {
  /// Creates a [ResultDetailSection] for [steps].
  const ResultDetailSection({required this.steps, super.key});

  /// The solver's typed reasoning steps, in order.
  final List<ReasoningStep> steps;

  @override
  Widget build(BuildContext context) {
    return BlocSelector<SubscriptionBloc, SubscriptionState, bool>(
      selector: (state) => state.isPremium,
      builder: (context, isPremium) {
        if (isPremium) return _ReasoningList(steps: steps);
        return BlocSelector<ResultBloc, ResultState, bool>(
          selector: (state) => state.detailUnlocked,
          builder: (context, unlocked) =>
              unlocked ? _ReasoningList(steps: steps) : const _LockedCard(),
        );
      },
    );
  }
}

/// The locked teaser: lock icon, copy, and the unlock CTA that opens the
/// unlock options sheet.
class _LockedCard extends StatelessWidget {
  const _LockedCard();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final palette = context.palette;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.lock_outline, size: 20, color: palette.muted),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.resultDetailLockedTitle,
                      style: context.textTheme.titleSmall?.copyWith(
                        color: palette.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l10n.resultDetailLockedBody,
                      style: context.textTheme.bodySmall?.copyWith(
                        color: palette.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SecondaryButton(
            key: const ValueKey('result-detail-unlock'),
            label: l10n.resultDetailUnlockCta,
            icon: Icons.lock_open_outlined,
            fullWidth: true,
            onPressed: () => _openUnlockSheet(context),
          ),
        ],
      ),
    );
  }

  /// Probes connectivity, then shows the unlock options sheet. The
  /// [ResultBloc] and a [ScaffoldMessengerState] are captured before the await
  /// so the sheet's callbacks never touch a stale context.
  Future<void> _openUnlockSheet(BuildContext context) async {
    final resultBloc = context.read<ResultBloc>();
    final rootContext = context;
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    final online = await getIt<ConnectivityService>().isOnline();
    if (!rootContext.mounted) return;

    await showModalBottomSheet<void>(
      context: rootContext,
      builder: (sheetContext) => _DetailUnlockSheet(
        online: online,
        onWatchAd: () {
          Navigator.of(sheetContext).pop();
          _watchAd(resultBloc, messenger, l10n);
        },
        onGoPremium: () {
          Navigator.of(sheetContext).pop();
          unawaited(rootContext.push(AppRoutes.paywall));
        },
      ),
    );
  }

  /// Shows a rewarded ad; grants the unlock ONLY on the reward callback. Early
  /// dismissal or failure keeps the section locked and surfaces a SnackBar.
  void _watchAd(
    ResultBloc resultBloc,
    ScaffoldMessengerState messenger,
    AppLocalizations l10n,
  ) {
    void snack(String text) => messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));

    unawaited(
      getIt<AdsService>().showRewarded(
        onReward: () => resultBloc.add(const ResultEvent.detailUnlockGranted()),
        onDismissedWithoutReward: () => snack(l10n.detailUnlockAdDismissed),
        onFailed: (_) => snack(l10n.detailUnlockAdFailed),
      ),
    );
  }
}

/// The bottom sheet offering the two unlock paths (or only "go premium" when
/// offline).
class _DetailUnlockSheet extends StatelessWidget {
  const _DetailUnlockSheet({
    required this.online,
    required this.onWatchAd,
    required this.onGoPremium,
  });

  final bool online;
  final VoidCallback onWatchAd;
  final VoidCallback onGoPremium;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final palette = context.palette;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.detailUnlockSheetTitle,
              style: context.textTheme.titleMedium,
            ),
            if (!online) ...[
              const SizedBox(height: 8),
              Text(
                l10n.detailUnlockOffline,
                style: context.textTheme.bodySmall?.copyWith(
                  color: palette.muted,
                ),
              ),
            ],
            const SizedBox(height: 16),
            if (online) ...[
              PrimaryButton(
                key: const ValueKey('detail-unlock-watch-ad'),
                label: l10n.detailUnlockWatchAd,
                icon: Icons.play_circle_outline,
                fullWidth: true,
                onPressed: onWatchAd,
              ),
              const SizedBox(height: 10),
            ],
            SecondaryButton(
              key: const ValueKey('detail-unlock-go-premium'),
              label: l10n.detailUnlockGoPremium,
              icon: Icons.workspace_premium_outlined,
              fullWidth: true,
              onPressed: onGoPremium,
            ),
          ],
        ),
      ),
    );
  }
}

/// The unlocked numbered reasoning list with hairline separators.
class _ReasoningList extends StatelessWidget {
  const _ReasoningList({required this.steps});

  final List<ReasoningStep> steps;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final palette = context.palette;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Eyebrow(l10n.resultWhyThis),
        const SizedBox(height: 10),
        AppCard(
          child: Column(
            children: [
              for (var i = 0; i < steps.length; i++)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: i < steps.length - 1
                      ? BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: palette.line),
                          ),
                        )
                      : null,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 24,
                        child: Text(
                          '${i + 1}'.padLeft(2, '0'),
                          style: AppTypography.monoStyle(
                            fontSize: 11,
                            color: palette.accent,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          reasoningStepText(l10n, steps[i]),
                          style: context.textTheme.bodySmall?.copyWith(
                            color: palette.ink,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
