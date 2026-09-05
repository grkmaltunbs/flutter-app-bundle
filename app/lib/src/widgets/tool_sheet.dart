import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart' hide Step, StepState;
import 'package:flutter_kit/kit.dart';

import '../theme.dart';
import 'common.dart';
import 'diff_view.dart';

/// A tool row, opened: the whole input and the whole result in the mono
/// face (the result up to 24 KB, then a note that the Mac has the rest),
/// the diff when there is one, and the file behind a path. Copy is the
/// selection's.
Future<void> showToolSheet(BuildContext context, DeckMessage m, {VoidCallback? onOpen, Future<void> Function()? onRevert}) {
  final t = context.tokens;
  final input = m.toolInput ?? const {};
  final name = toolLabel(m.toolName ?? '');
  final inputText = name == 'Bash' ? (input['command'] ?? '').toString() : prettyInput(input);
  final result = m.fullResult;
  final path = m.path;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: t.surface,
    builder: (sheet) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.96,
      builder: (context, ctrl) => SelectionArea(
        child: ListView(
          controller: ctrl,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            Row(children: [
              Expanded(
                child: InkWell(
                  onTap: onOpen == null
                      ? null
                      : () {
                          Navigator.of(sheet).pop();
                          onOpen();
                        },
                  child: Text(path ?? m.toolSummary, maxLines: 3, overflow: TextOverflow.ellipsis, style: t.mono(12.5, color: onOpen == null ? t.ink2 : t.accent)),
                ),
              ),
              if (onRevert != null && path != null)
                TextButton(
                  onPressed: () async {
                    final ok = await confirmRevert(context, path);
                    if (!ok) return;
                    await onRevert();
                    if (sheet.mounted) Navigator.of(sheet).pop();
                  },
                  child: const Text('REVERT FILE'),
                ),
            ]),
            const SizedBox(height: 10),
            if (m.diff != null) ...[
              const SheetHead('Diff'),
              DiffView(m.diff!),
              const SizedBox(height: 12),
            ],
            SheetHead('Input · $name'),
            MonoBlock(inputText.isEmpty ? '—' : inputText),
            const SizedBox(height: 12),
            SheetHead(m.running ? 'Result · running' : m.isError ? 'Result · error' : 'Result'),
            MonoBlock(result == null || result.trim().isEmpty ? '—' : result, error: m.isError),
            if (m.toolOutputCut)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text('Cut at ${toolOutputLimit ~/ 1024} KB — the rest is on the Mac.', style: t.mono(11, color: t.muted)),
              ),
          ],
        ),
      ),
    ),
  );
}

/// A tool's input as the sheet prints it: indented JSON, bounded like a
/// result.
String prettyInput(Map<String, Object?> input) {
  final s = const JsonEncoder.withIndent('  ').convert(input);
  return s.length <= toolOutputLimit ? s : '${s.substring(0, toolOutputLimit - 1)}…';
}

/// A small caption over a block of the sheet.
class SheetHead extends StatelessWidget {
  const SheetHead(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(text.toUpperCase(), style: context.tokens.readout(10)));
}

/// Text in the mono face, in a box, wrapping — a command, its output, a
/// subagent's report.
class MonoBlock extends StatelessWidget {
  const MonoBlock(this.text, {super.key, this.error = false});
  final String text;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: t.bg, borderRadius: BorderRadius.circular(8), border: Border.all(color: t.line)),
      child: Text(text, style: t.mono(11.5, color: error ? t.critical : t.ink2)),
    );
  }
}

/// The crew: one chip per subagent of the turn — its kind and description,
/// a pulse and a running clock while it works, dim with the time it took
/// once done. Wraps; a tap opens the member.
class CrewStrip extends StatefulWidget {
  const CrewStrip({super.key, required this.crew, required this.onTap});
  final List<CrewMember> crew;
  final void Function(CrewMember member) onTap;

  @override
  State<CrewStrip> createState() => _CrewStripState();
}

class _CrewStripState extends State<CrewStrip> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _arm();
  }

  @override
  void didUpdateWidget(CrewStrip old) {
    super.didUpdateWidget(old);
    _arm();
  }

  /// The clocks tick only while someone runs.
  void _arm() {
    final running = widget.crew.any((c) => c.running);
    if (running && _tick == null) {
      _tick = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    } else if (!running) {
      _tick?.cancel();
      _tick = null;
    }
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [for (final c in widget.crew) CrewChip(member: c, now: now, onTap: () => widget.onTap(c))],
    );
  }
}

class CrewChip extends StatelessWidget {
  const CrewChip({super.key, required this.member, required this.now, required this.onTap});
  final CrewMember member;
  final DateTime now;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final c = member;
    final color = c.failed ? t.critical : c.running ? t.accent : t.muted;
    // The clock grows with the text only so far; the description gives
    // way first — the chip never pushes its strip over.
    final clockScale = TextScaler.linear(MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.6));
    return Opacity(
      opacity: c.running || c.failed ? 1 : 0.7,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            color: c.running ? color.withValues(alpha: 0.10) : null,
            border: Border.all(color: color.withValues(alpha: c.running ? 0.6 : 0.4)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              StatusGlyph(color: color, mode: c.running ? GlyphMode.busy : GlyphMode.idle, size: 12),
              const SizedBox(width: 6),
              Flexible(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 190),
                  child: Text('${c.kind.toUpperCase()} · ${c.description}', maxLines: 1, overflow: TextOverflow.ellipsis, style: t.mono(11, color: c.running ? t.ink : t.ink2)),
                ),
              ),
              const SizedBox(width: 8),
              Text(clockLabel(c.elapsed(now)), textScaler: clockScale, maxLines: 1, style: t.readout(10, color: color)),
            ],
          ),
        ),
      ),
    );
  }
}
