import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart' show GestureBinding, PointerDeviceKind, PointerScrollEvent, PointerSignalEvent;
import 'package:flutter/material.dart' hide Step, StepState;
import 'package:flutter/scheduler.dart' show Ticker;
import 'package:flutter/services.dart' show HardwareKeyboard;

import '../theme.dart';
import '../widgets/common.dart';
import 'studio_data.dart';
import 'studio_desk.dart';
import 'studio_draft.dart';
import 'studio_graph.dart';
import 'studio_plans.dart';
import 'studio_resources.dart';
import 'studio_source.dart';
import 'studio_visuals.dart';

// The constellations: the lanes as a dependency graph around one NOW line,
// and the roadmap as milestone stars with their items in orbit. Both are
// drawn on the Instrument night sky whatever the app's skin, in two layers:
// a still one (rings, lines, labels — repainted when the picture changes)
// and a light animated one (halos, pulses, energy along the links).

const _sky = KitTokens.dark;

/// The zoom of a pan/zoom matrix: its x scale. (getMaxScaleOnAxis also
/// counts z, which our matrices never scale — it read 1 at any zoom below it.)
double _scaleOf(Matrix4 m) => m.storage[0];

/// The colour of the person's own pending changes on a graph.
const kDraftColor = Color(0xFFC79BFF);

final _noDraft = ChangeNotifier();

bool _still(BuildContext context) => MediaQuery.maybeDisableAnimationsOf(context) ?? false;

TextPainter _label(String text, double size, Color color, {FontWeight weight = FontWeight.w400, String family = kMonoFont, double? maxWidth}) {
  final tp = TextPainter(
    text: TextSpan(text: text, style: TextStyle(fontFamily: family, fontSize: size, color: color, fontWeight: weight, letterSpacing: 0.3)),
    textDirection: TextDirection.ltr,
    maxLines: 1,
    ellipsis: '…',
  )..layout(maxWidth: maxWidth ?? double.infinity);
  return tp;
}

void _glow(Canvas canvas, Offset o, double r, Color c, {double blur = 10, double alpha = 0.55}) {
  canvas.drawCircle(o, r, Paint()
    ..color = c.withValues(alpha: alpha)
    ..maskFilter = MaskFilter.blur(BlurStyle.normal, blur));
}

void _dashedCircle(Canvas canvas, Offset o, double r, Paint paint, {int n = 14}) {
  for (var i = 0; i < n; i++) {
    final a = 2 * math.pi * i / n;
    canvas.drawArc(Rect.fromCircle(center: o, radius: r), a, math.pi / n, false, paint);
  }
}

void _dashedPath(Canvas canvas, Path path, Paint paint, {double dash = 5, double gap = 4}) {
  for (final m in path.computeMetrics()) {
    var d = 0.0;
    while (d < m.length) {
      canvas.drawPath(m.extractPath(d, math.min(d + dash, m.length)), paint);
      d += dash + gap;
    }
  }
}

/// The night sky, filling the whole window behind the canvas whatever the
/// zoom: a deep gradient, two slow nebulae, the grid (fixed to the canvas,
/// so it pans and zooms with it), and two layers of stars that drift at a
/// fraction of the pan — the far ones slower — some of them twinkling.
/// Cheap: no blur, a few hundred dots, repainted by a slow clock.
class _SkyPainter extends CustomPainter {
  _SkyPainter({required this.view, required this.drift}) : super(repaint: Listenable.merge([view, drift]));
  final TransformationController view;
  final ValueNotifier<double> drift;

  static final _stars = () {
    final rnd = math.Random(7);
    return [for (var i = 0; i < 420; i++) (x: rnd.nextDouble(), y: rnd.nextDouble(), r: rnd.nextDouble() < 0.1 ? 1.4 : 0.7, a: 0.12 + rnd.nextDouble() * 0.35, far: i.isEven, tw: rnd.nextDouble() < 0.18, seed: rnd.nextDouble())];
  }();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final m = view.value;
    final scale = _scaleOf(m);
    final tx = m.storage[12], ty = m.storage[13];
    final t = drift.value;
    canvas.drawRect(rect, Paint()..shader = const RadialGradient(center: Alignment(-0.2, -0.5), radius: 1.4, colors: [Color(0xFF0F1C30), Color(0xFF070B12)]).createShader(rect));
    // Two nebulae, wandering a little, a hint of colour each.
    for (final (i, c) in [const Color(0xFF1B6FA8), const Color(0xFF5B3FA0)].indexed) {
      final a = 2 * math.pi * (t + i * 0.37);
      final center = Offset(size.width * (0.3 + 0.4 * i) + math.cos(a) * 60 + tx * 0.05, size.height * (0.35 + 0.3 * i) + math.sin(a) * 40 + ty * 0.05);
      final r = math.max(size.width, size.height) * 0.45;
      canvas.drawCircle(center, r, Paint()..shader = RadialGradient(colors: [c.withValues(alpha: 0.10), c.withValues(alpha: 0)]).createShader(Rect.fromCircle(center: center, radius: r)));
    }
    // The grid, on the canvas's own coordinates.
    final step = 48 * scale;
    if (step > 10) {
      final grid = Paint()..color = _sky.line.withValues(alpha: 0.06);
      for (var x = tx % step; x < size.width; x += step) {
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
      }
      for (var y = ty % step; y < size.height; y += step) {
        canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
      }
    }
    // Stars, wrapped around the window, drifting with the pan.
    final w = size.width + 40, h = size.height + 40;
    for (final st in _stars) {
      final f = st.far ? 0.12 : 0.3;
      final x = ((st.x * w + tx * f) % w + w) % w - 20;
      final y = ((st.y * h + ty * f) % h + h) % h - 20;
      var alpha = st.a;
      if (st.tw) alpha *= 0.45 + 0.55 * (0.5 + 0.5 * math.sin(2 * math.pi * (t * 6 + st.seed)));
      canvas.drawCircle(Offset(x, y), st.r, Paint()..color = Colors.white.withValues(alpha: alpha));
    }
  }

  @override
  bool shouldRepaint(_SkyPainter old) => false;
}

/// Two slow clocks for the effects, instead of a frame-rate animation:
/// [pulse] at about 30 a second for halos and energy, [drift] at about 12
/// for the sky. Both stop when the app is not the active window, when the
/// person asks for reduced motion, and when the view goes away — the Mac is
/// a game-development machine and the Studio must cost next to nothing.
mixin _FxClock<T extends StatefulWidget> on State<T> implements WidgetsBindingObserver {
  final pulse = ValueNotifier<double>(0);
  final drift = ValueNotifier<double>(0);
  final _watch = Stopwatch();
  Timer? _fast, _slow;
  bool _active = true;
  bool _motion = true;

  /// Seconds for one pulse.
  double get pulsePeriod => 2.6;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _active = WidgetsBinding.instance.lifecycleState == null || WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _motion = !_still(context);
    _sync();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _active = state == AppLifecycleState.resumed;
    _sync();
  }

  bool get moving => _active && _motion;

  void _sync() {
    if (moving && _fast == null) {
      _watch.start();
      _fast = Timer.periodic(const Duration(milliseconds: 33), (_) => pulse.value = (_watch.elapsedMilliseconds / 1000 / pulsePeriod) % 1.0);
      _slow = Timer.periodic(const Duration(milliseconds: 83), (_) => drift.value = (_watch.elapsedMilliseconds / 1000 / 240) % 1.0);
    } else if (!moving && _fast != null) {
      _fast?.cancel();
      _slow?.cancel();
      _fast = _slow = null;
      _watch.stop();
      pulse.value = 0;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _fast?.cancel();
    _slow?.cancel();
    pulse.dispose();
    drift.dispose();
    super.dispose();
  }
}

/// Zoom, fit and the extra switches, floating over a sky.
class _SkyControls extends StatelessWidget {
  const _SkyControls({required this.onZoom, required this.onFit, this.extra = const []});
  final void Function(double factor) onZoom;
  final VoidCallback onFit;
  final List<Widget> extra;
  @override
  Widget build(BuildContext context) {
    Widget b(IconData i, String tip, VoidCallback f) => IconButton(tooltip: tip, onPressed: f, icon: Icon(i, size: 18, color: _sky.ink2), visualDensity: VisualDensity.compact);
    return Container(
      decoration: BoxDecoration(color: _sky.surface.withValues(alpha: 0.82), borderRadius: BorderRadius.circular(10), border: Border.all(color: _sky.line)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        ...extra,
        b(Icons.remove, 'Zoom out', () => onZoom(1 / 1.25)),
        b(Icons.add, 'Zoom in', () => onZoom(1.25)),
        b(Icons.fit_screen, 'Fit', onFit),
      ]),
    );
  }
}

