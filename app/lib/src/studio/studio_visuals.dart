import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart' hide Step, StepState;

import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;

import '../theme.dart';
import '../widgets/common.dart';
import 'studio_desk.dart';
import 'studio_plans.dart';
import 'studio_resources.dart';
import 'studio_source.dart';

// The Studio's two pictures, in the constellation's language: rings by
// state, the step being worked on breathing, unfinished links dashed.

bool _still(BuildContext context) => MediaQuery.maybeDisableAnimationsOf(context) ?? false;

enum _NodeKind { done, current, next, held }

/// A lane as a line of rings: the last [doneShown] finished steps, the one
/// it is on (breathing), the next [nextShown]; the ends say how many more.
/// Scrolls sideways; a tap opens the step.
class LaneTrackView extends StatefulWidget {
  const LaneTrackView({super.key, required this.track, this.doneShown = 4, this.nextShown = 4, this.onOpen, this.working = true});
  final LaneTrack track;
  final int doneShown;
  final int nextShown;
  final void Function(StepItem item)? onOpen;

  /// The lane runs a step now: the current ring breathes.
  final bool working;

  @override
  State<LaneTrackView> createState() => _LaneTrackViewState();
}

class _LaneTrackViewState extends State<LaneTrackView> with SingleTickerProviderStateMixin {
  late final _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200));

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final tr = widget.track;
    if (tr.total == 0) return Text('NO STEP LIST FOUND', style: t.readout(10, color: t.muted));
    final animate = widget.working && tr.current != null && !_still(context);
    if (animate && !_pulse.isAnimating) _pulse.repeat();
    if (!animate && _pulse.isAnimating) _pulse.stop();
    final done = tr.done.length > widget.doneShown ? tr.done.sublist(tr.done.length - widget.doneShown) : tr.done;
    final next = tr.next.take(widget.nextShown).toList();
    final earlier = tr.done.length - done.length;
    final later = tr.next.length - next.length;
    final nodes = <(StepItem, _NodeKind)>[
      for (final d in done) (d, _NodeKind.done),
      if (tr.current != null) (tr.current!, _NodeKind.current),
      for (final n in next) (n, n.held ? _NodeKind.held : _NodeKind.next),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      // Start at the step being worked on, not at the oldest.
      reverse: false,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (earlier > 0) _EndCap(label: '+$earlier', sub: 'DONE', color: t.good),
          for (final (i, (item, kind)) in nodes.indexed) ...[
            if (i > 0 || earlier > 0) _Link(dashed: kind != _NodeKind.done && kind != _NodeKind.current, color: kind == _NodeKind.done || kind == _NodeKind.current ? t.lineStrong : t.accent.withValues(alpha: 0.3)),
            _Node(item: item, kind: kind, pulse: _pulse, animate: animate && kind == _NodeKind.current, onTap: widget.onOpen == null ? null : () => widget.onOpen!(item)),
          ],
          if (later > 0) ...[
            _Link(dashed: true, color: t.accent.withValues(alpha: 0.3)),
            _EndCap(label: '+$later', sub: 'NEXT', color: t.muted),
          ],
        ],
      ),
    );
  }
}

const double _ring = 26;
const double _cell = 64;

