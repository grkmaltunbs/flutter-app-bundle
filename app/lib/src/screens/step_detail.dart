import 'package:flutter/material.dart' hide Step, StepState;
import 'package:flutter_kit/kit.dart';

import '../draft.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'item_card.dart';

/// What a bubble opens: where the step sits, what stands in its way, what
/// the person should do about it (as runbooks), and the step's own spec.
class StepDetail extends StatelessWidget {
  const StepDetail({super.key, required this.plan, required this.graph, required this.step, required this.draft, required this.onSelectStep, this.controller});
  final Plan plan;
  final Graph graph;
  final Step step;
  final Draft draft;
  final void Function(String id) onSelectStep;
  final ScrollController? controller;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final v = graph.view(step);
    final unlocks = [for (final s in plan.steps) if (s.dependsOn.contains(step.id)) s];
    final deps = [for (final d in step.dependsOn) plan.step(d)].whereType<Step>().toList();
    final decisive = graph.decisiveItemIds();
    final needs = plan.manifest.needs;
    final itemsFrom = [for (final i in plan.items) if (i.isOpen && !i.blocks.contains(step.id) && i.step == step.id) i];
    final closed = [for (final i in plan.items) if (!i.isOpen && (i.blocks.contains(step.id) || i.step == step.id)) i]
      ..sort((a, b) => (b.doneAt ?? '').compareTo(a.doneAt ?? ''));

    return ListView(
      controller: controller,
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 40),
      children: [
        Row(children: [
          Expanded(child: Text('STEP ${step.number ?? step.id} · ${stateLabel(v.state)}'.toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis, style: t.display(13, ls: 2.2, color: t.forState(v.state)))),
          Text('RANK ${step.rank}', style: t.readout(11)),
        ]),
        const SizedBox(height: 6),
        Text(step.title, style: t.display(20, weight: FontWeight.w600, ls: 0.3, height: 1.2)),
        const SizedBox(height: 10),
        _whatItWaitsOn(context, v),
        if (step.gates.isNotEmpty) ...[
          const SectionHead('Gates', sub: 'What Claude proves before the step can close.'),
          Wrap(spacing: 8, runSpacing: 8, children: [for (final g in step.gates.values) GateCard(g)]),
          for (final g in step.gates.values)
            if (g.note != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text('${g.name} — ${g.note}', style: TextStyle(fontSize: 12.5, color: t.ink2)),
              ),
        ],
        if (deps.isNotEmpty) ...[
          const SectionHead('Comes after'),
          _stepChips(context, deps),
        ],
        if (unlocks.isNotEmpty) ...[
          const SectionHead('Unlocks'),
          _stepChips(context, unlocks),
        ],
        if (v.openBlockers.isNotEmpty) ...[
          SectionHead('What you should do', sub: '${v.openBlockers.length} item${v.openBlockers.length == 1 ? '' : 's'} stand between this step and done.'),
          for (final i in v.openBlockers) Padding(padding: const EdgeInsets.only(bottom: 10), child: ItemCard(item: i, plan: plan, graph: graph, draft: draft, needs: needs, decisive: decisive.contains(i.id))),
        ],
        if (itemsFrom.isNotEmpty) ...[
          SectionHead('Also from this step', sub: 'Open, but not gating it.'),
          for (final i in itemsFrom) Padding(padding: const EdgeInsets.only(bottom: 10), child: ItemCard(item: i, plan: plan, graph: graph, draft: draft, needs: needs, decisive: false)),
        ],
        if (closed.isNotEmpty) ...[
          SectionHead('Done for this step', sub: '${closed.length} closed. Reopen one if it was ticked by mistake.'),
          for (final i in closed) Padding(padding: const EdgeInsets.only(bottom: 10), child: ItemCard(item: i, plan: plan, graph: graph, draft: draft, needs: needs, decisive: false)),
        ],
        const SectionHead('Note to Claude', sub: 'Stays here until you press Send.'),
        _StepNote(draft: draft, stepId: step.id),
        for (final s in step.sections) ...[
          SectionHead(s.title),
          Md(s.body),
        ],
        if (step.history.isNotEmpty) ...[
          const SectionHead('History'),
          for (final h in step.history.reversed)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text('${h.at} · ${h.event}${h.note != null ? ' — ${h.note}' : ''}', style: t.mono(12, color: t.ink2)),
            ),
        ],
      ],
    );
  }

  Widget _whatItWaitsOn(BuildContext context, StepView v) {
    final t = context.tokens;
    String text;
    switch (v.state) {
      case StepState.done:
        text = 'Done.';
      case StepState.blocked:
      case StepState.waiting:
        text = 'Waits on ${v.missingDeps.map((d) => d.number ?? d.id).join(', ')} to finish first.';
      case StepState.ready:
        text = 'Nothing in the way — Claude can start this with /step.';
      case StepState.active:
        text = 'Claude is on it. ${v.pendingGates.length} gate${v.pendingGates.length == 1 ? '' : 's'} still to pass.';
      case StepState.codeComplete:
        text = 'Claude\'s half is finished. Only your items below stand in the way.';
      case StepState.flippable:
        text = 'Everything passed and nothing is open — Claude closes it with `kit step done`.';
    }
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: t.forState(v.state).withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10)),
      child: Text(text, style: TextStyle(color: t.ink, fontSize: 13.5)),
    );
  }

  Widget _stepChips(BuildContext context, List<Step> steps) {
    final t = context.tokens;
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final s in steps)
          ActionChip(
            avatar: Container(width: 10, height: 10, decoration: BoxDecoration(shape: BoxShape.circle, color: t.forState(graph.view(s).state))),
            label: Text('${s.number ?? s.id} · ${s.title}', maxLines: 1, overflow: TextOverflow.ellipsis),
            onPressed: () => onSelectStep(s.id),
          ),
      ],
    );
  }
}

class _StepNote extends StatefulWidget {
  const _StepNote({required this.draft, required this.stepId});
  final Draft draft;
  final String stepId;
  @override
  State<_StepNote> createState() => _StepNoteState();
}

class _StepNoteState extends State<_StepNote> {
  late final _c = TextEditingController(text: widget.draft.steps[widget.stepId] ?? '');

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _c,
      minLines: 1,
      maxLines: 4,
      decoration: const InputDecoration(hintText: 'Tell Claude something about this step…'),
      onChanged: (v) {
        widget.draft.steps[widget.stepId] = v;
        widget.draft.save();
      },
    );
  }
}