/// Pan and zoom over a canvas, smooth with a mouse: the wheel zooms around
/// the pointer, Shift + wheel pans sideways, a drag pans — every move eases
/// to its target instead of jumping, and so do the zoom and fit buttons. A trackpad's pinch and swipe stay
/// InteractiveViewer's; a grab cancels any glide in flight.
mixin _Sky<T extends StatefulWidget> on State<T> {
  final view = TransformationController();
  Size? _viewport;
  bool _placed = false;
  Matrix4? _target;
  Ticker? _glide;

  /// The canvas's size before zoom — the subclass says.
  Size get skyCanvas;

  static const _minScale = 0.3, _maxScale = 3.0;

  void zoom(double f) {
    final vp = _viewport;
    if (vp == null) return;
    _animateTo(_zoomed(_target ?? view.value, f, Offset(vp.width / 2, vp.height / 2)));
  }

  void fit(Size canvas, {bool animate = true}) {
    final vp = _viewport;
    if (vp == null) return;
    final s = math.min(vp.width / canvas.width, vp.height / canvas.height).clamp(_minScale, 1.0);
    final m = Matrix4.identity()
      ..translateByDouble((vp.width - canvas.width * s) / 2, (vp.height - canvas.height * s) / 2, 0, 1)
      ..scaleByDouble(s, s, 1, 1);
    animate ? _animateTo(m) : _jump(m);
  }

  void focusOn(Offset point, {double scale = 1.0, bool animate = true}) {
    final vp = _viewport;
    if (vp == null) return;
    final m = Matrix4.identity()
      ..translateByDouble(vp.width / 2 - point.dx * scale, vp.height / 2 - point.dy * scale, 0, 1)
      ..scaleByDouble(scale, scale, 1, 1);
    animate ? _animateTo(m) : _jump(m);
  }

  /// Called with the viewport on every layout; [place] runs once.
  void viewportIs(Size vp, VoidCallback place) {
    _viewport = vp;
    if (_placed) return;
    _placed = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) place();
    });
  }

  /// Set while a wheel event is being dispatched: InteractiveViewer calls
  /// onInteractionStart for it too, and that must not cancel the glide.
  bool _wheeling = false;

  /// For InteractiveViewer's onInteractionStart: a grab wins over a glide.
  void onGrab() {
    if (_wheeling) return;
    stopGlide();
  }

  void stopGlide() {
    _target = null;
    _glide?.stop();
  }

  /// For a Listener inside the canvas: claims the wheel before
  /// InteractiveViewer would turn it into a zoom.
  void onWheelSignal(PointerSignalEvent e) {
    if (e is! PointerScrollEvent || e.kind == PointerDeviceKind.trackpad) return;
    _wheeling = true;
    GestureBinding.instance.pointerSignalResolver.register(e, (ev) {
      _wheeling = false;
      _wheel(ev as PointerScrollEvent);
    });
  }

  /// The wheel zooms around the pointer, as InteractiveViewer's did, but
  /// eased: each notch moves the target and the view glides to it. Steps
  /// that come fast stack on the target, so a long spin is one smooth zoom.
  /// Shift + wheel pans sideways.
  void _wheel(PointerScrollEvent e) {
    final vp = _viewport;
    if (vp == null) return;
    final base = _target ?? view.value;
    if (HardwareKeyboard.instance.isShiftPressed) {
      final d = e.scrollDelta.dx != 0 ? e.scrollDelta.dx : e.scrollDelta.dy;
      final m = base.clone();
      m.storage[12] -= d;
      _animateTo(m);
      return;
    }
    if (e.scrollDelta.dy == 0) return;
    final at = MatrixUtils.transformPoint(view.value, e.localPosition);
    _animateTo(_zoomed(base, math.exp(-e.scrollDelta.dy / 240), at));
  }

  Matrix4 _zoomed(Matrix4 m, double f, Offset around) {
    final s = _scaleOf(m);
    final g = (s * f).clamp(_minScale, _maxScale) / s;
    final out = m.clone();
    out.storage[0] *= g;
    out.storage[5] *= g;
    out.storage[12] = around.dx + (m.storage[12] - around.dx) * g;
    out.storage[13] = around.dy + (m.storage[13] - around.dy) * g;
    return out;
  }

  /// Keeps at least a strip of the canvas in the window.
  Matrix4 _clamped(Matrix4 m) {
    final vp = _viewport;
    if (vp == null) return m;
    final s = _scaleOf(m);
    final w = skyCanvas.width * s, h = skyCanvas.height * s;
    const keep = 120.0;
    final out = m.clone();
    out.storage[12] = out.storage[12].clamp(math.min(keep - w, vp.width - keep), math.max(keep - w, vp.width - keep));
    out.storage[13] = out.storage[13].clamp(math.min(keep - h, vp.height - keep), math.max(keep - h, vp.height - keep));
    return out;
  }

  void _jump(Matrix4 m) {
    stopGlide();
    view.value = _clamped(m);
  }

  void _animateTo(Matrix4 m) {
    _target = _clamped(m);
    _glide ??= Ticker(_step);
    if (!_glide!.isActive) _glide!.start();
  }

  /// One frame of the glide: a fifth of the way there, until it is there.
  void _step(Duration _) {
    final t = _target;
    if (t == null) {
      _glide?.stop();
      return;
    }
    final cur = view.value;
    var far = 0.0;
    final next = Matrix4.zero();
    for (var i = 0; i < 16; i++) {
      final d = t.storage[i] - cur.storage[i];
      far = math.max(far, (i == 12 || i == 13) ? d.abs() : d.abs() * 400);
      next.storage[i] = cur.storage[i] + d * 0.2;
    }
    if (far < 0.4) {
      view.value = t;
      stopGlide();
    } else {
      view.value = next;
    }
  }

  @override
  void dispose() {
    _glide?.dispose();
    view.dispose();
    super.dispose();
  }
}

// --- the lanes ---------------------------------------------------------------------

const double _colW = 76;
const double _rowH = 118;
const double _left = 104;
const double _top = 46;

/// The lanes as one dependency graph: a row per lane, every lane's NOW in one
/// glowing column, real links (`after:`) as bright curves with energy flowing
/// into the steps that wait on them, suggested links dashed amber.
class LaneConstellation extends StatefulWidget {
  const LaneConstellation({super.key, required this.graph, required this.lanes, this.onAsk, this.onExplain, this.draft, this.threads, this.extraControls = const []});

  /// EXPLAIN: has the step desk write what the step is for.
  final void Function(String lane, StepItem item)? onExplain;

  /// The step desk's threads — the panel shows how many questions a step has.
  final StudioThreads? threads;

  /// Where [n]'s ring sits on the canvas (before pan and zoom).
  static Offset positionOf(LaneGraph g, LaneNode n) => Offset(_left + (n.col - g.minCol) * _colW + _colW / 2, _top + n.row * _rowH + _rowH / 2);

  final LaneGraph graph;
  final List<Lane> lanes;

  /// ASK A QUESTION on a selected step — opens its thread with the step desk.
  final void Function(String lane, StepItem item)? onAsk;

  /// Where link, add, edit and remove go; without it the panel only asks.
  final StudioDraft? draft;
  final List<Widget> extraControls;

  @override
  State<LaneConstellation> createState() => _LaneConstellationState();
}

class _LaneConstellationState extends State<LaneConstellation> with WidgetsBindingObserver, _Sky, _FxClock {
  String? _selected;

  /// LINK: the step that will wait — the next tap picks what it waits on.
  String? _linkFor;

  /// A hold-and-drag in flight: the step lifted and where the pointer is.
  String? _dragKey;
  Offset? _dragAt;

  LaneNode? _nodeAt(Offset p, {double within = 26}) {
    LaneNode? best;
    var bd = within;
    for (final n in g.nodes) {
      final d = (at(n) - p).distance;
      if (d < bd) {
        bd = d;
        best = n;
      }
    }
    return best;
  }

  /// Where a lifted step would land: the open step of its lane it goes right
  /// after (null: the front of the open steps), from the pointer's x.
  (String? after, double x)? _landing(LaneNode lifted, Offset p) {
    final row = g.nodes.where((n) => n.lane == lifted.lane && n.key != lifted.key && n.kind != NodeKind.done).toList()..sort((a, b) => a.col.compareTo(b.col));
    if (row.isEmpty) return null;
    LaneNode? after;
    for (final n in row) {
      if (at(n).dx < p.dx) after = n;
    }
    final x = after == null ? at(row.first).dx - _colW / 2 : at(after).dx + _colW / 2;
    return (after?.item.id, x);
  }

  void _liftStart(Offset p) {
    final n = _nodeAt(p);
    if (n == null || widget.draft == null || n.kind == NodeKind.done) return;
    setState(() {
      _dragKey = n.key;
      _dragAt = p;
      _selected = null;
    });
  }

  void _liftMove(Offset p) {
    if (_dragKey == null) return;
    setState(() => _dragAt = p);
  }

  void _liftEnd() {
    final key = _dragKey, p = _dragAt;
    setState(() {
      _dragKey = null;
      _dragAt = null;
    });
    if (key == null || p == null) return;
    final n = g.node(key)!;
    final land = _landing(n, p);
    if (land == null) return;
    // Dropped where it already is: nothing to do.
    final open = g.nodes.where((x) => x.lane == n.lane && x.kind != NodeKind.done).toList()..sort((a, b) => a.col.compareTo(b.col));
    final i = open.indexWhere((x) => x.key == key);
    final before = i > 0 ? open[i - 1].item.id : null;
    if (land.$1 == before) return;
    widget.draft!.add(DraftOrder(kind: DraftKind.move, lane: n.lane, target: n.item.id, other: land.$1 ?? '^'));
    setState(() => _selected = key);
  }

  LaneGraph get g => widget.graph;
  @override
  Size get skyCanvas => canvas;
  Size get canvas => Size(_left + (g.maxCol - g.minCol + 1) * _colW + 60, _top + math.max(1, g.lanes.length) * _rowH + 24);
  Offset at(LaneNode n) => LaneConstellation.positionOf(g, n);
  double get nowX => _left + (0 - g.minCol) * _colW + _colW / 2;

  void _tap(Offset p) {
    LaneNode? best;
    var bd = 26.0;
    for (final n in g.nodes) {
      final d = (at(n) - p).distance;
      if (d < bd) {
        bd = d;
        best = n;
      }
    }
    final pickFor = _linkFor;
    if (pickFor != null) {
      if (best != null && best.key != pickFor) {
        final w = g.node(pickFor)!;
        widget.draft?.add(DraftOrder(kind: DraftKind.link, lane: w.lane, target: w.item.id, other: best.lane == w.lane ? best.item.id : refOf(best.key)));
      }
      setState(() {
        _linkFor = null;
        _selected = pickFor;
      });
      return;
    }
    setState(() => _selected = best?.key);
  }

