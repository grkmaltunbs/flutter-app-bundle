import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:okey_acar_mi/core/di/injection.dart';
import 'package:okey_acar_mi/core/extensions/context_extensions.dart';
import 'package:okey_acar_mi/core/router/app_router.dart';
import 'package:okey_acar_mi/core/theme/app_typography.dart';
import 'package:okey_acar_mi/core/widgets/circle_icon_button.dart';
import 'package:okey_acar_mi/core/widgets/eyebrow.dart';
import 'package:okey_acar_mi/features/detection/domain/entities/detection_result.dart';
import 'package:okey_acar_mi/features/review/presentation/blocs/review_bloc.dart';
import 'package:okey_acar_mi/features/review/presentation/widgets/indicator_section.dart';
import 'package:okey_acar_mi/features/review/presentation/widgets/rack_count_bar.dart';
import 'package:okey_acar_mi/features/review/presentation/widgets/review_banners.dart';
import 'package:okey_acar_mi/features/review/presentation/widgets/review_footer.dart';
import 'package:okey_acar_mi/features/review/presentation/widgets/review_rack.dart';
import 'package:okey_acar_mi/features/review/presentation/widgets/tile_edit_panel.dart';
import 'package:okey_acar_mi/features/settings/presentation/cubit/settings_cubit.dart';

/// The review screen: owns the screen-scoped [ReviewBloc], seeded from this
/// capture's [result] and the game mode active when the screen opened.
class ReviewPage extends StatelessWidget {
  /// Creates a [ReviewPage] for [result].
  const ReviewPage({required this.result, super.key});

  /// The detection result under review (route `extra`, guarded by the router
  /// redirect).
  final DetectionResult result;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<ReviewBloc>(
      create: (context) => getIt<ReviewBloc>(
        param1: result,
        // Read once at creation — a later settings change does not retarget
        // an in-flight review.
        param2: context.read<SettingsCubit>().state.gameMode,
      ),
      child: const ReviewView(),
    );
  }
}

/// The review screen view (assumes a [ReviewBloc] is provided above it):
/// headline, banners, the editable rack, the inline edit panel, the
/// indicator section, and the pinned calculate footer.
class ReviewView extends StatefulWidget {
  /// Creates a [ReviewView].
  const ReviewView({super.key});

  @override
  State<ReviewView> createState() => _ReviewViewState();
}

class _ReviewViewState extends State<ReviewView> {
  /// Anchors `Scrollable.ensureVisible` on the edit panel when it opens.
  final GlobalKey _panelKey = GlobalKey();

  void _onEditingOpened(BuildContext context, ReviewState state) {
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 250);
    // Post-frame: the panel must be laid out before it can be scrolled to.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final panelContext = _panelKey.currentContext;
      if (panelContext == null) return;
      unawaited(
        Scrollable.ensureVisible(
          panelContext,
          duration: duration,
          alignment: 0.5,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<ReviewBloc, ReviewState>(
      listenWhen: (a, b) =>
          b.editingIndex != null && a.editingIndex != b.editingIndex,
      listener: _onEditingOpened,
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: _ReviewTopBar(),
              ),
              Expanded(child: _ReviewBody(panelKey: _panelKey)),
              const ReviewFooter(),
            ],
          ),
        ),
      ),
    );
  }
}

/// Back button + the centered step eyebrow.
class _ReviewTopBar extends StatelessWidget {
  const _ReviewTopBar();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final canPop = context.canPop();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          CircleIconButton(
            key: const ValueKey('review-back'),
            icon: canPop ? Icons.arrow_back : Icons.home_outlined,
            semanticLabel: canPop ? l10n.commonBack : l10n.commonGoStart,
            onPressed: () =>
                canPop ? context.pop() : context.go(AppRoutes.home),
          ),
          Expanded(child: Center(child: Eyebrow(l10n.reviewStepEyebrow))),
          // Balance the leading button so the eyebrow stays centered.
          const SizedBox(width: 48),
        ],
      ),
    );
  }
}

/// The scrollable body between the top bar and the pinned footer.
class _ReviewBody extends StatelessWidget {
  const _ReviewBody({required this.panelKey});

  /// Identifies the edit panel for the open-scroll side effect.
  final GlobalKey panelKey;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final palette = context.palette;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.reviewHeadline,
            style: AppTypography.serifStyle(
              fontSize: 32,
              color: palette.ink,
              letterSpacing: -0.64,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            l10n.reviewSubtitle,
            style: context.textTheme.bodyMedium?.copyWith(
              color: palette.muted,
            ),
          ),
          const SizedBox(height: 16),
          const ReviewLowConfidenceBanner(),
          const ReviewRack(),
          const SizedBox(height: 12),
          const RackCountBar(),
          const ReviewWrongCountBanner(),
          BlocSelector<ReviewBloc, ReviewState, bool>(
            selector: (state) => state.editingIndex != null,
            builder: (context, editing) => editing
                ? Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: _PanelFadeIn(child: TileEditPanel(key: panelKey)),
                  )
                : const SizedBox.shrink(),
          ),
          const SizedBox(height: 20),
          const IndicatorSection(),
        ],
      ),
    );
  }
}

/// Fades the edit panel in on open; renders it directly under reduce-motion.
class _PanelFadeIn extends StatelessWidget {
  const _PanelFadeIn({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 200),
      child: child,
      builder: (context, opacity, child) =>
          Opacity(opacity: opacity, child: child),
    );
  }
}
