import 'package:flutter/material.dart' hide Step, StepState;

import '../theme.dart';
import '../widgets/common.dart';
import '../host/bridge_session.dart';
import 'studio_constellation.dart';
import 'studio_board.dart';
import 'studio_data.dart';
import 'studio_desk.dart';
import 'studio_media.dart';
import 'studio_media_view.dart';
import 'studio_thread.dart';
import 'studio_draft.dart';
import 'studio_graph.dart';
import 'studio_orchestrator.dart';
import 'studio_plans.dart';
import 'studio_source.dart';
import 'studio_visuals.dart';

/// The Studio: one screen over the game's autopilot — what waits on the
/// person, what each lane is doing, the mail and the reviewer's calls, and
/// the game's own documents. Read-only by design: it shows, the person
/// decides, the orchestrator acts.
class StudioScreen extends StatefulWidget {
  const StudioScreen({super.key, required this.source, this.orchestrator, this.draft, this.threads, this.sendToOrchestrator, this.media, this.mediaTab, this.orchestratorTab, this.initialTab = 0, this.initialInboxSegment = 0, this.remote = false, this.onSettings, DateTime Function()? now}) : _now = now ?? DateTime.now;

  /// The MEDIA tab's content when it is not the Mac's gallery (the phone's).
  final Widget? mediaTab;

  /// The ORCHESTRATOR tab's content when it is not the Mac's (the phone's).
  final Widget? orchestratorTab;
  final int initialTab;

  /// Which INBOX list opens first: 0 mail, 1 the board, 2 decided, 3 issues.
  final int initialInboxSegment;

  /// The phone's Studio: read from the relay; the orchestrator's chat and
  /// editing come later.
  final bool remote;

  /// The pictures and videos gathered for the MEDIA tab and the strip.
  final StudioMedia? media;

  /// The step desk's threads — questions on a step, answers, proposals.
  final ThreadsApi? threads;

  /// How the draft reaches the orchestrator when there is no [orchestrator]
  /// session here (the phone sends through the Mac).
  final Future<String> Function(String text)? sendToOrchestrator;

  /// The changes made on the graphs, waiting for SEND TO ORCHESTRATOR.
  final StudioDraft? draft;

  final StudioData source;

  /// The orchestrator's session; without one the ORCHESTRATOR tab says how
  /// to set its folder.
  final BridgeSession? orchestrator;
  final VoidCallback? onSettings;
  final DateTime Function() _now;

  @override
  State<StudioScreen> createState() => _StudioScreenState();
}

class _StudioScreenState extends State<StudioScreen> {
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 7,
      initialIndex: widget.initialTab,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('STUDIO'),
          actions: [
            ListenableBuilder(
              listenable: widget.source,
              builder: (context, _) {
                final at = widget.source.snapshot.readAt;
                // When it last read lives in the tooltip: a readout beside the
                // title overflows the bar at large text sizes on a phone.
                return IconButton(tooltip: at == null ? 'Read again' : 'Read again (last read ${hhmm(at)})', icon: const Icon(Icons.refresh), onPressed: widget.source.refresh);
              },
            ),
            if (widget.onSettings != null) IconButton(tooltip: 'Folders', icon: const Icon(Icons.folder_outlined), onPressed: widget.onSettings),
          ],
          bottom: TabBar(isScrollable: _scrollTabs(context), tabAlignment: _scrollTabs(context) ? TabAlignment.start : null, tabs: const [Tab(text: 'NOW'), Tab(text: 'ORCHESTRATOR'), Tab(text: 'LANES'), Tab(text: 'ROADMAP'), Tab(text: 'INBOX'), Tab(text: 'MEDIA'), Tab(text: 'DOCS')]),
        ),
        bottomNavigationBar: widget.draft == null
            ? null
            : DraftBar(draft: widget.draft!, send: widget.sendToOrchestrator ?? (widget.orchestrator == null ? null : (text) => sendToOrchestrator(widget.orchestrator!, text))),
        body: ListenableBuilder(
          listenable: widget.source,
          builder: (context, _) {
            final src = widget.source;
            if (src.error != null && src.snapshot.lanes.isEmpty) return EmptyNote('Could not read the autopilot folder: ${src.error}');
            final s = src.snapshot;
            final now = widget._now();
            // No swiping between tabs: a sideways drag on LANES and ROADMAP
            // pans the map; the tab bar changes tabs.
            return TabBarView(physics: const NeverScrollableScrollPhysics(), children: [
              _NowTab(snapshot: s, now: now, source: src),
              widget.orchestratorTab ?? (widget.orchestrator == null
                  ? EmptyNote(widget.remote ? 'The Mac has not published the orchestrator.' : 'Pick the orchestrator\'s folder under Folders (usually the game repo) to talk to it here.')
                  : OrchestratorTab(bridge: widget.orchestrator!, lanes: s.lanes, media: widget.media)),
              _LanesTab(snapshot: s, now: now, source: src, orchestrator: widget.orchestrator, draft: widget.draft, threads: widget.threads),
              _RoadmapTab(snapshot: s, orchestrator: widget.orchestrator, draft: widget.draft, threads: widget.threads),
              _InboxTab(snapshot: s, initialSegment: widget.initialInboxSegment, reply: widget.sendToOrchestrator ?? (widget.orchestrator == null ? null : (text) => sendToOrchestrator(widget.orchestrator!, text))),
              widget.mediaTab ?? (widget.media == null ? const EmptyNote('No media yet.') : MediaGallery(media: widget.media!)),
              _DocsTab(source: src),
            ]);
          },
        ),
      ),
    );
  }
}

