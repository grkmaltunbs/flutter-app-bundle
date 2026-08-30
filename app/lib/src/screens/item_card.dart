import 'package:flutter/material.dart' hide Step, StepState;
import 'package:flutter_kit/kit.dart';

import '../draft.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// One thing for the person to do. The card carries the runbook — do /
/// expect / if it fails / how to verify — and the controls that go into
/// the draft: done, drop, an answer, a note. A decisive card wears amber:
/// closing it flips a step today.
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
    final longBody = !i.isOpen || i.body.length > 280 || i.runbook.length > 3;
    final border = drafted
        ? BorderSide(color: t.accent, width: 1.5)
        : widget.decisive
            ? BorderSide(color: t.warn.withValues(alpha: 0.45))
            : BorderSide(color: t.line);
    return Stack(
      children: [
        Container(
          width: double.infinity,
          decoration: BoxDecoration(color: t.surface, borderRadius: BorderRadius.circular(12), border: Border.fromBorderSide(border)),
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: widget.decisive
                        ? Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text('DECISIVE · UNBLOCKS ${blocks.map((s) => s.number ?? s.id).join(' + ')}'.toUpperCase(), maxLines: 2, overflow: TextOverflow.ellipsis, style: t.display(12, ls: 1.8, color: t.warn)),
                          )
                        : Wrap(spacing: 6, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
                            if (!i.isOpen)
                              Pill(i.status == ItemStatus.dropped ? 'not doing${i.doneAt != null ? ' · ${i.doneAt}' : ''}' : 'done${i.doneAt != null ? ' · ${i.doneAt}' : ''}',
                                  color: i.status == ItemStatus.dropped ? t.muted : t.good, icon: i.status == ItemStatus.dropped ? Icons.remove_circle_outline : Icons.check_circle),
                            if (i.isOpen && i.deadline != null) Pill('by ${i.deadline}', color: t.critical, icon: Icons.schedule),
                            for (final s in blocks) Pill('blocks ${s.number ?? s.id}', color: t.muted),
                          ]),
                  ),
                  const SizedBox(width: 8),
                  if (i.needs.isNotEmpty) Pill(widget.needs[i.needs.first]?.label ?? i.needs.first, color: widget.decisive ? t.warn : t.muted),
                ],
              ),
              const SizedBox(height: 8),
              Text(i.title, style: t.display(17, weight: FontWeight.w600, ls: 0.2, height: 1.2)),
              if (i.body.isNotEmpty || i.runbook.isNotEmpty) ...[
                const SizedBox(height: 8),
                AnimatedCrossFade(
                  duration: const Duration(milliseconds: 150),
                  crossFadeState: _open || !longBody ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                  firstChild: Text(_firstLine(i.body.isNotEmpty ? i.body : i.runbook.first.doText), maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, height: 1.45, color: t.ink2)),
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
                    style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 28), tapTargetSize: MaterialTapTargetSize.shrinkWrap, foregroundColor: t.muted),
                    onPressed: () => setState(() => _open = !_open),
                    child: Text(_open ? 'LESS' : 'SHOW THE STEPS'),
                  ),
              ],
              if (i.question != null) ...[
                const SizedBox(height: 8),
                Text(i.question!.ask.toUpperCase(), style: t.readout(11)),
                const SizedBox(height: 6),
                for (final o in _ordered(i.question!.options)) _Option(option: o, selected: (d?.answer ?? i.question!.answer) == o.label, onTap: () => _set((x) => x.answer = o.label)),
              ],
              if (i.note != null && i.note!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(i.note!, style: TextStyle(fontSize: 12.5, color: t.muted, fontStyle: FontStyle.italic)),
              ],
              Divider(height: 18, color: t.line),
              Row(
                children: i.isOpen
                    ? [
                        _Tick(label: 'DONE', value: d?.action == 'done', color: t.good, onChanged: (v) => _set((x) => x.action = v ? 'done' : null)),
                        const SizedBox(width: 12),
                        _Tick(label: 'NOT DOING', value: d?.action == 'drop', color: t.muted, onChanged: (v) => _set((x) => x.action = v ? 'drop' : null)),
                      ]
                    : [
                        _Tick(label: 'REOPEN', value: d?.action == 'reopen', color: t.warn, onChanged: (v) => _set((x) => x.action = v ? 'reopen' : null)),
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
        // The amber tab on a decisive card's spine.
        if (widget.decisive)
          Positioned(
            left: 0,
            top: 18,
            child: Container(width: 3, height: 28, decoration: BoxDecoration(color: t.warn, borderRadius: const BorderRadius.horizontal(right: Radius.circular(2)))),
          ),
      ],
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
            text: TextSpan(style: TextStyle(fontFamily: kBodyFont, fontSize: 12.5, color: t.ink2, height: 1.35), children: [
              TextSpan(text: '$label  ', style: t.readout(10.5, color: c, weight: FontWeight.w500)),
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
            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: t.accent.withValues(alpha: 0.45))),
            child: Text('$index', style: t.mono(10, color: t.accent, weight: FontWeight.w500, height: 1)),
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
      child: Container(
        constraints: const BoxConstraints(minHeight: 46),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        margin: const EdgeInsets.only(bottom: 6),
        decoration: BoxDecoration(
          color: selected ? t.accentSoft : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: selected ? t.accent.withValues(alpha: 0.45) : t.line),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(selected ? Icons.radio_button_checked : Icons.radio_button_off, size: 16, color: selected ? t.accent : t.muted),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(option.label, style: TextStyle(fontSize: 14, color: selected ? t.ink : t.ink2, fontWeight: selected ? FontWeight.w600 : FontWeight.w500)),
                  if (option.why != null) Text(option.why!, style: TextStyle(fontSize: 12, color: t.muted)),
                ],
              ),
            ),
            if (option.recommended) ...[
              const SizedBox(width: 6),
              Text('RECOMMENDED', style: t.readout(10, color: t.accent)),
            ],
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
          Text(label, style: t.display(13, weight: FontWeight.w600, ls: 1, color: value ? t.ink : t.ink2)),
        ]),
      ),
    );
  }
}
