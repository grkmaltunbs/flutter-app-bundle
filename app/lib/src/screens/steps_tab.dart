import 'package:flutter/material.dart' hide Step, StepState;
import 'package:flutter_kit/kit.dart';

import '../theme.dart';

const _sx = 1.15;
const _sy = 1.35;
const _r = 23.0;

/// The bubbles. Same layout as the board (`layoutDag`), scaled up a little
/// for fingers, on a pannable, zoomable canvas. Edges are faint until a
/// bubble is selected; then what it waits on and what it unlocks light up.
class StepsTab extends StatefulWidget {
  const StepsTab({super.key, required this.plan, required this.graph, required this.selected, required this.onSelect});
  final Plan plan;
  final Graph graph;
  final String? selected;
  final void Function(String? id) onSelect;

  @override
  State<StepsTab> createState() => _StepsTabState();
}

class _StepsTabState extends State<StepsTab> {
  final _controller = TransformationController();
  bool _centred = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final lay = layoutDag(widget.plan.steps);
    final views = {for (final v in widget.graph.views()) v.step.id: v};
    final width = lay.width * _sx + 120;
    final height = lay.height * _sy + 120;
    final next = widget.graph.nextStep()?.step.id;

    if (!_centred) {
      _centred = true;
      // Open on the step Claude works next, roughly centred.
      final focus = widget.selected ?? next;
      final pos = focus == null ? null : lay.nodes[focus];
      if (pos != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          final size = context.size ?? Size.zero;
          _controller.value = Matrix4.identity()..translateByDouble(size.width / 2 - pos.x * _sx, size.height / 2 - pos.y * _sy, 0, 1);
        });
      }
    }

    return Stack(
      children: [
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
              child: Stack(
                children: [
                  Positioned.fill(child: CustomPaint(painter: _EdgePainter(lay, widget.selected, t))),
                  for (final s in widget.plan.steps)
                    if (lay.nodes[s.id] case final pos?)
                      Positioned(
                        left: pos.x * _sx - 60,
                        top: pos.y * _sy - _r,
                        width: 120,
                        child: _Bubble(step: s, view: views[s.id]!, selected: s.id == widget.selected, isNext: s.id == next, onTap: () => widget.onSelect(s.id)),
                      ),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          left: 12,
          bottom: 12,
          child: _Legend(),
        ),
      ],
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.step, required this.view, required this.selected, required this.isNext, required this.onTap});
  final Step step;
  final StepView view;
  final bool selected;
  final bool isNext;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final color = t.forState(view.state);
    final filled = view.state == StepState.done || view.state == StepState.active;
    final label = step.number ?? step.id;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: _r * 2,
            height: _r * 2,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: filled ? color : t.surface,
              border: Border.all(color: selected ? t.ink : color, width: selected ? 3 : (isNext ? 2.5 : 1.6)),
              boxShadow: selected || isNext ? [BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 14, spreadRadius: 1)] : null,
            ),
            alignment: Alignment.center,
            child: Text(
              label.length > 4 ? label.substring(0, 4) : label,
              style: TextStyle(fontSize: label.length > 3 ? 10.5 : 13, fontWeight: FontWeight.w800, color: filled ? Colors.white : color),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            step.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 10.5, height: 1.15, color: selected ? t.ink : t.ink2, fontWeight: selected ? FontWeight.w700 : FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

class _EdgePainter extends CustomPainter {
  _EdgePainter(this.lay, this.selected, this.t);
  final DagLayout lay;
  final String? selected;
  final KitTokens t;

  @override
  void paint(Canvas canvas, Size size) {
    final faint = Paint()
      ..color = t.line
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final hot = Paint()
      ..color = t.accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2;
    for (final pass in [false, true]) {
      for (final (from, to) in lay.edges) {
        final isHot = selected != null && (from == selected || to == selected);
        if (isHot != pass) continue;
        final a = lay.nodes[from]!;
        final b = lay.nodes[to]!;
        final x1 = a.x * _sx + _r;
        final y1 = a.y * _sy;
        final x2 = b.x * _sx - _r;
        final y2 = b.y * _sy;
        final dx = (x2 - x1) / 2;
        final path = Path()
          ..moveTo(x1, y1)
          ..cubicTo(x1 + dx, y1, x2 - dx, y2, x2, y2);
        canvas.drawPath(path, isHot ? hot : faint);
      }
    }
  }

  @override
  bool shouldRepaint(_EdgePainter old) => old.selected != selected || old.lay != lay || old.t != t;
}

class _Legend extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    Widget dot(Color c, String l, {bool filled = true}) => Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(shape: BoxShape.circle, color: filled ? c : t.surface, border: Border.all(color: c, width: 1.5))),
          const SizedBox(width: 5),
          Text(l, style: TextStyle(fontSize: 11, color: t.ink2)),
        ]);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: t.surface.withValues(alpha: 0.92), borderRadius: BorderRadius.circular(10), border: Border.all(color: t.line)),
      child: Wrap(spacing: 12, runSpacing: 4, children: [
        dot(t.good, 'done'),
        dot(t.accent, 'in progress'),
        dot(t.accent, 'ready', filled: false),
        dot(t.warn, 'waiting on you', filled: false),
        dot(t.muted, 'blocked', filled: false),
      ]),
    );
  }
}
