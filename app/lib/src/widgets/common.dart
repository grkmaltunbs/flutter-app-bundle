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

class Pill extends StatelessWidget {
  const Pill(this.text, {super.key, required this.color, this.filled = false, this.icon});
  final String text;
  final Color color;
  final bool filled;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: filled ? color : color.withValues(alpha: t.brightness == Brightness.light ? 0.10 : 0.18),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 12, color: filled ? Colors.white : color), const SizedBox(width: 4)],
          // Loose, so a long label shrinks instead of overflowing — a Row
          // with mainAxisSize.min is only as small as its children insist on.
          Flexible(child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: filled ? Colors.white : color, letterSpacing: 0.2))),
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
  const SectionHead(this.title, {super.key, this.sub});
  final String title;
  final String? sub;
  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title.toUpperCase(), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.1, color: t.muted)),
          if (sub != null) Padding(padding: const EdgeInsets.only(top: 2), child: Text(sub!, style: TextStyle(fontSize: 12.5, color: t.ink2))),
        ],
      ),
    );
  }
}

class Md extends StatelessWidget {
  const Md(this.data, {super.key, this.compact = false});
  final String data;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final base = Theme.of(context).textTheme.bodyMedium!.copyWith(fontSize: compact ? 13 : 14, height: 1.45, color: t.ink2);
    return MarkdownBody(
      data: data,
      selectable: true,
      styleSheet: MarkdownStyleSheet(
        p: base,
        listBullet: base,
        code: base.copyWith(fontFamily: 'menlo', fontSize: (compact ? 12 : 13), backgroundColor: t.accentSoft.withValues(alpha: 0.5)),
        codeblockDecoration: BoxDecoration(color: t.bg, borderRadius: BorderRadius.circular(8), border: Border.all(color: t.line)),
        codeblockPadding: const EdgeInsets.all(10),
        h1: base.copyWith(fontSize: 18, fontWeight: FontWeight.w700, color: t.ink),
        h2: base.copyWith(fontSize: 16, fontWeight: FontWeight.w700, color: t.ink),
        h3: base.copyWith(fontSize: 14.5, fontWeight: FontWeight.w700, color: t.ink),
        h4: base.copyWith(fontWeight: FontWeight.w700, color: t.ink),
        strong: base.copyWith(fontWeight: FontWeight.w700, color: t.ink),
        blockquoteDecoration: BoxDecoration(border: Border(left: BorderSide(color: t.line, width: 3))),
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
