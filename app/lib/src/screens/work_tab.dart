import 'package:flutter/material.dart' hide Step, StepState;
import 'package:flutter_kit/kit.dart';

import '../draft.dart';
import '../relay.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'item_card.dart';

/// Your work: open items grouped by what they need from you — one sitting
/// at a console, one with the phone in hand, one with your ears. The chips
/// filter to one sitting; DONE is the record of what you decided, and
/// where a tick sent by mistake is undone.
class WorkTab extends StatefulWidget {
  const WorkTab({super.key, required this.plan, required this.graph, required this.draft, this.initialDone = false, this.threads, this.onAskItem});
  final Plan plan;
  final Graph graph;
  final Draft draft;
  final bool initialDone;
  final ThreadStore? threads;
  final void Function(Item item)? onAskItem;

  @override
  State<WorkTab> createState() => _WorkTabState();
}

const _done = '__done';

class _WorkTabState extends State<WorkTab> {
  late String? _filter = widget.initialDone ? _done : null;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final plan = widget.plan;
    final graph = widget.graph;
    final draft = widget.draft;
    final needs = plan.manifest.needs;
    final open = plan.items.where((i) => i.isOpen).length;
    final decisive = graph.decisiveItemIds();
    final closed = [for (final i in plan.items) if (!i.isOpen) i]
      ..sort((a, b) {
        final d = (b.doneAt ?? '').compareTo(a.doneAt ?? '');
        return d != 0 ? d : a.title.compareTo(b.title);
      });
    final sittings = graph.sittings();
    final order = [...needs.keys.where(sittings.containsKey), ...sittings.keys.where((k) => !needs.containsKey(k))];

    final sub = open == 0
        ? 'NOTHING WAITS ON YOU'
        : decisive.isEmpty
            ? '$open OPEN'
            : '${decisive.length} WOULD FLIP A STEP TODAY';

    final rows = <Widget>[
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('YOUR WORK', style: t.display(22, ls: 3.2)),
            const SizedBox(height: 4),
            Text(sub, style: t.readout(11, color: decisive.isEmpty || open == 0 ? t.muted : t.warn)),
          ],
        ),
      ),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        child: Row(
          children: [
            for (final key in order) ...[
              _chip(t, label: (needs[key]?.label ?? key), count: sittings[key]?.length ?? 0, selected: _filter == key, onTap: () => setState(() => _filter = _filter == key ? null : key)),
              const SizedBox(width: 8),
            ],
            _chip(t, label: 'done', count: closed.length, selected: _filter == _done, onTap: () => setState(() => _filter = _filter == _done ? null : _done)),
          ],
        ),
      ),
    ];

    if (_filter == _done) {
      if (closed.isEmpty) return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [...rows, const EmptyNote('Nothing closed yet.')]);
      rows.add(Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
        child: Text('Newest first. Reopen sends the item back to your list; an answer can be changed here.', style: TextStyle(fontSize: 12.5, color: t.muted)),
      ));
      for (final item in closed) {
        rows.add(Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: ItemCard(item: item, plan: plan, graph: graph, draft: draft, needs: needs, decisive: false, thread: widget.threads?.forItem(item.id), onAsk: widget.onAskItem == null ? null : () => widget.onAskItem!(item)),
        ));
      }
    } else {
      if (sittings.isEmpty) return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [...rows, const EmptyNote('Nothing is waiting on you.')]);
      for (final key in order) {
        if (_filter != null && _filter != key) continue;
        final items = sittings[key];
        if (items == null || items.isEmpty) continue;
        final kind = needs[key];
        rows.add(Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text((kind?.label ?? key).toUpperCase(), style: t.readout(11, weight: FontWeight.w500)),
              if (kind != null && kind.description.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 3), child: Text(kind.description, style: TextStyle(fontSize: 12.5, color: t.muted))),
            ],
          ),
        ));
        for (final i in items) {
          rows.add(Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: ItemCard(item: i, plan: plan, graph: graph, draft: draft, needs: needs, decisive: decisive.contains(i.id), thread: widget.threads?.forItem(i.id), onAsk: widget.onAskItem == null ? null : () => widget.onAskItem!(i)),
          ));
        }
      }
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: rows.length,
      itemBuilder: (_, i) => rows[i],
    );
  }

  Widget _chip(KitTokens t, {required String label, required int count, required bool selected, required VoidCallback onTap}) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: selected ? t.accentSoft : Colors.transparent,
          border: Border.all(color: selected ? t.accent.withValues(alpha: 0.38) : t.line),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(label.toUpperCase(), style: t.mono(12, color: selected ? t.accent : t.ink2, ls: 0.5)),
          const SizedBox(width: 6),
          Text('$count', style: t.mono(12, color: t.muted)),
        ]),
      ),
    );
  }
}
