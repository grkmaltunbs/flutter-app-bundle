import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:okey_acar_mi/core/di/injection.dart';
import 'package:okey_acar_mi/features/_template/presentation/blocs/template_bloc.dart';
import 'package:okey_acar_mi/features/_template/presentation/widgets/template_item_tile.dart';

/// Reference page: wires a page-scoped [TemplateBloc] and renders its state.
///
/// Not routed in Step 0 — it exists as the copy-target for future features.
class TemplatePage extends StatelessWidget {
  /// Creates a [TemplatePage].
  const TemplatePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<TemplateBloc>(
      create: (_) => getIt<TemplateBloc>()..add(const TemplateItemsRequested()),
      child: const _TemplateView(),
    );
  }
}

class _TemplateView extends StatelessWidget {
  const _TemplateView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Template')),
      body: BlocBuilder<TemplateBloc, TemplateState>(
        builder: (context, state) => switch (state) {
          TemplateInitial() || TemplateLoading() => const Center(
            child: CircularProgressIndicator(),
          ),
          TemplateLoaded(:final items) => ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, index) =>
                TemplateItemTile(item: items[index]),
          ),
          TemplateError(:final failure) => Center(
            child: Text(failure.toString()),
          ),
        },
      ),
    );
  }
}
