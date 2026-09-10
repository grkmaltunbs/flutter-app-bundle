import 'package:flutter/material.dart' hide Step, StepState;
import 'package:flutter_kit/kit.dart' show rulesClaudeMd, rulesLabel, rulesTargets;
import 'package:path/path.dart' as p;

import '../host/host_actions.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// The user's part of the standing brief: the kit's fixed lines folded
/// above, a plain field for this project's rules, Save at the bottom.
/// [onSave] is the host's line back — when the brief applies.
class BriefEditorScreen extends StatefulWidget {
  const BriefEditorScreen({super.key, required this.fixed, required this.current, required this.onSave});
  final String fixed;
  final String current;
  final Future<String> Function(String text) onSave;

  @override
  State<BriefEditorScreen> createState() => _BriefEditorScreenState();
}

Future<void> showBriefEditor(BuildContext context, {required String fixed, required String current, required Future<String> Function(String text) onSave}) =>
    Navigator.of(context).push(MaterialPageRoute<void>(fullscreenDialog: true, builder: (_) => BriefEditorScreen(fixed: fixed, current: current, onSave: onSave)));

class _BriefEditorScreenState extends State<BriefEditorScreen> {
  late final _c = TextEditingController(text: widget.current);
  bool _saving = false;
  bool _dirty = false;
  String? _line;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _line = null;
    });
    try {
      final r = await widget.onSave(_c.text);
      if (!mounted) return;
      setState(() {
        _line = r;
        _dirty = false;
      });
    } on Object catch (e) {
      if (mounted) setState(() => _line = 'Could not save: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Scaffold(
      appBar: AppBar(title: const Text('Brief')),
      // The body scrolls as one; Save is the bottom bar, so it stays
      // reachable at every text size.
      bottomNavigationBar: _SaveBar(
        note: 'Kept on the Mac beside the session options.',
        line: _line,
        lineIsError: _line != null && _line!.startsWith('Could not'),
        saving: _saving,
        onSave: _save,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
          ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(horizontal: 16),
            title: Text('What every session is told', style: t.display(15, weight: FontWeight.w600, ls: 0.4)),
            subtitle: Text('The kit\'s lines, fixed. Your block goes under them.', style: TextStyle(fontSize: 12.5, color: t.ink2)),
            children: [
              Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 12), child: SelectableText(widget.fixed, style: t.mono(11.5, color: t.ink2))),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: Text('THIS PROJECT\'S BRIEF${_dirty ? ' · UNSAVED' : ''}', style: t.readout(10.5, color: _dirty ? t.warn : null)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _c,
              minLines: 8,
              maxLines: null,
              keyboardType: TextInputType.multiline,
              textAlignVertical: TextAlignVertical.top,
              style: t.mono(13, color: t.ink),
              onChanged: (_) {
                if (!_dirty) setState(() => _dirty = true);
              },
              decoration: InputDecoration(
                hintText: 'Standing rules for this project — "Always answer in Turkish", "Never touch main". Read by the session at its next Start.',
                hintMaxLines: 4,
                alignLabelWithHint: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
          ],
        ),
      ),
    );
  }
}