class _Node extends StatelessWidget {
  const _Node({required this.item, required this.kind, required this.pulse, required this.animate, this.onTap});
  final StepItem item;
  final _NodeKind kind;
  final Animation<double> pulse;
  final bool animate;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final color = switch (kind) {
      _NodeKind.done => t.good,
      _NodeKind.current => t.accent,
      _NodeKind.next => t.muted,
      _NodeKind.held => t.warn,
    };
    final label = item.id.length > 11 ? '${item.id.substring(0, 10)}…' : item.id;
    return Semantics(
      button: onTap != null,
      label: '${item.id}: ${item.title}',
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: SizedBox(
          width: _cell,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            SizedBox(
              width: _ring + 24,
              height: _ring + 24,
              child: AnimatedBuilder(
                animation: pulse,
                builder: (context, _) => CustomPaint(painter: _RingPainter(kind: kind, color: color, phase: animate ? pulse.value : 0, t: t)),
              ),
            ),
            Text(label, maxLines: 1, overflow: TextOverflow.clip, textAlign: TextAlign.center, style: t.mono(9.5, color: kind == _NodeKind.current ? t.accent : t.ink2, weight: kind == _NodeKind.current ? FontWeight.w700 : FontWeight.w400)),
            if (kind == _NodeKind.current) Text('NOW', style: t.readout(8.5, color: t.accent)),
          ]),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.kind, required this.color, required this.phase, required this.t});
  final _NodeKind kind;
  final Color color;
  final double phase;
  final KitTokens t;

  @override
  void paint(Canvas canvas, Size size) {
    final o = size.center(Offset.zero);
    final r = kind == _NodeKind.current ? _ring / 2 + 2 : _ring / 2;
    if (kind == _NodeKind.current && phase > 0) {
      final p = Curves.easeOut.transform(phase);
      canvas.drawCircle(o, r + 3 + 9 * p, Paint()..style = PaintingStyle.stroke..strokeWidth = 1.5..color = color.withValues(alpha: 0.4 * (1 - p)));
    }
    switch (kind) {
      case _NodeKind.done:
        canvas.drawCircle(o, r, Paint()..color = color.withValues(alpha: 0.16));
        canvas.drawCircle(o, r, Paint()..style = PaintingStyle.stroke..strokeWidth = 1.5..color = color);
        final check = Path()
          ..moveTo(o.dx - 5, o.dy)
          ..lineTo(o.dx - 1.5, o.dy + 3.5)
          ..lineTo(o.dx + 5.5, o.dy - 4);
        canvas.drawPath(check, Paint()..style = PaintingStyle.stroke..strokeWidth = 1.8..strokeCap = StrokeCap.round..color = color);
      case _NodeKind.current:
        canvas.drawCircle(o, r, Paint()..color = color.withValues(alpha: 0.18));
        canvas.drawCircle(o, r, Paint()..style = PaintingStyle.stroke..strokeWidth = 2.4..color = color);
        canvas.drawCircle(o, 4, Paint()..color = color);
      case _NodeKind.next:
      case _NodeKind.held:
        _dashedCircle(canvas, o, r, Paint()..style = PaintingStyle.stroke..strokeWidth = 1.4..color = color);
        if (kind == _NodeKind.held) {
          canvas.drawLine(o + const Offset(-2.5, -4), o + const Offset(-2.5, 4), Paint()..strokeWidth = 1.8..color = color);
          canvas.drawLine(o + const Offset(2.5, -4), o + const Offset(2.5, 4), Paint()..strokeWidth = 1.8..color = color);
        }
    }
  }

  void _dashedCircle(Canvas canvas, Offset o, double r, Paint paint) {
    const n = 14;
    for (var i = 0; i < n; i++) {
      final a = 2 * math.pi * i / n;
      canvas.drawArc(Rect.fromCircle(center: o, radius: r), a, math.pi / n, false, paint);
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.phase != phase || old.kind != kind || old.color != color;
}

class _Link extends StatelessWidget {
  const _Link({required this.dashed, required this.color});
  final bool dashed;
  final Color color;
  @override
  Widget build(BuildContext context) => SizedBox(
        width: 14,
        height: _ring + 24,
        child: CustomPaint(painter: _LinkPainter(dashed: dashed, color: color)),
      );
}

class _LinkPainter extends CustomPainter {
  _LinkPainter({required this.dashed, required this.color});
  final bool dashed;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height / 2;
    final paint = Paint()..strokeWidth = 1.2..color = color;
    if (!dashed) {
      canvas.drawLine(Offset(-12, y), Offset(size.width + 12, y), paint);
      return;
    }
    for (var x = -12.0; x < size.width + 12; x += 6) {
      canvas.drawLine(Offset(x, y), Offset(math.min(x + 3, size.width + 12), y), paint);
    }
  }

  @override
  bool shouldRepaint(_LinkPainter old) => old.dashed != dashed || old.color != color;
}

class _EndCap extends StatelessWidget {
  const _EndCap({required this.label, required this.sub, required this.color});
  final String label;
  final String sub;
  final Color color;
  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return SizedBox(
      width: 48,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        SizedBox(height: _ring + 24, child: Center(child: Text(label, style: t.mono(12, color: color, weight: FontWeight.w700)))),
        Text(sub, style: t.readout(8.5, color: color)),
      ]),
    );
  }
}

/// A step of a lane's list, whole: what it is for, its text, and what
/// belongs to it — pictures, videos, documents, mail, decisions, its log.
void openStepItem(BuildContext context, String laneName, StepItem item, {String? lane}) {
  final id = lane ?? laneName.trim().split(' ').last.toLowerCase();
  Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => StepPage(laneName: laneName.toUpperCase(), lane: id, item: item)));
}

