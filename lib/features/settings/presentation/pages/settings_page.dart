import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:okey_acar_mi/core/app_info/app_info.dart';
import 'package:okey_acar_mi/core/constants/legal_links.dart';
import 'package:okey_acar_mi/core/di/injection.dart';
import 'package:okey_acar_mi/core/extensions/context_extensions.dart';
import 'package:okey_acar_mi/core/payments/purchase_failure.dart';
import 'package:okey_acar_mi/core/payments/subscription_bloc.dart';
import 'package:okey_acar_mi/core/router/app_router.dart';
import 'package:okey_acar_mi/core/theme/app_accent.dart';
import 'package:okey_acar_mi/core/theme/tile_style.dart';
import 'package:okey_acar_mi/core/widgets/eyebrow.dart';
import 'package:okey_acar_mi/features/auth/presentation/widgets/account_section.dart';
import 'package:okey_acar_mi/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:okey_acar_mi/l10n/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';

/// Settings tab — appearance (theme / tile style / accent), language, and the
/// default game mode, all bound live to [SettingsCubit], plus the account
/// section (auth feature), the purchases rows (Step 11 rewires them onto
/// RevenueCat), and the About section (legal links + version).
class SettingsPage extends StatelessWidget {
  /// Creates a [SettingsPage].
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: BlocBuilder<SettingsCubit, SettingsState>(
          builder: (context, settings) {
            final cubit = context.read<SettingsCubit>();
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              children: [
                Eyebrow(l10n.settingsEyebrow),
                const SizedBox(height: 4),
                Text(l10n.settingsTitle, style: context.textTheme.displaySmall),
                const SizedBox(height: 24),

                _SettingsSection(
                  title: l10n.settingsAppearanceLabel,
                  children: [
                    _Field(
                      label: l10n.settingsThemeLabel,
                      child: _ChipRow(
                        values: ThemeChoice.values,
                        selected: settings.themeChoice,
                        keyPrefix: 'settings-theme',
                        labelOf: (v) => _themeLabel(l10n, v),
                        onSelected: cubit.setThemeChoice,
                      ),
                    ),
                    _Field(
                      label: l10n.settingsTileStyleLabel,
                      child: _ChipRow(
                        values: TileStyle.values,
                        selected: settings.tileStyle,
                        keyPrefix: 'settings-tile-style',
                        labelOf: (v) => _styleLabel(l10n, v),
                        onSelected: cubit.setTileStyle,
                      ),
                    ),
                    _Field(
                      label: l10n.settingsAccentLabel,
                      child: Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          for (final accent in AppAccent.values)
                            _AccentSwatch(
                              key: ValueKey('settings-accent-${accent.name}'),
                              accent: accent,
                              label: _accentLabel(l10n, accent),
                              selected: settings.accent == accent,
                              onTap: () => cubit.setAccent(accent),
                            ),
                        ],
                      ),
                    ),
                    _Field(
                      label: l10n.settingsLanguageLabel,
                      child: _ChipRow(
                        values: AppLanguage.values,
                        selected: settings.language,
                        keyPrefix: 'settings-language',
                        labelOf: (v) => _languageLabel(l10n, v),
                        onSelected: cubit.setLanguage,
                      ),
                    ),
                  ],
                ),

                _SettingsSection(
                  title: l10n.settingsGameLabel,
                  children: [
                    _Field(
                      label: l10n.settingsDefaultModeLabel,
                      child: _ChipRow(
                        values: GameMode.values,
                        selected: settings.gameMode,
                        keyPrefix: 'settings-mode',
                        labelOf: (v) => _modeLabel(l10n, v),
                        onSelected: cubit.setGameMode,
                      ),
                    ),
                  ],
                ),

                _SettingsSection(
                  title: l10n.settingsAccountLabel,
                  children: const [AccountSection()],
                ),

                _SettingsSection(
                  title: l10n.settingsPurchasesLabel,
                  children: const [_PurchasesSection()],
                ),

                _SettingsSection(
                  title: l10n.settingsAboutLabel,
                  children: [
                    _ActionRow(
                      key: const ValueKey('settings-privacy-policy'),
                      label: l10n.settingsPrivacyPolicy,
                      trailingIcon: Icons.open_in_new,
                      onTap: () => unawaited(
                        _openLegalLink(context, LegalLinks.privacyPolicy),
                      ),
                    ),
                    _ActionRow(
                      key: const ValueKey('settings-terms-of-use'),
                      label: l10n.settingsTermsOfUse,
                      trailingIcon: Icons.open_in_new,
                      onTap: () => unawaited(
                        _openLegalLink(context, LegalLinks.termsOfUse),
                      ),
                    ),
                    _InfoRow(
                      label: l10n.settingsVersionLabel,
                      value: getIt<AppInfo>().label,
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  String _themeLabel(AppLocalizations l10n, ThemeChoice c) => switch (c) {
    ThemeChoice.light => l10n.settingsThemeLight,
    ThemeChoice.dark => l10n.settingsThemeDark,
    ThemeChoice.system => l10n.settingsThemeSystem,
    ThemeChoice.felt => l10n.settingsThemeFelt,
  };

  String _styleLabel(AppLocalizations l10n, TileStyle s) => switch (s) {
    TileStyle.classic => l10n.settingsTileStyleClassic,
    TileStyle.flat => l10n.settingsTileStyleFlat,
    TileStyle.minimal => l10n.settingsTileStyleMinimal,
    TileStyle.bold => l10n.settingsTileStyleBold,
  };

  String _accentLabel(AppLocalizations l10n, AppAccent a) => switch (a) {
    AppAccent.sage => l10n.settingsAccentSage,
    AppAccent.coral => l10n.settingsAccentCoral,
    AppAccent.indigo => l10n.settingsAccentIndigo,
    AppAccent.amber => l10n.settingsAccentAmber,
  };

  String _languageLabel(AppLocalizations l10n, AppLanguage v) => switch (v) {
    AppLanguage.system => l10n.settingsLanguageSystem,
    AppLanguage.turkish => l10n.settingsLanguageTurkish,
    AppLanguage.english => l10n.settingsLanguageEnglish,
  };

  String _modeLabel(AppLocalizations l10n, GameMode m) => switch (m) {
    GameMode.oneZeroOne => l10n.gameMode101Title,
    GameMode.okey => l10n.gameModeOkeyTitle,
  };

  /// Opens [url] in the external browser; a refusal or failure surfaces as a
  /// localized SnackBar instead of an exception.
  Future<void> _openLegalLink(BuildContext context, String url) async {
    // Captured before the await: the context must not be used across it.
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

/// The purchases rows, wired to [SubscriptionBloc].
///
/// Free users see "remove ads" (→ paywall) + restore. Premium users see a
/// "premium active" indicator, "manage subscription" (opens the platform store
/// page via url_launcher — never the purchase SDK), and restore. Restore /
/// purchase feedback is surfaced as SnackBars by the listener.
class _PurchasesSection extends StatelessWidget {
  const _PurchasesSection();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return BlocConsumer<SubscriptionBloc, SubscriptionState>(
      listenWhen: (a, b) => a.flow != b.flow,
      listener: (context, state) => _onFlow(context, state.flow),
      buildWhen: (a, b) => a.isPremium != b.isPremium,
      builder: (context, state) {
        final bloc = context.read<SubscriptionBloc>();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (state.isPremium) ...[
              _PremiumActiveRow(label: l10n.settingsPremiumActive),
              _ActionRow(
                key: const ValueKey('settings-manage-subscription'),
                label: l10n.settingsManageSubscription,
                trailingIcon: Icons.open_in_new,
                onTap: () => unawaited(_openManagement(context)),
              ),
            ] else
              _ActionRow(
                key: const ValueKey('settings-remove-ads'),
                label: l10n.settingsRemoveAds,
                onTap: () => context.push(AppRoutes.paywall),
              ),
            _ActionRow(
              key: const ValueKey('settings-restore-purchases'),
              label: l10n.settingsRestorePurchases,
              onTap: () => bloc.add(const SubscriptionEvent.restoreRequested()),
            ),
          ],
        );
      },
    );
  }

  void _onFlow(BuildContext context, SubscriptionFlow flow) {
    final l10n = context.l10n;
    String? text;
    switch (flow) {
      case SubscriptionFlowRestoreSucceeded():
        text = l10n.restoreSuccess;
      case SubscriptionFlowError(:final failure):
        text = failure is PurchaseRestoreNothing
            ? l10n.restoreNothingToRestore
            : l10n.paywallErrorGeneric;
      case SubscriptionFlowIdle():
      case SubscriptionFlowOfferingsLoading():
      case SubscriptionFlowPurchasing():
      case SubscriptionFlowRestoring():
      case SubscriptionFlowPurchaseSucceeded():
      case SubscriptionFlowOffline():
        text = null;
    }
    if (text == null) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  /// Opens the platform subscription-management page (App Store / Play). Keeps
  /// the purchase SDK out of the widget layer.
  Future<void> _openManagement(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(l10n.settingsManageSubscriptionOpening)),
      );
    final url = Platform.isIOS
        ? 'https://apps.apple.com/account/subscriptions'
        : 'https://play.google.com/store/account/subscriptions';
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
        ..showSnackBar(SnackBar(content: Text(l10n.settingsLinkError)));
    }
  }
}

/// A non-interactive "premium active" indicator row.
class _PremiumActiveRow extends StatelessWidget {
  const _PremiumActiveRow({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: Row(
        children: [
          Icon(Icons.verified_outlined, size: 18, color: palette.good),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: context.textTheme.bodyMedium?.copyWith(color: palette.ink),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Eyebrow(title),
        const SizedBox(height: 12),
        ...children,
        const SizedBox(height: 24),
      ],
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: context.textTheme.titleSmall),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

/// A wrap of [ChoiceChip]s for a fixed set of enum [values].
class _ChipRow<T extends Enum> extends StatelessWidget {
  const _ChipRow({
    required this.values,
    required this.selected,
    required this.keyPrefix,
    required this.labelOf,
    required this.onSelected,
  });

  final List<T> values;
  final T selected;
  final String keyPrefix;
  final String Function(T) labelOf;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final value in values)
          ChoiceChip(
            key: ValueKey('$keyPrefix-${value.name}'),
            label: Text(labelOf(value)),
            selected: selected == value,
            onSelected: (_) => onSelected(value),
          ),
      ],
    );
  }
}

/// A circular accent color swatch.
class _AccentSwatch extends StatelessWidget {
  const _AccentSwatch({
    required this.accent,
    required this.label,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final AppAccent accent;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Semantics(
      label: label,
      selected: selected,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(100),
        child: SizedBox(
          width: 48,
          height: 48,
          child: Center(
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: accent.seed,
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? palette.ink : Colors.transparent,
                  width: 2.5,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A tappable settings row: label (flexes — survives textScale 2.0 on narrow
/// screens) + trailing affordance icon, with a ≥48dp touch target.
class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.label,
    required this.onTap,
    this.trailingIcon = Icons.chevron_right,
    super.key,
  });

  final String label;
  final VoidCallback onTap;
  final IconData trailingIcon;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Row(
          children: [
            Expanded(
              child: Text(label, style: context.textTheme.bodyMedium),
            ),
            Icon(trailingIcon, size: 18, color: context.palette.muted),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: context.textTheme.bodyMedium),
          ),
          Text(
            value,
            style: context.textTheme.bodyMedium?.copyWith(color: palette.muted),
          ),
        ],
      ),
    );
  }
}
