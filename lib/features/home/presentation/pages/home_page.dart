import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:okey_acar_mi/core/extensions/context_extensions.dart';
import 'package:okey_acar_mi/core/router/app_router.dart';
import 'package:okey_acar_mi/core/theme/app_radii.dart';
import 'package:okey_acar_mi/core/theme/app_typography.dart';
import 'package:okey_acar_mi/core/widgets/circle_icon_button.dart';
import 'package:okey_acar_mi/core/widgets/eyebrow.dart';
import 'package:okey_acar_mi/features/settings/presentation/cubit/settings_cubit.dart';

/// Home / dashboard — greeting, game-mode chooser, the primary scan CTA, and
/// (until history lands in Step 9) an inviting empty state.
class HomePage extends StatelessWidget {
  /// Creates a [HomePage].
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final palette = context.palette;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Eyebrow(l10n.homeEyebrow)),
                  CircleIconButton(
                    key: const ValueKey('home-help'),
                    icon: Icons.help_outline,
                    semanticLabel: l10n.homeHelpSemantics,
                    onPressed: () => context.push(AppRoutes.tutorial),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: AlignmentDirectional.centerStart,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.homeGreetingLine1,
                      style: AppTypography.serifStyle(
                        fontSize: 36,
                        color: palette.ink,
                        letterSpacing: -0.7,
                      ),
                    ),
                    Text(
                      l10n.homeGreetingLine2,
                      style: AppTypography.serifStyle(
                        fontSize: 36,
                        color: palette.muted,
                        letterSpacing: -0.7,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Eyebrow(l10n.homeGameModeLabel),
              const SizedBox(height: 8),
              const _GameModeChooser(),
              const SizedBox(height: 20),
              const _ScanCta(),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(child: Eyebrow(l10n.homeLastScanLabel)),
                  Semantics(
                    button: true,
                    label: l10n.homeSeeAll,
                    excludeSemantics: true,
                    child: InkWell(
                      onTap: () => context.go(AppRoutes.history),
                      borderRadius: BorderRadius.circular(8),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 48),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 12,
                          ),
                          child: Center(
                            widthFactor: 1,
                            child: Text(
                              l10n.homeSeeAll,
                              style: context.textTheme.bodySmall?.copyWith(
                                color: palette.muted,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const _EmptyLastScan(),
            ],
          ),
        ),
      ),
    );
  }
}

/// The 101 / Okey mode chooser, bound live to [SettingsCubit].
class _GameModeChooser extends StatelessWidget {
  const _GameModeChooser();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return BlocBuilder<SettingsCubit, SettingsState>(
      buildWhen: (a, b) => a.gameMode != b.gameMode,
      builder: (context, settings) {
        final cubit = context.read<SettingsCubit>();
        return Row(
          children: [
            Expanded(
              child: _ModeButton(
                title: l10n.gameMode101Title,
                subtitle: l10n.gameMode101Sub,
                selected: settings.gameMode == GameMode.oneZeroOne,
                onTap: () => cubit.setGameMode(GameMode.oneZeroOne),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _ModeButton(
                title: l10n.gameModeOkeyTitle,
                subtitle: l10n.gameModeOkeySub,
                selected: settings.gameMode == GameMode.okey,
                onTap: () => cubit.setGameMode(GameMode.okey),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final bg = selected ? palette.ink : palette.surface;
    final fg = selected ? palette.surface : palette.ink;
    return Semantics(
      button: true,
      selected: selected,
      label: title,
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadii.md),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadii.md),
          child: Container(
            constraints: const BoxConstraints(minHeight: 56),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadii.md),
              border: Border.all(color: selected ? palette.ink : palette.line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.textTheme.titleSmall?.copyWith(color: fg),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.textTheme.bodySmall?.copyWith(
                    color: fg.withValues(alpha: 0.7),
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

/// The primary "snap the rack" call-to-action card.
class _ScanCta extends StatelessWidget {
  const _ScanCta();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final palette = context.palette;
    return Semantics(
      button: true,
      label: l10n.homeScanSemantics,
      child: Material(
        color: palette.ink,
        borderRadius: BorderRadius.circular(AppRadii.xl),
        child: InkWell(
          onTap: () => context.push(AppRoutes.camera),
          borderRadius: BorderRadius.circular(AppRadii.xl),
          child: Container(
            constraints: const BoxConstraints(minHeight: 170),
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Eyebrow(
                  l10n.homeScanEyebrow,
                  color: palette.surface.withValues(alpha: 0.6),
                ),
                const SizedBox(height: 8),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    l10n.homeScanTitle,
                    style: AppTypography.serifStyle(
                      fontSize: 36,
                      color: palette.surface,
                      letterSpacing: -0.7,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Text(
                        l10n.homeScanBody,
                        style: context.textTheme.bodyMedium?.copyWith(
                          color: palette.surface.withValues(alpha: 0.7),
                          height: 1.4,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: palette.surface,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.photo_camera_outlined,
                        color: palette.ink,
                        size: 26,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Inviting empty state shown in the last-scan slot until history exists.
class _EmptyLastScan extends StatelessWidget {
  const _EmptyLastScan();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final palette = context.palette;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 28),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: palette.line),
      ),
      child: Column(
        children: [
          Icon(Icons.style_outlined, size: 32, color: palette.faint),
          const SizedBox(height: 12),
          Text(
            l10n.homeEmptyTitle,
            textAlign: TextAlign.center,
            style: context.textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            l10n.homeEmptyBody,
            textAlign: TextAlign.center,
            style: context.textTheme.bodyMedium?.copyWith(color: palette.muted),
          ),
        ],
      ),
    );
  }
}
