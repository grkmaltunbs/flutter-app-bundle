import 'dart:math' as math;

import 'package:flutter/material.dart' hide Step, StepState;
import 'package:flutter_kit/kit.dart';

import '../theme.dart';
import '../widgets/common.dart';

/// The constellation. Same layout as the board (`layoutDag`), drawn as the
/// canvas draws it: rings by state over a faint grid, the ready step
/// pulsing, the selected one haloed. Portrait turns the graph on its side
/// so the story reads top to bottom on a phone.
class StepsTab extends StatefulWidget {
  const StepsTab({super.key, required this.plan, required this.graph, required this.selected, required this.onSelect, this.onOpenDetail, this.showPanel = true, this.session = GlyphMode.idle});
  final Plan plan;
  final Graph graph;
  final String? selected;
  final void Function(String? id) onSelect;

  /// The session's mood — it decides the colour and pace of the energy
  /// waves orbiting the step the session is on.
  final GlyphMode session;

  /// Opens the full step sheet (phone); the wide layout shows it beside.
  final void Function(String id)? onOpenDetail;
  final bool showPanel;

  @override
  State<StepsTab> createState() => _StepsTabState();
}

double _radiusFor(StepState s, {bool selected = false}) {
  final r = switch (s) {
    StepState.done => 9.0,
    StepState.blocked || StepState.waiting => 11.0,
    _ => 13.0,
  };
  return selected ? r + 2 : r;
}

bool _numbered(StepState s) => switch (s) {
      StepState.done || StepState.blocked || StepState.waiting => false,
      _ => true,
    };

