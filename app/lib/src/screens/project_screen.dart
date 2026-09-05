import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart' hide Step, StepState;
import 'package:flutter_kit/kit.dart';
import 'package:url_launcher/url_launcher.dart';

import '../draft.dart';
import '../host/host_projects.dart';
import '../host/bridge_session.dart';
import '../host/host_project.dart';
import '../plan_source.dart';
import '../relay.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'deck_tab.dart';
import 'remote_asks.dart';
import 'session_tab.dart';
import 'step_detail.dart';
import 'steps_tab.dart';
import 'thread_sheet.dart';
import 'work_tab.dart';

/// One project: Deck · Steps · Your work · (host) Session. The Deck wears
/// the "now" strip; the other tabs keep a one-line readout. The send bar
/// at the bottom is the only way a plan change leaves the device.
class ProjectScreen extends StatefulWidget {
  const ProjectScreen._({required this.source, required this.slug, this.host, this.remoteDoc});

  factory ProjectScreen.host(HostProject host) => ProjectScreen._(source: host.source, slug: host.slug ?? host.dir, host: host);

  factory ProjectScreen.remote({required RemotePlanSource source, required String slug}) => ProjectScreen._(
        source: source,
        slug: slug,
        remoteDoc: FirebaseFirestore.instance.collection('projects').doc(slug).snapshots().map(ProjectSummary.fromDoc),
      );

  final PlanSource source;
  final String slug;
  final HostProject? host;
  final Stream<ProjectSummary>? remoteDoc;

  bool get isHost => host != null;

  @override
  State<ProjectScreen> createState() => _ProjectScreenState();
}

class _ProjectScreenState extends State<ProjectScreen> with SingleTickerProviderStateMixin {
  late final Draft _draft = Draft(widget.slug);
  late final ThreadStore _threads = ThreadStore(FirebaseFirestore.instance, widget.slug)..start();
  late final TabController _tabs = TabController(length: widget.isHost ? 4 : 3, vsync: this);
  ProjectSummary? _summary;
  StreamSubscription<ProjectSummary>? _sub;
  String? _selected;
  bool _sending = false;

  /// The Deck folded its chrome on a drag; the tab strip goes with it.
  bool _chromeHidden = false;

  void _onChromeHidden(bool hidden) {
    if (hidden != _chromeHidden) setState(() => _chromeHidden = hidden);
  }

