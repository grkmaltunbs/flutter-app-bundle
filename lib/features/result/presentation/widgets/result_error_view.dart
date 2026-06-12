import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:okey_acar_mi/core/extensions/context_extensions.dart';
import 'package:okey_acar_mi/core/theme/app_typography.dart';
import 'package:okey_acar_mi/core/widgets/app_buttons.dart';
import 'package:okey_acar_mi/features/result/presentation/blocs/result_bloc.dart';

/// The solver-failure state: explanation + a retry that re-runs the solve.
class ResultErrorView extends StatelessWidget {
  /// Creates a [ResultErrorView].
  const ResultErrorView({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final palette = context.palette;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(32, 24, 32, 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline_rounded,
                size: 44,
                color: palette.muted,
              ),
              const SizedBox(height: 16),
              Text(
                l10n.resultErrorTitle,
                textAlign: TextAlign.center,
                style: AppTypography.serifStyle(
                  fontSize: 28,
                  color: palette.ink,
                  letterSpacing: -0.56,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.resultErrorBody,
                textAlign: TextAlign.center,
                style: context.textTheme.bodyMedium?.copyWith(
                  color: palette.muted,
                ),
              ),
              const SizedBox(height: 24),
              PrimaryButton(
                key: const ValueKey('result-retry'),
                label: l10n.resultRetry,
                icon: Icons.refresh,
                fullWidth: true,
                onPressed: () => context.read<ResultBloc>().add(
                  const ResultEvent.solveRequested(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
