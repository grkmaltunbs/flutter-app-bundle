import 'package:flutter/material.dart' hide Step, StepState;
import 'package:flutter_kit/kit.dart' show DeckMessage, DeckRole;

import '../host/bridge_session.dart';
import '../screens/ask_card.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'studio_desk.dart';
import 'studio_draft.dart';
import 'studio_media.dart';
import 'studio_media_view.dart';
import 'studio_source.dart';

/// One step's thread with the step desk: every question asked about it and
/// every answer, the live reply streaming in, a permission the desk asks for,
/// and the changes it proposes — each one tap from the draft. The composer
/// asks the next question in the same conversation.
class StepThreadScreen extends StatefulWidget {
  const StepThreadScreen({super.key, required this.title, required this.about, required this.stepText, required this.desk, required this.threads, this.draft, this.subtitle});
  final String title;
  final String? subtitle;
  final Map<String, Object?> about;

  /// The step as its file holds it — shown to the desk with every question.
  final String stepText;
  final BridgeSession desk;
  final StudioThreads threads;
  final StudioDraft? draft;

  @override
  State<StepThreadScreen> createState() => _StepThreadScreenState();
}

class _StepThreadScreenState extends State<StepThreadScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  bool _sending = false;
  String? _error;

  String get key => threadKeyOf(widget.about)!;

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    final err = await askDesk(widget.desk, widget.threads, about: widget.about, stepText: widget.stepText, text: text);
    if (err != null) {
      setState(() {
        _sending = false;
        _error = err;
      });
      return;
    }
    _input.clear();
    setState(() => _sending = false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.animateTo(_scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    });
  }

  /// The saved rows, then this session's rows about the step that are not saved yet.
  List<DeckMessage> _rows() {
    final saved = widget.threads.rows(key);
    final sid = widget.desk.sessionId ?? 'x';
    final ids = {for (final r in saved) r.id};
    final live = [
      for (final m in widget.desk.transcript.messages)
        if (threadKeyOf(m.about) == key && m.role != DeckRole.note && !ids.contains('$sid-${m.id}')) m,
    ];
    return [...saved, ...live];
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Scaffold(
      appBar: AppBar(title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        Text('STEP DESK · ASK ANYTHING ABOUT THIS STEP', style: t.readout(9, color: t.muted)),
      ])),
      body: ListenableBuilder(
        listenable: Listenable.merge([widget.desk, widget.threads, if (widget.draft != null) widget.draft!]),
        builder: (context, _) {
          final rows = _rows();
          final b = widget.desk;
          final mine = b.transcript.messages.any((m) => threadKeyOf(m.about) == key);
          final busyHere = b.transcript.turnOpen && mine && threadKeyOf(b.transcript.messages.lastOrNull?.about) == key;
          final ask = b.transcript.pending;
          return Column(children: [
            Expanded(
              child: ListView(
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                children: [
                  if (widget.subtitle != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(color: t.surface, borderRadius: BorderRadius.circular(10), border: Border.all(color: t.line)),
                      child: Text(widget.subtitle!, maxLines: 4, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, color: t.ink2, height: 1.4)),
                    ),
                  if (rows.isEmpty) const EmptyNote('No questions yet. Ask why it is next, what it waits on, what it changes — the desk reads the lane\'s files to answer.'),
                  for (final m in rows) _Row(message: m, draft: widget.draft),
                  if (busyHere) Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Row(children: [ThinkingDots(color: t.accent), const SizedBox(width: 8), Text('the desk is reading', style: t.mono(11, color: t.muted))])),
                  if (ask != null) Padding(padding: const EdgeInsets.only(top: 8), child: AskCard(ask: ask, onAnswer: (a, {bool remember = false}) => b.answer(a, remember: remember))),
                  if (_error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_error!, style: TextStyle(color: t.critical))),
                ],
              ),
            ),
            SafeArea(
              top: false,
              child: Container(
                decoration: BoxDecoration(color: t.surface, border: Border(top: BorderSide(color: t.line))),
                padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
                child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Expanded(
                    child: TextField(
                      controller: _input,
                      minLines: 1,
                      maxLines: 5,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: const InputDecoration(hintText: 'Ask about this step…', border: OutlineInputBorder(), isDense: true),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(tooltip: 'Ask', onPressed: _sending ? null : _send, icon: _sending ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.send)),
                ]),
              ),
            ),
          ]);
        },
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.message, this.draft});
  final DeckMessage message;
  final StudioDraft? draft;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final m = message;
    switch (m.role) {
      case DeckRole.user:
        // The scoped prompt carries the step's text; show what was typed.
        var typed = m.text.replaceFirst(RegExp(r'^\[Studio desk · [^\]]*\]\s*'), '').split('\n--- as its file holds it ---').first.trim();
        if (typed == kSummarize) typed = 'Explain what this step is for.';
        return Align(
          alignment: Alignment.centerRight,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 520),
            margin: const EdgeInsets.only(top: 10, bottom: 4, left: 40),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(color: t.bubble, borderRadius: BorderRadius.circular(12), border: Border.all(color: t.line)),
            child: Text(typed, style: TextStyle(fontSize: 14, color: t.ink, height: 1.35)),
          ),
        );
      case DeckRole.tool:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 1),
          child: Text('▸ ${m.toolSummary}', maxLines: 1, overflow: TextOverflow.ellipsis, style: t.mono(10.5, color: t.muted)),
        );
      case DeckRole.assistant:
        final parts = splitAnswer(m.text);
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (parts.summary != null) _SummaryCard(text: parts.summary!),
            if (parts.prose.isNotEmpty) Md(parts.prose),
            InlineMedia(paths: mediaPathsIn(parts.prose, resolve: StudioSource.current?.finderFor(null).resolve)),
            for (final o in parts.proposals) _ProposalCard(order: o, draft: draft),
          ]),
        );
      case DeckRole.note:
        return const SizedBox.shrink();
    }
  }
}