  @override
  Widget build(BuildContext context) {
    final sel = _selected == null ? null : g.node(_selected!);
    final lanesById = {for (final l in widget.lanes) l.id: l};
    return LayoutBuilder(builder: (context, c) {
      viewportIs(c.biggest, () => focusOn(Offset(nowX, canvas.height / 2), scale: c.biggest.width < 600 ? 0.8 : 1.0, animate: false));
      return Stack(children: [
        Positioned.fill(child: RepaintBoundary(child: CustomPaint(painter: _SkyPainter(view: view, drift: drift)))),
        Positioned.fill(
          child: InteractiveViewer(
            transformationController: view,
            constrained: false,
            minScale: 0.3,
            maxScale: 3,
            boundaryMargin: const EdgeInsets.all(400),
            onInteractionStart: (_) => onGrab(),
            // Its own wheel zoom off (an infinite factor makes every wheel
            // step a scale of 1): the wheel is ours, smooth; a pinch stays its.
            scaleFactor: double.infinity,
            child: Listener(
              onPointerSignal: onWheelSignal,
              child: GestureDetector(
              onTapUp: (d) => _tap(d.localPosition),
              // Hold a step and drag it along its lane to move it.
              onLongPressStart: (d) => _liftStart(d.localPosition),
              onLongPressMoveUpdate: (d) => _liftMove(d.localPosition),
              onLongPressEnd: (_) => _liftEnd(),
              child: SizedBox.fromSize(
                key: const Key('lane-sky'),
                size: canvas,
                child: Stack(children: [
                  Positioned.fill(child: RepaintBoundary(child: ListenableBuilder(listenable: widget.draft ?? _noDraft, builder: (context, _) => CustomPaint(painter: _LanesStill(graph: g, selected: _selected, at: at, nowX: nowX, lanes: lanesById, draft: widget.draft, version: widget.draft?.length ?? 0, linkFor: _linkFor))))),
                  Positioned.fill(child: RepaintBoundary(child: ValueListenableBuilder<double>(valueListenable: pulse, builder: (context, phase, _) => CustomPaint(painter: _LanesMoving(graph: g, phase: phase, at: at, nowX: nowX, selected: _selected, working: {for (final l in widget.lanes) if (laneWorking(l)) l.id}))))),
                  if (_dragKey != null && _dragAt != null) Positioned.fill(child: CustomPaint(painter: _LiftPainter(node: g.node(_dragKey!)!, at: _dragAt!, landingX: _landing(g.node(_dragKey!)!, _dragAt!)?.$2, rowY: LaneConstellation.positionOf(g, g.node(_dragKey!)!).dy))),
                ]),
              ),
            ),
            ),
          ),
        ),
        // The legend wraps in the room the controls leave on the right.
        Positioned(left: 10, top: 10, right: 250, child: Align(alignment: Alignment.topLeft, child: _Legend(items: [('DEPENDS ON', _sky.accent, false), ('SUGGESTED', _sky.warn, true), ('LANE ORDER', _sky.lineStrong, false), if (widget.draft != null && !widget.draft!.isEmpty) ('YOUR CHANGES', kDraftColor, true)]))),
        // When the canvas's own lane names scroll out of sight, badges pinned
        // to the left edge keep each row named.
        Positioned(left: 0, top: 0, bottom: 0, width: 60, child: IgnorePointer(child: CustomPaint(painter: _LaneBadges(view: view, lanes: g.lanes)))),
        if (_linkFor != null)
          Positioned(
            top: 56,
            left: 0,
            right: 0,
            child: Center(
              child: Material(
                color: kDraftColor.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 4, 4, 4),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Flexible(child: Text('Tap the step ${laneLabel(g.node(_linkFor!)!.lane)} · ${g.node(_linkFor!)!.item.id} waits on', style: const TextStyle(color: Color(0xFF1A0F2E), fontWeight: FontWeight.w600))),
                    TextButton(onPressed: () => setState(() => _linkFor = null), child: const Text('CANCEL', style: TextStyle(color: Color(0xFF1A0F2E)))),
                  ]),
                ),
              ),
            ),
          ),
        Positioned(right: 10, top: 10, child: _SkyControls(onZoom: zoom, onFit: () => fit(canvas), extra: widget.extraControls)),
        if (sel != null && _linkFor == null)
          Positioned(
            left: 10,
            right: 10,
            bottom: 10,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: _StepPanel(
                  node: sel,
                  graph: g,
                  draft: widget.draft,
                  threads: widget.threads,
                  onExplain: widget.onExplain == null ? null : () => widget.onExplain!(sel.lane, sel.item),
                  laneName: laneLabel(sel.lane),
                  onLink: widget.draft == null ? null : () => setState(() => _linkFor = sel.key),
                  onClose: () => setState(() => _selected = null),
                  onAsk: widget.onAsk == null ? null : () => widget.onAsk!(sel.lane, sel.item),
                  onJump: (key) {
                    final n = g.node(key);
                    if (n == null) return;
                    setState(() => _selected = key);
                    focusOn(at(n), scale: _scaleOf(view.value));
                  },
                ),
              ),
            ),
          ),
      ]);
    });
  }
}

class _LanesStill extends CustomPainter {
  _LanesStill({required this.graph, required this.selected, required this.at, required this.nowX, required this.lanes, this.draft, this.version = 0, this.linkFor});
  final LaneGraph graph;
  final StudioDraft? draft;

  /// The draft's size when painted — a change repaints.
  final int version;
  final String? linkFor;
  final String? selected;
  final Offset Function(LaneNode) at;
  final double nowX;
  final Map<String, Lane> lanes;

  @override
  void paint(Canvas canvas, Size size) {
    final t = _sky;
    // Lane bands and their names.
    for (final (row, id) in graph.lanes.indexed) {
      final y = _top + row * _rowH;
      if (row.isOdd) canvas.drawRect(Rect.fromLTWH(0, y, size.width, _rowH), Paint()..color = Colors.white.withValues(alpha: 0.018));
      canvas.drawLine(Offset(0, y + _rowH), Offset(size.width, y + _rowH), Paint()..color = t.line.withValues(alpha: 0.5));
      _label(laneLabel(id), 15, t.ink, weight: FontWeight.w700, family: kDisplayFont).paint(canvas, Offset(14, y + _rowH / 2 - 20));
      final l = lanes[id];
      if (l != null) _label(l.machine.toUpperCase(), 9, t.muted).paint(canvas, Offset(14, y + _rowH / 2 + 2));
      if (!graph.nodes.any((n) => n.lane == id)) {
        final why = l == null ? 'NO STEP LIST FOUND' : (l.status.state == LaneState.notStarted ? 'NOT STARTED · NO STEPS YET' : 'NO STEP LIST FOUND');
        final lp = _label(why, 10, t.muted);
        lp.paint(canvas, Offset(nowX - lp.width / 2, y + _rowH / 2 - lp.height / 2));
      }
    }
    // NOW: a soft column of light.
    final nowRect = Rect.fromLTWH(nowX - 30, _top - 18, 60, size.height - _top);
    canvas.drawRect(nowRect, Paint()..shader = LinearGradient(colors: [t.accent.withValues(alpha: 0), t.accent.withValues(alpha: 0.07), t.accent.withValues(alpha: 0)]).createShader(nowRect));
    canvas.drawLine(Offset(nowX, _top - 12), Offset(nowX, size.height - 8), Paint()
      ..color = t.accent.withValues(alpha: 0.35)
      ..strokeWidth = 1);
    final nowL = _label('NOW', 11, t.accent, weight: FontWeight.w700);
    nowL.paint(canvas, Offset(nowX - nowL.width / 2, _top - 34));

    final hot = selected == null ? const <String>{} : {selected!, for (final e in graph.edgesOf(selected!)) ...[e.from, e.to]};
    // Lines: the lanes' order first, faint; then suggestions; then real links on top.
    for (final kind in [EdgeKind.rail, EdgeKind.suggested, EdgeKind.after]) {
      for (final e in graph.edges.where((e) => e.kind == kind)) {
        final a = graph.node(e.from), b = graph.node(e.to);
        if (a == null || b == null) continue;
        final pa = at(a), pb = at(b);
        final isHot = selected != null && (e.from == selected || e.to == selected);
        final dim = selected != null && !isHot;
        switch (kind) {
          case EdgeKind.rail:
            final future = b.kind != NodeKind.done && b.kind != NodeKind.current;
            final paint = Paint()
              ..strokeWidth = 1.2
              ..color = (future ? t.accent.withValues(alpha: 0.22) : t.lineStrong).withValues(alpha: dim ? 0.12 : (future ? 0.22 : 0.6));
            final path = Path()
              ..moveTo(pa.dx + 13, pa.dy)
              ..lineTo(pb.dx - 13, pb.dy);
            future ? _dashedPath(canvas, path, paint) : canvas.drawPath(path, paint);
          case EdgeKind.suggested:
          case EdgeKind.after:
            final path = _curve(pa, pb);
            final color = kind == EdgeKind.after ? t.accent : t.warn;
            final alpha = dim ? 0.12 : (isHot ? 1.0 : (kind == EdgeKind.after ? 0.75 : 0.5));
            if (kind == EdgeKind.after && !dim) {
              canvas.drawPath(path, Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = isHot ? 7 : 5
                ..color = color.withValues(alpha: 0.16)
                ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
            }
            final paint = Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = isHot ? 2.4 : (kind == EdgeKind.after ? 1.8 : 1.2)
              ..color = color.withValues(alpha: alpha);
            kind == EdgeKind.after ? canvas.drawPath(path, paint) : _dashedPath(canvas, path, paint, dash: 4, gap: 4);
            if (kind == EdgeKind.after) _arrow(canvas, path, paint.color);
        }
      }
    }
    // The person's pending changes, in violet: new links dashed, unlinks
    // crossed out.
    final d = draft;
    if (d != null) {
      for (final (from, to) in d.laneLinks) {
        final a = graph.node(from), b = graph.node(to);
        if (a == null || b == null) continue;
        final path = _curve(at(a), at(b));
        final paint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = kDraftColor;
        _dashedPath(canvas, path, paint, dash: 6, gap: 4);
        _arrow(canvas, path, kDraftColor);
      }
      final cut = d.laneUnlinks;
      for (final e in graph.edges.where((e) => e.kind == EdgeKind.after && cut.contains('${e.from}>${e.to}'))) {
        final a = graph.node(e.from), b = graph.node(e.to);
        if (a == null || b == null) continue;
        final m = _curve(at(a), at(b)).computeMetrics().firstOrNull;
        final mid = m?.getTangentForOffset(m.length / 2)?.position;
        if (mid == null) continue;
        final p = Paint()
          ..strokeWidth = 2.4
          ..color = _sky.critical;
        canvas.drawLine(mid + const Offset(-6, -6), mid + const Offset(6, 6), p);
        canvas.drawLine(mid + const Offset(-6, 6), mid + const Offset(6, -6), p);
      }
    }
    // The rings.
    for (final n in graph.nodes) {
      final o = at(n);
      final dim = selected != null && !hot.contains(n.key);
      final isSel = n.key == selected;
      _ring(canvas, o, n, dim: dim, selected: isSel);
      final cap = n.item.id.length > 12 ? '${n.item.id.substring(0, 11)}…' : n.item.id;
      final lp = _label(cap, 9.5, n.kind == NodeKind.current ? t.accent : (dim ? t.muted.withValues(alpha: 0.5) : t.ink2), weight: n.kind == NodeKind.current ? FontWeight.w700 : FontWeight.w400);
      lp.paint(canvas, Offset(o.dx - lp.width / 2, o.dy + 20));
      if (d != null) {
        if (d.removed.contains(n.key)) {
          final p = Paint()
            ..strokeWidth = 2.2
            ..color = _sky.critical;
          canvas.drawLine(o + const Offset(-13, -13), o + const Offset(13, 13), p);
          canvas.drawLine(o + const Offset(-13, 13), o + const Offset(13, -13), p);
        }
        final mv = d.moved[n.key];
        if (mv != null) {
          _dashedCircle(canvas, o, 17, Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.6
            ..color = kDraftColor);
          final dest = mv.endsWith('/^') ? 'FRONT' : mv.split('/').last;
          final tag = _label('→ ${dest.length > 10 ? '${dest.substring(0, 9)}…' : dest}', 8.5, kDraftColor, weight: FontWeight.w700);
          tag.paint(canvas, Offset(o.dx - tag.width / 2, o.dy - 32));
        }
        if (d.edited.contains(n.key)) {
          canvas.drawCircle(o + const Offset(12, -12), 6, Paint()..color = kDraftColor);
          final pen = _label('✎', 8, const Color(0xFF1A0F2E), family: kBodyFont);
          pen.paint(canvas, o + Offset(12 - pen.width / 2, -12 - pen.height / 2));
        }
      }
      if (n.key == linkFor) {
        _dashedCircle(canvas, o, 22, Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..color = kDraftColor);
      }
      final off = graph.offscreen[n.key];
      if (off != null && off.isNotEmpty) {
        final tag = _label('↗${off.length}', 9, t.accent);
        tag.paint(canvas, Offset(o.dx + 12, o.dy - 24));
      }
    }
    _ghosts(canvas);
  }

  void _ghosts(Canvas canvas) {
    final d = draft;
    if (d == null) return;
    // New steps: a ghost ring just past the step they follow, a little above.
    final count = <String, int>{};
    for (final (after, id) in d.added) {
      final a = graph.node(after);
      if (a == null) continue;
      final k = count[after] = (count[after] ?? 0) + 1;
      final o = at(a) + Offset(_colW / 2, -34.0 * k);
      canvas.drawLine(at(a) + const Offset(10, -8), o, Paint()
        ..strokeWidth = 1
        ..color = kDraftColor.withValues(alpha: 0.6));
      canvas.drawCircle(o, 10, Paint()..color = _sky.bg);
      _dashedCircle(canvas, o, 10, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = kDraftColor);
      final plus = _label('+', 12, kDraftColor, weight: FontWeight.w700);
      plus.paint(canvas, o - Offset(plus.width / 2, plus.height / 2));
      final lp = _label(id.length > 12 ? '${id.substring(0, 11)}…' : id, 9, kDraftColor);
      lp.paint(canvas, Offset(o.dx + 14, o.dy - lp.height / 2));
    }
  }

  static Path _curve(Offset a, Offset b) {
    // Same row: an arch above; different rows: an S between them.
    if ((a.dy - b.dy).abs() < 1) {
      final mid = Offset((a.dx + b.dx) / 2, a.dy - 26 - (b.dx - a.dx).abs() * 0.12);
      return Path()
        ..moveTo(a.dx, a.dy - 13)
        ..quadraticBezierTo(mid.dx, mid.dy, b.dx, b.dy - 13);
    }
    final down = b.dy > a.dy;
    final pa = Offset(a.dx, a.dy + (down ? 13 : -13));
    final pb = Offset(b.dx, b.dy + (down ? -13 : 13));
    final dy = (pb.dy - pa.dy) * 0.55;
    return Path()
      ..moveTo(pa.dx, pa.dy)
      ..cubicTo(pa.dx, pa.dy + dy, pb.dx, pb.dy - dy, pb.dx, pb.dy);
  }

  static void _arrow(Canvas canvas, Path path, Color c) {
    final m = path.computeMetrics().firstOrNull;
    if (m == null || m.length < 10) return;
    final tan = m.getTangentForOffset(m.length - 1);
    if (tan == null) return;
    final dir = tan.vector / tan.vector.distance;
    final p = tan.position;
    final left = Offset(-dir.dy, dir.dx);
    final head = Path()
      ..moveTo(p.dx, p.dy)
      ..lineTo(p.dx - dir.dx * 7 + left.dx * 3.5, p.dy - dir.dy * 7 + left.dy * 3.5)
      ..lineTo(p.dx - dir.dx * 7 - left.dx * 3.5, p.dy - dir.dy * 7 - left.dy * 3.5)
      ..close();
    canvas.drawPath(head, Paint()..color = c);
  }

  void _ring(Canvas canvas, Offset o, LaneNode n, {required bool dim, required bool selected}) {
    final t = _sky;
    final a = dim ? 0.3 : 1.0;
    switch (n.kind) {
      case NodeKind.done:
        final recent = n.col > -3;
        if (recent && !dim) _glow(canvas, o, 12, t.good, alpha: 0.25);
        canvas.drawCircle(o, 11, Paint()..color = t.good.withValues(alpha: 0.18 * a));
        canvas.drawCircle(o, 11, Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = t.good.withValues(alpha: a));
        final check = Path()
          ..moveTo(o.dx - 4.5, o.dy)
          ..lineTo(o.dx - 1.2, o.dy + 3.2)
          ..lineTo(o.dx + 5, o.dy - 3.6);
        canvas.drawPath(check, Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.7
          ..strokeCap = StrokeCap.round
          ..color = t.good.withValues(alpha: a));
      case NodeKind.current:
        _glow(canvas, o, 18, t.accent, blur: 14, alpha: dim ? 0.15 : 0.5);
        canvas.drawCircle(o, 14, Paint()..color = t.accent.withValues(alpha: 0.2 * a));
        canvas.drawCircle(o, 14, Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.6
          ..color = t.accent.withValues(alpha: a));
        canvas.drawCircle(o, 4.5, Paint()..color = t.accent.withValues(alpha: a));
      case NodeKind.next:
      case NodeKind.held:
        final c = n.kind == NodeKind.held ? t.warn : t.ink2;
        canvas.drawCircle(o, 11, Paint()..color = t.bg.withValues(alpha: 0.9));
        _dashedCircle(canvas, o, 11, Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..color = c.withValues(alpha: 0.75 * a));
        if (n.kind == NodeKind.held) {
          final p = Paint()
            ..strokeWidth = 1.8
            ..color = c.withValues(alpha: a);
          canvas.drawLine(o + const Offset(-2.5, -4), o + const Offset(-2.5, 4), p);
          canvas.drawLine(o + const Offset(2.5, -4), o + const Offset(2.5, 4), p);
        }
    }
    if (selected) {
      canvas.drawCircle(o, 20, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = Colors.white.withValues(alpha: 0.7));
    }
  }

  @override
  bool shouldRepaint(_LanesStill old) => old.graph != graph || old.selected != selected || old.version != version || old.linkFor != linkFor;
}

class _LanesMoving extends CustomPainter {
  _LanesMoving({required this.graph, required this.phase, required this.at, required this.nowX, required this.selected, required this.working});
  final LaneGraph graph;
  final double phase;
  final Offset Function(LaneNode) at;
  final double nowX;
  final String? selected;
  final Set<String> working;