class StepPage extends StatefulWidget {
  const StepPage({super.key, required this.laneName, required this.lane, required this.item});
  final String laneName;
  final String lane;
  final StepItem item;
  @override
  State<StepPage> createState() => _StepPageState();
}

class _StepPageState extends State<StepPage> {
  late final StepResources? _res = StudioSource.current?.resourcesFor(widget.lane, widget.item);

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final item = widget.item;
    final key = 'step:${widget.lane}/${item.id}';
    return Scaffold(
      appBar: AppBar(title: Text('${widget.laneName} · ${item.id}', maxLines: 1, overflow: TextOverflow.ellipsis)),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Wrap(spacing: 6, runSpacing: 6, children: [
          Pill(item.done ? 'DONE' : (item.held ? 'ON HOLD' : 'OPEN'), color: item.done ? t.good : (item.held ? t.warn : t.accent)),
          if (item.run != null) Pill('RUN ${item.run}', color: t.muted),
        ]),
        if (item.section != null) ...[
          const SizedBox(height: 10),
          Text(item.section!.toUpperCase(), style: t.readout(10, color: t.muted)),
        ],
        const SizedBox(height: 12),
        ListenableBuilder(
          listenable: StudioDesk.threads,
          builder: (context, _) {
            final s = StudioDesk.threads.summary(key);
            return Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: t.accentSoft, borderRadius: BorderRadius.circular(10), border: Border.all(color: t.accent.withValues(alpha: 0.4))),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('WHAT IT IS FOR', style: t.readout(9.5, color: t.accent)),
                const SizedBox(height: 4),
                Text(s ?? item.title, style: TextStyle(fontSize: 14, color: t.ink, height: 1.4)),
                if (s == null) Padding(padding: const EdgeInsets.only(top: 4), child: Text('The step\'s own first line — EXPLAIN on its panel has the step desk write a plain summary.', style: t.mono(10.5, color: t.muted))),
              ]),
            );
          },
        ),
        const SizedBox(height: 14),
        Md(item.text),
        if (_res != null) ...[
          const SizedBox(height: 18),
          ResourcesView(resources: _res, lane: widget.lane, run: item.run),
        ],
      ]),
    );
  }
}

/// What belongs to a step: thumbnails that open full size, videos and
/// documents that open in their app, mail and decisions that open as
/// pages, and its log.
class ResourcesView extends StatelessWidget {
  const ResourcesView({super.key, required this.resources, this.lane, this.run});
  final StepResources resources;
  final String? lane;
  final String? run;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final r = resources;
    Widget row(IconData icon, String title, String sub, VoidCallback onTap) => ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 4),
          dense: true,
          leading: Icon(icon, color: t.accent),
          title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.mono(10.5, color: t.muted)),
          onTap: onTap,
        );
    void page(String title, String body) => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => Scaffold(appBar: AppBar(title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis)), body: ListView(padding: const EdgeInsets.all(16), children: [Md(body)]))));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SectionHead('RESOURCES', sub: r.isEmpty ? 'nothing found for this step' : r.label.toLowerCase()),
      if (r.missing > 0) Padding(padding: const EdgeInsets.only(top: 4), child: Text('${r.missing} named file${r.missing == 1 ? '' : 's'} not on this machine', style: t.mono(10.5, color: t.muted))),
      if (r.images.isNotEmpty) ...[
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final img in r.images)
            InkWell(
              onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => _ImageView(path: img))),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(File(img), width: 150, height: 100, fit: BoxFit.cover, cacheWidth: 300, errorBuilder: (_, _, _) => Container(width: 150, height: 100, color: t.ground, alignment: Alignment.center, child: Text(p.basename(img), textAlign: TextAlign.center, style: t.mono(9, color: t.muted)))),
              ),
            ),
        ]),
      ],
      for (final v in r.videos) row(Icons.movie_outlined, p.basename(v), v, () => OpenFilex.open(v)),
      for (final d in r.docs) row(d.endsWith('.md') ? Icons.article_outlined : Icons.description_outlined, p.basename(d), d, () => d.endsWith('.md') ? page(p.basename(d), File(d).readAsStringSync()) : OpenFilex.open(d)),
      for (final m in r.mails) row(Icons.mail_outline, m.title, m.file, () => page(m.title, m.body)),
      for (final (head, body) in r.decisions) row(Icons.gavel_outlined, head, 'decision log', () => page(head, body)),
      if (r.log != null && lane != null && run != null) row(Icons.terminal, 'Step log', p.basename(r.log!), () {
        final text = StudioSource.current?.stepLog(lane!, run!) ?? '';
        Navigator.of(context).push(MaterialPageRoute<void>(builder: (context) => Scaffold(appBar: AppBar(title: Text('STEP $run · LOG')), body: SelectionArea(child: ListView(padding: const EdgeInsets.all(16), children: [Text(text, style: context.tokens.mono(12, color: context.tokens.ink2))])))));
      }),
    ]);
  }
}

