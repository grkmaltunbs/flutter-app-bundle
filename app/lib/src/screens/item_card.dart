import 'package:flutter/material.dart' hide Step, StepState;
import 'package:flutter_kit/kit.dart';

import '../draft.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// One thing for the person to do. The card carries the runbook — do /
/// expect / if it fails / how to verify — and the controls that go into
/// the draft: done, drop, an answer, a note.
class ItemCard extends StatefulWidget {
  const ItemCard({super.key, required this.item, required this.plan, required this.graph, required this.draft, required this.needs, required this.decisive});
  final Item item;
  final Plan plan;
  final Graph graph;
  final Draft draft;
  final Map<String, NeedKind> needs;
  final bool decisive;

  @override
  State<ItemCard> createState() => _ItemCardState();
}

class _ItemCardState extends State<ItemCard> {
  bool _open = false;
  late final _note = TextEditingController(text: widget.draft.items[widget.item.id]?.note ?? '');

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  ItemDraft get _d => widget.draft.item(widget.item.id);

  void _set(void Function(ItemDraft d) f) {
    f(_d);
    widget.draft.save();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final i = widget.item;
    final d = widget.draft.items[i.id];
    final drafted = d != null && !d.isEmpty;
    final blocks = [for (final id in i.blocks) widget.plan.step(id)].whereType<Step>().toList();
    final longBody = i.body.length > 280 || i.runbook.length > 3;
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: drafted ? t.accent : t.line, width: drafted ? 1.5 : 1)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(spacing: 6, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
              if (i.deadline != null) Pill('by ${i.deadline}', color: t.critical, icon: Icons.schedule),
              if (widget.decisive) Pill('flips ${blocks.map((s) => s.number ?? s.id).join(', ')}', color: t.warn, icon: Icons.bolt),
              for (final n in i.needs) Pill(widget.needs[n]?.label ?? n, color: t.muted),
              if (!widget.decisive) for (final s in blocks) Pill('blocks ${s.number ?? s.id}', color: t.muted),
            ]),
            const SizedBox(height: 8),
            Text(i.title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: t.ink, height: 1.2)),
            if (i.body.isNotEmpty || i.runbook.isNotEmpty) ...[
              const SizedBox(height: 8),
              AnimatedCrossFade(
                duration: const Duration(milliseconds: 150),
                crossFadeState: _open || !longBody ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                firstChild: Text(_firstLine(i.body.isNotEmpty ? i.body : i.runbook.first.doText), maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, color: t.ink2)),
                secondChild: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (i.body.isNotEmpty) Md(i.body, compact: true),
                    if (i.runbook.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      for (var k = 0; k < i.runbook.length; k++) _RunbookRow(index: k + 1, line: i.runbook[k]),
                    ],
                  ],
                ),
              ),
              if (longBody)
                TextButton(
                  style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 28), tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                  onPressed: () => setState(() => _open = !_open),
                  child: Text(_open ? 'Less' : 'Show the steps'),
                ),
            ],
            if (i.question != null) ...[
              const SizedBox(height: 8),
              Text(i.question!.ask, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: t.ink)),
              const SizedBox(height: 4),
              for (final o in _ordered(i.question!.options)) _Option(option: o, selected: (d?.answer ?? i.question!.answer) == o.label, onTap: () => _set((x) => x.answer = o.label)),
            ],
            Divider(height: 18, color: t.line),
            Row(
              children: [
                _Tick(label: 'Done', value: d?.action == 'done', color: t.good, onChanged: (v) => _set((x) => x.action = v ? 'done' : null)),
                const SizedBox(width: 12),
                _Tick(label: 'Not doing', value: d?.action == 'drop', color: t.muted, onChanged: (v) => _set((x) => x.action = v ? 'drop' : null)),
              ],
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _note,
              minLines: 1,
              maxLines: 3,
              style: const TextStyle(fontSize: 13),
              decoration: const InputDecoration(hintText: 'Note to Claude (optional)', contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
              onChanged: (v) => _set((x) => x.note = v),
            ),
          ],
        ),
      ),
    );
  }

  static String _firstLine(String s) => s.split('\n').firstWhere((l) => l.trim().isNotEmpty, orElse: () => '').replaceAll(RegExp(r'[*_`#>]'), '');

  static List<QuestionOption> _ordered(List<QuestionOption> options) => [...options.where((o) => o.recommended), ...options.where((o) => !o.recommended)];
}

class _RunbookRow extends StatelessWidget {
  const _RunbookRow({required this.index, required this.line});
  final int index;
  final RunbookLine line;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    Widget sub(String label, String text, Color c) => Padding(
          padding: const EdgeInsets.only(top: 3),
          child: RichText(
            text: TextSpan(style: TextStyle(fontSize: 12.5, color: t.ink2, height: 1.35), children: [
              TextSpan(text: '$label  ', style: TextStyle(fontWeight: FontWeight.w700, color: c, fontSize: 11, letterSpacing: 0.6)),
              TextSpan(text: text),
            ]),
          ),
        );
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 20,
            height: 20,
            margin: const EdgeInsets.only(right: 8, top: 1),
            alignment: Alignment.center,
            decoration: BoxDecoration(shape: BoxShape.circle, color: t.accentSoft),
            child: Text('$index', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: t.accent)),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Md(line.doText, compact: true),
                if (line.expect != null) sub('EXPECT', line.expect!, t.good),
                if (line.ifFails != null) sub('IF NOT', line.ifFails!, t.critical),
                if (line.verify != null) sub('VERIFY', line.verify!, t.muted),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Option extends StatelessWidget {
  const _Option({required this.option, required this.selected, required this.onTap});
  final QuestionOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(selected ? Icons.radio_button_checked : Icons.radio_button_off, size: 18, color: selected ? t.accent : t.muted),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Flexible(child: Text(option.label, style: TextStyle(fontSize: 13.5, color: t.ink, fontWeight: selected ? FontWeight.w700 : FontWeight.w500))),
                    if (option.recommended) ...[const SizedBox(width: 6), Pill('recommended', color: t.accent)],
                  ]),
                  if (option.why != null) Text(option.why!, style: TextStyle(fontSize: 12, color: t.muted)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Tick extends StatelessWidget {
  const _Tick({required this.label, required this.value, required this.color, required this.onChanged});
  final String label;
  final bool value;
  final Color color;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(value ? Icons.check_box : Icons.check_box_outline_blank, size: 20, color: value ? color : t.muted),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 13.5, color: value ? t.ink : t.ink2, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }
}