// --- time --------------------------------------------------------------------

String two(int n) => n.toString().padLeft(2, '0');
String hhmm(DateTime d) => '${two(d.hour)}:${two(d.minute)}';

/// "22:17" today, "yesterday 22:17", "11-04 21:27" before that.
String whenLabel(DateTime at, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(at.year, at.month, at.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return hhmm(at);
  if (diff == 1) return 'yesterday ${hhmm(at)}';
  return '${two(at.month)}-${two(at.day)} ${hhmm(at)}';
}

/// "4 min", "2 h 10 min", "3 days".
String sinceLabel(DateTime at, DateTime now) {
  final d = now.difference(at);
  if (d.isNegative || d.inMinutes < 1) return 'just now';
  if (d.inMinutes < 60) return '${d.inMinutes} min';
  if (d.inHours < 24) return '${d.inHours} h ${d.inMinutes % 60} min';
  final days = d.inDays;
  return days == 1 ? '1 day' : '$days days';
}

// --- lane look ----------------------------------------------------------------

({Color color, GlyphMode mode, String label}) laneLook(BuildContext context, Lane lane, DateTime now) {
  final t = context.tokens;
  if (lane.failStreak >= 2) return (color: t.critical, mode: GlyphMode.ask, label: 'FAILING');
  if (lane.paused) return (color: t.warn, mode: GlyphMode.idle, label: 'PAUSED');
  if (lane.stopping) return (color: t.warn, mode: GlyphMode.idle, label: 'STOPPING');
  if (lane.staleAt(now)) return (color: t.warn, mode: GlyphMode.idle, label: 'NO NEWS');
  return switch (lane.status.state) {
    LaneState.running => (color: t.accent, mode: GlyphMode.busy, label: 'WORKING'),
    LaneState.waiting => (color: t.muted, mode: GlyphMode.idle, label: 'WAITING'),
    LaneState.paused => (color: t.warn, mode: GlyphMode.idle, label: 'PAUSED'),
    LaneState.stopped => (color: t.muted, mode: GlyphMode.idle, label: 'STOPPED'),
    LaneState.failed => (color: t.critical, mode: GlyphMode.ask, label: 'FAILED'),
    LaneState.notStarted => (color: t.muted, mode: GlyphMode.idle, label: 'NOT STARTED'),
    LaneState.unknown => (color: t.muted, mode: GlyphMode.idle, label: '—'),
  };
}

/// One lane at a glance: name, machine, state, what it does, what it did last.
class LaneCard extends StatelessWidget {
  const LaneCard({super.key, required this.lane, required this.now, this.onTap, this.track, this.doneShown = 3, this.nextShown = 3});
  final Lane lane;
  final DateTime now;
  final VoidCallback? onTap;

  /// The lane's step list as a track of rings, drawn under the status.
  final LaneTrack? track;
  final int doneShown;
  final int nextShown;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final look = laneLook(context, lane, now);
    final last = lane.lastDone;
    final at = lane.status.at;
    final today = lane.doneOn(now);
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // The state pill drops under the name when large text leaves no room.
              Row(children: [
                StatusGlyph(color: look.color, mode: look.mode),
                const SizedBox(width: 10),
                Expanded(
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    alignment: WrapAlignment.spaceBetween,
                    children: [
                      Text(lane.name.toUpperCase(), style: t.display(17, ls: 0.8)),
                      Pill(look.label, color: look.color, filled: look.label == 'FAILING' || look.label == 'FAILED'),
                    ],
                  ),
                ),
              ]),
              const SizedBox(height: 6),
              Text([lane.machine, if (lane.engineLine.isNotEmpty) lane.engineLine].join(' · ').toUpperCase(), style: t.readout(10, color: t.muted)),
              const SizedBox(height: 10),
              Text(lane.status.text, style: TextStyle(fontSize: 14.5, color: t.ink, fontWeight: FontWeight.w600)),
              if (at != null) Text('since ${whenLabel(at, now)} · ${sinceLabel(at, now)}', style: t.mono(11, color: t.muted)),
              if (track != null && track!.total > 0) ...[
                const SizedBox(height: 10),
                LaneTrackView(track: track!, doneShown: doneShown, nextShown: nextShown, working: lane.status.state == LaneState.running, onOpen: (item) => openStepItem(context, lane.name, item)),
                Text('${track!.done.length} of ${track!.total} ticked${track!.current != null ? ' · on ${track!.current!.id}' : ''}', style: t.mono(10.5, color: t.muted)),
              ],
              if (last != null) ...[
                const SizedBox(height: 10),
                Text('LAST DONE · STEP ${last.step}${last.at == null ? '' : ' · ${whenLabel(last.at!, now)}'}', style: t.readout(10, color: t.good)),
                const SizedBox(height: 2),
                Text(last.summary ?? '', maxLines: 3, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, color: t.ink2, height: 1.4)),
              ],
              if (today > 0 || lane.inbox > 0 || lane.failStreak > 0) ...[
                const SizedBox(height: 10),
                Wrap(spacing: 6, runSpacing: 6, children: [
                  if (today > 0) Pill('$today DONE TODAY', color: t.good),
                  if (lane.inbox > 0) Pill('${lane.inbox} MAIL WAITING', color: t.accent),
                  if (lane.failStreak > 0) Pill('${lane.failStreak} FAILED IN A ROW', color: t.critical),
                ]),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// --- NOW ------------------------------------------------------------------------

class _NowTab extends StatelessWidget {
  const _NowTab({required this.snapshot, required this.now, required this.source});
  final StudioSnapshot snapshot;
  final DateTime now;
  final StudioData source;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final waiting = snapshot.waitingForUser;
    final digest = snapshot.digest;
    final lastNote = digest?.subsections.isNotEmpty == true ? digest!.subsections.last : null;
    return ListView(
      key: const Key('studio-now'),
      padding: const EdgeInsets.all(16),
      children: [
        _WaitingCard(items: waiting, at: digest?.at, now: now),
        const SizedBox(height: 20),
        const SectionHead('LANES'),
        const SizedBox(height: 8),
        _LaneGrid(lanes: snapshot.lanes, now: now, source: source, tracks: snapshot.tracks),
        const SizedBox(height: 20),
        SectionHead('REVIEWER', sub: [
          if (snapshot.mode != null) snapshot.mode == 'afk' ? 'you are away mode' : '${snapshot.mode} mode',
          if (snapshot.lastReview != null) 'last review ${whenLabel(snapshot.lastReview!, now)}',
        ].join(' · ')),
        const SizedBox(height: 8),
        if (lastNote != null)
          Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(lastNote.title.toUpperCase(), style: t.readout(10, color: t.accent)), const SizedBox(height: 6), Md(lastNote.body, compact: true)])))
        else
          const EmptyNote('No review note yet.'),
      ],
    );
  }
}

