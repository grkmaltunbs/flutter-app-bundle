import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart' hide Step, StepState;
import 'package:flutter_kit/kit.dart';
import 'package:url_launcher/url_launcher.dart';

import '../draft.dart';
import '../host/host_project.dart';
import '../plan_source.dart';
import '../relay.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'deck_tab.dart';
import 'session_tab.dart';
import 'step_detail.dart';
import 'steps_tab.dart';
import 'work_tab.dart';

/// One project: (host) Deck · Steps · Your work · (host) Session. The "now"
/// line under the title is what Claude is doing this second; the send bar
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
  late final TabController _tabs = TabController(length: widget.isHost ? 4 : 2, vsync: this);
  ProjectSummary? _summary;
  StreamSubscription<ProjectSummary>? _sub;
  String? _selected;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _draft.load();
    _sub = widget.remoteDoc?.listen((s) => setState(() => _summary = s));
  }

  @override
  void dispose() {
    _sub?.cancel();
    _tabs.dispose();
    _draft.dispose();
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

  void _select(String? id, {required bool wide}) {
    setState(() => _selected = id);
    if (id == null || wide) return;
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
            return StepDetail(plan: p, graph: Graph(p), step: s, draft: _draft, controller: ctrl, onSelectStep: (other) {
              Navigator.of(context).pop();
              _select(other, wide: false);
            });
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final wide = MediaQuery.sizeOf(context).width >= 900;
    return ListenableBuilder(
      listenable: Listenable.merge([widget.source, _draft, if (widget.host != null) widget.host!, if (widget.host != null) widget.host!.hooks, if (widget.host != null) widget.host!.session, if (widget.host != null) widget.host!.bridge]),
      builder: (context, _) {
        final plan = widget.source.plan;
        final graph = widget.source.graph;
        final sessionUrl = widget.isHost ? widget.host!.session.sessionUrl : _summary?.sessionUrl;
        return Scaffold(
          appBar: AppBar(
            title: Text(plan?.manifest.projectName ?? widget.slug),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(74),
              child: Column(
                children: [
                  _NowLine(host: widget.host, summary: _summary),
                  TabBar(
                    controller: _tabs,
                    isScrollable: false,
                    labelColor: t.ink,
                    indicatorColor: t.accent,
                    tabs: [
                      if (widget.isHost) const Tab(text: 'Deck'),
                      const Tab(text: 'Steps'),
                      Tab(text: plan == null ? 'Your work' : 'Your work · ${plan.items.where((i) => i.isOpen).length}'),
                      if (widget.isHost) const Tab(text: 'Session'),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              if (sessionUrl != null)
                TextButton.icon(
                  onPressed: () => launchUrl(Uri.parse(sessionUrl), mode: LaunchMode.externalApplication),
                  icon: const Icon(Icons.open_in_new, size: 16),
                  label: const Text('Open in Claude'),
                ),
            ],
          ),
          body: plan == null
              ? (widget.source.error != null ? EmptyNote(widget.source.error!) : const Center(child: CircularProgressIndicator()))
              : TabBarView(
                  controller: _tabs,
                  // No swipe between tabs: a horizontal drag belongs to the
                  // bubble canvas, and on a phone the TabBarView was taking
                  // it first. The tab strip switches tabs.
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    if (widget.isHost) DeckTab(bridge: widget.host!.bridge),
                    wide
                        ? Row(
                            children: [
                              Expanded(child: StepsTab(plan: plan, graph: graph!, selected: _selected, onSelect: (id) => _select(id, wide: true))),
                              Container(
                                width: 440,
                                decoration: BoxDecoration(color: t.surface, border: Border(left: BorderSide(color: t.line))),
                                child: _selected == null || plan.step(_selected!) == null
                                    ? const EmptyNote('Tap a bubble.')
                                    : StepDetail(plan: plan, graph: graph, step: plan.step(_selected!)!, draft: _draft, onSelectStep: (id) => _select(id, wide: true)),
                              ),
                            ],
                          )
                        : StepsTab(plan: plan, graph: graph!, selected: _selected, onSelect: (id) => _select(id, wide: false)),
                    WorkTab(plan: plan, graph: graph, draft: _draft),
                    if (widget.isHost) SessionTab(host: widget.host!),
                  ],
                ),
          bottomNavigationBar: _draft.count == 0
              ? null
              : SafeArea(
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
                    decoration: BoxDecoration(color: t.surface, border: Border(top: BorderSide(color: t.line))),
                    child: Row(
                      children: [
                        Expanded(child: Text('${_draft.count} change${_draft.count == 1 ? '' : 's'} on this device', style: TextStyle(color: t.ink2))),
                        TextButton(onPressed: _sending ? null : () => _draft.clear(), child: const Text('Discard')),
                        const SizedBox(width: 6),
                        FilledButton.icon(onPressed: _sending ? null : _send, icon: const Icon(Icons.send, size: 16), label: Text(_sending ? 'Sending…' : 'Send to Claude')),
                      ],
                    ),
                  ),
                ),
        );
      },
    );
  }
}

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
      live = summary?.sessionState == 'connected';
      if (now != null && now.isNotEmpty) {
        text = (now['summary'] ?? '').toString();
        needsYou = now['needsYou'] == true;
        at = DateTime.tryParse((now['at'] ?? '').toString());
      } else {
        text = live ? 'Session live' : 'No session running';
      }
    }
    final color = needsYou ? t.warn : (live ? t.good : t.muted);
    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      alignment: Alignment.centerLeft,
      child: Row(
        children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
          const SizedBox(width: 8),
          Expanded(child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, color: t.ink2))),
          if (at != null) Text(_ago(at), style: TextStyle(fontSize: 11, color: t.muted)),
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
