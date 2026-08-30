import 'dart:math' as math;

import 'package:flutter/material.dart' hide Step, StepState;
import 'package:flutter_kit/kit.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

import '../theme.dart';

String stateLabel(StepState s) {
  switch (s) {
    case StepState.done:
      return 'done';
    case StepState.blocked:
      return 'blocked';
    case StepState.waiting:
      return 'waiting';
    case StepState.ready:
      return 'ready';
    case StepState.active:
      return 'in progress';
    case StepState.codeComplete:
      return 'code complete';
    case StepState.flippable:
      return 'ready to close';
  }
}

/// The skin's chip: a small mono ALL-CAPS readout in a hairline box.
/// Filled, it is the hot state (NEEDS YOU) and takes the colour as ground.
class Pill extends StatelessWidget {
  const Pill(this.text, {super.key, required this.color, this.filled = false, this.icon});
  final String text;
  final Color color;
  final bool filled;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final fg = filled ? (color.computeLuminance() > 0.45 ? const Color(0xFF10161E) : Colors.white) : color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: filled ? color : Colors.transparent,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: filled ? color : color.withValues(alpha: t.brightness == Brightness.dark ? 0.45 : 0.6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 11, color: fg), const SizedBox(width: 4)],
          // Loose, so a long label shrinks instead of overflowing — a Row
          // with mainAxisSize.min is only as small as its children insist on.
          Flexible(child: Text(text.toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis, style: t.mono(10, color: fg, weight: FontWeight.w500, ls: 0.6, height: 1.5))),
        ],
      ),
    );
  }
}

class StatePill extends StatelessWidget {
  const StatePill(this.state, {super.key});
  final StepState state;
  @override
  Widget build(BuildContext context) => Pill(stateLabel(state), color: context.tokens.forState(state), filled: state == StepState.active);
}

class SectionHead extends StatelessWidget {
  const SectionHead(this.title, {super.key, this.sub, this.color});
  final String title;
  final String? sub;
  final Color? color;
  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title.toUpperCase(), style: t.readout(11, color: color ?? t.muted, weight: FontWeight.w500)),
          if (sub != null) Padding(padding: const EdgeInsets.only(top: 3), child: Text(sub!, style: TextStyle(fontSize: 12.5, color: t.ink2))),
        ],
      ),
    );
  }
}

class Md extends StatelessWidget {
  const Md(this.data, {super.key, this.compact = false, this.color});
  final String data;
  final bool compact;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final base = Theme.of(context).textTheme.bodyMedium!.copyWith(fontSize: compact ? 13 : 14.5, height: 1.5, color: color ?? t.ink2);
    return MarkdownBody(
      data: data,
      selectable: true,
      styleSheet: MarkdownStyleSheet(
        p: base,
        listBullet: base,
        code: t.mono(compact ? 12 : 13, color: t.ink).copyWith(backgroundColor: t.accentSoft.withValues(alpha: 0.5)),
        codeblockDecoration: BoxDecoration(color: t.bg, borderRadius: BorderRadius.circular(8), border: Border.all(color: t.line)),
        codeblockPadding: const EdgeInsets.all(10),
        h1: t.display(18, weight: FontWeight.w600, ls: 0.6),
        h2: t.display(16, weight: FontWeight.w600, ls: 0.5),
        h3: t.display(15, weight: FontWeight.w600, ls: 0.4),
        h4: base.copyWith(fontWeight: FontWeight.w700, color: t.ink),
        strong: base.copyWith(fontWeight: FontWeight.w700, color: t.ink),
        blockquoteDecoration: BoxDecoration(border: Border(left: BorderSide(color: t.lineStrong, width: 3))),
        blockquotePadding: const EdgeInsets.only(left: 12),
        tableBorder: TableBorder.all(color: t.line),
        tableCellsPadding: const EdgeInsets.all(6),
        horizontalRuleDecoration: BoxDecoration(border: Border(top: BorderSide(color: t.line))),
      ),
    );
  }
}

class EmptyNote extends StatelessWidget {
  const EmptyNote(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Center(child: Text(text, textAlign: TextAlign.center, style: TextStyle(color: context.tokens.muted))),
      );
}