  @override
  void paint(Canvas canvas, Size size) {
    if (phase == 0) return;
    final t = _sky;
    // The step being worked on breathes, and three sparks circle it.
    for (final n in graph.nodes.where((n) => n.kind == NodeKind.current)) {
      final o = at(n);
      final live = working.contains(n.lane);
      final p = Curves.easeOut.transform(phase);
      canvas.drawCircle(o, 17 + 14 * p, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = t.accent.withValues(alpha: (live ? 0.45 : 0.2) * (1 - p)));
      if (live) {
        for (var k = 0; k < 3; k++) {
          final a = 2 * math.pi * (phase + k / 3);
          final s = o + Offset(math.cos(a) * 20, math.sin(a) * 20);
          _glow(canvas, s, 3, t.accent, blur: 3, alpha: 0.8);
          canvas.drawCircle(s, 1.6, Paint()..color = Colors.white);
        }
      }
    }
    // Energy along each real link, flowing into the step that waits.
    for (final e in graph.edges.where((e) => e.kind == EdgeKind.after)) {
      final a = graph.node(e.from), b = graph.node(e.to);
      if (a == null || b == null) continue;
      final m = _LanesStill._curve(at(a), at(b)).computeMetrics().firstOrNull;
      if (m == null) continue;
      for (var k = 0; k < 2; k++) {
        final f = (phase + k / 2) % 1.0;
        final tan = m.getTangentForOffset(m.length * f);
        if (tan == null) continue;
        final hot = selected != null && (e.from == selected || e.to == selected);
        _glow(canvas, tan.position, hot ? 5 : 3.5, t.accent, blur: 4, alpha: 0.9);
        canvas.drawCircle(tan.position, 1.4, Paint()..color = Colors.white.withValues(alpha: 0.9));
      }
    }
    // A slow shimmer down the NOW line.
    final y = _top + (size.height - _top) * phase;
    final r = Rect.fromLTWH(nowX - 1.5, y - 40, 3, 80);
    canvas.drawRect(r, Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [t.accent.withValues(alpha: 0), t.accent.withValues(alpha: 0.8), t.accent.withValues(alpha: 0)]).createShader(r));
  }

  @override
  bool shouldRepaint(_LanesMoving old) => old.phase != phase || old.selected != selected || old.graph != graph;
}

class _Legend extends StatelessWidget {
  const _Legend({required this.items});
  final List<(String, Color, bool)> items;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: _sky.surface.withValues(alpha: 0.82), borderRadius: BorderRadius.circular(10), border: Border.all(color: _sky.line)),
      child: Wrap(spacing: 12, runSpacing: 4, children: [
        for (final (label, color, dashed) in items)
          Row(mainAxisSize: MainAxisSize.min, children: [
            SizedBox(width: 18, height: 8, child: CustomPaint(painter: _LegendLine(color: color, dashed: dashed))),
            const SizedBox(width: 5),
            Flexible(child: Text(label, style: _sky.readout(9, color: _sky.ink2))),
          ]),
      ]),
    );
  }
}

class _LegendLine extends CustomPainter {
  _LegendLine({required this.color, required this.dashed});
  final Color color;
  final bool dashed;
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = 1.8;
    final path = Path()
      ..moveTo(0, size.height / 2)
      ..lineTo(size.width, size.height / 2);
    dashed ? _dashedPath(canvas, path, p, dash: 3, gap: 3) : canvas.drawPath(path, p);
  }

  @override
  bool shouldRepaint(_LegendLine old) => false;
}

/// The selected step: what it is, what it waits on, what waits on it.
class _StepPanel extends StatelessWidget {
  const _StepPanel({required this.node, required this.graph, required this.laneName, required this.onClose, required this.onJump, this.onAsk, this.draft, this.onLink, this.threads, this.onExplain});
  final StudioThreads? threads;
  final VoidCallback? onExplain;
  final LaneNode node;
  final LaneGraph graph;
  final String laneName;
  final VoidCallback onClose;
  final VoidCallback? onAsk;
  final void Function(String key) onJump;
  final StudioDraft? draft;
  final VoidCallback? onLink;

