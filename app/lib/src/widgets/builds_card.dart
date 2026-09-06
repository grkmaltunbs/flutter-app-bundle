import 'package:flutter/material.dart' hide Step, StepState;
import 'package:flutter_kit/kit.dart';

import '../theme.dart';
import 'common.dart';

/// Try it: TRY IT, the build-on-flip switch, and the last three builds
/// as rows — version, sha, size, age; a bar while one builds; a tap on
/// a ready row installs it on this phone ([onInstall], with the
/// download's progress); a failed row opens its log ([onLog]).
/// [onAction] is the host's `build` command — `start`, `delete`,
/// `switch` — and returns the one line to toast.
class BuildsCard extends StatefulWidget {
  const BuildsCard({super.key, required this.builds, required this.buildOnFlip, required this.onAction, this.onInstall, this.onLog, this.now});
  final List<BuildRecord> builds;
  final bool buildOnFlip;
  final Future<String> Function(String action, {String? id, bool? on}) onAction;

  /// Downloads and opens the installer; says how far as it goes. Null on
  /// a Mac — there the row names the object.
  final Future<String> Function(BuildRecord b, void Function(double fraction) onProgress)? onInstall;
  final void Function(BuildRecord b)? onLog;
  final DateTime Function()? now;

  @override
  State<BuildsCard> createState() => _BuildsCardState();
}

class _BuildsCardState extends State<BuildsCard> {
  String? _busy;
  final Map<String, double> _downloading = {};

  Future<void> _run(String action, {String? id, bool? on}) async {
    setState(() => _busy = action);
    String line;
    try {
      line = await widget.onAction(action, id: id, on: on);
    } on Object catch (e) {
      line = 'Could not $action: $e';
    }
    if (!mounted) return;
    setState(() => _busy = null);
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(line)));
  }

  Future<void> _install(BuildRecord b) async {
    final install = widget.onInstall;
    if (install == null || _downloading.containsKey(b.id)) return;
    setState(() => _downloading[b.id] = 0);
    String line;
    try {
      line = await install(b, (f) {
        if (mounted) setState(() => _downloading[b.id] = f);
      });
    } on Object catch (e) {
      line = 'Could not install: $e';
    }
    if (!mounted) return;
    setState(() => _downloading.remove(b.id));
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(line)));
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final builds = widget.builds;
    final latest = builds.isEmpty ? null : builds.first;
    final building = latest?.building ?? false;
    final busy = _busy != null;
    final color = latest == null ? t.muted : latest.building ? t.accent : latest.failed ? t.critical : t.good;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(color: t.surface, borderRadius: BorderRadius.circular(10), border: Border.all(color: t.line)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              StatusGlyph(color: color, mode: building ? GlyphMode.busy : GlyphMode.idle, size: 12),
              const SizedBox(width: 8),
              Expanded(child: Text('BUILDS · ${latest == null ? 'NONE YET' : buildLine(latest, now: widget.now?.call()).toUpperCase()}', maxLines: 2, overflow: TextOverflow.ellipsis, style: t.readout(11, color: color))),
            ],
          ),
          if (building)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: LinearProgressIndicator(value: latest!.progress <= 0 ? null : latest.progress, minHeight: 3, backgroundColor: t.line, color: t.accent),
            ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              FilledButton.tonal(onPressed: busy || building ? null : () => _run('start'), child: Text(building ? 'BUILDING…' : _busy == 'start' ? 'STARTING…' : 'TRY IT')),
              Text('A debug build for the phone in your hand.', style: t.mono(11, color: t.muted)),
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
                      Text('BUILD ON FLIP', style: t.readout(10)),
                      Text('A step flipping to done or code complete builds on its own.', maxLines: 2, overflow: TextOverflow.ellipsis, style: t.mono(11, color: t.muted)),
                    ],
                  ),
                ),
                Switch(value: widget.buildOnFlip, onChanged: busy ? null : (v) => _run('switch', on: v)),
              ],
            ),
          ),
          for (final b in builds) _BuildRow(record: b, downloading: _downloading[b.id], now: widget.now, onInstall: widget.onInstall == null || !b.ready ? null : () => _install(b), onLog: widget.onLog == null ? null : () => widget.onLog!(b), onDelete: busy || b.building ? null : () => _run('delete', id: b.id)),
        ],
      ),
    );
  }
}

class _BuildRow extends StatelessWidget {
  const _BuildRow({required this.record, this.downloading, this.now, this.onInstall, this.onLog, this.onDelete});
  final BuildRecord record;
  final double? downloading;
  final DateTime Function()? now;
  final VoidCallback? onInstall;
  final VoidCallback? onLog;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final b = record;
    final color = b.building ? t.accent : b.failed ? t.critical : t.ink2;
    final head = [if (b.version.isNotEmpty) b.version, if (b.sha.isNotEmpty) b.sha, if (b.branch.isNotEmpty) b.branch, if (b.by != null) 'by ${b.by}'].join(' · ');
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: InkWell(
        onTap: onInstall,
        borderRadius: BorderRadius.circular(6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(head.isEmpty ? b.id : head, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.mono(11.5, color: color)),
            Text(buildLine(b, now: now?.call()).toUpperCase(), maxLines: 2, overflow: TextOverflow.ellipsis, style: t.readout(10, color: color)),
            if (downloading != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: LinearProgressIndicator(value: downloading! <= 0 ? null : downloading, minHeight: 3, backgroundColor: t.line, color: t.accent),
              ),
            if (b.failed && b.error != null) Padding(padding: const EdgeInsets.only(top: 2), child: Text(b.error!, maxLines: 2, overflow: TextOverflow.ellipsis, style: t.mono(11, color: t.critical))),
            Wrap(
              spacing: 4,
              children: [
                if (onInstall != null) TextButton(onPressed: onInstall, child: Text(downloading == null ? 'INSTALL' : 'DOWNLOADING · ${((downloading ?? 0) * 100).round()} %')),
                if (onLog != null && b.log.isNotEmpty) TextButton(onPressed: onLog, child: const Text('LOG')),
                if (onDelete != null) TextButton(onPressed: onDelete, child: Text('REMOVE', style: TextStyle(color: t.muted))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