class _ImageView extends StatelessWidget {
  const _ImageView({required this.path});
  final String path;
  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(title: Text(p.basename(path), maxLines: 1, overflow: TextOverflow.ellipsis), actions: [IconButton(tooltip: 'Open in Preview', icon: const Icon(Icons.open_in_new), onPressed: () => OpenFilex.open(path))]),
        body: InteractiveViewer(maxScale: 8, child: Center(child: Image.file(File(path)))),
      );
}

// --- the roadmap ----------------------------------------------------------------

Color statusColor(KitTokens t, ItemStatus s) => switch (s) {
      ItemStatus.done => t.good,
      ItemStatus.built => const Color(0xFF7FB6A6),
      ItemStatus.inProgress => t.accent,
      ItemStatus.notStarted => t.muted,
      ItemStatus.other => t.ink2,
    };

String statusWord(ItemStatus s) => switch (s) {
      ItemStatus.done => 'DONE',
      ItemStatus.built => 'BUILT · CHECK OWED',
      ItemStatus.inProgress => 'IN PROGRESS',
      ItemStatus.notStarted => 'NOT STARTED',
      ItemStatus.other => 'OPEN',
    };

/// The milestone ladder, top to bottom: each milestone a bar of its items
/// by state and a field of dots, one per item; a tap opens the item.
class RoadmapView extends StatelessWidget {
  const RoadmapView({super.key, required this.milestones});
  final List<Milestone> milestones;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    if (milestones.isEmpty) return const EmptyNote('No roadmap found — pick the game repo under Folders (it reads production/production-plan.md).');
    // The first milestone with open work is where the team is.
    final nowKey = milestones.firstWhere((m) => m.items.any((i) => i.status != ItemStatus.done), orElse: () => milestones.last).key;
    return ListView(
      key: const Key('studio-roadmap'),
      padding: const EdgeInsets.all(16),
      children: [
        Wrap(spacing: 12, runSpacing: 6, children: [
          for (final s in [ItemStatus.done, ItemStatus.built, ItemStatus.inProgress, ItemStatus.notStarted])
            Row(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 10, height: 10, decoration: BoxDecoration(shape: BoxShape.circle, color: statusColor(t, s))),
              const SizedBox(width: 5),
              Flexible(child: Text(statusWord(s), style: t.readout(9.5, color: t.ink2))),
            ]),
        ]),
        const SizedBox(height: 14),
        for (final (i, m) in milestones.indexed) _MilestoneRow(milestone: m, current: m.key == nowKey, last: i == milestones.length - 1),
      ],
    );
  }
}

