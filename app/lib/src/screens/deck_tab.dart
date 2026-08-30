import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart' hide Step, StepState;
import 'package:flutter_kit/kit.dart';

import '../host/bridge_session.dart';
import '../relay.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'ask_card.dart';
import 'remote_asks.dart';

/// The conversation with this project's session: what was said, what ran,
/// and — pinned above the composer — what Claude is asking. One view, two
/// sources: the host reads its own [BridgeSession]; the phone reads the
/// mirror and sends commands. Neither owns the process from here.
class DeckView extends StatefulWidget {
  const DeckView({
    super.key,
    required this.state,
    required this.facts,
    required this.messages,
    required this.running,
    required this.canResume,
    required this.onStart,
    required this.onResume,
    required this.onStop,
    required this.onSend,
    this.error,
    this.askSlot,
    this.turnOpen = false,
    this.resumeLabel = 'Resume',
    this.here = 'Mac',
  });

  final BridgeState state;
  final List<String> facts;
  final List<DeckMessage> messages;
  final bool running;
  final bool canResume;
  final String? error;

  /// The pending ask, rendered by whoever knows it: the host's card or the
  /// phone's panel.
  final Widget? askSlot;
  final bool turnOpen;
  final String resumeLabel;
  final String here;
  final VoidCallback onStart;
  final VoidCallback onResume;
  final VoidCallback onStop;
  final void Function(String text) onSend;

  @override
  State<DeckView> createState() => _DeckViewState();
}

