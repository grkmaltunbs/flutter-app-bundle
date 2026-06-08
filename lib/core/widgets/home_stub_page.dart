import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:okey_acar_mi/core/extensions/context_extensions.dart';
import 'package:okey_acar_mi/core/theme/app_accent.dart';
import 'package:okey_acar_mi/core/theme/tile_style.dart';
import 'package:okey_acar_mi/core/widgets/app_buttons.dart';
import 'package:okey_acar_mi/core/widgets/app_pill.dart';
import 'package:okey_acar_mi/core/widgets/eyebrow.dart';
import 'package:okey_acar_mi/core/widgets/meld.dart';
import 'package:okey_acar_mi/core/widgets/rack.dart';
import 'package:okey_acar_mi/core/widgets/tile.dart';
import 'package:okey_acar_mi/core/widgets/tile_data.dart';
import 'package:okey_acar_mi/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:okey_acar_mi/l10n/app_localizations.dart';

/// A live design gallery used to verify theming and the tile kit on a
/// simulator.
///
/// Lets the user switch theme, tile style, and accent (bound to
/// [SettingsCubit]) and previews the [Tile] / [Rack] / [Meld] / pill / button
/// primitives. Everything is flex-based inside a [SingleChildScrollView] and is
/// overflow-safe across the responsive matrix at textScale 2.0. The real Home
/// screen arrives in Step 2; this surface is intentionally throwaway.
class HomeStubPage extends StatelessWidget {
  /// Creates a [HomeStubPage].
  const HomeStubPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final palette = context.palette;
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.appTitle,
                style: context.textTheme.displaySmall,
              ),
              const SizedBox(height: 4),
              Text(
                l10n.homeGreeting,
                style: context.textTheme.bodyMedium?.copyWith(
                  color: palette.muted,
                ),
              ),
              const SizedBox(height: 24),
              const _ThemeControls(),
              const SizedBox(height: 24),
              _Section(
                title: l10n.gallerySectionRack101,
                child: const Rack(tiles: _sample101),
              ),
              const SizedBox(height: 20),
              _Section(
                title: l10n.gallerySectionRackOkey,
                child: const Rack(tiles: _sampleOkey),
              ),
              const SizedBox(height: 20),
              _Section(
                title: l10n.gallerySectionMelds,
                child: Wrap(
                  spacing: 16,
                  runSpacing: 12,
                  children: [
                    Meld(
                      label: l10n.galleryMeldRunLabel,
                      score: 12,
                      tiles: const [
                        TileData(color: TileColor.blue, number: 3),
                        TileData(color: TileColor.blue, number: 4),
                        TileData(color: TileColor.blue, number: 5),
                      ],
                    ),
                    Meld(
                      label: l10n.galleryMeldSetLabel,
                      score: 21,
                      tiles: const [
                        TileData(color: TileColor.red, number: 7),
                        TileData(color: TileColor.black, number: 7),
                        TileData(color: TileColor.joker),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _Section(
                title: l10n.gallerySectionTileStyles,
                child: const _TileStyleShowcase(),
              ),
              const SizedBox(height: 20),
              _Section(
                title: l10n.gallerySectionComponents,
                child: _Components(l10n: l10n),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The three live control rows: theme, tile style, accent.
class _ThemeControls extends StatelessWidget {
  const _ThemeControls();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return BlocBuilder<SettingsCubit, SettingsState>(
      builder: (context, settings) {
        final cubit = context.read<SettingsCubit>();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Eyebrow(l10n.galleryThemeLabel),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final choice in ThemeChoice.values)
                  ChoiceChip(
                    key: ValueKey('gallery-theme-${choice.name}'),
                    label: Text(_themeLabel(l10n, choice)),
                    selected: settings.themeChoice == choice,
                    onSelected: (_) => cubit.setThemeChoice(choice),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Eyebrow(l10n.galleryTileStyleLabel),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final style in TileStyle.values)
                  ChoiceChip(
                    key: ValueKey('gallery-tile-style-${style.name}'),
                    label: Text(_styleLabel(l10n, style)),
                    selected: settings.tileStyle == style,
                    onSelected: (_) => cubit.setTileStyle(style),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Eyebrow(l10n.galleryAccentLabel),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final accent in AppAccent.values)
                  _AccentSwatch(
                    key: ValueKey('gallery-accent-${accent.name}'),
                    accent: accent,
                    selected: settings.accent == accent,
                    onTap: () => cubit.setAccent(accent),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }

  String _themeLabel(AppLocalizations l10n, ThemeChoice c) => switch (c) {
    ThemeChoice.light => l10n.galleryThemeLight,
    ThemeChoice.dark => l10n.galleryThemeDark,
    ThemeChoice.system => l10n.galleryThemeSystem,
    ThemeChoice.felt => l10n.galleryThemeFelt,
  };

  String _styleLabel(AppLocalizations l10n, TileStyle s) => switch (s) {
    TileStyle.classic => l10n.galleryTileStyleClassic,
    TileStyle.flat => l10n.galleryTileStyleFlat,
    TileStyle.minimal => l10n.galleryTileStyleMinimal,
    TileStyle.bold => l10n.galleryTileStyleBold,
  };
}

/// A circular accent color swatch.
class _AccentSwatch extends StatelessWidget {
  const _AccentSwatch({
    required this.accent,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final AppAccent accent;
  final bool selected;
  final VoidCallback onTap;

  String _label(AppLocalizations l10n) => switch (accent) {
    AppAccent.sage => l10n.galleryAccentSage,
    AppAccent.coral => l10n.galleryAccentCoral,
    AppAccent.indigo => l10n.galleryAccentIndigo,
    AppAccent.amber => l10n.galleryAccentAmber,
  };

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Semantics(
      label: _label(context.l10n),
      selected: selected,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(100),
        child: Container(
          width: 48,
          height: 48,
          alignment: Alignment.center,
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
    );
  }
}

/// A labeled section with an eyebrow header.
class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Eyebrow(title),
        const SizedBox(height: 10),
        child,
      ],
    );
  }
}

/// A row of one tile per style, including a joker.
class _TileStyleShowcase extends StatelessWidget {
  const _TileStyleShowcase();

  @override
  Widget build(BuildContext context) {
    return const Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        Tile(color: TileColor.red, number: 7, style: TileStyle.classic),
        Tile(color: TileColor.blue, number: 9, style: TileStyle.flat),
        Tile(color: TileColor.yellow, number: 4, style: TileStyle.minimal),
        Tile(color: TileColor.black, number: 11, style: TileStyle.bold),
        Tile(color: TileColor.joker, style: TileStyle.classic),
      ],
    );
  }
}

/// Pills and buttons.
class _Components extends StatelessWidget {
  const _Components({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            AppPill(label: l10n.galleryPillReady),
            AppPill(label: l10n.galleryPillOpens, variant: PillVariant.good),
            AppPill(label: l10n.galleryPillCloses, variant: PillVariant.bad),
          ],
        ),
        const SizedBox(height: 16),
        PrimaryButton(label: l10n.galleryButtonPrimary, fullWidth: true),
        const SizedBox(height: 10),
        SecondaryButton(label: l10n.galleryButtonSecondary, fullWidth: true),
        const SizedBox(height: 10),
        AccentButton(label: l10n.galleryButtonAccent, fullWidth: true),
      ],
    );
  }
}