/// A change the desk proposes: what it would do, and ADD TO DRAFT.
class _ProposalCard extends StatelessWidget {
  const _ProposalCard({required this.order, this.draft});
  final DraftOrder order;
  final StudioDraft? draft;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final d = draft;
    final inDraft = d != null && d.orders.any((o) => o.kind == order.kind && o.lane == order.lane && o.target == order.target && o.other == order.other && o.text == order.text && o.newId == order.newId);
    const violet = Color(0xFFC79BFF);
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: violet.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10), border: Border.all(color: violet.withValues(alpha: 0.7))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('PROPOSED CHANGE', style: t.readout(9.5, color: violet)),
        const SizedBox(height: 4),
        Text(order.summary, style: TextStyle(fontSize: 14, color: t.ink, fontWeight: FontWeight.w600)),
        if (order.text != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(order.text!, maxLines: 8, overflow: TextOverflow.ellipsis, style: t.mono(11.5, color: t.ink2))),
        const SizedBox(height: 8),
        if (d != null)
          inDraft
              ? Row(children: [Icon(Icons.check, size: 16, color: t.good), const SizedBox(width: 4), Text('IN THE DRAFT', style: t.readout(10, color: t.good))])
              : FilledButton.tonalIcon(onPressed: () => d.add(order), icon: const Icon(Icons.add, size: 16), label: const Text('ADD TO DRAFT')),
      ]),
    );
  }
}


class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: t.accentSoft, borderRadius: BorderRadius.circular(10), border: Border.all(color: t.accent.withValues(alpha: 0.5))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('WHAT IT IS FOR', style: t.readout(9.5, color: t.accent)),
        const SizedBox(height: 4),
        Text(text, style: TextStyle(fontSize: 14, color: t.ink, height: 1.4)),
      ]),
    );
  }
}