class _StepsTabState extends State<StepsTab> with TickerProviderStateMixin {
  final _controller = TransformationController();
  late final _halo = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400));
  late final _orbit = AnimationController(vsync: this, duration: _orbitDuration(widget.session));
  GlyphMode _orbitMode = GlyphMode.idle;
  bool _centred = false;

  static Duration _orbitDuration(GlyphMode m) => switch (m) {
        GlyphMode.idle => const Duration(milliseconds: 7000),
        GlyphMode.live => const Duration(milliseconds: 4500),
        GlyphMode.busy => const Duration(milliseconds: 1600),
        GlyphMode.ask => const Duration(milliseconds: 1000),
      };

  @override
  void dispose() {
    _controller.dispose();
    _halo.dispose();
    _orbit.dispose();
    super.dispose();
  }

  Offset _pt(NodePos p, bool portrait) => portrait ? Offset(p.y + 60, p.x * 0.9 + 40) : Offset(p.x * 1.15 + 60, p.y * 1.35 + 30);

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final lay = layoutDag(widget.plan.steps);
    final views = {for (final v in widget.graph.views()) v.step.id: v};
    final next = widget.graph.nextStep()?.step.id;
    final selectedView = widget.selected == null ? null : views[widget.selected];

    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final hasReady = views.values.any((v) => v.state == StepState.ready);
    if (hasReady && !still) {
      if (!_halo.isAnimating) _halo.repeat();
    } else {
      _halo.stop();
    }
    if (_orbitMode != widget.session) {
      _orbitMode = widget.session;
      _orbit.duration = _orbitDuration(widget.session);
      if (_orbit.isAnimating) _orbit.repeat();
    }
    if (!still && !_orbit.isAnimating) _orbit.repeat();
    if (still) _orbit.stop();

    // The waves circle the step the session is on: the active one, else
    // the one it would pick up next.
    String? waveTarget;
    for (final v in views.values) {
      if (v.state == StepState.active) {
        waveTarget = v.step.id;
        break;
      }
    }
    waveTarget ??= next;

    return LayoutBuilder(
      builder: (context, box) {
        final portrait = box.maxHeight >= box.maxWidth;
        final width = (portrait ? lay.height : lay.width * 1.15) + 120;
        final height = (portrait ? lay.width * 0.9 : lay.height * 1.35) + 110;

        if (!_centred) {
          _centred = true;
          // Open on the step Claude works next, roughly centred.
          final focus = widget.selected ?? next;
          final pos = focus == null ? null : lay.nodes[focus];
          if (pos != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              final size = context.size ?? Size.zero;
              final o = _pt(pos, portrait);
              _controller.value = Matrix4.identity()..translateByDouble(size.width / 2 - o.dx, size.height / 3 - o.dy, 0, 1);
            });
          }
        }

        return Column(
          children: [
            _Head(views: views.values.toList(), tokens: t),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: Container(
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(color: t.ground, borderRadius: BorderRadius.circular(12), border: Border.all(color: t.line)),
                  child: Stack(
                    children: [
                      Positioned.fill(child: CustomPaint(painter: _GridPainter(t))),
                      Positioned.fill(
                        child: InteractiveViewer(
                          transformationController: _controller,
                          constrained: false,
                          minScale: 0.35,
                          maxScale: 2.5,
                          boundaryMargin: const EdgeInsets.all(600),
                          child: SizedBox(
                            width: width,
                            height: height,
                            child: AnimatedBuilder(
                              animation: Listenable.merge([_halo, _orbit]),
                              builder: (context, _) => Stack(
                                children: [
                                  Positioned.fill(
                                    child: GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onTap: () => widget.onSelect(null),
                                      child: CustomPaint(
                                        painter: _ConstellationPainter(
                                        lay: lay,
                                        views: views,
                                        selected: widget.selected,
                                        next: next,
                                        phase: _halo.isAnimating ? _halo.value : 0,
                                        waveMode: widget.session,
                                        waveTarget: waveTarget,
                                        wavePhase: _orbit.isAnimating ? _orbit.value : -1,
                                        portrait: portrait,
                                        t: t,
                                        pt: (p) => _pt(p, portrait),
                                        ),
                                      ),
                                    ),
                                  ),
                                  for (final s in widget.plan.steps)
                                    if (lay.nodes[s.id] case final pos?) _node(t, s, views[s.id]!, _pt(pos, portrait)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (widget.showPanel && selectedView != null)
              _StepPanel(
                view: selectedView,
                maxHeight: box.maxHeight * 0.45,
                onOpen: widget.onOpenDetail == null ? null : () => widget.onOpenDetail!(widget.selected!),
              ),
          ],
        );
      },
    );
  }

  Widget _node(KitTokens t, Step s, StepView v, Offset o) {
    final selected = s.id == widget.selected;
    final r = _radiusFor(v.state, selected: selected);
    final color = t.forState(v.state);
    final label = s.number ?? s.id;
    return Positioned(
      left: o.dx - 52,
      top: o.dy - r,
      width: 104,
      child: GestureDetector(
        onTap: () => widget.onSelect(selected ? null : s.id),
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: r * 2,
              child: _numbered(v.state)
                  ? Center(
                      child: Text(
                        label.length > 4 ? label.substring(0, 4) : label,
                        style: t.display(label.length > 3 ? 10 : 12, ls: 0, color: v.state == StepState.active ? t.onAccent : color),
                      ),
                    )
                  : null,
            ),
            const SizedBox(height: 5),
            Text(
              s.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: t.mono(10, height: 1.25, color: selected ? t.ink : (v.state == StepState.done || v.state == StepState.blocked || v.state == StepState.waiting ? t.muted : t.ink2)),
            ),
          ],
        ),
      ),
    );
  }
}

class _Head extends StatelessWidget {
  const _Head({required this.views, required this.tokens});
  final List<StepView> views;
  final KitTokens tokens;

  @override
  Widget build(BuildContext context) {
    final t = tokens;
    int of(StepState s) => views.where((v) => v.state == s).length;
    final done = of(StepState.done) + of(StepState.flippable);
    final active = of(StepState.active);
    final cc = of(StepState.codeComplete);
    final ready = of(StepState.ready);
    final parts = [
      '${views.length}',
      if (done > 0) '$done DONE',
      if (active > 0) '$active ACTIVE',
      if (cc > 0) '$cc CODE COMPLETE',
      if (ready > 0) '$ready READY',
    ];
    Widget ring(Color c, String l, {bool filled = false}) => Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: filled ? c.withValues(alpha: 0.5) : null, border: Border.all(color: c, width: filled ? 1 : 2))),
          const SizedBox(width: 5),
          Text(l, style: t.readout(9)),
        ]);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.end,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('STEPS', style: t.display(22, ls: 3.2)),
              const SizedBox(height: 4),
              Text(parts.join(' · '), style: t.readout(11)),
            ],
          ),
          ring(t.good, 'DONE', filled: true),
          ring(t.warn, 'WAITS ON YOU'),
          ring(t.accent, 'READY'),
        ],
      ),
    );
  }
}