class _DeckViewState extends State<DeckView> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _focus = FocusNode();
  int _seen = 0;

  static const _chips = ['/step', '/qa', '/next', '/plan-status'];

  @override
  void didUpdateWidget(DeckView old) {
    super.didUpdateWidget(old);
    _follow();
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    _focus.dispose();
    super.dispose();
  }

  /// Keeps the newest row in view while the transcript grows.
  void _follow() {
    final n = widget.messages.length;
    final grew = n != _seen;
    _seen = n;
    if (!grew && !widget.turnOpen) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  void _send() {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    widget.onSend(text);
    _input.clear();
    _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final w = widget;
    return LayoutBuilder(
      builder: (context, box) => Column(
        children: [
          _Header(view: w),
          Expanded(
            child: w.messages.isEmpty
                ? EmptyNote(w.running ? 'Session ready. Ask, or give an order.' : 'Start a session to talk to Claude Code in this folder.')
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    itemCount: w.messages.length,
                    itemBuilder: (context, i) => _Row(message: w.messages[i]),
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
                  if (w.askSlot != null) w.askSlot!,
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
                                      onPressed: w.running
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
                                  enabled: w.running,
                                  minLines: 1,
                                  maxLines: 3,
                                  textInputAction: TextInputAction.send,
                                  onSubmitted: (_) => _send(),
                                  decoration: InputDecoration(hintText: w.running ? 'Ask, or give an order…' : 'Not running'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              SizedBox(
                                height: 44,
                                child: FilledButton(onPressed: w.running ? _send : null, child: const Icon(Icons.arrow_forward, size: 20)),
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
  }
}

/// The host's Deck: straight off its own bridge.
class DeckTab extends StatelessWidget {
  const DeckTab({super.key, required this.bridge});
  final BridgeSession bridge;

  @override
  Widget build(BuildContext context) {
    final b = bridge;
    return ListenableBuilder(
      listenable: b,
      builder: (context, _) {
        final prev = b.running ? null : b.previous();
        final pending = b.transcript.pending;
        return DeckView(
          state: b.state,
          facts: [
            if (b.sessionId != null) 'session ${shortId(b.sessionId!)}',
            if (b.transcript.model != null) b.transcript.model!,
            if (b.cliVersion != null) 'claude ${b.cliVersion}${b.cliVersion == bridgeProvenOn ? '' : ' (proven on $bridgeProvenOn)'}',
            if (b.transcript.pool?.resetsAt != null) 'pool resets ${hm(b.transcript.pool!.resetsAt!)}',
          ],
          error: b.error,
          messages: b.transcript.messages,
          running: b.running,
          canResume: prev != null,
          resumeLabel: prev == null ? 'Resume' : 'Resume ${shortId(prev.sessionId)}',
          turnOpen: b.transcript.turnOpen,
          askSlot: pending == null
              ? null
              : AskCard(
                  key: ValueKey(pending.requestId),
                  ask: pending,
                  here: 'Mac',
                  onAnswer: (a, {remember = false}) => b.answer(a, remember: remember),
                ),
          onStart: () => b.start(),
          onResume: () => b.start(resume: true),
          onStop: () => b.stop(),
          onSend: b.send,
        );
      },
    );
  }
}

/// The phone's Deck: the mirror in, commands out.
class RemoteDeckTab extends StatefulWidget {
  const RemoteDeckTab({super.key, required this.db, required this.slug, this.from = 'phone'});
  final FirebaseFirestore db;
  final String slug;
  final String from;

  @override
  State<RemoteDeckTab> createState() => _RemoteDeckTabState();
}

class _RemoteDeckTabState extends State<RemoteDeckTab> {
  late final RemoteDeck _deck = RemoteDeck(widget.db, widget.slug, from: widget.from)..start();

  @override
  void dispose() {
    _deck.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = _deck;
    return ListenableBuilder(
      listenable: d,
      builder: (context, _) => DeckView(
        state: d.state,
        facts: [
          if (d.sessionId != null) 'session ${shortId(d.sessionId!)}',
          if (d.model != null) d.model!,
          if (d.cliVersion != null) 'claude ${d.cliVersion}',
          if (d.machine != null) d.machine!,
        ],
        error: d.error,
        messages: d.view,
        running: d.running,
        canResume: d.canResume,
        turnOpen: d.turnOpen,
        here: widget.from,
        askSlot: RemoteAskPanel(db: widget.db, slug: widget.slug, from: widget.from),
        onStart: () => d.startSession(),
        onResume: () => d.startSession(resume: true),
        onStop: d.stopSession,
        onSend: d.send,
      ),
    );
  }
}

/// The first block of a uuid — or the whole of anything shorter.
String shortId(String id) => id.length > 8 ? id.substring(0, 8) : id;

String hm(DateTime at) {
  final l = at.toLocal();
  return '${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}';
}

class _Header extends StatelessWidget {
  const _Header({required this.view});
  final DeckView view;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final w = view;
    final color = switch (w.state) {
      BridgeState.waiting => t.warn,
      BridgeState.busy || BridgeState.ready || BridgeState.starting => t.good,
      BridgeState.failed => t.critical,
      _ => t.muted,
    };
    final label = switch (w.state) {
      BridgeState.waiting => 'needs you',
      BridgeState.busy => 'working',
      BridgeState.ready => 'ready',
      BridgeState.starting => 'starting',
      BridgeState.stopped => 'stopped',
      BridgeState.failed => 'failed',
      BridgeState.idle => 'idle',
    };
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
      decoration: BoxDecoration(color: t.surface, border: Border(bottom: BorderSide(color: t.line))),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 10,
        runSpacing: 6,
        children: [
          Pill(label, color: color, filled: w.state == BridgeState.waiting),
          if (w.facts.isNotEmpty) Text(w.facts.join(' · '), maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: t.muted)),
          if (w.error != null) Text(w.error!, maxLines: 3, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, color: t.critical)),
          if (!w.running) FilledButton.icon(onPressed: w.onStart, icon: const Icon(Icons.play_arrow, size: 18), label: const Text('Start')),
          if (!w.running && w.canResume) OutlinedButton(onPressed: w.onResume, child: Text(w.resumeLabel)),
          if (w.running) OutlinedButton.icon(onPressed: w.onStop, icon: const Icon(Icons.stop, size: 18), label: const Text('Stop')),
        ],
      ),
    );
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
              decoration: BoxDecoration(
                color: m.streaming ? t.accentSoft.withValues(alpha: 0.5) : t.accentSoft,
                borderRadius: const BorderRadius.only(topLeft: Radius.circular(14), topRight: Radius.circular(14), bottomLeft: Radius.circular(14), bottomRight: Radius.circular(4)),
              ),
              child: SelectableText(m.text, style: TextStyle(fontSize: 14, height: 1.4, color: m.streaming ? t.ink2 : t.ink)),
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
                Flexible(child: Text('CLAUDE · ${hm(m.at)}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, letterSpacing: 1, color: t.muted))),
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
}
