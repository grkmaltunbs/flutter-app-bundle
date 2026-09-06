import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart' hide Step, StepState;
import 'package:flutter_kit/kit.dart';

import '../attachments.dart';
import '../theme.dart';

/// What the sheet needs from whichever side it opens on: the frame's
/// record as it ticks, the bytes of the newest frame, the heartbeat that
/// keeps the host streaming, one frame on demand, and the input.
class MirrorHooks {
  const MirrorHooks({required this.state, required this.frame, required this.ping, required this.requestFrame, required this.input});

  /// The `mirror` record, current value first.
  final Stream<MirrorState> state;

  /// The newest frame's bytes.
  final Future<Uint8List> Function() frame;

  /// "A sheet is open here" — every [watchPing] while it is.
  final Future<void> Function() ping;

  /// One frame now; returns the host's line.
  final Future<String> Function() requestFrame;

  /// Plays an input; returns the host's line.
  final Future<String> Function(Map<String, Object?> command) input;
}

/// The mirror sheet: the device's screen, full width and at its aspect,
/// with the frame's age, a tap or a drag played on the device, a caption
/// for the last input, and a camera icon that hands the frame to the
/// composer ([onAttach]) as a picture the session can look at.
Future<void> showMirrorSheet(BuildContext context, MirrorHooks hooks, {required String title, void Function(PendingAttachment frame)? onAttach}) {
  final t = context.tokens;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: t.surface,
    builder: (sheet) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.92,
      maxChildSize: 0.96,
      builder: (context, ctrl) => MirrorView(
        hooks: hooks,
        title: title,
        onAttach: onAttach == null
            ? null
            : (f) {
                Navigator.of(sheet).pop();
                onAttach(f);
              },
      ),
    ),
  );
}

class MirrorView extends StatefulWidget {
  const MirrorView({super.key, required this.hooks, required this.title, this.onAttach, this.now});
  final MirrorHooks hooks;
  final String title;
  final void Function(PendingAttachment frame)? onAttach;
  final DateTime Function()? now;

  @override
  State<MirrorView> createState() => _MirrorViewState();
}

class _MirrorViewState extends State<MirrorView> {
  MirrorState _state = const MirrorState();
  Uint8List? _bytes;
  int _shownSeq = 0;
  bool _fetching = false;
  String? _line;
  StreamSubscription<MirrorState>? _sub;
  Timer? _ping;
  Timer? _age;
  Offset? _dragStart;

  DateTime get _now => widget.now?.call() ?? DateTime.now();

  @override
  void initState() {
    super.initState();
    _sub = widget.hooks.state.listen((s) {
      if (!mounted) return;
      setState(() => _state = s);
      if (s.seq != _shownSeq) _fetch(s.seq);
    });
    unawaited(widget.hooks.ping());
    unawaited(widget.hooks.requestFrame().then((l) => _say(l), onError: (Object e) => _say('$e')));
    _ping = Timer.periodic(watchPing, (_) => widget.hooks.ping());
    _age = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _fetch(int seq) async {
    if (_fetching) return;
    _fetching = true;
    try {
      final b = await widget.hooks.frame();
      if (!mounted) return;
      setState(() {
        _bytes = b;
        _shownSeq = seq;
      });
    } on Object catch (e) {
      _say('could not fetch the frame: $e');
    } finally {
      _fetching = false;
      if (mounted && _state.seq != _shownSeq) unawaited(_fetch(_state.seq));
    }
  }

  void _say(String line) {
    if (mounted) setState(() => _line = line);
  }

  @override
  void dispose() {
    _sub?.cancel();
    _ping?.cancel();
    _age?.cancel();
    super.dispose();
  }

  Future<void> _send(Map<String, Object?> cmd) async {
    _say(inputLabel(cmd));
    try {
      final r = await widget.hooks.input(cmd);
      _say(r);
    } on Object catch (e) {
      _say('$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final s = _state;
    final aspect = s.w > 0 && s.h > 0 ? s.w / s.h : 9 / 19.5;
    final age = s.at == null ? null : ageLabel(_now.difference(s.at!));
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 6),
          child: Row(
            children: [
              Expanded(child: Text(widget.title.toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis, style: t.readout(11))),
              Text(age == null ? '—' : '$age ago', style: t.readout(10, color: s.streaming ? t.good : t.muted)),
              const SizedBox(width: 6),
              if (widget.onAttach != null)
                IconButton(
                  tooltip: 'Attach this frame to the next message',
                  visualDensity: VisualDensity.compact,
                  icon: Icon(Icons.photo_camera_outlined, color: _bytes == null ? t.muted : t.accent),
                  onPressed: _bytes == null ? null : () => widget.onAttach!(PendingAttachment(name: 'frame-${s.seq}.jpg', mime: 'image/jpeg', bytes: _bytes!)),
                ),
            ],
          ),
        ),
        Expanded(
          child: Center(
            child: AspectRatio(
              aspectRatio: aspect,
              child: LayoutBuilder(
                builder: (context, box) => GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapUp: (d) {
                    final (x, y) = deviceXY(d.localPosition.dx, d.localPosition.dy, drawnW: box.maxWidth, drawnH: box.maxHeight, dw: s.dw, dh: s.dh);
                    unawaited(_send(inputCommand('tap', x: x, y: y)));
                  },
                  onPanStart: (d) => _dragStart = d.localPosition,
                  onPanEnd: (d) {
                    final start = _dragStart;
                    _dragStart = null;
                    if (start == null) return;
                    final end = d.localPosition;
                    if ((end - start).distance < 12) return;
                    final (x, y) = deviceXY(start.dx, start.dy, drawnW: box.maxWidth, drawnH: box.maxHeight, dw: s.dw, dh: s.dh);
                    final (x2, y2) = deviceXY(end.dx, end.dy, drawnW: box.maxWidth, drawnH: box.maxHeight, dw: s.dw, dh: s.dh);
                    unawaited(_send(inputCommand('swipe', x: x, y: y, x2: x2, y2: y2)));
                  },
                  child: Container(
                    decoration: BoxDecoration(color: t.bg, border: Border.all(color: t.line)),
                    child: _bytes == null
                        ? Center(child: Text(s.error ?? 'Waiting for the first frame…', textAlign: TextAlign.center, style: t.mono(12, color: s.error == null ? t.muted : t.warn)))
                        : Image.memory(_bytes!, fit: BoxFit.contain, gaplessPlayback: true),
                  ),
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
          child: Row(
            children: [
              Expanded(child: Text((_line ?? s.lastInput ?? (s.dw > 0 ? 'Tap or drag on the screen to drive it.' : '')).toUpperCase(), maxLines: 2, overflow: TextOverflow.ellipsis, style: t.readout(10, color: (_line ?? '').contains('not installed') || s.error != null ? t.warn : t.muted))),
              TextButton(onPressed: () => widget.hooks.requestFrame().then(_say, onError: (Object e) => _say('$e')), child: const Text('FRAME')),
            ],
          ),
        ),
      ],
    );
  }
}
