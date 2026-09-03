import 'package:flutter/material.dart' hide Step, StepState;

import 'theme.dart';

/// The plugin's commands, as the Deck previews them. One row per file in
/// `commands/`; the descriptions are the files' own frontmatter, and a
/// test holds this table against the directory so it cannot drift.
class DeckCommand {
  const DeckCommand(this.name, this.what, {this.args, this.group = 'Plan'});
  final String name;
  final String what;
  final String? args;
  final String group;
}

const kDeckCommandGroups = ['Plan', 'Build', 'Quality', 'Setup'];

const kDeckCommands = [
  // Driving the plan.
  DeckCommand('/step', 'Implement the next plan step and verify it at runtime before calling it done', args: '[step-id]'),
  DeckCommand('/next', 'What the human can do right now, grouped by what it needs, and what Claude works next'),
  DeckCommand('/plan-status', 'Show plan progress — every step\'s state, what each waits on, and the next step'),
  DeckCommand('/blocks', 'Everything standing between a step and done — dependencies, gates, and the human items', args: '<step-id>'),
  DeckCommand('/done', 'Close a human item (or drop it), and see what it unblocked', args: '<item-id> [--drop] [note…]'),
  DeckCommand('/plan-extend', 'Add, split, remove, or reorder plan steps — and add human items', args: '<add|split|remove|reorder|item …>'),
  DeckCommand('/board', 'Pick up what the user sent from the board, regenerate it from plan/, and republish at its standing URL'),
  // Building.
  DeckCommand('/feature', 'Implement a new feature end-to-end with tests and runtime verification', args: '<description>', group: 'Build'),
  DeckCommand('/fix', 'Reproduce a bug, fix its root cause, and lock it in with a regression test', args: '<bug description>', group: 'Build'),
  DeckCommand('/refactor', 'Refactor code in small, test-guarded steps with behavior unchanged', args: '<what to refactor>', group: 'Build'),
  DeckCommand('/test', 'Add or improve tests for recent changes or a named scope', args: '[files or scope]', group: 'Build'),
  DeckCommand('/codegen', 'Run build_runner code generation and verify the output', args: '[watch|clean|l10n]', group: 'Build'),
  // Quality and release.
  DeckCommand('/qa', 'Run an on-demand full QA sweep on the project\'s QA runtime (integration tests + runtime-error sweep + the overflow matrix)', args: '[flow or scope]', group: 'Quality'),
  DeckCommand('/app-review', 'Review code and present prioritized findings — read-only, never auto-fixes', args: '[files or scope]', group: 'Quality'),
  DeckCommand('/ship', 'Prepare a release — audit, full tests, version bump, changelog, artifacts', args: '[platform or version]', group: 'Quality'),
  DeckCommand('/clean', 'Clean build artifacts and rebuild the project from scratch', group: 'Quality'),
  DeckCommand('/deps', 'Manage pub dependencies — add, upgrade, audit, or lock', args: 'add <pkg> | upgrade | audit | lock', group: 'Quality'),
  // Setup.
  DeckCommand('/init-app', 'Take a new app from idea to spec, plan, and working Flutter scaffold', group: 'Setup'),
  DeckCommand('/kit-sync', 'Refresh this project\'s flutter-kit files (permissions + Flutter rules) after a plugin update', group: 'Setup'),
];

/// The command palette: every plugin command with its one-liner. Tapping a
/// row hands the command back to the composer.
Future<void> showDeckCommandsSheet(BuildContext context, {String? highlight, required void Function(String command) onPick}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: context.tokens.surface,
    builder: (sheet) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.72,
      maxChildSize: 0.96,
      builder: (context, ctrl) => DeckCommandsSheet(
        highlight: highlight,
        controller: ctrl,
        onPick: (c) {
          Navigator.of(sheet).pop();
          onPick(c);
        },
      ),
    ),
  );
}

class DeckCommandsSheet extends StatelessWidget {
  const DeckCommandsSheet({super.key, this.highlight, this.controller, required this.onPick});
  final String? highlight;
  final ScrollController? controller;
  final void Function(String command) onPick;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    // The long-pressed chip's command leads; its group follows in order.
    final lead = highlight == null ? null : kDeckCommands.where((c) => c.name == highlight).firstOrNull;
    return ListView(
      controller: controller,
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
      children: [
        Text('COMMANDS', style: t.readout(11, color: t.accent)),
        const SizedBox(height: 4),
        Text('Anything you type reaches the session; these are the plugin\'s. Tap one to put it in the composer.', style: TextStyle(fontSize: 12.5, color: t.ink2)),
        if (lead != null) ...[
          const SizedBox(height: 12),
          _Row(command: lead, highlighted: true, onPick: onPick),
        ],
        for (final group in kDeckCommandGroups) ...[
          Padding(
            padding: const EdgeInsets.only(top: 16, bottom: 6),
            child: Text(group.toUpperCase(), style: t.readout(10.5)),
          ),
          for (final c in kDeckCommands)
            if (c.group == group && c.name != highlight) _Row(command: c, onPick: onPick),
        ],
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.command, this.highlighted = false, required this.onPick});
  final DeckCommand command;
  final bool highlighted;
  final void Function(String command) onPick;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => onPick(command.name),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: highlighted
            ? BoxDecoration(color: t.accentSoft.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(8), border: Border.all(color: t.accent.withValues(alpha: 0.45)))
            : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(command.name, style: t.mono(13, color: t.accent, weight: FontWeight.w500)),
                if (command.args != null) Text(command.args!, style: t.mono(11, color: t.muted)),
              ],
            ),
            const SizedBox(height: 2),
            Text(command.what, style: TextStyle(fontSize: 12.5, height: 1.35, color: t.ink2)),
          ],
        ),
      ),
    );
  }
}