class _WaitingCard extends StatelessWidget {
  const _WaitingCard({required this.items, this.at, required this.now});
  final List<String> items;
  final DateTime? at;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final none = items.isEmpty;
    return Container(
      decoration: BoxDecoration(color: none ? t.surface : t.warnSoft, borderRadius: BorderRadius.circular(12), border: Border.all(color: none ? t.line : t.warn)),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(none ? Icons.check_circle_outline : Icons.front_hand_outlined, size: 18, color: none ? t.good : t.warn),
            const SizedBox(width: 8),
            Expanded(child: Text(none ? 'NOTHING WAITS ON YOU' : 'WAITING FOR YOU · ${items.length}', style: t.display(16, ls: 0.8, color: none ? t.good : t.warn))),
          ]),
          if (at != null) Padding(padding: const EdgeInsets.only(top: 2), child: Text('as the reviewer listed it at ${whenLabel(at!, now)}', style: t.mono(11, color: t.muted))),
          for (final (i, item) in items.indexed) ...[
            const SizedBox(height: 10),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SizedBox(width: 24, child: Text('${i + 1}.', style: t.mono(13, color: t.warn, weight: FontWeight.w700))),
              Expanded(child: Md(item, compact: true, color: t.ink)),
            ]),
          ],
        ],
      ),
    );
  }
}

/// Lane cards, two across when the window is wide.
class _LaneGrid extends StatelessWidget {
  const _LaneGrid({required this.lanes, required this.now, required this.source, this.tracks = const {}});
  final List<Lane> lanes;
  final Map<String, LaneTrack> tracks;
  final DateTime now;
  final StudioData source;

  @override
  Widget build(BuildContext context) {
    if (lanes.isEmpty) return const EmptyNote('No lane-<x> folders here.');
    return LayoutBuilder(builder: (context, c) {
      final cols = c.maxWidth >= 760 ? 2 : 1;
      final w = (c.maxWidth - (cols - 1) * 12) / cols;
      return Wrap(spacing: 12, runSpacing: 12, children: [
        for (final l in lanes) SizedBox(width: w, child: LaneCard(lane: l, now: now, track: tracks[l.id], onTap: () => openLane(context, l, source, now, tracks[l.id]))),
      ]);
    });
  }
}

// --- LANES ----------------------------------------------------------------------

/// LANES: the dependency graph of every lane, or the cards with their
/// latest steps — a switch on the sky flips between them.
class _LanesTab extends StatefulWidget {
  const _LanesTab({required this.snapshot, required this.now, required this.source, this.orchestrator, this.draft, this.threads});
  final ThreadsApi? threads;
  final StudioSnapshot snapshot;
  final DateTime now;
  final StudioData source;
  final BridgeSession? orchestrator;
  final StudioDraft? draft;
  @override
  State<_LanesTab> createState() => _LanesTabState();
}

class _LanesTabState extends State<_LanesTab> {
  bool _list = false;
  bool _all = false;