  /// How [key] is written in this step's `after:` tag.
  String _ref(String key) => key.split('/').first == node.lane ? key.split('/').last : refOf(key);

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final it = node.item;
    final into = [for (final e in graph.edges) if (e.to == node.key && e.kind != EdgeKind.rail) e];
    final outOf = [for (final e in graph.edges) if (e.from == node.key && e.kind != EdgeKind.rail) e];
    final off = graph.offscreen[node.key] ?? const [];
    final (word, color) = switch (node.kind) {
      NodeKind.done => ('DONE', t.good),
      NodeKind.current => ('NOW', t.accent),
      NodeKind.held => ('ON HOLD', t.warn),
      NodeKind.next => ('NEXT', t.muted),
    };
    final d = draft;
    // A link chip: tap jumps there. On WAITS ON, × unlinks a real link and
    // ✓ accepts a suggestion — both as draft orders.
    Widget link(LaneEdge e, String key, {bool waitsOn = false}) {
      final n = graph.node(key);
      final label = Text('${laneLabel(key.split('/').first)} · ${n?.item.id ?? key.split('/').last}${e.kind == EdgeKind.suggested ? ' ?' : ''}');
      final avatar = Icon(e.kind == EdgeKind.after ? Icons.link : Icons.help_outline, size: 14, color: e.kind == EdgeKind.after ? t.accent : t.warn);
      if (d == null || !waitsOn) return ActionChip(avatar: avatar, label: label, onPressed: () => onJump(key));
      final suggested = e.kind == EdgeKind.suggested;
      final cut = !suggested && d.laneUnlinks.contains('$key>${node.key}');
      final accepted = suggested && d.laneLinks.contains((key, node.key));
      return InputChip(
        avatar: avatar,
        label: cut || accepted ? DefaultTextStyle.merge(style: TextStyle(decoration: cut ? TextDecoration.lineThrough : null, color: kDraftColor), child: label) : label,
        onPressed: () => onJump(key),
        deleteIcon: Icon(cut || accepted ? Icons.undo : (suggested ? Icons.check : Icons.close), size: 16, color: cut || accepted ? kDraftColor : (suggested ? t.good : t.critical)),
        deleteButtonTooltipMessage: cut ? 'Keep this link' : (accepted ? 'Take the acceptance back' : (suggested ? 'Accept: make it a real link' : 'Unlink')),
        // The draft cancels a link against its unlink, so a second tap undoes the first.
        onDeleted: () => d.add(DraftOrder(kind: (suggested && !accepted) || cut ? DraftKind.link : DraftKind.unlink, lane: node.lane, target: it.id, other: _ref(key))),
      );
    }

    return Material(
      elevation: 8,
      color: t.surface,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 6, 12),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.45),
          child: SingleChildScrollView(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Row(children: [
                Expanded(child: Text('$laneName · ${it.id}', style: t.display(15, ls: 0.6), overflow: TextOverflow.ellipsis)),
                Pill(word, color: color),
                IconButton(tooltip: 'Close', icon: const Icon(Icons.close, size: 18), onPressed: onClose),
              ]),
              Padding(padding: const EdgeInsets.only(right: 8), child: Text(it.title, maxLines: 3, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13.5, color: t.ink, height: 1.35))),
              if (it.section != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text(it.section!.toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis, style: t.readout(9.5, color: t.muted))),
              _ForLine(threads: threads, threadKey: 'step:${node.key}', onExplain: onExplain),
              _ResourceLine(load: () => StudioSource.current?.resourcesCached(node.lane, it), onOpen: () => openStepItem(context, laneName, it, lane: node.lane)),
              ListenableBuilder(
                listenable: d ?? _noDraft,
                builder: (context, _) {
                  // Links in the draft, not sent yet: violet, × takes one back.
                  final pending = [
                    if (d != null)
                      for (final (i, o) in d.orders.indexed)
                        if (o.kind == DraftKind.link && o.key == node.key) (i, o),
                  ];
                  if (into.isEmpty && pending.isEmpty) return const SizedBox.shrink();
                  return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const SizedBox(height: 10),
                    Text('WAITS ON', style: t.readout(9.5, color: t.accent)),
                    const SizedBox(height: 4),
                    Wrap(spacing: 6, runSpacing: 6, children: [
                      for (final e in into) link(e, e.from, waitsOn: true),
                      for (final (i, o) in pending)
                        InputChip(
                          avatar: const Icon(Icons.link, size: 14, color: kDraftColor),
                          label: Text('${o.other} · in the draft'),
                          side: const BorderSide(color: kDraftColor),
                          deleteIcon: const Icon(Icons.close, size: 16, color: kDraftColor),
                          deleteButtonTooltipMessage: 'Take this link out of the draft',
                          onDeleted: () => d!.removeAt(i),
                        ),
                    ]),
                  ]);
                },
              ),
              if (outOf.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text('UNLOCKS', style: t.readout(9.5, color: t.accent)),
                const SizedBox(height: 4),
                Wrap(spacing: 6, runSpacing: 6, children: [for (final e in outOf) link(e, e.to)]),
              ],
              if (off.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text('Also waits on, not in this view: ${off.join(', ')}', style: t.mono(11, color: t.muted))),
              if (into.isEmpty && outOf.isEmpty && off.isEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text('No links yet — only the lane\'s order. Links come as `after:` tags.', style: t.mono(11, color: t.muted))),
              const SizedBox(height: 10),
              Wrap(spacing: 8, runSpacing: 8, children: [
                if (onAsk != null) _ThreadButton(threads: threads, threadKey: 'step:${node.key}', onPressed: onAsk!),
                OutlinedButton(onPressed: () => openStepItem(context, laneName, it, lane: node.lane), child: const Text('OPEN STEP')),
              ]),
              if (threads != null) _LastAnswer(threads: threads!, threadKey: 'step:${node.key}'),
              if (d != null) ...[
                const SizedBox(height: 8),
                ListenableBuilder(
                  listenable: d,
                  builder: (context, _) {
                    final removed = d.removed.contains(node.key);
                    final open = !it.done;
                    return Wrap(spacing: 6, runSpacing: 6, children: [
                      _DraftButton(icon: Icons.link, label: 'WAITS ON…', onPressed: onLink),
                      _DraftButton(icon: Icons.add, label: 'ADD AFTER', onPressed: () async {
                        final r = await editStepDialog(context, title: 'New step after ${it.id}', askId: true);
                        if (r != null) d.add(DraftOrder(kind: DraftKind.add, lane: node.lane, target: it.id, newId: r.id, text: r.text));
                      }),
                      if (open)
                        _DraftButton(icon: Icons.edit_outlined, label: 'EDIT', onPressed: () async {
                          final r = await editStepDialog(context, title: 'Edit ${it.id}', text: it.text.replaceFirst(RegExp(r'^\S+\s*'), ''));
                          if (r != null) d.add(DraftOrder(kind: DraftKind.edit, lane: node.lane, target: it.id, text: '- [ ] ${it.id}: ${r.text}'));
                        }),
                      if (open)
                        _DraftButton(
                          icon: removed ? Icons.undo : Icons.delete_outline,
                          label: removed ? 'KEEP IT' : 'REMOVE',
                          danger: !removed,
                          onPressed: () {
                            if (removed) {
                              d.removeAt(d.orders.indexWhere((o) => o.kind == DraftKind.remove && o.key == node.key));
                            } else {
                              d.add(DraftOrder(kind: DraftKind.remove, lane: node.lane, target: it.id));
                            }
                          },
                        ),
                    ]);
                  },
                ),
              ],
            ]),
          ),
        ),
      ),
    );
  }
}

// --- the roadmap ---------------------------------------------------------------------

/// The roadmap as a constellation: milestone stars on a glowing path, the
/// path lit up to where the team is, each milestone's items in orbit —
/// colour by state, size by effort — and their own links as curves.
class RoadmapConstellation extends StatefulWidget {
  const RoadmapConstellation({super.key, required this.milestones, this.steps = const {}, this.onAskItem, this.onExplainItem, this.draft, this.threads, this.extraControls = const []});
  final void Function(RoadmapItem item)? onExplainItem;
  final StudioThreads? threads;
  final List<Milestone> milestones;

  /// Lane steps naming an item, by item id.
  final Map<String, List<(String, StepItem)>> steps;
  final void Function(RoadmapItem item)? onAskItem;
  final StudioDraft? draft;
  final List<Widget> extraControls;

  @override
  State<RoadmapConstellation> createState() => _RoadmapConstellationState();
}

class _RoadmapConstellationState extends State<RoadmapConstellation> with WidgetsBindingObserver, _Sky, _FxClock {
  @override
  double get pulsePeriod => 3.2;
  late RoadmapLayout _lay = RoadmapLayout.build(widget.milestones);
  @override
  Size get skyCanvas => _lay.size;
  String? _item;
  String? _star;

  /// WAITS ON…: the item that will wait — the next tap picks what it waits on.
  String? _linkFor;

  /// A hold-and-drag in flight on the roadmap.
  String? _dragId;
  Offset? _dragAt;

  /// What a drop at [p] lands on: another item (it goes after it) or a star
  /// (it joins that milestone).
  ({String? item, String? star})? _dropOn(Offset p, String lifted) {
    for (final e in _lay.items.entries) {
      if (e.key != lifted && (e.value.at - p).distance < 18) return (item: e.key, star: null);
    }
    for (final e in _lay.stars.entries) {
      if ((e.value - p).distance < 34) return (item: null, star: e.key);
    }
    return null;
  }

  void _liftStart(Offset p) {
    if (widget.draft == null) return;
    String? best;
    var bd = 16.0;
    for (final e in _lay.items.entries) {
      final d = (e.value.at - p).distance;
      if (d < bd) {
        bd = d;
        best = e.key;
      }
    }
    if (best == null || _lay.items[best]!.item.status == ItemStatus.done) return;
    setState(() {
      _dragId = best;
      _dragAt = p;
      _item = null;
      _star = null;
    });
  }

  void _liftEnd() {
    final id = _dragId, p = _dragAt;
    setState(() {
      _dragId = null;
      _dragAt = null;
    });
    if (id == null || p == null) return;
    final on = _dropOn(p, id);
    if (on == null) return;
    final item = _lay.items[id]!.item;
    if (on.star != null && on.star == item.milestone) return;
    widget.draft!.add(DraftOrder(kind: DraftKind.move, target: id, other: on.item ?? 'milestone:${on.star}'));
    setState(() => _item = id);
  }

  @override
  void didUpdateWidget(RoadmapConstellation old) {
    super.didUpdateWidget(old);
    if (old.milestones != widget.milestones) _lay = RoadmapLayout.build(widget.milestones);
  }

