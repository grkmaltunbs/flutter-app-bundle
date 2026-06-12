import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:okey_acar_mi/core/extensions/context_extensions.dart';
import 'package:okey_acar_mi/features/result/presentation/blocs/result_bloc.dart';

/// The Rack / List segmented pills switching the result body layout.
class ResultLayoutToggle extends StatelessWidget {
  /// Creates a [ResultLayoutToggle].
  const ResultLayoutToggle({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return BlocSelector<ResultBloc, ResultState, ResultLayout>(
      selector: (state) => state.layout,
      builder: (context, layout) => Row(
        children: [
          _TogglePill(
            key: const ValueKey('result-layout-rack'),
            label: l10n.resultLayoutRack,
            selected: layout == ResultLayout.rack,
            onTap: () => context.read<ResultBloc>().add(
              const ResultEvent.layoutToggled(ResultLayout.rack),
            ),
          ),
          const SizedBox(width: 8),
          _TogglePill(
            key: const ValueKey('result-layout-list'),
            label: l10n.resultLayoutList,
            selected: layout == ResultLayout.list,
            onTap: () => context.read<ResultBloc>().add(
              const ResultEvent.layoutToggled(ResultLayout.list),
            ),
          ),
        ],
      ),
    );
  }
}

/// One toggle pill (filled ink when selected, hairline chip otherwise) with
/// a ≥48dp tap target around the 36pt visual.
class _TogglePill extends StatelessWidget {
  const _TogglePill({
    required this.label,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(100),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: selected ? palette.ink : palette.surface,
                borderRadius: BorderRadius.circular(100),
                border: Border.all(
                  color: selected ? palette.ink : palette.line,
                ),
              ),
              child: Text(
                label,
                style: context.textTheme.bodySmall?.copyWith(
                  color: selected ? palette.surface : palette.ink,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