/// What a tap shows without leaving the constellation: the step's state,
/// its gate rings, and the boxes of yours that hold it.
class _StepPanel extends StatelessWidget {
  const _StepPanel({required this.view, required this.maxHeight, this.onOpen});
  final StepView view;
  final double maxHeight;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final v = view;
    final s = v.step;
    final color = t.forState(v.state);
    return Container(
      width: double.infinity,
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: BoxDecoration(color: t.surface, border: Border(top: BorderSide(color: t.accent.withValues(alpha: 0.28)))),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(child: Text('STEP ${s.number ?? s.id} · ${stateLabel(v.state)}'.toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis, style: t.display(13, ls: 2.2, color: color))),
              Text('RANK ${s.rank}', style: t.readout(11)),
            ]),
            const SizedBox(height: 6),
            Text(s.title, style: t.display(19, weight: FontWeight.w600, ls: 0.3, height: 1.2)),
            if (s.gates.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(spacing: 8, runSpacing: 8, children: [for (final g in s.gates.values) GateCard(g)]),
            ],
            if (v.openBlockers.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('HELD BY ${v.openBlockers.length} OF YOUR BOX${v.openBlockers.length == 1 ? '' : 'ES'}', style: t.readout(11, color: t.warn)),
              const SizedBox(height: 8),
              for (final (i, item) in v.openBlockers.indexed)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(children: [
                    Pill(item.needs.isEmpty ? 'item' : item.needs.first, color: i == 0 ? t.warn : t.muted),
                    const SizedBox(width: 10),
                    Expanded(child: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13.5, color: i == 0 ? t.ink : t.ink2))),
                  ]),
                ),
            ],
            if (onOpen != null) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(foregroundColor: t.accent, side: BorderSide(color: t.accent.withValues(alpha: 0.45)), backgroundColor: t.accentSoft.withValues(alpha: 0.5)),
                  onPressed: onOpen,
                  child: const Text('OPEN THE STEP'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  _GridPainter(this.t);
  final KitTokens t;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = t.lineStrong.withValues(alpha: t.brightness == Brightness.dark ? 0.12 : 0.35)
      ..strokeWidth = 1;
    for (var x = 0.0; x < size.width; x += 28) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var y = 0.0; y < size.height; y += 28) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_GridPainter old) => old.t != t;
}

class _ConstellationPainter extends CustomPainter {
  _ConstellationPainter(
      {required this.lay,
      required this.views,
      required this.selected,
      required this.next,
      required this.phase,
      required this.waveMode,
      required this.waveTarget,
      required this.wavePhase,
      required this.portrait,
      required this.t,
      required this.pt});
  final DagLayout lay;
  final Map<String, StepView> views;
  final String? selected;
  final String? next;
  final double phase;
  final GlyphMode waveMode;
  final String? waveTarget;

  /// -1 under "reduce motion": no waves.
  final double wavePhase;
  final bool portrait;
  final KitTokens t;
  final Offset Function(NodePos) pt;