class _MilestoneRow extends StatelessWidget {
  const _MilestoneRow({required this.milestone, required this.current, required this.last});
  final Milestone milestone;
  final bool current;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final m = milestone;
    final total = m.items.length;
    final closed = total > 0 && m.doneCount == total;
    final color = closed ? t.good : (current ? t.accent : t.muted);
    final counts = {for (final s in ItemStatus.values) s: m.items.where((i) => i.status == s).length};
    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // The ladder's rail: a ring per milestone, joined.
        SizedBox(
          width: 34,
          child: Column(children: [
            Container(
              width: 22,
              height: 22,
              margin: const EdgeInsets.only(top: 2),
              decoration: BoxDecoration(shape: BoxShape.circle, color: closed ? t.good.withValues(alpha: 0.18) : (current ? t.accentSoft : null), border: Border.all(color: color, width: current ? 2.4 : 1.5)),
              child: closed ? Icon(Icons.check, size: 13, color: t.good) : null,
            ),
            if (!last) Expanded(child: Container(width: 1.5, color: closed ? t.good.withValues(alpha: 0.5) : t.line)),
          ]),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 22),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                Text(m.key, style: t.display(18, color: color)),
                Text(m.name.replaceFirst(RegExp('^${RegExp.escape(m.key)}\\s*'), '').toUpperCase(), style: t.display(15, ls: 0.6)),
                if (current) Pill('WE ARE HERE', color: t.accent, filled: true),
              ]),
              if (total > 0) Text('${m.doneCount} of $total done${counts[ItemStatus.inProgress]! > 0 ? ' · ${counts[ItemStatus.inProgress]} in progress' : ''}${counts[ItemStatus.built]! > 0 ? ' · ${counts[ItemStatus.built]} built, check owed' : ''}', style: t.mono(11, color: t.muted)),
              if (m.goal.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text(m.goal, maxLines: current ? 4 : 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, color: t.ink2, height: 1.35))),
              if (total > 0) ...[
                const SizedBox(height: 8),
                _StatusBar(counts: counts, total: total),
                const SizedBox(height: 8),
                Wrap(spacing: 6, runSpacing: 6, children: [for (final it in _sorted(m.items)) _ItemDot(item: it)]),
              ],
            ]),
          ),
        ),
      ]),
    );
  }

  /// In progress first, then built, not started, done — what moves leads.
  static List<RoadmapItem> _sorted(List<RoadmapItem> items) {
    const order = {ItemStatus.inProgress: 0, ItemStatus.built: 1, ItemStatus.other: 2, ItemStatus.notStarted: 3, ItemStatus.done: 4};
    return [...items]..sort((a, b) => order[a.status]!.compareTo(order[b.status]!));
  }
}

class _StatusBar extends StatelessWidget {
  const _StatusBar({required this.counts, required this.total});
  final Map<ItemStatus, int> counts;
  final int total;
  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: SizedBox(
        height: 7,
        child: Row(children: [
          for (final s in [ItemStatus.done, ItemStatus.built, ItemStatus.inProgress, ItemStatus.other, ItemStatus.notStarted])
            if (counts[s]! > 0) Expanded(flex: counts[s]!, child: Container(color: s == ItemStatus.notStarted ? t.line : statusColor(t, s))),
        ]),
      ),
    );
  }
}

class _ItemDot extends StatelessWidget {
  const _ItemDot({required this.item});
  final RoadmapItem item;
  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final c = statusColor(t, item.status);
    final filled = item.status == ItemStatus.done || item.status == ItemStatus.built;
    return Tooltip(
      message: '${item.id} · ${item.task}',
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: () => openRoadmapItem(context, item),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            color: filled ? c.withValues(alpha: 0.16) : (item.status == ItemStatus.inProgress ? t.accentSoft : null),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: c.withValues(alpha: item.status == ItemStatus.notStarted ? 0.5 : 0.9)),
          ),
          child: Text(item.id, style: t.mono(10.5, color: item.status == ItemStatus.notStarted ? t.muted : t.ink, weight: item.status == ItemStatus.inProgress ? FontWeight.w700 : FontWeight.w400)),
        ),
      ),
    );
  }
}

void openRoadmapItem(BuildContext context, RoadmapItem item) {
  final t = context.tokens;
  Navigator.of(context).push(MaterialPageRoute<void>(
    builder: (context) => Scaffold(
      appBar: AppBar(title: Text('${item.id} · ${item.task}', maxLines: 1, overflow: TextOverflow.ellipsis)),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Text(item.task, style: t.display(19, weight: FontWeight.w600)),
        const SizedBox(height: 8),
        Wrap(spacing: 6, runSpacing: 6, children: [
          Pill(statusWord(item.status), color: statusColor(t, item.status)),
          Pill(item.milestone, color: t.muted),
          if (item.size != null) Pill('SIZE ${item.size}', color: t.muted),
        ]),
        if (item.owner != null) ...[const SizedBox(height: 10), Text('OWNER · ${item.owner}'.toUpperCase(), style: t.readout(10, color: t.muted))],
        const SizedBox(height: 12),
        Md(item.status == ItemStatus.done ? 'Done ${item.statusText}' : item.statusText, compact: true, color: t.ink),
        if (item.summary.isNotEmpty) ...[const SizedBox(height: 12), Md(item.summary)],
        if (StudioSource.current != null) ...[const SizedBox(height: 18), ResourcesView(resources: StudioSource.current!.resourcesForItem(item))],
      ]),
    ),
  ));
}