  @override
  void initState() {
    super.initState();
    _draft.load();
    _sub = widget.remoteDoc?.listen((s) => setState(() => _summary = s));
    // The Deck pins the ask itself; the bottom panel covers the other tabs.
    _tabs.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _sub?.cancel();
    _tabs.dispose();
    _draft.dispose();
    _threads.dispose();
    if (!widget.isHost) widget.source.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final batch = _draft.toBatch();
    setState(() => _sending = true);
    try {
      if (widget.isHost) {
        final r = await widget.host!.applyBatch(batch);
        _toast(r.summary);
      } else {
        await InboxSender(FirebaseFirestore.instance, widget.slug).send(batch, from: 'phone');
        _toast('Sent. The Mac applies it and Claude sees it on its next step.');
      }
      await _draft.clear();
    } on Object catch (e) {
      _toast('Could not send: $e');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _toast(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  void _openDetail(String id) {
    final plan = widget.source.plan!;
    final step = plan.step(id);
    if (step == null) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: context.tokens.surface,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.72,
        maxChildSize: 0.96,
        builder: (context, ctrl) => ListenableBuilder(
          listenable: Listenable.merge([widget.source, _draft]),
          builder: (_, _) {
            final p = widget.source.plan;
            final s = p?.step(id);
            if (p == null || s == null) return const SizedBox.shrink();
            return StepDetail(
                plan: p,
                graph: Graph(p),
                step: s,
                draft: _draft,
                controller: ctrl,
                threads: _threads,
                onAskItem: (i) => _askAbout({'item': i.id}, i.title),
                onAskStep: () => _askAbout({'step': s.id}, s.title),
                onSelectStep: (other) {
                  Navigator.of(context).pop();
                  setState(() => _selected = other);
                  _openDetail(other);
                });
          },
        ),
      ),
    );
  }

  bool get _bridgeRunning => widget.isHost ? widget.host!.bridge.running : _summary?.mode == 'bridge';

  /// Sends one scoped message to whichever session this surface drives.
  Future<String?> _sendScoped(String text, Map<String, Object?> about) async {
    if (widget.isHost) {
      final b = widget.host!.bridge;
      if (!b.running) return 'The session is not running — start it on the Deck.';
      b.send(text, about: about);
      return null;
    }
    if (!_bridgeRunning) return 'The session is not running — start it on the Deck.';
    try {
      await CommandSender(FirebaseFirestore.instance, widget.slug).send({'type': 'send', 'text': text, 'about': about}, from: 'phone');
      return null;
    } on Object catch (e) {
      return 'Could not send: $e';
    }
  }

  void _askAbout(Map<String, Object?> about, String title) {
    showThreadSheet(
      context,
      db: FirebaseFirestore.instance,
      slug: widget.slug,
      about: about,
      title: title,
      running: _bridgeRunning,
      onSend: (t) => _sendScoped(t, about),
    );
  }

  /// The session's mood, for the constellation's energy waves: idle breath,
  /// cyan while a task runs, green when the turn is done, amber on an ask.
  GlyphMode _sessionGlyph() {
    if (widget.host != null) {
      return switch (widget.host!.bridge.state) {
        BridgeState.waiting => GlyphMode.ask,
        BridgeState.busy || BridgeState.starting => GlyphMode.busy,
        BridgeState.ready => GlyphMode.live,
        _ => GlyphMode.idle,
      };
    }
    final st = _summary?.sessionState ?? 'idle';
    if ((_summary?.pendingAsks ?? 0) > 0 || st == 'waiting') return GlyphMode.ask;
    return switch (st) {
      'busy' || 'starting' => GlyphMode.busy,
      'ready' => GlyphMode.live,
      _ => (_summary?.live ?? false) ? GlyphMode.live : GlyphMode.idle,
    };
  }

  /// The Deck's "now" strip: the latest event, the active step, its gates.
  Widget? _nowStrip(Plan? plan, Graph? graph) {
    if (plan == null) return null;
    final next = graph?.nextStep();
    final active = next != null && next.state == StepState.active ? next : null;
    String text;
    var needsYou = false;
    var live = false;
    DateTime? at;
    if (widget.host != null) {
      final h = widget.host!;
      final e = h.hooks.latest;
      live = h.session.running || h.bridge.running;
      if (e != null) {
        text = e.summary;
        needsYou = e.needsYou;
        at = e.at;
      } else {
        text = live ? 'Session live — waiting for a prompt' : 'No session running';
      }
    } else {
      final now = _summary?.now;
      live = _summary?.live ?? false;
      needsYou = (_summary?.pendingAsks ?? 0) > 0;
      if (now != null && now.isNotEmpty) {
        text = (now['summary'] ?? '').toString();
        needsYou = needsYou || now['needsYou'] == true;
        at = DateTime.tryParse((now['at'] ?? '').toString());
      } else {
        text = live ? 'Session live' : 'No session running';
      }
    }
    return NowStrip(
      label: 'NOW · ${active?.step.id ?? (next != null ? 'NEXT ${next.step.id}' : 'IDLE')}',
      text: text,
      ago: at == null ? null : _ago(at),
      gates: active?.step.gates.values.toList() ?? const [],
      live: live,
      needsYou: needsYou,
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final wide = MediaQuery.sizeOf(context).width >= 900;
    return ListenableBuilder(
      listenable: Listenable.merge([widget.source, _draft, _threads, if (widget.host != null) widget.host!, if (widget.host != null) widget.host!.hooks, if (widget.host != null) widget.host!.session, if (widget.host != null) widget.host!.bridge]),
      builder: (context, _) {
        final plan = widget.source.plan;
        final graph = widget.source.graph;
        final sessionUrl = widget.isHost ? widget.host!.session.sessionUrl : _summary?.sessionUrl;
        final openCount = plan?.items.where((i) => i.isOpen).length ?? 0;
        return Scaffold(
          body: SafeArea(
            bottom: false,
            child: Column(
              children: [
                // On a phone the Deck folds the strip away while the user
                // reads down; a drag up brings it back.
                AnimatedSize(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                  alignment: Alignment.topCenter,
                  child: _chromeHidden && _tabs.index == 0
                      ? const SizedBox(width: double.infinity)
                      : Container(
                  decoration: BoxDecoration(border: Border(bottom: BorderSide(color: t.line))),
                  child: Row(
                    children: [
                      if (Navigator.of(context).canPop())
                        IconButton(icon: const Icon(Icons.chevron_left), tooltip: 'Back', onPressed: () => Navigator.of(context).pop()),
                      Expanded(
                        child: TabBar(
                          controller: _tabs,
                          isScrollable: true,
                          tabAlignment: TabAlignment.start,
                          padding: EdgeInsets.zero,
                          tabs: [
                            const Tab(text: 'DECK'),
                            const Tab(text: 'STEPS'),
                            Tab(text: openCount == 0 ? 'YOUR WORK' : 'YOUR WORK · $openCount'),
                            if (widget.isHost) const Tab(text: 'SESSION'),
                          ],
                        ),
                      ),
                      if (sessionUrl != null)
                        IconButton(
                          tooltip: 'Open in Claude',
                          icon: Icon(Icons.open_in_new, size: 18, color: t.muted),
                          onPressed: () => launchUrl(Uri.parse(sessionUrl), mode: LaunchMode.externalApplication),
                        ),
                    ],
                  ),
                ),
                ),
                if (_tabs.index != 0) _NowLine(host: widget.host, summary: _summary),
                Expanded(
                  child: plan == null
                      ? (widget.source.error != null ? EmptyNote(widget.source.error!) : const Center(child: CircularProgressIndicator()))
                      : TabBarView(
                          controller: _tabs,
                          // No swipe between tabs: a horizontal drag belongs to the
                          // bubble canvas, and on a phone the TabBarView was taking
                          // it first. The tab strip switches tabs.
                          physics: const NeverScrollableScrollPhysics(),
                          children: [
                            widget.isHost
                                ? DeckTab(bridge: widget.host!.bridge, title: plan.manifest.projectName, nowSlot: _nowStrip(plan, graph), testPush: widget.host!.testPush, onChromeHidden: _onChromeHidden, files: widget.host!.files, git: widget.host!.gitStatus, onGit: widget.host!.gitOp)
                                : RemoteDeckTab(db: FirebaseFirestore.instance, slug: widget.slug, title: plan.manifest.projectName, nowSlot: _nowStrip(plan, graph), onChromeHidden: _onChromeHidden),
                            wide
                                ? Row(
                                    children: [
                                      Expanded(child: StepsTab(plan: plan, graph: graph!, selected: _selected, showPanel: false, session: _sessionGlyph(), onSelect: (id) => setState(() => _selected = id))),
                                      Container(
                                        width: 440,
                                        decoration: BoxDecoration(color: t.surface, border: Border(left: BorderSide(color: t.line))),
                                        child: _selected == null || plan.step(_selected!) == null
                                            ? const EmptyNote('Tap a step.')
                                            : StepDetail(
                                                plan: plan,
                                                graph: graph,
                                                step: plan.step(_selected!)!,
                                                draft: _draft,
                                                threads: _threads,
                                                onAskItem: (i) => _askAbout({'item': i.id}, i.title),
                                                onAskStep: () => _askAbout({'step': _selected!}, plan.step(_selected!)!.title),
                                                onSelectStep: (id) => setState(() => _selected = id)),
                                      ),
                                    ],
                                  )
                                : StepsTab(plan: plan, graph: graph!, selected: _selected, session: _sessionGlyph(), onSelect: (id) => setState(() => _selected = id), onOpenDetail: _openDetail, onAskStep: (id) => _askAbout({'step': id}, plan.step(id)?.title ?? id)),
                            WorkTab(plan: plan, graph: graph, draft: _draft, threads: _threads, onAskItem: (i) => _askAbout({'item': i.id}, i.title)),
                            if (widget.isHost) SessionTab(host: widget.host!, presence: HostProjects.presence, power: HostProjects.power, loginItem: HostProjects.loginItem),
                          ],
                        ),
                ),
              ],
            ),
          ),
          // The bottom of a phone's project: what Claude is asking, then the
          // draft bar. The host answers asks on its Deck.
          bottomNavigationBar: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!widget.isHost && _tabs.index != 0) RemoteAskPanel(db: FirebaseFirestore.instance, slug: widget.slug),
                if (_draft.count > 0) _draftBar(t),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _draftBar(KitTokens t) {
    final ticks = _draft.items.values.where((d) => d.action != null).length;
    final answers = _draft.items.values.where((d) => d.answer != null).length;
    final notes = _draft.items.values.where((d) => d.note.trim().isNotEmpty).length + _draft.steps.length;
    String n(int c, String what) => '$c $what${c == 1 ? '' : 's'}';
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
      decoration: BoxDecoration(color: t.surface, border: Border(top: BorderSide(color: t.line))),
      // A Wrap, not a Row: at the largest text sizes SEND TO CLAUDE is
      // wider than the phone and takes its own line.
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 10,
        runSpacing: 8,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('DRAFT ON THIS DEVICE', style: t.readout(10.5)),
              const SizedBox(height: 2),
              Text('${n(ticks, 'tick')} · ${n(answers, 'answer')} · ${n(notes, 'note')}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, color: t.ink2)),
            ],
          ),
          Wrap(spacing: 6, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
            TextButton(onPressed: _sending ? null : () => _draft.clear(), child: const Text('DISCARD')),
            FilledButton.icon(
              onPressed: _sending ? null : _send,
              icon: const Icon(Icons.arrow_forward, size: 16),
              iconAlignment: IconAlignment.end,
              label: Text(_sending ? 'SENDING…' : 'SEND TO CLAUDE'),
            ),
          ]),
        ],
      ),
    );
  }

