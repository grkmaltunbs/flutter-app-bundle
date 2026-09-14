import 'package:flutter/material.dart';
import 'package:flutter_kit/kit.dart';

import '../theme.dart';

/// A fact from the protocol, never inferred by comparing requested model IDs.
String modelConfirmationLabel(ModelConfirmation confirmation, String? model) {
  if (confirmation == ModelConfirmation.confirmed && model != null) {
    return 'Server confirmed: $model';
  }
  final last = model == null ? '' : '\nLast server confirmed: $model';
  return confirmation == ModelConfirmation.pending
      ? 'Waiting for the next turn to confirm$last'
      : 'Not yet confirmed by the server$last';
}

Future<String?> showModelPickerSheet(
  BuildContext context, {
  required String selected,
  required List<String> models,
  required ModelConfirmation confirmation,
  required String? confirmedModel,
  required Future<void> Function(String) onSelect,
}) => showModalBottomSheet<String>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  backgroundColor: context.tokens.surface,
  builder: (context) => DraggableScrollableSheet(
    expand: false,
    initialChildSize: 0.72,
    maxChildSize: 0.96,
    builder: (context, controller) => ModelPickerSheet(
      selected: selected,
      models: models,
      confirmation: confirmation,
      confirmedModel: confirmedModel,
      controller: controller,
      onSelect: onSelect,
      onSelected: (model) => Navigator.of(context).pop(model),
    ),
  ),
);

// Widget tree: draggable sheet > lazy list > status, catalog source, choices.
// Material list tiles keep the established sheet style and accessible targets;
// errors remain inside the sheet, with the current selection still available.
class ModelPickerSheet extends StatefulWidget {
  const ModelPickerSheet({
    super.key,
    required this.selected,
    required this.models,
    required this.confirmation,
    required this.confirmedModel,
    required this.onSelect,
    required this.onSelected,
    this.controller,
  });

  final String selected;
  final List<String> models;
  final ModelConfirmation confirmation;
  final String? confirmedModel;
  final Future<void> Function(String) onSelect;
  final ValueChanged<String> onSelected;
  final ScrollController? controller;

  @override
  State<ModelPickerSheet> createState() => _ModelPickerSheetState();
}

class _ModelPickerSheetState extends State<ModelPickerSheet> {
  bool _busy = false;
  String? _error;

  Future<void> _select(String model) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onSelect(model);
      if (mounted) widget.onSelected(model);
    } on Object catch (error) {
      if (mounted) setState(() => _error = 'Could not select model: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final choices = modelChoicesFor(
      'codex',
      reported: widget.models,
    ).toSet().toList();
    return ListView.builder(
      controller: widget.controller,
      itemCount: choices.length + 2,
      itemBuilder: (context, index) {
        if (index == 0) {
          return ListTile(
            title: Text('CODEX MODEL', style: t.readout(11, color: t.accent)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Selected for next turn: ${widget.selected}',
                  style: t.mono(12, color: t.ink),
                ),
                Text(
                  modelConfirmationLabel(
                    widget.confirmation,
                    widget.confirmedModel,
                  ),
                ),
                if (_busy) const Text('Saving selection…'),
                if (_error != null)
                  Semantics(
                    liveRegion: true,
                    child: Text(_error!, style: TextStyle(color: t.critical)),
                  ),
              ],
            ),
          );
        }
        if (index == 1) {
          return ListTile(
            subtitle: Text(
              widget.models.isEmpty
                  ? 'Available models have not been verified for this session. These are built-in choices; start or resume Codex to refresh. Default lets the server choose.'
                  : 'Models reported by Codex. Default lets the server choose. Selection is confirmed when Codex starts the next turn.',
            ),
          );
        }
        final model = choices[index - 2];
        return ListTile(
          key: ValueKey('model-choice-$model'),
          enabled: !_busy,
          selected: model == widget.selected,
          selectedColor: t.accent,
          title: Text(
            model,
            style: t.mono(
              12,
              color: model == widget.selected ? t.accent : t.ink,
            ),
          ),
          subtitle: model == widget.selected
              ? const Text('Selected for next turn')
              : null,
          onTap: () => _select(model),
        );
      },
    );
  }
}