/// A representative 21-tile 101 rack (mixed colors + a joker).
const List<TileData> _sample101 = [
  TileData(color: TileColor.red, number: 1),
  TileData(color: TileColor.red, number: 2),
  TileData(color: TileColor.red, number: 3),
  TileData(color: TileColor.blue, number: 4),
  TileData(color: TileColor.blue, number: 5),
  TileData(color: TileColor.blue, number: 6),
  TileData(color: TileColor.yellow, number: 7),
  TileData(color: TileColor.yellow, number: 8),
  TileData(color: TileColor.yellow, number: 9),
  TileData(color: TileColor.black, number: 10),
  TileData(color: TileColor.black, number: 11),
  TileData(color: TileColor.black, number: 12),
  TileData(color: TileColor.red, number: 13),
  TileData(color: TileColor.joker),
  TileData(color: TileColor.blue, number: 1, lowConfidence: true),
  TileData(color: TileColor.blue, number: 2),
  TileData(color: TileColor.yellow, number: 3),
  TileData(color: TileColor.yellow, number: 4),
  TileData(color: TileColor.black, number: 5),
  TileData(color: TileColor.red, number: 6),
  TileData(color: TileColor.red, number: 7),
];

/// A representative 14-tile Okey rack.
const List<TileData> _sampleOkey = [
  TileData(color: TileColor.red, number: 3),
  TileData(color: TileColor.red, number: 4),
  TileData(color: TileColor.red, number: 5),
  TileData(color: TileColor.blue, number: 8),
  TileData(color: TileColor.black, number: 8),
  TileData(color: TileColor.yellow, number: 8),
  TileData(color: TileColor.joker),
  TileData(color: TileColor.blue, number: 10),
  TileData(color: TileColor.blue, number: 11),
  TileData(color: TileColor.blue, number: 12),
  TileData(color: TileColor.yellow, number: 1),
  TileData(color: TileColor.yellow, number: 2),
  TileData(color: TileColor.black, number: 13),
  TileData(color: TileColor.red, number: 13),
];