  void _tap(Offset p) {
    String? best;
    var bd = 16.0;
    for (final e in _lay.items.entries) {
      final d = (e.value.at - p).distance;
      if (d < bd) {
        bd = d;
        best = e.key;
      }
    }
    final pickFor = _linkFor;
    if (pickFor != null) {
      if (best != null && best != pickFor) widget.draft?.add(DraftOrder(kind: DraftKind.link, target: pickFor, other: best));
      setState(() {
        _linkFor = null;
        _item = pickFor;
      });
      return;
    }
    if (best != null) {
      setState(() {
        _item = best;
        _star = null;
      });
      return;
    }
    String? star;
    for (final e in _lay.stars.entries) {
      if ((e.value - p).distance < 30) star = e.key;
    }
    setState(() {
      _item = null;
      _star = star;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.milestones.isEmpty) return const EmptyNote('No roadmap found — pick the game repo under Folders (it reads production/production-plan.md).');
    final lay = _lay;
    final item = _item == null ? null : lay.items[_item!]?.item;
    final star = _star == null ? null : widget.milestones.where((m) => m.key == _star).firstOrNull;
    return LayoutBuilder(builder: (context, c) {
      viewportIs(c.biggest, () {
        final cur = lay.current == null ? null : lay.stars[lay.current!];
        if (cur != null && c.biggest.width < 900) {
          focusOn(cur, scale: 0.75, animate: false);
        } else {
          fit(lay.size, animate: false);
        }
      });
      return Stack(children: [
        Positioned.fill(child: RepaintBoundary(child: CustomPaint(painter: _SkyPainter(view: view, drift: drift)))),
        Positioned.fill(
          child: InteractiveViewer(
            transformationController: view,
            constrained: false,
            minScale: 0.3,
            maxScale: 3,
            boundaryMargin: const EdgeInsets.all(500),
            onInteractionStart: (_) => onGrab(),
            // Its own wheel zoom off (an infinite factor makes every wheel
            // step a scale of 1): the wheel is ours, smooth; a pinch stays its.
            scaleFactor: double.infinity,
            child: Listener(
              onPointerSignal: onWheelSignal,
              child: GestureDetector(
              onTapUp: (d) => _tap(d.localPosition),
              // Hold an item and drop it by another item, or on a milestone.
              onLongPressStart: (d) => _liftStart(d.localPosition),
              onLongPressMoveUpdate: (d) {
                if (_dragId != null) setState(() => _dragAt = d.localPosition);
              },
              onLongPressEnd: (_) => _liftEnd(),
              child: SizedBox.fromSize(
                key: const Key('road-sky'),
                size: lay.size,
                child: Stack(children: [
                  Positioned.fill(child: RepaintBoundary(child: ListenableBuilder(listenable: widget.draft ?? _noDraft, builder: (context, _) => CustomPaint(painter: _RoadStill(lay: lay, milestones: widget.milestones, selected: _item, star: _star, steps: widget.steps, draft: widget.draft, version: widget.draft?.length ?? 0, linkFor: _linkFor))))),
                  Positioned.fill(child: RepaintBoundary(child: ValueListenableBuilder<double>(valueListenable: pulse, builder: (context, phase, _) => CustomPaint(painter: _RoadMoving(lay: lay, milestones: widget.milestones, phase: phase, selected: _item))))),
                  if (_dragId != null && _dragAt != null)
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _RoadLiftPainter(
                          id: _dragId!,
                          at: _dragAt!,
                          target: () {
                            final on = _dropOn(_dragAt!, _dragId!);
                            if (on == null) return null;
                            return on.item != null ? lay.items[on.item!]!.at : lay.stars[on.star!];
                          }(),
                        ),
                      ),
                    ),
                ]),
              ),
            ),
            ),
          ),
        ),
        Positioned(
          left: 10,
          top: 10,
          right: 210,
          child: Align(
            alignment: Alignment.topLeft,
            child: _Legend(items: [
              for (final s in [ItemStatus.done, ItemStatus.built, ItemStatus.inProgress, ItemStatus.notStarted]) (statusWord(s), statusColor(_sky, s), s == ItemStatus.notStarted),
            ]),
          ),
        ),
        Positioned(right: 10, top: 10, child: _SkyControls(onZoom: zoom, onFit: () => fit(lay.size), extra: widget.extraControls)),
        if (_linkFor != null)
          Positioned(
            top: 56,
            left: 0,
            right: 0,
            child: Center(
              child: Material(
                color: kDraftColor.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 4, 4, 4),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Flexible(child: Text('Tap the item $_linkFor waits on', style: const TextStyle(color: Color(0xFF1A0F2E), fontWeight: FontWeight.w600))),
                    TextButton(onPressed: () => setState(() => _linkFor = null), child: const Text('CANCEL', style: TextStyle(color: Color(0xFF1A0F2E)))),
                  ]),
                ),
              ),
            ),
          ),
        if ((item != null || star != null) && _linkFor == null)
          Positioned(
            left: 10,
            right: 10,
            bottom: 10,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: item != null
                    ? _ItemPanel(item: item, steps: widget.steps[item.id] ?? const [], draft: widget.draft, threads: widget.threads, onExplain: widget.onExplainItem == null ? null : () => widget.onExplainItem!(item), onLink: widget.draft == null ? null : () => setState(() => _linkFor = item.id), onClose: () => setState(() => _item = null), onAsk: widget.onAskItem == null ? null : () => widget.onAskItem!(item), onJump: (id) {
                        final at = lay.items[id];
                        if (at == null) return;
                        setState(() => _item = id);
                        focusOn(at.at, scale: _scaleOf(view.value));
                      })
                    : _StarPanel(milestone: star!, current: star.key == lay.current, onClose: () => setState(() => _star = null)),
              ),
            ),
          ),
      ]);
    });
  }
}

double _itemR(RoadmapItem i) => switch (i.size) { 'S' => 5.0, 'L' => 9.0, 'XL' => 10.5, _ => 7.0 };

class _RoadStill extends CustomPainter {
  _RoadStill({required this.lay, required this.milestones, required this.selected, required this.star, required this.steps, this.draft, this.version = 0, this.linkFor});
  final StudioDraft? draft;
  final int version;
  final String? linkFor;
  final RoadmapLayout lay;
  final List<Milestone> milestones;
  final String? selected;
  final String? star;
  final Map<String, List<(String, StepItem)>> steps;

  @override
  void paint(Canvas canvas, Size size) {
    final t = _sky;
    final keys = [for (final m in milestones) m.key];
    final curIdx = lay.current == null ? keys.length : keys.indexOf(lay.current!);
    // The spine: lit up to where the team is, dashed beyond.
    for (var i = 1; i < keys.length; i++) {
      final a = lay.stars[keys[i - 1]]!, b = lay.stars[keys[i]]!;
      final pa = a + Offset(lay.starRadius[keys[i - 1]]! * 0.0 + 22, 0), pb = b - const Offset(22, 0);
      final lit = i <= curIdx;
      final path = Path()
        ..moveTo(pa.dx, pa.dy)
        ..lineTo(pb.dx, pb.dy);
      if (lit) {
        canvas.drawPath(path, Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 8
          ..color = (i < curIdx ? t.good : t.accent).withValues(alpha: 0.18)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
        canvas.drawPath(path, Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..shader = LinearGradient(colors: [i <= curIdx - 1 ? t.good : t.accent, i < curIdx ? t.good : t.accent]).createShader(Rect.fromPoints(pa, pb)));
      } else {
        _dashedPath(canvas, path, Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..color = t.muted.withValues(alpha: 0.5), dash: 7, gap: 6);
      }
    }
    // Orbits.
    for (final m in milestones) {
      final c = lay.stars[m.key]!;
      final r = lay.starRadius[m.key]!;
      if (m.items.isEmpty) continue;
      for (var rr = 74.0; rr <= r; rr += 30) {
        canvas.drawCircle(c, rr, Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8
          ..color = t.line.withValues(alpha: m.key == lay.current ? 0.55 : 0.25));
      }
    }
    final hotIds = selected == null ? const <String>{} : {selected!, for (final (a, b) in lay.links) if (a == selected || b == selected) ...[a, b]};
    // Item links.
    for (final (a, b) in lay.links) {
      final pa = lay.items[a]!.at, pb = lay.items[b]!.at;
      final hot = hotIds.contains(a) && hotIds.contains(b) && selected != null;
      final mid = Offset((pa.dx + pb.dx) / 2, (pa.dy + pb.dy) / 2 - 40);
      final path = Path()
        ..moveTo(pa.dx, pa.dy)
        ..quadraticBezierTo(mid.dx, mid.dy, pb.dx, pb.dy);
      canvas.drawPath(path, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = hot ? 2.2 : 1.2
        ..color = t.accent.withValues(alpha: selected == null ? 0.55 : (hot ? 1 : 0.15)));
    }
    // Pending roadmap links, in violet.
    final d = draft;
    if (d != null) {
      for (final (a, b) in d.roadmapLinks) {
        final pa = lay.items[a]?.at, pb = lay.items[b]?.at;
        if (pa == null || pb == null) continue;
        final mid = Offset((pa.dx + pb.dx) / 2, (pa.dy + pb.dy) / 2 - 40);
        _dashedPath(canvas, Path()
          ..moveTo(pa.dx, pa.dy)
          ..quadraticBezierTo(mid.dx, mid.dy, pb.dx, pb.dy), Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = kDraftColor, dash: 6, gap: 4);
      }
    }
    final touched = d?.roadmapTouched ?? const <String>{};
    // Items.
    for (final e in lay.items.entries) {
      final it = e.value.item;
      final o = e.value.at;
      final c = statusColor(t, it.status);
      final r = _itemR(it);
      final dim = selected != null && !hotIds.contains(e.key);
      final a = dim ? 0.3 : 1.0;
      switch (it.status) {
        case ItemStatus.done:
          canvas.drawCircle(o, r, Paint()..color = c.withValues(alpha: 0.35 * a));
          canvas.drawCircle(o, r, Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1
            ..color = c.withValues(alpha: 0.8 * a));
        case ItemStatus.notStarted:
          _dashedCircle(canvas, o, r, Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.1
            ..color = c.withValues(alpha: 0.8 * a), n: 10);
        default:
          if (!dim) _glow(canvas, o, r + 3, c, blur: 6, alpha: 0.45);
          canvas.drawCircle(o, r, Paint()..color = c.withValues(alpha: 0.85 * a));
      }
      if ((steps[e.key]?.isNotEmpty ?? false) && !dim) {
        canvas.drawCircle(o + Offset(r + 2, -r - 2), 2.2, Paint()..color = t.good);
      }
      final lp = _label(it.id, 8.5, dim ? t.muted.withValues(alpha: 0.4) : t.ink2);
      lp.paint(canvas, Offset(o.dx - lp.width / 2, o.dy + r + 2));
      if (touched.contains(e.key) || e.key == linkFor) {
        _dashedCircle(canvas, o, r + 5, Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = kDraftColor, n: 10);
      }
      if (e.key == selected) {
        canvas.drawCircle(o, r + 7, Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = Colors.white.withValues(alpha: 0.8));
        // The lane steps that name it, as small satellites.
        final n = math.min(12, steps[e.key]?.length ?? 0);
        for (var k = 0; k < n; k++) {
          final ang = 2 * math.pi * k / math.max(1, n) - math.pi / 2;
          final s = o + Offset(math.cos(ang) * (r + 14), math.sin(ang) * (r + 14));
          canvas.drawCircle(s, 2.6, Paint()..color = t.good);
        }
      }
    }
    // Stars.
    for (final (i, m) in milestones.indexed) {
      final c = lay.stars[m.key]!;
      final closed = m.items.isNotEmpty && m.doneCount == m.items.length;
      final isCur = m.key == lay.current;
      final color = closed ? t.good : (isCur ? t.accent : (i > curIdx ? t.muted : t.ink2));
      _glow(canvas, c, isCur ? 30 : 22, color, blur: isCur ? 18 : 12, alpha: isCur ? 0.6 : 0.35);
      canvas.drawCircle(c, isCur ? 22 : 18, Paint()..color = t.bg);
      canvas.drawCircle(c, isCur ? 22 : 18, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = isCur ? 3 : 2
        ..color = color);
      if (m.items.isNotEmpty) {
        final frac = m.doneCount / m.items.length;
        canvas.drawArc(Rect.fromCircle(center: c, radius: isCur ? 27 : 23), -math.pi / 2, 2 * math.pi * frac, false, Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round
          ..color = t.good);
      }
      final k = _label(m.key, isCur ? 16 : 14, color, weight: FontWeight.w700, family: kDisplayFont);
      k.paint(canvas, c - Offset(k.width / 2, k.height / 2));
      final name = _label(m.name.replaceFirst(RegExp('^${RegExp.escape(m.key)}\\s*'), '').toUpperCase(), 11, t.ink, weight: FontWeight.w600, family: kDisplayFont, maxWidth: 180);
      name.paint(canvas, Offset(c.dx - name.width / 2, c.dy - lay.starRadius[m.key]! - 30));
      if (m.items.isNotEmpty) {
        final cnt = _label('${m.doneCount}/${m.items.length} DONE', 9, t.muted);
        cnt.paint(canvas, Offset(c.dx - cnt.width / 2, c.dy - lay.starRadius[m.key]! - 15));
      }
      if (isCur) {
        final here = _label('WE ARE HERE', 10, t.accent, weight: FontWeight.w700);
        here.paint(canvas, Offset(c.dx - here.width / 2, c.dy + lay.starRadius[m.key]! + 6));
      }
      if (m.key == star) {
        canvas.drawCircle(c, (isCur ? 22 : 18) + 12, Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = Colors.white.withValues(alpha: 0.8));
      }
    }
  }

  @override
  bool shouldRepaint(_RoadStill old) => old.lay != lay || old.selected != selected || old.star != star || old.version != version || old.linkFor != linkFor;
}

class _RoadMoving extends CustomPainter {
  _RoadMoving({required this.lay, required this.milestones, required this.phase, required this.selected});
  final RoadmapLayout lay;
  final List<Milestone> milestones;
  final double phase;
  final String? selected;