  @override
  Widget build(BuildContext context) {
    final s = widget.snapshot;
    if (s.lanes.isEmpty) return const EmptyNote('No lane-<x> folders here.');
    if (_list) {
      return Stack(children: [
        _LaneList(snapshot: s, now: widget.now, source: widget.source),
        Positioned(right: 12, top: 8, child: FilledButton.tonalIcon(onPressed: () => setState(() => _list = false), icon: const Icon(Icons.hub_outlined, size: 18), label: const Text('GRAPH'))),
      ]);
    }
    final graph = LaneGraph.build(s.tracks, all: _all);
    return LaneConstellation(
      graph: graph,
      lanes: s.lanes,
      draft: widget.draft,
      threads: widget.threads,
      onExplain: widget.threads == null ? null : (lane, item) => explain(context, widget.threads, about: stepAbout(lane, item.id), stepText: [if (item.section != null) '(under "${item.section}")', '${item.done ? '[x]' : '[ ]'} ${item.text}'].join('\n')),
      onAsk: widget.threads == null ? null : (lane, item) => openThread(context,
          threads: widget.threads,
          draft: widget.draft,
          title: '${laneLabel(lane)} · ${item.id}',
          subtitle: item.title,
          about: stepAbout(lane, item.id),
          stepText: [if (item.section != null) '(under "${item.section}")', '${item.done ? '[x]' : '[ ]'} ${item.text}'].join('\n')),
      extraControls: [
        IconButton(tooltip: _all ? 'Show the steps around NOW' : 'Show every step', onPressed: () => setState(() => _all = !_all), icon: Icon(_all ? Icons.unfold_less : Icons.unfold_more, size: 18, color: KitTokens.dark.ink2), visualDensity: VisualDensity.compact),
        IconButton(tooltip: 'Lane cards', onPressed: () => setState(() => _list = true), icon: Icon(Icons.view_agenda_outlined, size: 18, color: KitTokens.dark.ink2), visualDensity: VisualDensity.compact),
      ],
    );
  }
}

/// ROADMAP: the constellation, or the ladder.
class _RoadmapTab extends StatefulWidget {
  const _RoadmapTab({required this.snapshot, this.orchestrator, this.draft, this.threads});
  final ThreadsApi? threads;
  final StudioSnapshot snapshot;
  final BridgeSession? orchestrator;
  final StudioDraft? draft;
  @override
  State<_RoadmapTab> createState() => _RoadmapTabState();
}

class _RoadmapTabState extends State<_RoadmapTab> {
  bool _ladder = false;
  Map<String, LaneTrack>? _tracksSeen;
  Map<String, List<(String, StepItem)>> _steps = const {};

  @override
  Widget build(BuildContext context) {
    final s = widget.snapshot;
    if (!identical(_tracksSeen, s.tracks)) {
      _tracksSeen = s.tracks;
      _steps = stepsByRoadmapId(s.tracks);
    }
    if (_ladder) {
      return Stack(children: [
        RoadmapView(milestones: s.roadmap),
        Positioned(right: 12, top: 8, child: FilledButton.tonalIcon(onPressed: () => setState(() => _ladder = false), icon: const Icon(Icons.auto_awesome, size: 18), label: const Text('CONSTELLATION'))),
      ]);
    }
    return RoadmapConstellation(
      milestones: s.roadmap,
      steps: _steps,
      draft: widget.draft,
      threads: widget.threads,
      onExplainItem: widget.threads == null ? null : (item) => explain(context, widget.threads, about: itemAbout(item.id), stepText: '${item.id} · ${item.task} · ${item.milestone}\nStatus: ${item.statusText}\n${item.summary}'),
      onAskItem: widget.threads == null ? null : (item) => openThread(context,
          threads: widget.threads,
          draft: widget.draft,
          title: '${item.id} · ${item.task}',
          subtitle: item.statusText.replaceAll(RegExp(r'\*\*|`'), ''),
          about: itemAbout(item.id),
          stepText: '${item.id} · ${item.task} · ${item.milestone} · size ${item.size ?? '?'} · owner ${item.owner ?? '?'}\nStatus: ${item.statusText}\n${item.summary}'),
      extraControls: [
        IconButton(tooltip: 'Ladder', onPressed: () => setState(() => _ladder = true), icon: Icon(Icons.format_list_bulleted, size: 18, color: KitTokens.dark.ink2), visualDensity: VisualDensity.compact),
      ],
    );
  }
}

class _LaneList extends StatelessWidget {
  const _LaneList({required this.snapshot, required this.now, required this.source});
  final StudioSnapshot snapshot;
  final DateTime now;
  final StudioData source;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    if (snapshot.lanes.isEmpty) return const EmptyNote('No lane-<x> folders here.');
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final l in snapshot.lanes) ...[
          LaneCard(lane: l, now: now, track: snapshot.tracks[l.id], doneShown: 5, nextShown: 6, onTap: () => openLane(context, l, source, now, snapshot.tracks[l.id])),
          const SizedBox(height: 6),
          for (final e in l.history.reversed.where((e) => e.isVerdict).take(3))
            _EventRow(event: e, now: now, onTap: e.step == null ? null : () => openLog(context, source, l, e.step!)),
          Align(alignment: Alignment.centerLeft, child: TextButton(onPressed: () => openLane(context, l, source, now, snapshot.tracks[l.id]), child: Text('ALL ${l.history.where((e) => e.isVerdict).length} STEPS', style: t.readout(11, color: t.accent)))),
          const SizedBox(height: 14),
        ],
      ],
    );
  }
}

