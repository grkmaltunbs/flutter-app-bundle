import 'package:flutter/material.dart' hide Step, StepState;
import 'package:flutter_kit/kit.dart';

import '../host/bridge_session.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'ask_card.dart';

/// The conversation with this project's session: what was said, what ran,
/// and — pinned above the composer — what Claude is asking. The host owns
/// the process; this widget only renders the transcript and sends.
class DeckTab extends StatefulWidget {
  const DeckTab({super.key, required this.bridge});
  final BridgeSession bridge;

  @override
  State<DeckTab> createState() => _DeckTabState();
}

class _DeckTabState extends State<DeckTab> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _focus = FocusNode();
  int _seen = 0;

  static const _chips = ['/step', '/qa', '/next', '/plan-status'];

  @override
  void initState() {
    super.initState();
    widget.bridge.addListener(_follow);
  }

  @override
  void dispose() {
    widget.bridge.removeListener(_follow);
    _input.dispose();
    _scroll.dispose();
    _focus.dispose();
    super.dispose();
  }

  /// Keeps the newest row in view while the transcript grows.
  void _follow() {
    final n = widget.bridge.transcript.messages.length;
    final grew = n != _seen;
    _seen = n;
    if (!grew && !widget.bridge.transcript.turnOpen) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  void _send() {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    widget.bridge.send(text);
    _input.clear();
    _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final b = widget.bridge;
    return ListenableBuilder(
      listenable: b,
      builder: (context, _) {
        final tr = b.transcript;
        return LayoutBuilder(
          builder: (context, box) => Column(
            children: [
              _Header(bridge: b),
              Expanded(
                child: tr.messages.isEmpty
                    ? EmptyNote(b.running ? 'Session ready. Ask, or give an order.' : 'Start a session to talk to Claude Code in this folder.')
                    : ListView.builder(
                        controller: _scroll,
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                        itemCount: tr.messages.length,
                        itemBuilder: (context, i) => _Row(message: tr.messages[i]),
                      ),
              ),
              // The ask and the composer share the bottom; at the largest
              // text sizes a question card grows past the screen, so the
              // bottom scrolls inside its own share and the transcript keeps
              // the rest, instead of a Column overflowing.
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: box.maxHeight * 0.6),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (tr.pending != null)
                        AskCard(
                          key: ValueKey(tr.pending!.requestId),
                          ask: tr.pending!,
                          here: 'Mac',
                          onAnswer: (a, {remember = false}) => b.answer(a, remember: remember),
                        ),
                      SafeArea(
                        top: false,
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                          decoration: BoxDecoration(color: t.surface, border: Border(top: BorderSide(color: t.line))),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: [
                                    for (final c in _chips)
                                      Padding(
                                        padding: const EdgeInsets.only(right: 6),
                                        child: ActionChip(
                                          label: Text(c, style: const TextStyle(fontFamily: 'menlo')),
                                          onPressed: b.running
                                              ? () {
                                                  _input.text = c;
                                                  _focus.requestFocus();
                                                }
                                              : null,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: _input,
                                      focusNode: _focus,
                                      enabled: b.running,
                                      minLines: 1,
                                      maxLines: 3,
                                      textInputAction: TextInputAction.send,
                                      onSubmitted: (_) => _send(),
                                      decoration: InputDecoration(hintText: b.running ? 'Ask, or give an order…' : 'Not running'),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  SizedBox(
                                    height: 44,
                                    child: FilledButton(onPressed: b.running ? _send : null, child: const Icon(Icons.arrow_forward, size: 20)),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.bridge});
  final BridgeSession bridge;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final b = bridge;
    final prev = b.running ? null : b.previous();
    final color = switch (b.state) {
      BridgeState.waiting => t.warn,
      BridgeState.busy || BridgeState.ready || BridgeState.starting => t.good,
      BridgeState.failed => t.critical,
      _ => t.muted,
    };
    final label = switch (b.state) {
      BridgeState.waiting => 'needs you',
      BridgeState.busy => 'working',
      BridgeState.ready => 'ready',
      BridgeState.starting => 'starting',
      BridgeState.stopped => 'stopped',
      BridgeState.failed => 'failed',
      BridgeState.idle => 'idle',
    };
    final facts = <String>[
      if (b.sessionId != null) 'session ${b.sessionId!.substring(0, 8)}',
      if (b.transcript.model != null) b.transcript.model!,
      if (b.cliVersion != null) 'claude ${b.cliVersion}${b.cliVersion == bridgeProvenOn ? '' : ' (proven on $bridgeProvenOn)'}',
      if (b.transcript.pool?.resetsAt != null) 'pool resets ${_hm(b.transcript.pool!.resetsAt!)}',
    ];
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
      decoration: BoxDecoration(color: t.surface, border: Border(bottom: BorderSide(color: t.line))),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 10,
        runSpacing: 6,
        children: [
          Pill(label, color: color, filled: b.state == BridgeState.waiting),
          if (facts.isNotEmpty) Text(facts.join(' · '), maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: t.muted)),
          if (b.error != null) Text(b.error!, maxLines: 3, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, color: t.critical)),
          if (!b.running) FilledButton.icon(onPressed: () => b.start(), icon: const Icon(Icons.play_arrow, size: 18), label: const Text('Start')),
          if (!b.running && prev != null) OutlinedButton(onPressed: () => b.start(resume: true), child: Text('Resume ${prev.sessionId.substring(0, 8)}')),
          if (b.running) OutlinedButton.icon(onPressed: () => b.stop(), icon: const Icon(Icons.stop, size: 18), label: const Text('Stop')),
        ],
      ),
    );
  }

  static String _hm(DateTime at) {
    final l = at.toLocal();
    return '${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}';
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.message});
  final DeckMessage message;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final m = message;
    switch (m.role) {
      case DeckRole.user:
        return Padding(
          padding: const EdgeInsets.only(bottom: 12, left: 48),
          child: Align(
            alignment: Alignment.centerRight,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: t.accentSoft, borderRadius: const BorderRadius.only(topLeft: Radius.circular(14), topRight: Radius.circular(14), bottomLeft: Radius.circular(14), bottomRight: Radius.circular(4))),
              child: SelectableText(m.text, style: TextStyle(fontSize: 14, height: 1.4, color: t.ink)),
            ),
          ),
        );
      case DeckRole.assistant:
        return Padding(
          padding: const EdgeInsets.only(bottom: 14, right: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(width: 14, height: 2, color: t.accent),
                const SizedBox(width: 8),
                // Loose: at the largest text sizes the caption is wider than a phone.
                Flexible(child: Text('CLAUDE · ${_hm(m.at)}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, letterSpacing: 1, color: t.muted))),
              ]),
              const SizedBox(height: 6),
              if (m.text.isEmpty && m.streaming) Text('…', style: TextStyle(color: t.muted)) else Md(m.streaming ? '${m.text} ▍' : m.text),
            ],
          ),
        );
      case DeckRole.tool:
        final done = m.toolResult != null;
        final color = m.isError ? t.critical : (done ? t.good : t.accent);
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(color: t.bg, borderRadius: BorderRadius.circular(8), border: Border.all(color: t.line)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Icon(m.isError ? Icons.error_outline : (done ? Icons.check : Icons.play_arrow), size: 13, color: color),
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(m.toolSummary, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: 'menlo', fontSize: 12, color: t.ink2))),
                  ],
                ),
                if (done && m.toolResult!.trim().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4, left: 21),
                    child: Text(m.toolResult!.trim(), maxLines: 3, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: 'menlo', fontSize: 11.5, color: m.isError ? t.critical : t.muted)),
                  ),
              ],
            ),
          ),
        );
      case DeckRole.note:
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text(m.text, style: TextStyle(fontSize: 12.5, fontStyle: FontStyle.italic, color: t.muted)),
        );
    }
  }

  static String _hm(DateTime at) {
    final l = at.toLocal();
    return '${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}';
  }
}