  @override
  void paint(Canvas canvas, Size size) {
    // Edges first: settled lines solid and faint, unfinished ones dashed
    // cyan; whatever touches the selected step lights up.
    for (final pass in [false, true]) {
      for (final (from, to) in lay.edges) {
        final isHot = selected != null && (from == selected || to == selected);
        if (isHot != pass) continue;
        final a = pt(lay.nodes[from]!);
        final b = pt(lay.nodes[to]!);
        final va = views[from]!;
        final vb = views[to]!;
        final dir = (b - a) / (b - a).distance;
        final p1 = a + dir * (_radiusFor(va.state) + 4);
        final p2 = b - dir * (_radiusFor(vb.state) + 4);
        final settled = vb.state == StepState.done || vb.state == StepState.flippable;
        final paint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = isHot ? 2 : 1
          ..color = isHot
              ? t.accent
              : settled
                  ? t.lineStrong
                  : t.accent.withValues(alpha: 0.28);
        if (settled || isHot) {
          canvas.drawLine(p1, p2, paint);
        } else {
          _dashed(canvas, p1, p2, paint);
        }
      }
    }

    for (final e in lay.nodes.entries) {
      final v = views[e.key]!;
      final o = pt(e.value);
      final isSelected = e.key == selected;
      final r = _radiusFor(v.state, selected: isSelected);
      final color = t.forState(v.state);

      // The session's energy circles the step it is on — colour and pace
      // follow its mood: dim when idle, cyan while working, green when the
      // turn is done, amber when it asks for a hand.
      if (e.key == waveTarget && wavePhase >= 0) _waves(canvas, o, r);

      // The ready step breathes; the selected one wears a still halo.
      if (v.state == StepState.ready && e.key == next && phase > 0) {
        final p = Curves.easeOut.transform(phase);
        canvas.drawCircle(
            o,
            r + 4 + 12 * p,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.5
              ..color = t.accent.withValues(alpha: 0.35 * (1 - p)));
      }
      if (isSelected) {
        canvas.drawCircle(
            o,
            r + 9,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1
              ..color = color.withValues(alpha: 0.55));
      }

      switch (v.state) {
        case StepState.done:
          canvas.drawCircle(o, r, Paint()..color = t.good.withValues(alpha: t.brightness == Brightness.dark ? 0.22 : 0.16));
          canvas.drawCircle(
              o,
              r,
              Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 1.4
                ..color = t.good.withValues(alpha: 0.8));
        case StepState.blocked:
        case StepState.waiting:
          canvas.drawCircle(o, r, Paint()..color = t.ground);
          _dashedCircle(
              canvas,
              o,
              r,
              Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 1.5
                ..color = t.muted.withValues(alpha: 0.7));
        case StepState.active:
          canvas.drawCircle(o, r, Paint()..color = color);
        default:
          canvas.drawCircle(o, r, Paint()..color = t.surface);
          canvas.drawCircle(
              o,
              r,
              Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = isSelected ? 2.5 : 2
                ..color = color);
      }
    }
  }

  void _waves(Canvas canvas, Offset o, double baseR) {
    final color = switch (waveMode) {
      GlyphMode.idle => t.muted,
      GlyphMode.busy => t.accent,
      GlyphMode.live => t.good,
      GlyphMode.ask => t.warn,
    };
    final idle = waveMode == GlyphMode.idle;
    final arcs = idle ? 1 : 3;
    for (var i = 0; i < arcs; i++) {
      final dir = i.isEven ? 1.0 : -1.0;
      final radius = baseR + 8 + i * 5.5;
      final start = 2 * math.pi * wavePhase * dir + i * 2.1;
      final sweep = (1.7 - i * 0.35) * dir;
      final rect = Rect.fromCircle(center: o, radius: radius);
      // The soft glow under the filament.
      canvas.drawArc(
          rect,
          start,
          sweep,
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 4.5
            ..strokeCap = StrokeCap.round
            ..color = color.withValues(alpha: idle ? 0.05 : 0.10));
      canvas.drawArc(
          rect,
          start,
          sweep,
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.6
            ..strokeCap = StrokeCap.round
            ..color = color.withValues(alpha: idle ? 0.35 : 0.85 - i * 0.18));
      if (!idle) {
        // The spark at the wave's head.
        final head = start + sweep;
        canvas.drawCircle(o + Offset(math.cos(head), math.sin(head)) * radius, 1.9, Paint()..color = color.withValues(alpha: 0.95));
      }
    }
  }

  void _dashed(Canvas canvas, Offset a, Offset b, Paint paint, {double dash = 3, double gap = 4}) {
    final total = (b - a).distance;
    if (total <= 0) return;
    final dir = (b - a) / total;
    var d = 0.0;
    while (d < total) {
      canvas.drawLine(a + dir * d, a + dir * (d + dash).clamp(0, total), paint);
      d += dash + gap;
    }
  }

  void _dashedCircle(Canvas canvas, Offset c, double r, Paint paint, {double dash = 3, double gap = 3}) {
    final path = Path()..addOval(Rect.fromCircle(center: c, radius: r));
    for (final metric in path.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        canvas.drawPath(metric.extractPath(d, (d + dash).clamp(0, metric.length)), paint);
        d += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(_ConstellationPainter old) =>
      old.selected != selected ||
      old.next != next ||
      old.phase != phase ||
      old.wavePhase != wavePhase ||
      old.waveMode != waveMode ||
      old.waveTarget != waveTarget ||
      old.lay != lay ||
      old.t != t ||
      old.portrait != portrait;
}