class _EventRow extends StatelessWidget {
  const _EventRow({required this.event, required this.now, this.onTap});
  final LaneEvent event;
  final DateTime now;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final (color, word) = switch (event.kind) {
      EventKind.done => (t.good, 'DONE'),
      EventKind.failed => (t.critical, 'FAILED'),
      EventKind.waitForMail => (t.muted, 'WAITS FOR MAIL'),
      EventKind.waitFor => (t.muted, 'WAITS'),
      EventKind.planComplete => (t.good, 'PLAN COMPLETE'),
      EventKind.started => (t.accent, 'STARTED'),
      _ => (t.muted, ''),
    };
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(['STEP ${event.step ?? '?'}', if (word.isNotEmpty) word, if (event.at != null) whenLabel(event.at!, now)].join(' · '), style: t.readout(10, color: color)),
          if ((event.summary ?? '').isNotEmpty) Text(event.summary!, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, color: t.ink2, height: 1.35)),
        ]),
      ),
    );
  }
}

void openLane(BuildContext context, Lane lane, StudioData source, DateTime now, [LaneTrack? track]) {
  Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => LaneScreen(lane: lane, source: source, now: now, track: track)));
}

void openLog(BuildContext context, StudioData source, Lane lane, String step) {
  final text = source.stepLog(lane.id, step);
  Navigator.of(context).push(MaterialPageRoute<void>(
    builder: (context) => Scaffold(
      appBar: AppBar(title: Text('${lane.name.toUpperCase()} · STEP $step')),
      body: text.isEmpty
          ? const EmptyNote('No log for this step in the folder (the snapshot keeps the readable logs, not the raw streams).')
          : SelectionArea(child: ListView(padding: const EdgeInsets.all(16), children: [Text(text, style: context.tokens.mono(12, color: context.tokens.ink2))])),
    ),
  ));
}

/// One lane: its card, then every step it finished, newest first.
class LaneScreen extends StatelessWidget {
  const LaneScreen({super.key, required this.lane, required this.source, required this.now, this.track});
  final Lane lane;
  final StudioData source;
  final DateTime now;
  final LaneTrack? track;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final events = lane.history.reversed.where((e) => e.isVerdict || e.kind == EventKind.paused || e.kind == EventKind.stopped).toList();
    final upNext = [if (track?.current != null) track!.current!, ...?track?.next.take(12)];
    final head = <Widget>[
      LaneCard(lane: lane, now: now, track: track, doneShown: 8, nextShown: 10),
      if (upNext.isNotEmpty) ...[
        Padding(padding: const EdgeInsets.only(top: 18, bottom: 4), child: SectionHead('UP NEXT', sub: '${track!.next.length + (track!.current == null ? 0 : 1)} open in the list')),
        for (final item in upNext)
          InkWell(
            onTap: () => openStepItem(context, lane.name, item),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text([item.id, if (identical(item, track!.current)) 'NOW', if (item.held) 'ON HOLD'].join(' · '), style: t.readout(10, color: identical(item, track!.current) ? t.accent : (item.held ? t.warn : t.muted))),
                Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, color: t.ink2, height: 1.35)),
              ]),
            ),
          ),
      ],
      if (track?.source != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text('step list: ${track!.source}', style: t.mono(10, color: t.muted))),
      Padding(padding: const EdgeInsets.only(top: 18, bottom: 6), child: SectionHead('FINISHED', sub: '${events.length} · tap one for its log')),
    ];
    return Scaffold(
      appBar: AppBar(title: Text(lane.name.toUpperCase())),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: events.length + head.length,
        itemBuilder: (context, i) {
          if (i < head.length) return head[i];
          final e = events[i - head.length];
          if (!e.isVerdict) return Padding(padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4), child: Text('${e.at == null ? '' : '${whenLabel(e.at!, now)} · '}${e.text}'.toUpperCase(), style: context.tokens.readout(10, color: context.tokens.warn)));
          return _EventRow(event: e, now: now, onTap: e.step == null ? null : () => openLog(context, source, lane, e.step!));
        },
      ),
    );
  }
}

// --- INBOX ----------------------------------------------------------------------

class _InboxTab extends StatefulWidget {
  const _InboxTab({required this.snapshot, this.initialSegment = 0, this.reply});
  final StudioSnapshot snapshot;
  final int initialSegment;

  /// Sends the orchestrator a request to answer on the board; null when there is none.
  final Future<String> Function(String text)? reply;
  @override
  State<_InboxTab> createState() => _InboxTabState();
}

