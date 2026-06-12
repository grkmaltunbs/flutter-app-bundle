import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:okey_acar_mi/core/di/injection.dart';
import 'package:okey_acar_mi/core/extensions/context_extensions.dart';
import 'package:okey_acar_mi/core/router/app_router.dart';
import 'package:okey_acar_mi/core/widgets/circle_icon_button.dart';
import 'package:okey_acar_mi/core/widgets/eyebrow.dart';
import 'package:okey_acar_mi/features/result/presentation/blocs/result_bloc.dart';
import 'package:okey_acar_mi/features/result/presentation/models/result_arrangement.dart';
import 'package:okey_acar_mi/features/result/presentation/widgets/result_detail_section.dart';
import 'package:okey_acar_mi/features/result/presentation/widgets/result_error_view.dart';
import 'package:okey_acar_mi/features/result/presentation/widgets/result_extras.dart';
import 'package:okey_acar_mi/features/result/presentation/widgets/result_footer.dart';
import 'package:okey_acar_mi/features/result/presentation/widgets/result_layout_toggle.dart';
import 'package:okey_acar_mi/features/result/presentation/widgets/result_list_layout.dart';
import 'package:okey_acar_mi/features/result/presentation/widgets/result_loading_view.dart';
import 'package:okey_acar_mi/features/result/presentation/widgets/result_rack_layout.dart';
import 'package:okey_acar_mi/features/result/presentation/widgets/result_verdict_header.dart';
import 'package:okey_acar_mi/features/review/domain/entities/review_outcome.dart';
import 'package:okey_acar_mi/features/solver/domain/entities/solve_result.dart';

/// The result screen: owns the screen-scoped [ResultBloc], seeded from the
/// confirmed [outcome], which solves immediately on creation.
class ResultPage extends StatelessWidget {
  /// Creates a [ResultPage] for [outcome].
  const ResultPage({required this.outcome, super.key});

  /// The confirmed review outcome to solve (route `extra`, guarded by the
  /// router redirect).
  final ReviewOutcome outcome;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<ResultBloc>(
      create: (_) => getIt<ResultBloc>(param1: outcome),
      child: const ResultView(),
    );
  }
}

/// The result screen view (assumes a [ResultBloc] is provided above it):
/// top bar, the status-switched body, and the pinned footer.
class ResultView extends StatelessWidget {
  /// Creates a [ResultView].
  const ResultView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: _ResultTopBar(),
            ),
            Expanded(
              child: BlocSelector<ResultBloc, ResultState, ResultSolveStatus>(
                selector: (state) => state.status,
                builder: (context, status) => switch (status) {
                  ResultSolving() => const ResultLoadingView(),
                  ResultSolveFailed() => const ResultErrorView(),
                  ResultSolved(:final result) => _SolvedBody(result: result),
                },
              ),
            ),
            const ResultFooter(),
          ],
        ),
      ),
    );
  }
}

/// Close (X → home) + the centered step eyebrow.
class _ResultTopBar extends StatelessWidget {
  const _ResultTopBar();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          CircleIconButton(
            key: const ValueKey('result-close'),
            icon: Icons.close,
            semanticLabel: l10n.resultCloseSemantics,
            onPressed: () => context.go(AppRoutes.home),
          ),
          Expanded(child: Center(child: Eyebrow(l10n.resultStepEyebrow))),
          // Balance the leading button so the eyebrow stays centered.
          const SizedBox(width: 48),
        ],
      ),
    );
  }
}

/// The scrollable solved body: verdict, layout toggle, the chosen layout,
/// okey extras, and the reasoning section.
class _SolvedBody extends StatelessWidget {
  const _SolvedBody({required this.result});

  final SolveResult result;

  @override
  Widget build(BuildContext context) {
    // Cheap pure mapping (≤ 21 cells); rebuilt only when the status changes.
    final arrangement = ResultArrangement.of(result);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ResultVerdictHeader(verdict: result.verdict),
          const SizedBox(height: 20),
          const ResultLayoutToggle(),
          const SizedBox(height: 14),
          BlocSelector<ResultBloc, ResultState, ResultLayout>(
            selector: (state) => state.layout,
            builder: (context, layout) => layout == ResultLayout.rack
                ? ResultRackLayout(arrangement: arrangement)
                : ResultListLayout(arrangement: arrangement),
          ),
          const SizedBox(height: 20),
          ResultExtras(result: result, neededCount: arrangement.neededCount),
          ResultDetailSection(steps: result.reasoning),
        ],
      ),
    );
  }
}
