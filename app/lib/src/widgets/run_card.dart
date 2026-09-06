import 'package:flutter/material.dart' hide Step, StepState;
import 'package:flutter_kit/kit.dart';

import '../theme.dart';
import 'common.dart';

/// The run bay's card: the state — Running · iPhone 17 Pro · 4 min, amber
/// once the app threw — the device picker, RUN · RELOAD · RESTART · STOP,
/// the log, and reload on edit. [onAction] is the host's `run` command
/// (`start`, `reload`, `restart`, `stop`, `devices`, `reload_on_edit`)
/// and returns the one line to toast; [onLog] opens the log sheet.
class RunCard extends StatefulWidget {
  const RunCard({super.key, required this.run, required this.onAction, this.onLog, this.now});
  final RunState run;
  final Future<String> Function(String action, {String? device, bool? on}) onAction;
  final VoidCallback? onLog;

  /// The clock, for a test.
  final DateTime Function()? now;

  @override
  State<RunCard> createState() => _RunCardState();
}

class _RunCardState extends State<RunCard> {
  String? _busy;

  /// The device picked for the next RUN; null is the plan's default.
  String? _device;

  Future<void> _run(String action, {String? device, bool? on}) async {
    setState(() => _busy = action);
    String line;
    try {
      line = await widget.onAction(action, device: device, on: on);
    } on Object catch (e) {
      line = 'Could not $action: $e';
    }
    if (!mounted) return;
    setState(() => _busy = null);
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(line)));
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final r = widget.run;
    final busy = _busy != null;
    final color = switch (r.phase) {
      RunPhase.running => r.exceptions > 0 ? t.warn : t.good,
      RunPhase.starting => t.accent,
      RunPhase.failed => t.critical,
      _ => t.muted,
    };
    final line = runLine(r, now: widget.now?.call()) ?? 'Idle';
    final devices = r.devices;
    // The picker: the plan's default first, then every device the host listed.
    final picked = _device != null && devices.any((d) => d.id == _device) ? _device : null;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(color: t.surface, borderRadius: BorderRadius.circular(10), border: Border.all(color: t.line)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              StatusGlyph(color: color, mode: r.phase == RunPhase.starting ? GlyphMode.busy : r.running ? GlyphMode.live : GlyphMode.idle, size: 12),
              const SizedBox(width: 8),
              Expanded(child: Text('RUN · ${line.toUpperCase()}', maxLines: 2, overflow: TextOverflow.ellipsis, style: t.readout(11, color: color))),
            ],
          ),
          if (r.lastError != null && r.exceptions > 0)
            Padding(padding: const EdgeInsets.only(top: 4), child: Text(r.lastError!, maxLines: 2, overflow: TextOverflow.ellipsis, style: t.mono(11.5, color: t.warn))),
          if (r.phase == RunPhase.failed && r.error != null && r.exceptions == 0)
            Padding(padding: const EdgeInsets.only(top: 4), child: Text(r.error!, maxLines: 2, overflow: TextOverflow.ellipsis, style: t.mono(11.5, color: t.critical))),
          if (!r.up)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                children: [
                  Expanded(
                    child: DropdownButton<String?>(
                      isExpanded: true,
                      isDense: true,
                      value: picked,
                      underline: const SizedBox.shrink(),
                      style: t.mono(12, color: t.ink),
                      items: [
                        DropdownMenuItem<String?>(value: null, child: Text('Default device', style: t.mono(12, color: t.ink2))),
                        for (final d in devices) DropdownMenuItem<String?>(value: d.id, child: Text('${d.name}${d.off ? ' (off)' : ''}', maxLines: 1, overflow: TextOverflow.ellipsis)),
                      ],
                      onChanged: busy ? null : (v) => setState(() => _device = v),
                    ),
                  ),
                  IconButton(
                    tooltip: 'List devices again',
                    visualDensity: VisualDensity.compact,
                    icon: Icon(Icons.refresh, size: 18, color: t.ink2),
                    onPressed: busy ? null : () => _run('devices'),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (!r.up) FilledButton.tonal(onPressed: busy ? null : () => _run('start', device: picked), child: Text(_busy == 'start' ? 'STARTING…' : 'RUN')),
              if (r.running) OutlinedButton(onPressed: busy ? null : () => _run('reload'), child: Text(_busy == 'reload' ? 'RELOADING…' : 'RELOAD')),
              if (r.running) OutlinedButton(onPressed: busy ? null : () => _run('restart'), child: Text(_busy == 'restart' ? 'RESTARTING…' : 'RESTART')),
              if (r.up) OutlinedButton(onPressed: busy ? null : () => _run('stop'), child: Text(_busy == 'stop' ? 'STOPPING…' : 'STOP')),
              if (widget.onLog != null && r.runId != null) TextButton(onPressed: widget.onLog, child: Text('LOG · ${r.lines}')),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('RELOAD ON EDIT', style: t.readout(10)),
                      Text('A save under lib/ hot-reloads the running app.', maxLines: 2, overflow: TextOverflow.ellipsis, style: t.mono(11, color: t.muted)),
                    ],
                  ),
                ),
                Switch(value: r.reloadOnEdit, onChanged: busy ? null : (v) => _run('reload_on_edit', on: v)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
