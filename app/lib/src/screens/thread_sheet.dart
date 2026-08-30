import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart' hide Step, StepState;
import 'package:flutter_kit/kit.dart';

import '../theme.dart';
import '../widgets/common.dart';

/// One thread: everything ever asked about one item or step, and the
/// composer that asks more. Both devices read the same collection; the
/// send goes to whichever session the surface drives.
Future<void> showThreadSheet(
  BuildContext context, {
  required FirebaseFirestore db,
  required String slug,
  required Map<String, Object?> about,
  required String title,
  required bool running,
  required Future<String?> Function(String text) onSend,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: context.tokens.surface,
    builder: (_) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.72,
      maxChildSize: 0.96,
      builder: (context, ctrl) => ThreadView(db: db, slug: slug, about: about, title: title, running: running, onSend: onSend, controller: ctrl),
    ),
  );
}

class ThreadView extends StatefulWidget {
  const ThreadView({super.key, required this.db, required this.slug, required this.about, required this.title, required this.running, required this.onSend, this.controller});
  final FirebaseFirestore db;
  final String slug;
  final Map<String, Object?> about;
  final String title;
  final bool running;

  /// Sends one scoped message; a returned string is the reason it could not.
  final Future<String?> Function(String text) onSend;
  final ScrollController? controller;

  @override
  State<ThreadView> createState() => _ThreadViewState();
}

class _ThreadViewState extends State<ThreadView> {
  final _input = TextEditingController();
  bool _sending = false;

  String get _kind => widget.about.containsKey('item') ? 'item' : 'step';

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    final err = await widget.onSend(text);
    if (!mounted) return;
    setState(() => _sending = false);
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
    } else {
      _input.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final key = threadKey(widget.about)!;
    final messages = widget.db.collection('projects').doc(widget.slug).collection('threads').doc(key).collection('messages').snapshots();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('ASK ABOUT THIS ${_kind.toUpperCase()}', style: t.readout(11, color: t.accent)),
              const SizedBox(height: 4),
              Text(widget.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: t.display(17, weight: FontWeight.w600, ls: 0.3, height: 1.2)),
            ],
          ),
        ),
        Divider(height: 1, color: t.line),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: messages,
            builder: (context, snap) {
              if (snap.hasError) return EmptyNote('Could not read the thread: ${snap.error}');
              if (!snap.hasData) return const Center(child: CircularProgressIndicator());
              final rows = snap.data!.docs.map((d) => DeckMessage.fromMap({for (final e in d.data().entries) e.key: e.value as Object?})).toList()
                ..sort((a, b) {
                  final c = a.at.compareTo(b.at);
                  return c != 0 ? c : a.id.compareTo(b.id);
                });
              if (rows.isEmpty) {
                return EmptyNote('Nothing asked yet. Claude answers from this $_kind\'s own facts — and edits it when the answer should live in the plan.');
              }
              return ListView.builder(
                controller: widget.controller,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                itemCount: rows.length,
                itemBuilder: (context, i) => _ThreadRow(message: rows[i]),
              );
            },
          ),
        ),
        SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
            decoration: BoxDecoration(color: t.bg, border: Border(top: BorderSide(color: t.line))),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: _input,
                    enabled: widget.running && !_sending,
                    minLines: 1,
                    maxLines: 3,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _send(),
                    style: TextStyle(fontSize: 15, color: t.ink),
                    decoration: InputDecoration(hintText: widget.running ? 'Ask about this $_kind…' : 'Session not running — start it on the Deck'),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 48,
                  height: 48,
                  child: FilledButton(
                    style: FilledButton.styleFrom(padding: EdgeInsets.zero, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    onPressed: widget.running && !_sending ? _send : null,
                    child: const Icon(Icons.arrow_forward, size: 20),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ThreadRow extends StatelessWidget {
  const _ThreadRow({required this.message});
  final DeckMessage message;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final m = message;
    switch (m.role) {
      case DeckRole.user:
        return Padding(
          padding: const EdgeInsets.only(bottom: 10, left: 40),
          child: Align(
            alignment: Alignment.centerRight,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: t.bubble,
                border: Border.all(color: t.line),
                borderRadius: const BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12), bottomLeft: Radius.circular(12), bottomRight: Radius.circular(4)),
              ),
              child: SelectableText(m.text, style: TextStyle(fontSize: 14, height: 1.4, color: t.ink)),
            ),
          ),
        );
      case DeckRole.assistant:
        return Padding(
          padding: const EdgeInsets.only(bottom: 12, right: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(width: 14, height: 2, color: t.accent),
                const SizedBox(width: 8),
                Flexible(child: Text('CLAUDE · ${_hm(m.at)}', maxLines: 1, overflow: TextOverflow.ellipsis, style: t.readout(10.5))),
              ]),
              const SizedBox(height: 5),
              Md(m.text, color: t.ink),
            ],
          ),
        );
      case DeckRole.tool:
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(color: t.surface, borderRadius: BorderRadius.circular(6), border: Border.all(color: t.line)),
            child: Row(children: [
              Icon(m.isError ? Icons.error_outline : Icons.check, size: 11, color: m.isError ? t.critical : t.good),
              const SizedBox(width: 8),
              Expanded(child: Text(m.toolSummary, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.mono(11, color: t.ink2))),
            ]),
          ),
        );
      case DeckRole.note:
        if (m.text.startsWith('UPDATED')) return UpdatedStrip(text: m.text);
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(m.text, style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: t.muted)),
        );
    }
  }

  static String _hm(DateTime at) {
    final l = at.toLocal();
    return '${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}';
  }
}

/// The strip that says Claude changed the thing itself.
class UpdatedStrip extends StatelessWidget {
  const UpdatedStrip({super.key, required this.text, this.ago});
  final String text;
  final String? ago;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: t.accentSoft.withValues(alpha: t.brightness == Brightness.dark ? 0.4 : 1),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: t.accent.withValues(alpha: 0.22)),
        ),
        child: Row(children: [
          Icon(Icons.add, size: 11, color: t.accent),
          const SizedBox(width: 6),
          Expanded(child: Text(text.toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis, style: t.readout(10.5, color: t.accent))),
          if (ago != null) Text(ago!, style: t.mono(10.5, color: t.muted)),
        ]),
      ),
    );
  }
}