class _InboxTabState extends State<_InboxTab> {
  late int _which = widget.initialSegment;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final s = widget.snapshot;
    final forYou = s.board.where((m) => m.forYou).length;
    final segments = [('MAIL', s.userMail.length), ('BOARD', s.board.length), ('DECIDED', s.decisions.length), ('ISSUES', s.openIssues.length)];
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: Wrap(spacing: 8, runSpacing: 8, children: [
          for (final (i, seg) in segments.indexed)
            ChoiceChip(label: Text(seg.$1 == 'BOARD' && forYou > 0 ? 'BOARD · ${seg.$2} · $forYou FROM FIRAT' : '${seg.$1} · ${seg.$2}'), selected: _which == i, onSelected: (_) => setState(() => _which = i), selectedColor: t.accentSoft),
        ]),
      ),
      Expanded(
        child: switch (_which) {
          0 => _list(s.userMail.length, (i) {
              final m = s.userMail[i];
              return _InboxRow(kicker: m.at == null ? m.file : whenLabel(m.at!, DateTime.now()), title: m.title, onTap: () => _open(context, m.title, m.body));
            }, 'No mail to you.'),
          1 => _list(s.board.length, (i) {
              final m = s.board[i];
              return _BoardRow(message: m, onTap: () => _openBoard(context, m));
            }, 'No board yet — the Mac fetches the messaging-board branch every few minutes.'),
          2 => _list(s.decisions.length, (i) {
              final d = s.decisions[i];
              return _InboxRow(kicker: d.at == null ? 'DECIDED' : 'DECIDED · ${whenLabel(d.at!, DateTime.now())}', title: d.title, onTap: () => _open(context, d.title, d.body));
            }, 'The reviewer decided nothing for you.'),
          _ => _list(s.openIssues.length, (i) {
              final o = s.openIssues[i];
              return _InboxRow(kicker: o.lane == null ? 'OPEN' : 'OPEN · LANE ${o.lane}', title: o.text, maxLines: 4, onTap: () => _open(context, 'Open issue', o.text));
            }, 'No open issues.'),
        },
      ),
    ]);
  }

  void _openBoard(BuildContext context, BoardMessage m) {
    final t = context.tokens;
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (context) => Scaffold(
        appBar: AppBar(title: Text('${m.from} → ${m.to}', maxLines: 1, overflow: TextOverflow.ellipsis)),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          Text([if (m.at != null) whenLabel(m.at!, DateTime.now()), m.from, '→ ${m.to}'].join(' · ').toUpperCase(), style: t.readout(10, color: m.forYou ? t.warn : t.muted)),
          const SizedBox(height: 12),
          Md(m.text),
          const SizedBox(height: 18),
          if (widget.reply != null)
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(icon: const Icon(Icons.reply, size: 18), label: const Text('REPLY'), onPressed: () => _reply(context, m)),
            ),
        ]),
      ),
    ));
  }

  /// REPLY: what the person wants said (or nothing, for the orchestrator to
  /// draft), sent to the orchestrator to post with /send-team-message.
  Future<void> _reply(BuildContext context, BoardMessage m) async {
    final send = widget.reply;
    if (send == null) return;
    final note = await showDialog<String>(context: context, builder: (_) => const _ReplyDialog());
    if (note == null || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final said = await send(boardReplyPrompt(m, note));
    messenger.showSnackBar(SnackBar(content: Text('$said — the orchestrator answers on the board and says so on its tab')));
  }

  Widget _list(int n, Widget Function(int) row, String empty) {
    if (n == 0) return EmptyNote(empty);
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: n,
      separatorBuilder: (_, _) => Divider(height: 1, color: context.tokens.line),
      itemBuilder: (_, i) => row(i),
    );
  }

  void _open(BuildContext context, String title, String body) {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => Scaffold(appBar: AppBar(title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis)), body: ListView(padding: const EdgeInsets.all(16), children: [Md(body)])),
    ));
  }
}

class _InboxRow extends StatelessWidget {
  const _InboxRow({required this.kicker, required this.title, this.onTap, this.maxLines = 2});
  final String kicker;
  final String title;
  final VoidCallback? onTap;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(kicker.toUpperCase(), style: t.readout(10, color: t.muted)),
          const SizedBox(height: 2),
          Text(title, maxLines: maxLines, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14, color: t.ink, height: 1.35)),
        ]),
      ),
    );
  }
}

// --- DOCS -----------------------------------------------------------------------

/// The game's documents, grouped as the person asks for them.
class _DocsTab extends StatelessWidget {
  const _DocsTab({required this.source});
  final StudioData source;

  static const roadmap = [('production/production-plan.md', 'Production plan', 'scope and status — the source of truth'), ('production/timetable-2027.md', 'Timetable 2027', 'dates and milestones to Next Fest and Early Access')];
  static const rules = [('CLAUDE.md', 'Agent rules', 'how every agent works in the repo'), ('AGENTS.md', 'AGENTS.md', 'the same rules for Codex')];
  static const canon = ('design/notes/ai-gone-rogue-direction-2026-09-15.md', 'Canon brief', 'wins where the plan disagrees');

  @override
  Widget build(BuildContext context) {
    if (source.gameDir == null) return const EmptyNote('Pick the game repo under Folders to read its roadmap, rules and concept.');
    final gdd = source.gddFiles();
    Widget row((String, String, String) d) => _DocRow(title: d.$2, sub: d.$3, onTap: () => openDoc(context, source, d.$1, d.$2));
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SectionHead('ROADMAP'),
        for (final d in roadmap) row(d),
        const SizedBox(height: 16),
        const SectionHead('RULES'),
        for (final d in rules) row(d),
        const SizedBox(height: 16),
        const SectionHead('CONCEPT'),
        row(canon),
        for (final f in gdd) row((f, _gddTitle(f), f.split('/').last)),
      ],
    );
  }

  static String _gddTitle(String rel) {
    final name = rel.split('/').last.replaceAll('.md', '');
    if (name == 'README') return 'Game design document — index';
    return name.replaceFirst(RegExp(r'^\d+-'), '').replaceAll('-', ' ').replaceFirstMapped(RegExp(r'^.'), (m) => m.group(0)!.toUpperCase());
  }
}

