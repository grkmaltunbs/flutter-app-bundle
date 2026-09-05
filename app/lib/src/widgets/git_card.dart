import 'package:flutter/material.dart' hide Step, StepState;

import '../host/host_actions.dart';
import '../theme.dart';

/// The Git card: branch, ahead/behind, dirty count, the last commit's
/// first line — and Commit (a message) and Push, which the host runs
/// directly. [onOp] returns the one line to toast.
class GitCard extends StatefulWidget {
  const GitCard({super.key, required this.git, required this.onOp});
  final GitStatus? git;
  final Future<String> Function(String op, {String? message, String? path}) onOp;

  @override
  State<GitCard> createState() => _GitCardState();
}

class _GitCardState extends State<GitCard> {
  String? _busy;

  Future<void> _run(String op, {String? message}) async {
    setState(() => _busy = op);
    String line;
    try {
      line = await widget.onOp(op, message: message);
    } on Object catch (e) {
      line = 'Could not $op: $e';
    }
    if (!mounted) return;
    setState(() => _busy = null);
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(line)));
  }

  Future<void> _commit() async {
    final message = await showDialog<String>(context: context, builder: (_) => const _CommitDialog());
    if (message == null || message.trim().isEmpty) return;
    await _run('commit', message: message.trim());
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final g = widget.git;
    final busy = _busy != null;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(color: t.surface, borderRadius: BorderRadius.circular(10), border: Border.all(color: t.line)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('GIT · ${g == null ? '…' : g.ok ? g.branch.toUpperCase() : 'NONE'}', style: t.readout(11, color: t.ink2)),
              if (g != null && g.ok) ...[
                if (g.ahead > 0 || g.behind > 0) Text('↑${g.ahead} ↓${g.behind}', style: t.readout(11, color: g.ahead > 0 ? t.accent : t.muted)),
                Text(g.dirty == 0 ? 'CLEAN' : '${g.dirty} CHANGED', style: t.readout(11, color: g.dirty == 0 ? t.good : t.warn)),
              ],
            ],
          ),
          if (g != null && g.ok && g.lastCommit.isNotEmpty)
            Padding(padding: const EdgeInsets.only(top: 4), child: Text(g.lastCommit, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.mono(11.5, color: t.muted))),
          if (g != null && !g.ok) Padding(padding: const EdgeInsets.only(top: 4), child: Text(g.error!, maxLines: 2, overflow: TextOverflow.ellipsis, style: t.mono(11.5, color: t.critical))),
          if (g == null) Padding(padding: const EdgeInsets.only(top: 4), child: Text('Reading…', style: t.mono(11.5, color: t.muted))),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.tonal(onPressed: busy || g == null || !g.ok || g.dirty == 0 ? null : _commit, child: Text(_busy == 'commit' ? 'COMMITTING…' : 'COMMIT')),
              OutlinedButton(onPressed: busy || g == null || !g.ok ? null : () => _run('push'), child: Text(_busy == 'push' ? 'PUSHING…' : 'PUSH')),
            ],
          ),
        ],
      ),
    );
  }
}

/// The message field; owns its controller for as long as the dialog is
/// on screen, closing animation included.
class _CommitDialog extends StatefulWidget {
  const _CommitDialog();

  @override
  State<_CommitDialog> createState() => _CommitDialogState();
}

class _CommitDialogState extends State<_CommitDialog> {
  final _message = TextEditingController();

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Commit'),
        content: TextField(
          controller: _message,
          autofocus: true,
          minLines: 1,
          maxLines: 4,
          decoration: const InputDecoration(hintText: 'What changed, in one line', isDense: true),
          onSubmitted: (v) => Navigator.of(context).pop(v),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('CANCEL')),
          FilledButton(onPressed: () => Navigator.of(context).pop(_message.text), child: const Text('COMMIT')),
        ],
      );
}