// --- Motion: exactly three things move — the live dot, the sweep and the
// --- ready halo. Each stops under "reduce motion".

bool _still(BuildContext context) => MediaQuery.maybeDisableAnimationsOf(context) ?? false;

/// How the session carries itself: a resting breath, a working sweep, the
/// live pulse, or the amber double-knock when it needs a person.
enum GlyphMode { idle, live, busy, ask }

class StatusGlyph extends StatefulWidget {
  const StatusGlyph({super.key, required this.color, required this.mode, this.size = 16});
  final Color color;
  final GlyphMode mode;
  final double size;

  @override
  State<StatusGlyph> createState() => _StatusGlyphState();
}

class _StatusGlyphState extends State<StatusGlyph> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: _durationFor(widget.mode));

  static Duration _durationFor(GlyphMode m) => switch (m) {
        GlyphMode.idle => const Duration(milliseconds: 3600),
        GlyphMode.live => const Duration(milliseconds: 2200),
        GlyphMode.busy => const Duration(milliseconds: 1100),
        GlyphMode.ask => const Duration(milliseconds: 1400),
      };

  @override
  void didUpdateWidget(StatusGlyph old) {
    super.didUpdateWidget(old);
    if (old.mode != widget.mode) {
      _c.duration = _durationFor(widget.mode);
      if (_c.isAnimating) _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final still = _still(context);
    if (!still && !_c.isAnimating) _c.repeat();
    if (still) _c.stop();
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) => CustomPaint(size: Size.square(widget.size), painter: _GlyphPainter(widget.mode, widget.color, still ? -1 : _c.value)),
    );
  }
}

class _GlyphPainter extends CustomPainter {
  _GlyphPainter(this.mode, this.color, this.phase);
  final GlyphMode mode;
  final Color color;

  /// -1 under "reduce motion": just the dot.
  final double phase;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    const dotR = 3.5;
    if (phase < 0) {
      canvas.drawCircle(c, dotR, Paint()..color = color);
      return;
    }
    switch (mode) {
      case GlyphMode.idle:
        // A slow breath.
        final a = 0.35 + 0.55 * math.sin(math.pi * phase);
        canvas.drawCircle(c, dotR, Paint()..color = color.withValues(alpha: a));
      case GlyphMode.live:
        canvas.drawCircle(c, dotR, Paint()..color = color);
        final p = Curves.easeOut.transform(phase);
        canvas.drawCircle(
            c,
            dotR + 0.5 + 4.5 * p,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.4
              ..color = color.withValues(alpha: 0.5 * (1 - p)));
      case GlyphMode.busy:
        // The radar arc.
        canvas.drawCircle(c, dotR, Paint()..color = color);
        final rect = Rect.fromCircle(center: c, radius: size.width / 2 - 1.5);
        canvas.drawArc(
            rect,
            0,
            math.pi * 2,
            false,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.2
              ..color = color.withValues(alpha: 0.18));
        canvas.drawArc(
            rect,
            math.pi * 2 * phase,
            1.9,
            false,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.6
              ..strokeCap = StrokeCap.round
              ..color = color.withValues(alpha: 0.9));
      case GlyphMode.ask:
        // Two staggered knocks.
        canvas.drawCircle(c, dotR, Paint()..color = color);
        for (final k in const [0.0, 0.5]) {
          final p = Curves.easeOut.transform((phase + k) % 1.0);
          canvas.drawCircle(
              c,
              dotR + 0.5 + 4.5 * p,
              Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 1.4
                ..color = color.withValues(alpha: 0.55 * (1 - p)));
        }
    }
  }

  @override
  bool shouldRepaint(_GlyphPainter old) => old.phase != phase || old.mode != mode || old.color != color;
}

/// Claude is composing: three dots that ripple until the first words land.
class ThinkingDots extends StatefulWidget {
  const ThinkingDots({super.key, required this.color});
  final Color color;

  @override
  State<ThinkingDots> createState() => _ThinkingDotsState();
}

