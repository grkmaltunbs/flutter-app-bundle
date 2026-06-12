import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:okey_acar_mi/core/extensions/context_extensions.dart';
import 'package:okey_acar_mi/core/router/app_router.dart';
import 'package:okey_acar_mi/core/widgets/app_buttons.dart';

/// The pinned bottom bar: "Tekrar" (new scan → camera) and "Bitir" (finish
/// → home). Navigation is a widget-side effect — the bloc never navigates.
class ResultFooter extends StatelessWidget {
  /// Creates a [ResultFooter].
  const ResultFooter({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final palette = context.palette;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).scaffoldBackgroundColor.withValues(alpha: 0.92),
        border: Border(top: BorderSide(color: palette.line)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          // TODO(step-11): banner-ad seam — mount the AdMob banner (gated
          // through SubscriptionBloc / AdsService) directly above this row
          // for free users.
          child: Row(
            children: [
              Expanded(
                flex: 10,
                child: SecondaryButton(
                  key: const ValueKey('result-again'),
                  label: l10n.resultAgain,
                  icon: Icons.refresh,
                  fullWidth: true,
                  onPressed: () => context.go(AppRoutes.camera),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 14,
                child: PrimaryButton(
                  key: const ValueKey('result-done'),
                  label: l10n.resultDone,
                  icon: Icons.check,
                  fullWidth: true,
                  onPressed: () => context.go(AppRoutes.home),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
