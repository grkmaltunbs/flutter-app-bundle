import 'package:flutter/material.dart' hide Step, StepState;
import 'package:flutter_kit/kit.dart';

import '../draft.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'item_card.dart';

/// Your work: open items grouped by what they need from you — one sitting
/// at a console, one with the phone in hand, one with your ears. The Done
/// list is the record of what you decided, and where a tick sent by
/// mistake is undone.
class WorkTab extends StatefulWidget {
  const WorkTab({super.key, required this.plan, required this.graph, required this.draft, this.initialDone = false});
  final Plan plan;
  final Graph graph;
  final Draft draft;
  final bool initialDone;

  @override
  State<WorkTab> createState() => _WorkTabState();
}

class _WorkTabState extends State<WorkTab> {
  late bool _done = widget.initialDone;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final plan = widget.plan;
    final graph = widget.graph;
    final draft = widget.draft;
    final needs = plan.manifest.needs;
    final open = plan.items.where((i) => i.isOpen).length;
    final closed = [for (final i in plan.items) if (!i.isOpen) i]
      ..sort((a, b) {
        final d = (b.doneAt ?? '').compareTo(a.doneAt ?? '');
        return d != 0 ? d : a.title.compareTo(b.title);
      });
    final toggle = Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: SegmentedButton<bool>(
        segments: [
          ButtonSegment(value: false, label: Text('To do · $open')),
          ButtonSegment(value: true, label: Text('Done · ${closed.length}')),
        ],
        selected: {_done},
        showSelectedIcon: false,
        onSelectionChanged: (v) => setState(() => _done = v.first),
      ),
    );
    if (_done) {
      if (closed.isEmpty) return Column(children: [toggle, const EmptyNote('Nothing closed yet.')]);
      return ListView.builder(
        padding: const EdgeInsets.only(bottom: 24),
        itemCount: closed.length + 2,
        itemBuilder: (_, i) {
          if (i == 0) return toggle;
          if (i == 1) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: Text('Newest first. Reopen sends the item back to your list; an answer can be changed here.', style: TextStyle(fontSize: 12.5, color: t.muted)),
            );
          }
          final item = closed[i - 2];
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: ItemCard(item: item, plan: plan, graph: graph, draft: draft, needs: needs, decisive: false),
          );
        },
      );
    }
    final sittings = graph.sittings();
    final decisive = graph.decisiveItemIds();
    if (sittings.isEmpty) return Column(children: [toggle, const EmptyNote('Nothing is waiting on you.')]);
    final rows = <Widget>[toggle];
    final order = [...needs.keys, ...sittings.keys.where((k) => !needs.containsKey(k))];
    for (final key in order) {
      final items = sittings[key];
      if (items == null || items.isEmpty) continue;
      final kind = needs[key];
      rows.add(Padding(
        padding: const EdgeInsets.fromLTRB(16, 22, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(child: Text(kind?.label ?? key, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: t.ink))),
              Pill('${items.length}', color: t.muted),
            ]),
            if (kind != null) Padding(padding: const EdgeInsets.only(top: 2), child: Text(kind.description, style: TextStyle(fontSize: 12.5, color: t.muted))),
          ],
        ),
      ));
      for (final i in items) {
        rows.add(Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: ItemCard(item: i, plan: plan, graph: graph, draft: draft, needs: needs, decisive: decisive.contains(i.id)),
        ));
      }
    }
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: rows.length,
      itemBuilder: (_, i) => rows[i],
    );
  }
}