  @override
  void paint(Canvas canvas, Size size) {
    if (phase == 0) return;
    final t = _sky;
    final cur = lay.current == null ? null : lay.stars[lay.current!];
    if (cur != null) {
      // WE ARE HERE: two rings breathing out of the current star.
      for (var k = 0; k < 2; k++) {
        final p = (phase + k / 2) % 1.0;
        canvas.drawCircle(cur, 26 + 34 * Curves.easeOut.transform(p), Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..color = t.accent.withValues(alpha: 0.5 * (1 - p)));
      }
      // A light travelling the lit spine, from the first star to here.
      final first = lay.stars[milestones.first.key]!;
      if ((cur - first).distance > 1) {
        final x = first.dx + (cur.dx - first.dx) * phase;
        _glow(canvas, Offset(x, cur.dy), 7, t.accent, blur: 6, alpha: 0.9);
        canvas.drawCircle(Offset(x, cur.dy), 2.4, Paint()..color = Colors.white);
      }
    }
    // Work in progress twinkles.
    for (final e in lay.items.entries) {
      if (e.value.item.status != ItemStatus.inProgress) continue;
      final w = 0.5 + 0.5 * math.sin(2 * math.pi * (phase + (e.key.hashCode % 100) / 100));
      _glow(canvas, e.value.at, _itemR(e.value.item) + 4, t.accent, blur: 5, alpha: 0.35 * w);
    }
    // Energy along links into the selected item.
    for (final (a, b) in lay.links) {
      if (selected != null && a != selected && b != selected) continue;
      final pa = lay.items[a]!.at, pb = lay.items[b]!.at;
      final mid = Offset((pa.dx + pb.dx) / 2, (pa.dy + pb.dy) / 2 - 40);
      final path = Path()
        ..moveTo(pa.dx, pa.dy)
        ..quadraticBezierTo(mid.dx, mid.dy, pb.dx, pb.dy);
      final m = path.computeMetrics().firstOrNull;
      final tan = m?.getTangentForOffset(m.length * phase);
      if (tan == null) continue;
      _glow(canvas, tan.position, 4, t.accent, blur: 4, alpha: 0.9);
    }
  }

  @override
  bool shouldRepaint(_RoadMoving old) => old.phase != phase || old.selected != selected || old.lay != lay;
}

class _ItemPanel extends StatelessWidget {
  const _ItemPanel({required this.item, required this.steps, required this.onClose, required this.onJump, this.onAsk, this.draft, this.onLink, this.threads, this.onExplain});
  final StudioThreads? threads;
  final VoidCallback? onExplain;
  final StudioDraft? draft;
  final VoidCallback? onLink;
  final RoadmapItem item;
  final List<(String, StepItem)> steps;
  final VoidCallback onClose;
  final VoidCallback? onAsk;
  final void Function(String id) onJump;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Material(
      elevation: 8,
      color: t.surface,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 6, 12),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.45),
          child: SingleChildScrollView(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Row(children: [
                Expanded(child: Text('${item.id} · ${item.task}', maxLines: 2, overflow: TextOverflow.ellipsis, style: t.display(15, ls: 0.4))),
                IconButton(tooltip: 'Close', icon: const Icon(Icons.close, size: 18), onPressed: onClose),
              ]),
              Wrap(spacing: 6, runSpacing: 6, children: [
                Pill(statusWord(item.status), color: statusColor(t, item.status)),
                Pill(item.milestone, color: t.muted),
                if (item.size != null) Pill('SIZE ${item.size}', color: t.muted),
              ]),
              if (item.owner != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text('OWNER · ${item.owner}'.toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis, style: t.readout(9.5, color: t.muted))),
              _ForLine(threads: threads, threadKey: 'item:${item.id}', onExplain: onExplain),
              _ResourceLine(load: () => StudioSource.current?.resourcesForItem(item), onOpen: () => openRoadmapItem(context, item)),
              Padding(padding: const EdgeInsets.only(top: 6, right: 8), child: Text(item.status == ItemStatus.done ? 'Done ${item.statusText}' : item.statusText.replaceAll(RegExp(r'\*\*|`'), ''), maxLines: 4, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, color: t.ink2, height: 1.35))),
              if (item.after.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('WAITS ON', style: t.readout(9.5, color: t.accent)),
                const SizedBox(height: 4),
                Wrap(spacing: 6, runSpacing: 6, children: [
                  for (final id in item.after)
                    draft == null
                        ? ActionChip(avatar: Icon(Icons.link, size: 14, color: t.accent), label: Text(id), onPressed: () => onJump(id))
                        : InputChip(
                            avatar: Icon(Icons.link, size: 14, color: t.accent),
                            label: Text(id),
                            onPressed: () => onJump(id),
                            deleteIcon: Icon(Icons.close, size: 16, color: t.critical),
                            deleteButtonTooltipMessage: 'Unlink',
                            onDeleted: () => draft!.add(DraftOrder(kind: DraftKind.unlink, target: item.id, other: id)),
                          ),
                ]),
              ],
              if (steps.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('LANE STEPS NAMING IT · ${steps.length}', style: t.readout(9.5, color: t.good)),
                for (final (lane, s) in steps.take(8))
                  InkWell(
                    onTap: () => openStepItem(context, laneLabel(lane), s),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text('${laneLabel(lane)} · ${s.id}${s.done ? ' ✓' : ''} — ${s.title}', maxLines: 1, overflow: TextOverflow.ellipsis, style: t.mono(11, color: t.ink2)),
                    ),
                  ),
              ],
              const SizedBox(height: 10),
              Wrap(spacing: 8, runSpacing: 8, children: [
                if (onAsk != null) _ThreadButton(threads: threads, threadKey: 'item:${item.id}', onPressed: onAsk!),
                OutlinedButton(onPressed: () => openRoadmapItem(context, item), child: const Text('OPEN DETAILS')),
              ]),
              if (threads != null) _LastAnswer(threads: threads!, threadKey: 'item:${item.id}'),
              if (draft != null) ...[
                const SizedBox(height: 8),
                Wrap(spacing: 6, runSpacing: 6, children: [
                  _DraftButton(icon: Icons.link, label: 'WAITS ON…', onPressed: onLink),
                  _DraftButton(icon: Icons.add, label: 'ADD AFTER', onPressed: () async {
                    final r = await editStepDialog(context, title: 'New ${item.milestone} item after ${item.id}', askId: true);
                    if (r != null) draft!.add(DraftOrder(kind: DraftKind.add, target: item.id, newId: r.id, text: r.text));
                  }),
                  if (item.status != ItemStatus.done) ...[
                    _DraftButton(icon: Icons.edit_outlined, label: 'EDIT', onPressed: () async {
                      final r = await editStepDialog(context, title: 'Edit ${item.id}', text: '${item.task}\n\n${item.statusText}');
                      if (r != null) draft!.add(DraftOrder(kind: DraftKind.edit, target: item.id, text: r.text));
                    }),
                    _DraftButton(icon: Icons.delete_outline, label: 'REMOVE', danger: true, onPressed: () => draft!.add(DraftOrder(kind: DraftKind.remove, target: item.id))),
                  ],
                ]),
              ],
            ]),
          ),
        ),
      ),
    );
  }
}

