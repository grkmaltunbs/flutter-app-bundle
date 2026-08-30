import 'package:flutter/material.dart' hide Step, StepState;
import 'package:flutter_kit/kit.dart';

import '../theme.dart';

/// What Claude is asking, on whichever screen is looking. A permission
/// shows the command with Allow · This session · Always · Deny; a question
/// shows its options and takes one answer per question. [here] names the
/// surface in the denial the model reads.
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
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: t.warn.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12), border: Border.all(color: t.warn.withValues(alpha: 0.6))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(children: [
            Expanded(child: Text(ask.isQuestion ? 'CLAUDE ASKS' : 'AUTHORIZATION REQUESTED', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.2, color: t.warn))),
            Text(ask.isQuestion ? 'question' : ask.toolName, style: TextStyle(fontSize: 11, color: t.muted)),
          ]),
          const SizedBox(height: 8),
          if (ask.isQuestion) ...[
            for (final q in ask.questions) ...[
              if (q.header.isNotEmpty) Text(q.header.toUpperCase(), style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, letterSpacing: 1, color: t.muted)),
              Text(q.question, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: t.ink)),
              const SizedBox(height: 6),
              for (final o in q.options) _option(context, q, o),
              const SizedBox(height: 8),
            ],
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: _complete
                    ? () => widget.onAnswer(AskAnswer.answers(ask, {for (final q in ask.questions) q.question: (_picked[q.question] ?? const {}).join(', ')}))
                    : null,
                child: const Text('Answer'),
              ),
            ),
          ] else ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(color: t.bg, borderRadius: BorderRadius.circular(8), border: Border.all(color: t.line)),
              child: SelectableText(ask.summary, style: TextStyle(fontFamily: 'menlo', fontSize: 12.5, height: 1.4, color: t.ink)),
            ),
            if ((ask.description ?? '').isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text(ask.description!, style: TextStyle(fontSize: 13, color: t.ink2))),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  height: 44,
                  child: FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: t.warn, foregroundColor: const Color(0xFF1A1206)),
                    onPressed: () => widget.onAnswer(AskAnswer.allow(ask)),
                    child: const Text('Allow'),
                  ),
                ),
                SizedBox(
                  height: 44,
                  child: OutlinedButton(onPressed: () => widget.onAnswer(AskAnswer.allow(ask), remember: true), child: const Text('This session')),
                ),
                if (ask.suggestions.isNotEmpty)
                  SizedBox(
                    height: 44,
                    child: OutlinedButton(onPressed: () => widget.onAnswer(AskAnswer.always(ask)), child: const Text('Always')),
                  ),
                SizedBox(
                  height: 44,
                  child: TextButton(onPressed: () => widget.onAnswer(AskAnswer.deny('The user declined from the ${widget.here}.')), child: const Text('Deny')),
                ),
              ],
            ),
          ],
        ],
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
        constraints: const BoxConstraints(minHeight: 44),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        margin: const EdgeInsets.only(bottom: 6),
        decoration: BoxDecoration(color: on ? t.accentSoft : t.surface, borderRadius: BorderRadius.circular(8), border: Border.all(color: on ? t.accent : t.line)),
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
                  Text(o.label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: t.ink)),
                  if (o.description.isNotEmpty) Text(o.description, style: TextStyle(fontSize: 12.5, color: t.ink2)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
