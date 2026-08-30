import 'package:flutter/material.dart' hide Step, StepState;
import 'package:flutter_kit/kit.dart';

import '../theme.dart';
import '../widgets/common.dart';

/// What Claude is asking, on whichever screen is looking — the amber card
/// with the corner ticks. A permission shows the command with
/// ALLOW · THIS SESSION · ALWAYS · DENY; a question shows its options and
/// takes one answer per question. [here] names the surface in the denial
/// the model reads.
class AskCard extends StatefulWidget {
  const AskCard({super.key, required this.ask, required this.onAnswer, this.here = 'Mac'});
  final Ask ask;
  final void Function(AskAnswer answer, {bool remember}) onAnswer;
  final String here;

  @override
  State<AskCard> createState() => _AskCardState();
}

class _AskCardState extends State<AskCard> {
  final Map<String, Set<String>> _picked = {};

  bool get _complete => widget.ask.questions.every((q) => (_picked[q.question] ?? const {}).isNotEmpty);

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final ask = widget.ask;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: CornerTicks(
        color: t.warn,
        radius: 12,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: t.warnSoft,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: t.warn.withValues(alpha: 0.45)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(children: [
                Expanded(child: Text(ask.isQuestion ? 'CLAUDE ASKS' : 'AUTHORIZATION REQUESTED', style: t.display(13, ls: 2.3, color: t.warn))),
                Text((ask.isQuestion ? 'question' : ask.toolName).toUpperCase(), style: t.readout(11)),
              ]),
              const SizedBox(height: 10),
              if (ask.isQuestion) ...[
                for (final q in ask.questions) ...[
                  if (q.header.isNotEmpty) ...[
                    Text(q.header.toUpperCase(), style: t.readout(10.5)),
                    const SizedBox(height: 3),
                  ],
                  Text(q.question, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: t.ink)),
                  const SizedBox(height: 8),
                  for (final o in q.options) _option(context, q, o),
                  const SizedBox(height: 6),
                ],
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton(
                    onPressed: _complete
                        ? () => widget.onAnswer(AskAnswer.answers(ask, {for (final q in ask.questions) q.question: (_picked[q.question] ?? const {}).join(', ')}))
                        : null,
                    child: const Text('ANSWER'),
                  ),
                ),
              ] else ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(color: t.bg, borderRadius: BorderRadius.circular(8), border: Border.all(color: t.line)),
                  child: SelectableText(ask.summary, style: t.mono(13, color: t.ink, height: 1.5)),
                ),
                if ((ask.description ?? '').isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text(ask.description!, style: TextStyle(fontSize: 13.5, height: 1.45, color: t.ink2))),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: t.warn, foregroundColor: t.onWarn, minimumSize: const Size(120, 44)),
                      onPressed: () => widget.onAnswer(AskAnswer.allow(ask)),
                      child: const Text('ALLOW'),
                    ),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(foregroundColor: t.warn, side: BorderSide(color: t.warn.withValues(alpha: 0.55))),
                      onPressed: () => widget.onAnswer(AskAnswer.allow(ask), remember: true),
                      child: const Text('THIS SESSION'),
                    ),
                    if (ask.suggestions.isNotEmpty)
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(foregroundColor: t.warn, side: BorderSide(color: t.warn.withValues(alpha: 0.55))),
                        onPressed: () => widget.onAnswer(AskAnswer.always(ask)),
                        child: const Text('ALWAYS'),
                      ),
                    TextButton(onPressed: () => widget.onAnswer(AskAnswer.deny('The user declined from the ${widget.here}.')), child: const Text('DENY')),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _option(BuildContext context, AskQuestion q, AskOption o) {
    final t = context.tokens;
    final set = _picked[q.question] ?? <String>{};
    final on = set.contains(o.label);
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => setState(() {
        final s = _picked.putIfAbsent(q.question, () => <String>{});
        if (q.multiSelect) {
          on ? s.remove(o.label) : s.add(o.label);
        } else {
          s
            ..clear()
            ..add(o.label);
        }
      }),
      child: Container(
        constraints: const BoxConstraints(minHeight: 46),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        margin: const EdgeInsets.only(bottom: 6),
        decoration: BoxDecoration(
          color: on ? t.accentSoft : t.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: on ? t.accent.withValues(alpha: 0.55) : t.line),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(q.multiSelect ? (on ? Icons.check_box : Icons.check_box_outline_blank) : (on ? Icons.radio_button_checked : Icons.radio_button_off), size: 18, color: on ? t.accent : t.muted),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(o.label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: on ? t.ink : t.ink2)),
                  if (o.description.isNotEmpty) Text(o.description, style: TextStyle(fontSize: 12.5, color: t.muted)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