class _ThinkingDotsState extends State<ThinkingDots> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000));

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final still = _still(context);
    if (!still && !_c.isAnimating) _c.repeat();
    if (still) _c.stop();
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) => CustomPaint(size: const Size(30, 12), painter: _DotsPainter(widget.color, still ? -1 : _c.value)),
    );
  }
}

class _DotsPainter extends CustomPainter {
  _DotsPainter(this.color, this.phase);
  final Color color;
  final double phase;

  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < 3; i++) {
      final a = phase < 0 ? 0.6 : 0.22 + 0.7 * math.sin(math.pi * (((phase - i * 0.18) % 1.0 + 1.0) % 1.0));
      canvas.drawCircle(Offset(5 + i * 9.0, size.height / 2), 2.6, Paint()..color = color.withValues(alpha: a.clamp(0.15, 1.0)));
    }
  }

  @override
  bool shouldRepaint(_DotsPainter old) => old.phase != phase || old.color != color;
}

/// The thin light that sweeps along the bottom of the "now" strip while the
/// session is live.
class SweepLine extends StatefulWidget {
  const SweepLine({super.key, required this.color, this.live = true});
  final Color color;
  final bool live;

  @override
  State<SweepLine> createState() => _SweepLineState();
}

class _SweepLineState extends State<SweepLine> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(seconds: 3));

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final run = widget.live && !_still(context);
    if (run && !_c.isAnimating) _c.repeat();
    if (!run) _c.stop();
    if (!run) return const SizedBox(height: 1);
    return SizedBox(
      height: 1,
      child: LayoutBuilder(
        builder: (context, box) => AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final w = box.maxWidth * 0.2;
            return Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                Positioned(
                  left: (_c.value * 1.2 - 0.2) * box.maxWidth,
                  width: w,
                  top: 0,
                  bottom: 0,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [widget.color.withValues(alpha: 0), widget.color, widget.color.withValues(alpha: 0)]),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// The amber corner ticks on whatever asks for the person's hand.
class CornerTicks extends StatelessWidget {
  const CornerTicks({super.key, required this.color, required this.radius, this.length = 10, required this.child});
  final Color color;
  final double radius;
  final double length;
  final Widget child;

  @override
  Widget build(BuildContext context) => Stack(
        children: [
          child,
          Positioned.fill(child: IgnorePointer(child: CustomPaint(painter: _TicksPainter(color, radius, length)))),
        ],
      );
}

class _TicksPainter extends CustomPainter {
  _TicksPainter(this.color, this.radius, this.length);
  final Color color;
  final double radius;
  final double length;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = color;
    final rrect = RRect.fromRectAndRadius((Offset.zero & size).deflate(1), Radius.circular(radius));
    final cs = radius + length;
    final corners = [
      Rect.fromLTWH(0, 0, cs, cs),
      Rect.fromLTWH(size.width - cs, 0, cs, cs),
      Rect.fromLTWH(0, size.height - cs, cs, cs),
      Rect.fromLTWH(size.width - cs, size.height - cs, cs, cs),
    ];
    for (final c in corners) {
      canvas.save();
      canvas.clipRect(c);
      canvas.drawRRect(rrect, paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_TicksPainter old) => old.color != color || old.radius != radius || old.length != length;
}

/// A gate as a ring: full and green when passed, red with a cross when
/// failed, a faint circle while pending.
class GateRing extends StatelessWidget {
  const GateRing(this.status, {super.key, this.size = 28});
  final GateStatus status;
  final double size;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final color = switch (status) {
      GateStatus.passed => t.good,
      GateStatus.failed => t.critical,
      GateStatus.pending => t.muted,
    };
    return CustomPaint(size: Size.square(size), painter: _GatePainter(status, color));
  }
}

class _GatePainter extends CustomPainter {
  _GatePainter(this.status, this.color);
  final GateStatus status;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2 - 2;
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = status == GateStatus.pending ? color.withValues(alpha: 0.4) : color.withValues(alpha: 0.25);
    canvas.drawCircle(c, r, ring);
    if (status == GateStatus.pending) return;
    canvas.drawCircle(c, r, ring..color = color);
    final glyph = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = color;
    final w = size.width;
    if (status == GateStatus.passed) {
      final p = Path()
        ..moveTo(w * 0.32, w * 0.52)
        ..lineTo(w * 0.45, w * 0.65)
        ..lineTo(w * 0.70, w * 0.36);
      canvas.drawPath(p, glyph);
    } else {
      canvas.drawLine(Offset(w * 0.36, w * 0.36), Offset(w * 0.64, w * 0.64), glyph);
      canvas.drawLine(Offset(w * 0.64, w * 0.36), Offset(w * 0.36, w * 0.64), glyph);
    }
  }

  @override
  bool shouldRepaint(_GatePainter old) => old.status != status || old.color != color;
}

/// A gate ring with its name and record, as the canvas draws them on a step.
class GateCard extends StatelessWidget {
  const GateCard(this.gate, {super.key});
  final Gate gate;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final sub = gate.at ?? (gate.note == null ? gate.status.name : null);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), border: Border.all(color: t.line)),
      child: Row(
        children: [
          GateRing(gate.status),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(gate.name.toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis, style: t.readout(10)),
                if (sub != null) Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: t.ink2)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The "now" strip — what the session does this second, the active step's
/// gates, and the sweep along its foot while the session is live.
class NowStrip extends StatelessWidget {
  const NowStrip({super.key, required this.label, required this.text, this.ago, this.gates = const <Gate>[], this.live = false, this.needsYou = false});

  /// The mono headline: `NOW · INSTRUMENT-SKIN`.
  final String label;

  /// The latest event, word for word.
  final String text;
  final String? ago;
  final List<Gate> gates;
  final bool live;
  final bool needsYou;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      decoration: BoxDecoration(color: t.surface, borderRadius: BorderRadius.circular(10), border: Border.all(color: t.line)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 11),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(child: Text(label.toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis, style: t.readout(11, color: needsYou ? t.warn : t.muted))),
                  if (ago != null) Text(ago!, style: t.mono(11, color: t.muted)),
                ]),
                const SizedBox(height: 6),
                Text(text, maxLines: 2, overflow: TextOverflow.ellipsis, style: t.mono(13, color: t.ink)),
                if (gates.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(spacing: 6, runSpacing: 6, children: [for (final g in gates.take(4)) GateChip(g)]),
                ],
              ],
            ),
          ),
          SweepLine(color: t.accent, live: live),
        ],
      ),
    );
  }
}

