import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:okey_acar_mi/core/extensions/context_extensions.dart';
import 'package:okey_acar_mi/core/router/app_router.dart';
import 'package:okey_acar_mi/core/widgets/app_buttons.dart';
import 'package:okey_acar_mi/core/widgets/eyebrow.dart';

/// History tab — past scans. Until persistence lands in Step 9 this shows the
/// inviting empty state from `screen-history`.
class HistoryPage extends StatelessWidget {
  /// Creates a [HistoryPage].
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final palette = context.palette;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  Expanded(child: Eyebrow(l10n.historyEyebrow)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  l10n.historyTitle,
                  style: context.textTheme.displaySmall,
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(32, 24, 32, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 24),
                    Icon(
                      Icons.history_outlined,
                      size: 44,
                      color: palette.faint,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      l10n.historyEmptyTitle,
                      textAlign: TextAlign.center,
                      style: context.textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.historyEmptyBody,
                      textAlign: TextAlign.center,
                      style: context.textTheme.bodyMedium?.copyWith(
                        color: palette.muted,
                      ),
                    ),
                    const SizedBox(height: 24),
                    PrimaryButton(
                      label: l10n.historyEmptyCta,
                      icon: Icons.photo_camera_outlined,
                      onPressed: () => context.push(AppRoutes.camera),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