class _DocRow extends StatelessWidget {
  const _DocRow({required this.title, required this.sub, required this.onTap});
  final String title;
  final String sub;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      leading: Icon(Icons.description_outlined, color: t.accent),
      title: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
      subtitle: Text(sub, style: t.mono(11, color: t.muted)),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

void openDoc(BuildContext context, StudioData source, String rel, String title) {
  final raw = source.gameFile(rel);
  Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => DocScreen(title: title, parts: DocPart.split(raw))));
}

/// A long document as its `##` parts: a list of headings, one part at a time.
class DocScreen extends StatelessWidget {
  const DocScreen({super.key, required this.title, required this.parts});
  final String title;
  final List<DocPart> parts;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    if (parts.isEmpty) return Scaffold(appBar: AppBar(title: Text(title)), body: const EmptyNote('The file is empty or missing.'));
    if (parts.length == 1) return Scaffold(appBar: AppBar(title: Text(title)), body: ListView(padding: const EdgeInsets.all(16), children: [Md(parts.single.body)]));
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: parts.length,
        separatorBuilder: (_, _) => Divider(height: 1, color: t.line),
        itemBuilder: (context, i) {
          final part = parts[i];
          final words = part.body.split(RegExp(r'\s+')).length;
          return ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
            title: Text(part.title, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600)),
            subtitle: Text('${(words / 230).ceil()} min read', style: t.mono(11, color: t.muted)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => Scaffold(appBar: AppBar(title: Text(part.title, maxLines: 1, overflow: TextOverflow.ellipsis)), body: ListView(padding: const EdgeInsets.all(16), children: [Md(part.body)])))),
          );
        },
      ),
    );
  }
}


/// The draft's bar: how many changes wait, REVIEW to see and drop them,
/// SEND TO ORCHESTRATOR to send them as one message — then the draft clears.
/// Hidden while there is nothing in the draft.
class DraftBar extends StatelessWidget {
  const DraftBar({super.key, required this.draft, this.send});
  final StudioDraft draft;

  /// Sends the draft's message to the orchestrator; null when there is none.
  final Future<String> Function(String text)? send;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: draft,
      builder: (context, _) {
        if (draft.isEmpty) return const SizedBox.shrink();
        final t = context.tokens;
        return Material(
          color: t.surface,
          elevation: 8,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
              child: Row(children: [
                Container(width: 10, height: 10, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFC79BFF))),
                const SizedBox(width: 8),
                Expanded(child: Text('${draft.length} CHANGE${draft.length == 1 ? '' : 'S'} IN THE DRAFT', overflow: TextOverflow.ellipsis, style: t.readout(11, color: t.ink))),
                TextButton(onPressed: () => showDraftSheet(context, draft, send), child: const Text('REVIEW')),
                const SizedBox(width: 4),
                Flexible(child: FilledButton.icon(onPressed: () => sendDraft(context, draft, send), icon: const Icon(Icons.send, size: 16), label: const Text('SEND TO ORCHESTRATOR', overflow: TextOverflow.ellipsis))),
              ]),
            ),
          ),
        );
      },
    );
  }
}

/// Sends the draft as one message and clears it; a toast says what came of it.
Future<void> sendDraft(BuildContext context, StudioDraft draft, Future<String> Function(String text)? send) async {
  final messenger = ScaffoldMessenger.of(context);
  if (send == null) {
    messenger.showSnackBar(const SnackBar(content: Text('Set the orchestrator folder under Folders first.')));
    return;
  }
  final text = draftPrompt(draft.orders);
  final n = draft.length;
  final said = await send(text);
  if (said.startsWith('The orchestrator did not start') || said.startsWith('not running') || said.startsWith('failed')) {
    messenger.showSnackBar(SnackBar(content: Text(said)));
    return;
  }
  draft.clear();
  messenger.showSnackBar(SnackBar(content: Text('$n change${n == 1 ? '' : 's'} sent — $said. Its answer is on the ORCHESTRATOR tab.')));
}

