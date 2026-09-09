import 'package:flutter/material.dart' hide Step, StepState;

import '../host/host_actions.dart';
import '../theme.dart';

/// The Git card: branch, ahead/behind, dirty count, the last commit's
/// first line — and Commit (a message) and Push, which the host runs
/// directly. [onOp] returns the one line to toast. A project of its own
/// ([canAddWorktree]) offers NEW TREE; a worktree entry ([worktree], its
/// name) offers MERGE INTO MAIN — a conflict comes back as a line that
/// starts with `conflict:` and the card offers to send the resolution to
/// the main session — and REMOVE, which a dirty tree answers with a line
/// that starts with `dirty:` until the removal is forced.
class GitCard extends StatefulWidget {
  const GitCard({super.key, required this.git, required this.onOp, this.worktree, this.canAddWorktree = false});
  final GitStatus? git;
  final Future<String> Function(String op, {String? message, String? path}) onOp;
  final String? worktree;
  final bool canAddWorktree;

  @override
  State<GitCard> createState() => _GitCardState();
}

class _GitCardState extends State<GitCard> {
  String? _busy;

  Future<String> _op(String op, {String? message}) async {
    setState(() => _busy = op);
    String line;
    try {
      line = await widget.onOp(op, message: message);
    } on Object catch (e) {
      line = 'Could not $op: $e';
    }
    if (mounted) setState(() => _busy = null);
    return line;
  }

  void _toast(String line) => ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(line)));

  Future<void> _run(String op, {String? message}) async {
    final line = await _op(op, message: message);
    if (mounted) _toast(line);
  }

  Future<void> _commit() async {
    final message = await showDialog<String>(context: context, builder: (_) => const _CommitDialog());
    if (message == null || message.trim().isEmpty) return;
    await _run('commit', message: message.trim());
  }

  Future<void> _newTree() async {
    final name = await showDialog<String>(context: context, builder: (_) => const _NameDialog());
    if (name == null || name.trim().isEmpty) return;
    await _run('worktree_add', message: name.trim());
  }

  Future<void> _merge() async {
    final line = await _op('merge');
    if (!mounted) return;
    if (!line.startsWith('conflict:')) return _toast(line);
    final send = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Merge conflict'),
        content: Text('${line.substring('conflict:'.length).trim()}\n\nThe main tree is left as git left it. Send "resolve the merge of ${widget.worktree}" to the main session?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(d).pop(false), child: const Text('LEAVE IT')),
          FilledButton(onPressed: () => Navigator.of(d).pop(true), child: const Text('SEND')),
        ],
      ),
    );
    if (send == true && mounted) await _run('resolve_merge');
  }

  Future<void> _remove() async {
    var line = await _op('worktree_remove');
    if (!mounted) return;
    if (line.startsWith('dirty:')) {
      final force = await showDialog<bool>(
        context: context,
        builder: (d) => AlertDialog(
          title: const Text('Remove the worktree?'),
          content: Text('${line.substring('dirty:'.length).trim()}. Removing anyway loses those changes; the branch stays.'),
          actions: [
            TextButton(onPressed: () => Navigator.of(d).pop(false), child: const Text('CANCEL')),
            FilledButton(onPressed: () => Navigator.of(d).pop(true), child: const Text('FORCE')),
          ],
        ),
      );
      if (force != true || !mounted) return;
      line = await _op('worktree_remove', message: 'force');
      if (!mounted) return;
    }
    _toast(line);
    // The tree is gone and this screen was its own: back to the list
    // rather than an empty Deck for an entry that no longer exists.
    if (line.startsWith('worktree ') && line.contains(' removed')) Navigator.of(context).maybePop();
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
              if (widget.worktree != null) Text('WORKTREE', style: t.readout(11, color: t.accent)),
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
              if (widget.canAddWorktree) OutlinedButton(onPressed: busy || g == null || !g.ok ? null : _newTree, child: Text(_busy == 'worktree_add' ? 'ADDING…' : 'NEW TREE')),
              if (widget.worktree != null) ...[
                OutlinedButton(onPressed: busy || g == null || !g.ok ? null : _merge, child: Text(_busy == 'merge' ? 'MERGING…' : _busy == 'resolve_merge' ? 'SENDING…' : 'MERGE INTO MAIN')),
                OutlinedButton(onPressed: busy ? null : _remove, child: Text(_busy == 'worktree_remove' ? 'REMOVING…' : 'REMOVE')),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// The name of a new worktree — its branch and its folder.
class _NameDialog extends StatefulWidget {
  const _NameDialog();

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  final _name = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('New worktree'),
        content: TextField(
          controller: _name,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'settings — the branch and the folder', isDense: true),
          onSubmitted: (v) => Navigator.of(context).pop(v),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('CANCEL')),
          FilledButton(onPressed: () => Navigator.of(context).pop(_name.text), child: const Text('CREATE')),
        ],
      );
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
