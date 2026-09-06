import 'dart:async';

import 'package:flutter/material.dart' hide Step, StepState;
import 'package:flutter/services.dart';

import '../theme.dart';

/// The run's log: a monospaced tail that follows the newest line, with
/// PAUSE (stop following), a find that keeps only the lines matching,
/// and COPY. [lines] is the whole log as it grows — the relay's documents
/// on the phone, the bay's ring on the Mac.
Future<void> showLogSheet(BuildContext context, {required Stream<List<String>> lines, required String title, List<String> initial = const []}) {
  final t = context.tokens;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: t.surface,
    builder: (sheet) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      maxChildSize: 0.96,
      builder: (context, ctrl) => LogView(lines: lines, title: title, initial: initial, controller: ctrl),
    ),
  );
}

class LogView extends StatefulWidget {
  const LogView({super.key, required this.lines, required this.title, this.initial = const [], this.controller});
  final Stream<List<String>> lines;
  final String title;
  final List<String> initial;
  final ScrollController? controller;

  @override
  State<LogView> createState() => _LogViewState();
}

class _LogViewState extends State<LogView> {
  late List<String> _all = widget.initial;
  StreamSubscription<List<String>>? _sub;
  final _find = TextEditingController();
  late final ScrollController _scroll = widget.controller ?? ScrollController();
  bool _paused = false;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _sub = widget.lines.listen((l) {
      if (!mounted) return;
      setState(() => _all = l);
      if (!_paused) _toEnd();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _toEnd());
  }

  void _toEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _find.dispose();
    if (widget.controller == null) _scroll.dispose();
    super.dispose();
  }

  List<String> get _shown {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _all;
    return [for (final l in _all) if (l.toLowerCase().contains(q)) l];
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final shown = _shown;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
          child: Row(
            children: [
              Expanded(child: Text(widget.title.toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis, style: t.readout(11))),
              Text('${shown.length}${_query.trim().isEmpty ? '' : ' / ${_all.length}'}', style: t.readout(10, color: t.muted)),
              TextButton(
                onPressed: () => setState(() {
                  _paused = !_paused;
                  if (!_paused) _toEnd();
                }),
                child: Text(_paused ? 'FOLLOW' : 'PAUSE'),
              ),
              TextButton(
                onPressed: shown.isEmpty
                    ? null
                    : () {
                        Clipboard.setData(ClipboardData(text: shown.join('\n')));
                        ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text('Copied ${shown.length} lines')));
                      },
                child: const Text('COPY'),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
          child: TextField(
            controller: _find,
            style: t.mono(12),
            decoration: InputDecoration(isDense: true, hintText: 'Find', prefixIcon: const Icon(Icons.search, size: 18), suffixIcon: _query.isEmpty ? null : IconButton(icon: const Icon(Icons.close, size: 16), onPressed: () => setState(() => _query = (_find..clear()).text))),
            onChanged: (v) => setState(() => _query = v),
          ),
        ),
        Expanded(
          child: shown.isEmpty
              ? Center(child: Text(_all.isEmpty ? 'Nothing yet.' : 'No line matches.', style: t.mono(12, color: t.muted)))
              : SelectionArea(
                  child: ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    itemCount: shown.length,
                    itemBuilder: (context, i) {
                      final l = shown[i];
                      final bad = l.contains('EXCEPTION CAUGHT') || l.contains('Unhandled Exception');
                      return Text(l, style: t.mono(11, color: bad ? t.warn : t.ink2));
                    },
                  ),
                ),
        ),
      ],
    );
  }
}