class _StarPanel extends StatelessWidget {
  const _StarPanel({required this.milestone, required this.current, required this.onClose});
  final Milestone milestone;
  final bool current;
  final VoidCallback onClose;
  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final m = milestone;
    final counts = {for (final s in ItemStatus.values) s: m.items.where((i) => i.status == s).length};
    return Material(
      elevation: 8,
      color: t.surface,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 6, 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            Expanded(child: Text('${m.key} · ${m.name.replaceFirst(RegExp('^${RegExp.escape(m.key)}\\s*'), '')}'.toUpperCase(), style: t.display(16, ls: 0.6))),
            if (current) Pill('WE ARE HERE', color: t.accent, filled: true),
            IconButton(tooltip: 'Close', icon: const Icon(Icons.close, size: 18), onPressed: onClose),
          ]),
          if (m.goal.isNotEmpty) Padding(padding: const EdgeInsets.only(right: 8), child: Text(m.goal, maxLines: 3, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, color: t.ink2, height: 1.35))),
          const SizedBox(height: 8),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final s in [ItemStatus.done, ItemStatus.built, ItemStatus.inProgress, ItemStatus.notStarted])
              if (counts[s]! > 0) Pill('${counts[s]} ${statusWord(s)}', color: statusColor(t, s)),
          ]),
          if (m.ladderStatus.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8, right: 8), child: Text(m.ladderStatus, maxLines: 3, overflow: TextOverflow.ellipsis, style: t.mono(11, color: t.muted))),
        ]),
      ),
    );
  }
}


/// A small violet-edged button for a change that goes into the draft.
class _DraftButton extends StatelessWidget {
  const _DraftButton({required this.icon, required this.label, required this.onPressed, this.danger = false});
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool danger;
  @override
  Widget build(BuildContext context) {
    final c = danger ? context.tokens.critical : kDraftColor;
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(side: BorderSide(color: c.withValues(alpha: 0.8)), foregroundColor: danger ? c : null, visualDensity: VisualDensity.compact),
      onPressed: onPressed,
      icon: Icon(icon, size: 16, color: c),
      label: Text(label),
    );
  }
}

/// Asks for a step's (or item's) text — markdown, indented `- ` lines are
/// its substeps — and, for a new one, its id. Null when cancelled.
Future<({String id, String text})?> editStepDialog(BuildContext context, {required String title, String text = '', bool askId = false}) {
  return showDialog<({String id, String text})>(context: context, builder: (_) => _StepDialog(title: title, text: text, askId: askId));
}

class _StepDialog extends StatefulWidget {
  const _StepDialog({required this.title, required this.text, required this.askId});
  final String title;
  final String text;
  final bool askId;
  @override
  State<_StepDialog> createState() => _StepDialogState();
}

class _StepDialogState extends State<_StepDialog> {
  final _id = TextEditingController();
  late final _text = TextEditingController(text: widget.text);

  @override
  void dispose() {
    _id.dispose();
    _text.dispose();
    super.dispose();
  }

  bool get _ok => _text.text.trim().isNotEmpty && (!widget.askId || RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]*$').hasMatch(_id.text.trim()));

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (widget.askId) ...[
              TextField(controller: _id, autofocus: true, decoration: const InputDecoration(labelText: 'Step id (e.g. ROOMLAB-2A)', border: OutlineInputBorder()), onChanged: (_) => setState(() {})),
              const SizedBox(height: 12),
            ],
            TextField(controller: _text, autofocus: !widget.askId, minLines: 4, maxLines: 14, decoration: const InputDecoration(labelText: 'What the step does', alignLabelWithHint: true, border: OutlineInputBorder()), style: t.mono(13), onChanged: (_) => setState(() {})),
            const SizedBox(height: 6),
            Text('Substeps: indented lines starting with "  - ". A dependency: (after: lane-b/STEP-ID).', style: TextStyle(fontSize: 12, color: t.muted)),
            const SizedBox(height: 4),
            Text('It goes into the draft — nothing changes until you send it to the orchestrator.', style: TextStyle(fontSize: 12, color: t.muted)),
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
        FilledButton(onPressed: _ok ? () => Navigator.pop(context, (id: _id.text.trim(), text: _text.text.trim())) : null, child: const Text('ADD TO DRAFT')),
      ],
    );
  }
}


/// QUESTIONS (n) when the step has a thread, ASK A QUESTION when not.
class _ThreadButton extends StatelessWidget {
  const _ThreadButton({required this.threads, required this.threadKey, required this.onPressed});
  final StudioThreads? threads;
  final String threadKey;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) {
    final th = threads;
    Widget button(int n) => FilledButton.icon(onPressed: onPressed, icon: const Icon(Icons.forum_outlined, size: 18), label: Text(n == 0 ? 'ASK A QUESTION' : 'QUESTIONS · $n'));
    if (th == null) return button(0);
    return ListenableBuilder(listenable: th, builder: (context, _) => button(th.questions(threadKey)));
  }
}

/// The latest answer in the step's thread, two lines of it.
class _LastAnswer extends StatelessWidget {
  const _LastAnswer({required this.threads, required this.threadKey});
  final StudioThreads threads;
  final String threadKey;
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: threads,
      builder: (context, _) {
        final a = threads.lastAnswer(threadKey);
        if (a == null || a.isEmpty) return const SizedBox.shrink();
        final t = context.tokens;
        return Padding(
          padding: const EdgeInsets.only(top: 8, right: 8),
          child: Text('LAST ANSWER · ${a.replaceAll(RegExp(r'[*`#]'), '').replaceAll('\n', ' ')}', maxLines: 2, overflow: TextOverflow.ellipsis, style: t.mono(11, color: t.ink2)),
        );
      },
    );
  }
}


/// The lifted step following the pointer, and where it would land.
class _LiftPainter extends CustomPainter {
  _LiftPainter({required this.node, required this.at, required this.landingX, required this.rowY});
  final LaneNode node;
  final Offset at;
  final double? landingX;
  final double rowY;
  @override
  void paint(Canvas canvas, Size size) {
    if (landingX != null) {
      final p = Paint()
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round
        ..color = kDraftColor;
      canvas.drawLine(Offset(landingX!, rowY - 24), Offset(landingX!, rowY + 24), p);
      _glow(canvas, Offset(landingX!, rowY), 10, kDraftColor, blur: 8, alpha: 0.4);
    }
    _glow(canvas, at, 18, kDraftColor, blur: 10, alpha: 0.5);
    canvas.drawCircle(at, 14, Paint()..color = _sky.bg);
    canvas.drawCircle(at, 14, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..color = kDraftColor);
    final lp = _label(node.item.id, 10, kDraftColor, weight: FontWeight.w700);
    lp.paint(canvas, Offset(at.dx - lp.width / 2, at.dy + 18));
  }

  @override
  bool shouldRepaint(_LiftPainter old) => old.at != at || old.landingX != landingX;
}


class _RoadLiftPainter extends CustomPainter {
  _RoadLiftPainter({required this.id, required this.at, this.target});
  final String id;
  final Offset at;
  final Offset? target;
  @override
  void paint(Canvas canvas, Size size) {
    if (target != null) {
      _dashedCircle(canvas, target!, 22, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = kDraftColor);
      canvas.drawLine(at, target!, Paint()
        ..strokeWidth = 1
        ..color = kDraftColor.withValues(alpha: 0.5));
    }
    _glow(canvas, at, 12, kDraftColor, blur: 8, alpha: 0.5);
    canvas.drawCircle(at, 8, Paint()..color = kDraftColor);
    final lp = _label(id, 10, kDraftColor, weight: FontWeight.w700);
    lp.paint(canvas, Offset(at.dx - lp.width / 2, at.dy + 12));
  }

  @override
  bool shouldRepaint(_RoadLiftPainter old) => old.at != at || old.target != target;
}


/// WHAT IT IS FOR: the desk's summary, or EXPLAIN to have it written.
class _ForLine extends StatelessWidget {
  const _ForLine({required this.threads, required this.threadKey, this.onExplain});
  final StudioThreads? threads;
  final String threadKey;
  final VoidCallback? onExplain;
  @override
  Widget build(BuildContext context) {
    final th = threads;
    if (th == null) return const SizedBox.shrink();
    final t = context.tokens;
    return ListenableBuilder(
      listenable: th,
      builder: (context, _) {
        final s = th.summary(threadKey);
        return Padding(
          padding: const EdgeInsets.only(top: 8, right: 8),
          child: s != null
              ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('WHAT IT IS FOR', style: t.readout(9.5, color: t.accent)),
                  const SizedBox(height: 2),
                  Text(s, maxLines: 4, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, color: t.ink, height: 1.35)),
                ])
              : (onExplain == null
                  ? const SizedBox.shrink()
                  : Align(alignment: Alignment.centerLeft, child: TextButton.icon(onPressed: onExplain, icon: const Icon(Icons.lightbulb_outline, size: 16), label: const Text('EXPLAIN WHAT IT IS FOR')))),
        );
      },
    );
  }
}

/// RESOURCES · 3 PICTURES · 2 MAILS — tap for the step's page.
class _ResourceLine extends StatelessWidget {
  const _ResourceLine({required this.load, required this.onOpen});
  final StepResources? Function() load;
  final VoidCallback onOpen;
  @override
  Widget build(BuildContext context) {
    final r = load();
    if (r == null || r.isEmpty) return const SizedBox.shrink();
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: InkWell(
        onTap: onOpen,
        child: Row(children: [
          Icon(Icons.perm_media_outlined, size: 15, color: t.accent),
          const SizedBox(width: 6),
          Flexible(child: Text('RESOURCES · ${r.label}', maxLines: 1, overflow: TextOverflow.ellipsis, style: t.readout(9.5, color: t.accent))),
        ]),
      ),
    );
  }
}


/// Lane badges pinned to the left edge, following the rows through pan and
/// zoom — drawn only while the canvas's own names are out of sight.
class _LaneBadges extends CustomPainter {
  _LaneBadges({required this.view, required this.lanes}) : super(repaint: view);
  final TransformationController view;
  final List<String> lanes;
  @override
  void paint(Canvas canvas, Size size) {
    final m = view.value;
    final s = _scaleOf(m);
    final tx = m.storage[12], ty = m.storage[13];
    // The canvas's names sit at x 14–90: visible while tx > -14 * s.
    if (tx > -20 * s) return;
    for (final (row, id) in lanes.indexed) {
      final y = ty + (_top + row * _rowH + _rowH / 2) * s;
      if (y < -20 || y > size.height + 20) continue;
      final r = RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(26, y), width: 38, height: 26), const Radius.circular(8));
      canvas.drawRRect(r, Paint()..color = _sky.surface.withValues(alpha: 0.92));
      canvas.drawRRect(r, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = _sky.lineStrong);
      final lp = _label(id.toUpperCase(), 13, _sky.ink, weight: FontWeight.w700, family: kDisplayFont);
      lp.paint(canvas, Offset(26 - lp.width / 2, y - lp.height / 2));
    }
  }

  @override
  bool shouldRepaint(_LaneBadges old) => old.lanes != lanes;
}