/// One gate in the "now" strip: ✓ and green when passed, red when failed,
/// a dashed outline while it waits.
class GateChip extends StatelessWidget {
  const GateChip(this.gate, {super.key});
  final Gate gate;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final color = switch (gate.status) {
      GateStatus.passed => t.good,
      GateStatus.failed => t.critical,
      GateStatus.pending => t.muted,
    };
    final label = Text(gate.name.toUpperCase(), style: t.readout(11, color: color));
    final icon = switch (gate.status) {
      GateStatus.passed => Icon(Icons.check, size: 11, color: color),
      GateStatus.failed => Icon(Icons.close, size: 11, color: color),
      GateStatus.pending => null,
    };
    final child = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      child: Row(mainAxisSize: MainAxisSize.min, children: [if (icon != null) ...[icon, const SizedBox(width: 5)], label]),
    );
    if (gate.status == GateStatus.pending) {
      return CustomPaint(painter: DashedBorderPainter(color: color.withValues(alpha: 0.6), radius: 6), child: child);
    }
    return Container(
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(6), border: Border.all(color: color.withValues(alpha: 0.45))),
      child: child,
    );
  }
}

/// A 1px dashed rounded border — the "not yet" outline.
class DashedBorderPainter extends CustomPainter {
  DashedBorderPainter({required this.color, required this.radius, this.dash = 3, this.gap = 4});
  final Color color;
  final double radius;
  final double dash;
  final double gap;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = color;
    final path = Path()..addRRect(RRect.fromRectAndRadius((Offset.zero & size).deflate(0.5), Radius.circular(radius)));
    for (final metric in path.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        canvas.drawPath(metric.extractPath(d, (d + dash).clamp(0, metric.length)), paint);
        d += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(DashedBorderPainter old) => old.color != color || old.radius != radius;
}