/// The editors' bottom bar: the host's last line, a note, and SAVE — a
/// column, so the largest text sizes stack rather than overflow.
class _SaveBar extends StatelessWidget {
  const _SaveBar({required this.note, required this.line, required this.lineIsError, required this.saving, required this.onSave});
  final String note;
  final String? line;
  final bool lineIsError;
  final bool saving;
  final VoidCallback? onSave;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Material(
      color: t.surface,
      child: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
          decoration: BoxDecoration(border: Border(top: BorderSide(color: t.line))),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (line case final l?) Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(l, maxLines: 3, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, color: lineIsError ? t.critical : t.ink2))),
              Row(
                children: [
                  Expanded(child: Text(note, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: t.muted))),
                  const SizedBox(width: 10),
                  FilledButton.icon(
                    onPressed: saving ? null : onSave,
                    icon: saving ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save_outlined, size: 18),
                    label: Text(saving ? 'SAVING…' : 'SAVE', maxLines: 1),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// `CLAUDE.md` and the plan's qa note in a plain editor with the mono
/// face. [read] is the host's file (with its stamp); [write] hands the
/// text back with that stamp and returns the host's line — a save over a
/// file that changed meanwhile is refused, and the editor offers to
/// reload.
class RulesEditorScreen extends StatefulWidget {
  const RulesEditorScreen({super.key, required this.read, required this.write, this.initialPath = rulesClaudeMd, this.targets = rulesTargets});
  final Future<FileRead> Function(String path) read;
  final Future<String> Function(String path, String text, {int? base}) write;
  final String initialPath;
  final List<String> targets;

  @override
  State<RulesEditorScreen> createState() => _RulesEditorScreenState();
}

Future<void> showRulesEditor(BuildContext context, {required Future<FileRead> Function(String path) read, required Future<String> Function(String path, String text, {int? base}) write, String initialPath = rulesClaudeMd}) =>
    Navigator.of(context).push(MaterialPageRoute<void>(fullscreenDialog: true, builder: (_) => RulesEditorScreen(read: read, write: write, initialPath: initialPath)));

class _RulesEditorScreenState extends State<RulesEditorScreen> {
  late String _path = widget.initialPath;
  final _c = TextEditingController();
  FileRead? _file;
  String? _error;
  bool _loading = true;
  bool _saving = false;
  bool _dirty = false;
  String? _line;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _line = null;
    });
    try {
      final f = await widget.read(_path);
      if (!mounted) return;
      setState(() {
        _file = f;
        _c.text = f.ok ? f.text : '';
        _dirty = false;
      });
    } on Object catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _switchTo(String path) async {
    if (path == _path) return;
    if (_dirty) {
      final drop = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Unsaved changes'),
          content: Text('${rulesLabel(_path)} has changes you have not saved. Drop them?'),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('KEEP EDITING')),
            TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('DROP')),
          ],
        ),
      );
      if (drop != true || !mounted) return;
    }
    setState(() => _path = path);
    await _load();
  }

  static bool isStale(String line) => line.startsWith('refused: changed on disk');

  Future<void> _save() async {
    final f = _file;
    if (f == null || !f.ok) return;
    setState(() {
      _saving = true;
      _line = null;
    });
    String r;
    try {
      r = await widget.write(_path, _c.text, base: f.stamp);
    } on Object catch (e) {
      r = 'Could not save: $e';
    }
    if (!mounted) return;
    setState(() => _saving = false);
    if (isStale(r)) {
      // The file moved under the editor: nothing was written. Reload to
      // see it, or keep the text here to carry over by hand.
      final reload = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Changed on the Mac'),
          content: Text('${rulesLabel(_path)} changed on disk since you opened it, so nothing was saved. Reload to see it — your edits here go with the reload.'),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('KEEP EDITING')),
            FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('RELOAD')),
          ],
        ),
      );
      if (!mounted) return;
      if (reload == true) {
        await _load();
      } else {
        setState(() => _line = r);
      }
      return;
    }
    setState(() => _line = r);
    if (r.startsWith('saved') || r == 'nothing changed') {
      // The disk now holds this text: read it again for the new stamp.
      final line = r;
      await _load();
      if (mounted) setState(() => _line = line);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final f = _file;
    final refused = f != null && !f.ok;
    final failed = _line != null && (_line!.startsWith('refused') || _line!.startsWith('Could not') || _line!.startsWith('saved, not'));
    return Scaffold(
      appBar: AppBar(
        title: Text(p.basename(_path == rulesClaudeMd ? _path : rulesLabel(_path)), maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [IconButton(tooltip: 'Reload', icon: const Icon(Icons.refresh), onPressed: _loading ? null : _load)],
      ),
      bottomNavigationBar: _SaveBar(
        note: 'Save writes the file on the Mac and commits just that file.',
        line: _line,
        lineIsError: failed,
        saving: _saving,
        onSave: _saving || _loading || f == null || !f.ok || f.truncated ? null : _save,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
          if (widget.targets.length > 1)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final target in widget.targets)
                    ChoiceChip(label: Text(rulesLabel(target).toUpperCase()), selected: target == _path, onSelected: (_) => _switchTo(target)),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
            child: Text(
              [
                _path,
                if (f != null && f.ok) '${f.lines} line${f.lines == 1 ? '' : 's'}',
                if (f != null && f.truncated) 'the first ${(f.text.length / 1024).round()} KB only — too big to edit here',
                if (_dirty) 'unsaved',
              ].join(' · ').toUpperCase(),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: t.readout(10.5, color: _dirty ? t.warn : (f != null && f.truncated ? t.critical : t.muted)),
            ),
          ),
          if (_loading)
            const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))
          else if (_error != null)
            EmptyNote(_error!)
          else if (refused)
            EmptyNote('Refused: ${f.refused}')
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _c,
                minLines: 12,
                maxLines: null,
                keyboardType: TextInputType.multiline,
                textAlignVertical: TextAlignVertical.top,
                style: t.mono(12.5, color: t.ink, height: 1.45),
                onChanged: (_) {
                  if (!_dirty) setState(() => _dirty = true);
                },
                decoration: InputDecoration(
                  hintText: _path == rulesClaudeMd ? 'The rules Claude Code reads in this project.' : 'The qa note: what the /step workflow must know about this project\'s QA.',
                  hintMaxLines: 3,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
