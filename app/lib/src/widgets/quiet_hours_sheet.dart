import 'package:flutter/material.dart';
import 'package:flutter_kit/kit.dart';

import '../theme.dart';

/// The phone's quiet hours: a switch and a window. Every change goes to
/// the phone's row through [onSet] at once — the Mac reads it from there
/// and holds "Turn ended" and problems for one digest at the window's
/// end. Asks, and a session that died, come through regardless.
Future<void> showQuietHoursSheet(BuildContext context, {required QuietWindow? current, required Future<void> Function(QuietWindow? window) onSet, bool registered = true}) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => QuietHoursSheet(current: current, onSet: onSet, registered: registered),
    );

class QuietHoursSheet extends StatefulWidget {
  const QuietHoursSheet({super.key, required this.current, required this.onSet, this.registered = true, this.offsetMinutes});
  final QuietWindow? current;
  final Future<void> Function(QuietWindow? window) onSet;

  /// Notifications are set up on this phone — without a row there is
  /// nothing to write the window to.
  final bool registered;

  /// The phone's clock against UTC; the device's own when null.
  final int? offsetMinutes;

  @override
  State<QuietHoursSheet> createState() => _QuietHoursSheetState();
}

class _QuietHoursSheetState extends State<QuietHoursSheet> {
  late QuietWindow _w = widget.current ?? QuietWindow(on: false, start: QuietWindow.defaultStart, end: QuietWindow.defaultEnd, offset: _offset);
  String? _error;
  bool _busy = false;

  int get _offset => widget.offsetMinutes ?? DateTime.now().timeZoneOffset.inMinutes;

  Future<void> _set(QuietWindow w) async {
    final next = w.copyWith(offset: _offset);
    setState(() {
      _w = next;
      _busy = true;
      _error = null;
    });
    try {
      await widget.onSet(next);
    } on Object catch (e) {
      _error = 'Could not save: $e';
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _pick({required bool start}) async {
    final minutes = start ? _w.start : _w.end;
    final t = await showTimePicker(context: context, initialTime: TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60), helpText: start ? 'QUIET FROM' : 'QUIET UNTIL');
    if (t == null || !mounted) return;
    final m = t.hour * 60 + t.minute;
    await _set(start ? _w.copyWith(start: m) : _w.copyWith(end: m));
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final bottom = MediaQuery.viewInsetsOf(context).bottom + MediaQuery.paddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 4, 20, 20 + bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('QUIET HOURS', style: t.display(15, ls: 2.4)),
            const SizedBox(height: 8),
            Text(
              'In the window, "Turn ended" and problems wait on the Mac and arrive as one line at its end — "While you slept · 3 turns ended". Claude\'s asks, and a session that died, come through regardless.',
              style: TextStyle(fontSize: 13, color: t.ink2, height: 1.35),
            ),
            if (!widget.registered) ...[
              const SizedBox(height: 12),
              Text('Notifications are not set up on this phone yet — allow them from the bell first.', style: TextStyle(fontSize: 13, color: t.warn)),
            ],
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _w.on,
              onChanged: widget.registered && !_busy ? (v) => _set(_w.copyWith(on: v)) : null,
              title: Text(_w.on ? 'On · ${_w.label}' : 'Off', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              subtitle: Text('This phone\'s clock (UTC${_offset >= 0 ? '+' : '−'}${QuietWindow.hm(_offset.abs())}).', style: t.readout(10)),
            ),
            Row(
              children: [
                Expanded(child: _TimeButton(label: 'FROM', value: QuietWindow.hm(_w.start), enabled: widget.registered && !_busy, onTap: () => _pick(start: true))),
                const SizedBox(width: 10),
                Expanded(child: _TimeButton(label: 'UNTIL', value: QuietWindow.hm(_w.end), enabled: widget.registered && !_busy, onTap: () => _pick(start: false))),
              ],
            ),
            if (_error != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(_error!, style: TextStyle(fontSize: 12.5, color: t.critical))),
            const SizedBox(height: 14),
            Align(alignment: Alignment.centerRight, child: TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('DONE'))),
          ],
        ),
      ),
    );
  }
}

class _TimeButton extends StatelessWidget {
  const _TimeButton({required this.label, required this.value, required this.enabled, required this.onTap});
  final String label;
  final String value;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return OutlinedButton(
      onPressed: enabled ? onTap : null,
      style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: t.readout(10)),
          const SizedBox(height: 2),
          Text(value, style: t.mono(18, color: enabled ? t.ink : t.muted)),
        ],
      ),
    );
  }
}