/// The draft, one row per change, each with a bin; CLEAR and SEND below.
Future<void> showDraftSheet(BuildContext context, StudioDraft draft, Future<String> Function(String text)? send) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheet) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.95,
      builder: (context, ctrl) => ListenableBuilder(
        listenable: draft,
        builder: (context, _) {
          final t = context.tokens;
          return ListView(
            controller: ctrl,
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
            children: [
              Text('THE DRAFT · ${draft.length}', style: t.readout(11, color: t.accent)),
              const SizedBox(height: 4),
              Text('Nothing changes until you send. The orchestrator applies each change the autopilot\'s own way and answers one line per change.', style: TextStyle(fontSize: 12.5, color: t.ink2)),
              const SizedBox(height: 10),
              for (final (i, o) in draft.orders.indexed)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(switch (o.kind) { DraftKind.link => Icons.link, DraftKind.unlink => Icons.link_off, DraftKind.add => Icons.add_circle_outline, DraftKind.edit => Icons.edit_outlined, DraftKind.remove => Icons.delete_outline, DraftKind.move => Icons.swap_horiz }, color: o.kind == DraftKind.remove || o.kind == DraftKind.unlink ? t.critical : const Color(0xFFC79BFF)),
                  title: Text(o.summary, style: const TextStyle(fontSize: 14)),
                  subtitle: o.text == null ? null : Text(o.text!, maxLines: 2, overflow: TextOverflow.ellipsis, style: t.mono(11, color: t.muted)),
                  trailing: IconButton(tooltip: 'Drop this change', icon: const Icon(Icons.close), onPressed: () => draft.removeAt(i)),
                ),
              if (draft.isEmpty) const Padding(padding: EdgeInsets.all(16), child: Text('The draft is empty.')),
              const SizedBox(height: 12),
              Row(children: [
                TextButton(onPressed: draft.isEmpty ? null : draft.clear, child: const Text('CLEAR ALL')),
                const Spacer(),
                FilledButton.icon(
                  onPressed: draft.isEmpty
                      ? null
                      : () async {
                          Navigator.of(sheet).pop();
                          await sendDraft(context, draft, send);
                        },
                  icon: const Icon(Icons.send, size: 16),
                  label: const Text('SEND TO ORCHESTRATOR'),
                ),
              ]),
            ],
          );
        },
      ),
    ),
  );
}


/// Opens a step's thread with the step desk.
void openThread(BuildContext context, {required ThreadsApi? threads, required StudioDraft? draft, required String title, String? subtitle, required Map<String, Object?> about, required String stepText}) {
  if (threads == null) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Set the orchestrator folder under Folders first — the step desk works there too.')));
    return;
  }
  Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => StepThreadScreen(title: title, subtitle: subtitle, about: about, stepText: stepText, threads: threads, draft: draft)));
}

/// EXPLAIN: asks the step desk what a step is for; the summary lands in the
/// step's thread and shows on its panel when it comes.
Future<void> explain(BuildContext context, ThreadsApi? threads, {required Map<String, Object?> about, required String stepText}) async {
  final messenger = ScaffoldMessenger.of(context);
  if (threads == null) {
    messenger.showSnackBar(const SnackBar(content: Text('Set the orchestrator folder under Folders first — the step desk works there too.')));
    return;
  }
  messenger.showSnackBar(const SnackBar(content: Text('Asking the step desk — the summary shows here when it answers.')));
  final err = await threads.ask(about, stepText: stepText, text: kSummarize);
  if (err != null) messenger.showSnackBar(SnackBar(content: Text(err)));
}


/// Seven tabs fit side by side from about 760 px; narrower (a phone) or with
/// large text, the tab bar scrolls so every name reads whole.
bool _scrollTabs(BuildContext context) => MediaQuery.sizeOf(context).width < 760 || MediaQuery.textScalerOf(context).scale(10) > 15;


/// The request REPLY sends the orchestrator.
String boardReplyPrompt(BoardMessage m, String note) => [
      '[Studio · board] Reply on the messaging board to this message, with /send-team-message:',
      '',
      '> ${m.at == null ? '' : '${m.at!.year}-${m.at!.month.toString().padLeft(2, '0')}-${m.at!.day.toString().padLeft(2, '0')} ${m.at!.hour.toString().padLeft(2, '0')}:${m.at!.minute.toString().padLeft(2, '0')} · '}${m.from} → ${m.to}: ${m.text}',
      '',
      note.isEmpty ? 'Draft the reply yourself from what you know; keep it short, as the board asks.' : 'The user wants it to say: $note',
      'Then tell me in one line what you posted.',
    ].join('\n');

/// One board message: who to whom and when; Fırat's side to this one in amber.
class _BoardRow extends StatelessWidget {
  const _BoardRow({required this.message, required this.onTap});
  final BoardMessage message;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final m = message;
    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: m.forYou ? BoxDecoration(border: Border(left: BorderSide(color: t.warn, width: 3))) : null,
        padding: EdgeInsets.only(left: m.forYou ? 10 : 0, top: 10, bottom: 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text([if (m.at != null) whenLabel(m.at!, DateTime.now()), '${m.from} → ${m.to}'].join(' · ').toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis, style: t.readout(10, color: m.forYou ? t.warn : t.muted)),
          const SizedBox(height: 2),
          Text(m.text.replaceAll(RegExp(r'\*\*|`'), ''), maxLines: 3, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14, color: t.ink, height: 1.35)),
        ]),
      ),
    );
  }
}


/// What to say on the board — its controller lives as long as the dialog
/// (disposing it as the dialog closes trips the framework mid-animation).
class _ReplyDialog extends StatefulWidget {
  const _ReplyDialog();
  @override
  State<_ReplyDialog> createState() => _ReplyDialogState();
}

class _ReplyDialogState extends State<_ReplyDialog> {
  final _ctrl = TextEditingController();
  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Reply on the board'),
        content: TextField(controller: _ctrl, autofocus: true, minLines: 2, maxLines: 6, decoration: const InputDecoration(hintText: 'What to say — or leave it empty and the orchestrator drafts the reply', border: OutlineInputBorder())),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
          FilledButton(onPressed: () => Navigator.pop(context, _ctrl.text.trim()), child: const Text('SEND TO ORCHESTRATOR')),
        ],
      );
}