  static String _ago(DateTime at) {
    final d = DateTime.now().difference(at.toLocal());
    if (d.inSeconds < 60) return 'now';
    if (d.inMinutes < 60) return '${d.inMinutes}m';
    if (d.inHours < 24) return '${d.inHours}h';
    return '${d.inDays}d';
  }
}

/// The one-line readout the other tabs keep: a dot, the latest event, how
/// long ago.
class _NowLine extends StatelessWidget {
  const _NowLine({this.host, this.summary});
  final HostProject? host;
  final ProjectSummary? summary;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    String text;
    bool needsYou = false;
    bool live = false;
    DateTime? at;
    if (host != null) {
      final e = host!.hooks.latest;
      live = host!.session.running || host!.bridge.running;
      if (e != null) {
        text = e.summary;
        needsYou = e.needsYou;
        at = e.at;
      } else {
        text = live ? 'Session live — waiting for a prompt' : 'No session running';
      }
    } else {
      final now = summary?.now;
      live = summary?.live ?? false;
      if ((summary?.pendingAsks ?? 0) > 0) {
        return _line(t, color: t.warn, text: 'Claude is asking — see below', at: null);
      }
      if (now != null && now.isNotEmpty) {
        text = (now['summary'] ?? '').toString();
        needsYou = now['needsYou'] == true;
        at = DateTime.tryParse((now['at'] ?? '').toString());
      } else {
        text = live ? 'Session live' : 'No session running';
      }
    }
    return _line(t, color: needsYou ? t.warn : (live ? t.good : t.muted), text: text, at: at);
  }

  Widget _line(KitTokens t, {required Color color, required String text, required DateTime? at}) {
    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: t.line))),
      child: Row(
        children: [
          Container(width: 7, height: 7, decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
          const SizedBox(width: 8),
          Expanded(child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.mono(11.5, color: t.ink2))),
          if (at != null) Text(_ProjectScreenState._ago(at), style: t.mono(11, color: t.muted)),
        ],
      ),
    );
  }
}
