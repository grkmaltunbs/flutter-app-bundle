import 'package:flutter/material.dart';
import 'package:okey_acar_mi/core/extensions/context_extensions.dart';

/// The solving state: a centered progress indicator + "Hesaplanıyor…".
class ResultLoadingView extends StatelessWidget {
  /// Creates a [ResultLoadingView].
  const ResultLoadingView({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: palette.accent,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            context.l10n.resultSolving,
            style: context.textTheme.bodyMedium?.copyWith(
              color: palette.muted,
            ),
          ),
        ],
      ),
    );
  }
}
