import 'dart:math' as math;

import 'package:flutter/material.dart' hide Step, StepState;
import 'package:path/path.dart' as p;

import '../host/host_actions.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/diff_view.dart';

/// A file on the Mac, from a tap: monospaced, line numbers, a find field.
/// **Ask about this** pops with `path:line`, the scope the composer takes.
/// [load] is the Mac's disk or the relay; [onRevert], when the host can,
/// is `git checkout -- <path>` behind a confirm.
class FileViewScreen extends StatefulWidget {
  const FileViewScreen({super.key, required this.path, required this.load, this.onRevert});
  final String path;
  final Future<FileRead> Function() load;
  final Future<String> Function()? onRevert;

  @override
  State<FileViewScreen> createState() => _FileViewScreenState();
}

class _FileViewScreenState extends State<FileViewScreen> {
  FileRead? _file;
  String? _error;
  List<String> _lines = const [];
  final _find = TextEditingController();
  final _scroll = ScrollController();

  /// The line the last find landed on — what Ask about this names.
  int? _hit;
  int _hits = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _file = null;
      _error = null;
    });
    try {
      final f = await widget.load();
      if (!mounted) return;
      setState(() {
        _file = f;
        _lines = f.text.isEmpty ? const [] : f.text.split('\n');
        if (_lines.isNotEmpty && _lines.last.isEmpty) _lines = _lines.sublist(0, _lines.length - 1);
      });
    } on Object catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  @override
  void dispose() {
    _find.dispose();
    _scroll.dispose();
    super.dispose();
  }

  double _rowHeight(BuildContext context) => MediaQuery.textScalerOf(context).scale(20);

  /// The next line holding the query, after the last hit; wraps.
  void _findNext() {
    final q = _find.text.trim().toLowerCase();
    if (q.isEmpty || _lines.isEmpty) return;
    final start = (_hit ?? -1) + 1;
    int? found;
    for (var i = 0; i < _lines.length; i++) {
      final idx = (start + i) % _lines.length;
      if (_lines[idx].toLowerCase().contains(q)) {
        found = idx;
        break;
      }
    }
    final count = _lines.where((l) => l.toLowerCase().contains(q)).length;
    setState(() {
      _hit = found;
      _hits = count;
    });
    if (found != null && _scroll.hasClients) {
      final y = found * _rowHeight(context) - _rowHeight(context) * 3;
      _scroll.jumpTo(y.clamp(0.0, _scroll.position.maxScrollExtent));
    }
  }

  Future<void> _revert() async {
    final onRevert = widget.onRevert;
    if (onRevert == null) return;
    if (!await confirmRevert(context, widget.path)) return;
    final r = await onRevert();
    if (!mounted) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(r)));
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final f = _file;
    return Scaffold(
      appBar: AppBar(
        title: Text(p.basename(widget.path), maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          if (widget.onRevert != null) IconButton(tooltip: 'Revert file', icon: const Icon(Icons.history), onPressed: f == null || !f.ok ? null : _revert),
          IconButton(
            tooltip: 'Ask about this',
            icon: const Icon(Icons.chat_bubble_outline),
            onPressed: f == null || !f.ok ? null : () => Navigator.of(context).pop('${widget.path}:${(_hit ?? 0) + 1}'),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: TextField(
              controller: _find,
              onSubmitted: (_) => _findNext(),
              textInputAction: TextInputAction.search,
              style: TextStyle(fontSize: 14, color: t.ink),
              decoration: InputDecoration(
                isDense: true,
                hintText: 'Find…',
                prefixIcon: const Icon(Icons.search, size: 18),
                suffixText: _hit == null ? null : '${_hit! + 1} · $_hits',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
          if (f != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
              child: Text(
                [
                  widget.path,
                  if (f.ok) '${f.lines} lines',
                  if (f.truncated) 'first ${(f.text.length / 1024).round()} KB of ${(f.bytes / 1024).round()} KB',
                ].join(' · ').toUpperCase(),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: t.readout(10.5, color: f.truncated ? t.warn : t.muted),
              ),
            ),
          Expanded(
            child: f == null
                ? (_error != null ? EmptyNote(_error!) : const Center(child: CircularProgressIndicator()))
                : !f.ok
                    ? EmptyNote('Refused: ${f.refused}')
                    : _lines.isEmpty
                        ? const EmptyNote('An empty file.')
                        : _body(context, t),
          ),
        ],
      ),
    );
  }

  Widget _body(BuildContext context, KitTokens t) {
    final rowH = _rowHeight(context);
    final scale = MediaQuery.textScalerOf(context).scale(1);
    var longest = 0;
    for (final l in _lines) {
      if (l.length > longest) longest = l.length;
    }
    final gutter = 56.0 * scale;
    return LayoutBuilder(
      builder: (context, box) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: math.max(box.maxWidth, longest * 7.3 * scale + gutter + 24),
          child: ListView.builder(
            controller: _scroll,
            itemExtent: rowH,
            itemCount: _lines.length,
            itemBuilder: (context, i) {
              final hit = _hit == i;
              return Container(
                color: hit ? t.accentSoft : null,
                padding: const EdgeInsets.only(right: 12),
                child: Row(
                  children: [
                    SizedBox(width: gutter, child: Padding(padding: const EdgeInsets.only(right: 10), child: Text('${i + 1}', textAlign: TextAlign.right, style: t.mono(11, color: t.muted)))),
                    Text(_lines[i], softWrap: false, style: t.mono(12, color: hit ? t.ink : t.ink2)),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
