import 'package:flutter/material.dart' hide Step, StepState;
import 'package:flutter_kit/kit.dart';

import '../draft.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'item_card.dart';

/// Your work: open items grouped by what they need from you — one sitting
/// at a console, one with the phone in hand, one with your ears.
class WorkTab extends StatelessWidget {
  const WorkTab({super.key, required this.plan, required this.graph, required this.draft});
  final Plan plan;
  final Graph graph;
  final Draft draft;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final sittings = graph.sittings();
    final needs = plan.manifest.needs;
    final decisive = graph.decisiveItemIds();
    if (sittings.isEmpty) return const EmptyNote('Nothing is waiting on you.');
    final rows = <Widget>[];
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
