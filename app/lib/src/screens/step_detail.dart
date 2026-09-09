import 'package:flutter/material.dart' hide Step, StepState;
import 'package:flutter_kit/kit.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;

import '../draft.dart';
import '../relay.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'item_card.dart';

/// What a bubble opens: where the step sits, what stands in its way, what
/// the person should do about it (as runbooks), and the step's own spec.
class StepDetail extends StatelessWidget {
  const StepDetail({super.key, required this.plan, required this.graph, required this.step, required this.draft, required this.onSelectStep, this.controller, this.threads, this.onAskItem, this.onAskStep, this.actions, this.moved = false});
  final Plan plan;
  final Graph graph;
  final Step step;
  final Draft draft;
  final void Function(String id) onSelectStep;
  final ScrollController? controller;
  final ThreadStore? threads;
  final void Function(Item item)? onAskItem;

  /// Opens the step's own thread — ASK ABOUT THIS STEP.
  final VoidCallback? onAskStep;

  /// Start · Blocks · Mark done, when the surface can drive the plan.
  final StepActions? actions;

  /// The step sits where a drag on the constellation put it — not applied yet.
  final bool moved;

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
          Text(moved ? 'RANK ${step.rank} · MOVED' : 'RANK ${step.rank}', style: t.readout(11, color: moved ? t.warn : null)),
        ]),
        const SizedBox(height: 6),
        Text(step.title, style: t.display(20, weight: FontWeight.w600, ls: 0.3, height: 1.2)),
        const SizedBox(height: 10),
        _whatItWaitsOn(context, v),
        if (actions != null) ...[
          const SizedBox(height: 10),
          StepControls(view: v, actions: actions!),
        ],
        if (onAskStep != null) ...[
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(foregroundColor: t.accent, side: BorderSide(color: t.accent.withValues(alpha: 0.45)), backgroundColor: t.accentSoft.withValues(alpha: 0.5)),
              onPressed: onAskStep,
              icon: const Icon(Icons.forum_outlined, size: 16),
              label: Text(
                'ASK ABOUT THIS STEP${(threads?.forStep(step.id)?.count ?? 0) > 0 ? ' · ${threads!.forStep(step.id)!.count}' : ''}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
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
          for (final i in v.openBlockers) Padding(padding: const EdgeInsets.only(bottom: 10), child: ItemCard(item: i, plan: plan, graph: graph, draft: draft, needs: needs, decisive: decisive.contains(i.id), thread: threads?.forItem(i.id), onAsk: onAskItem == null ? null : () => onAskItem!(i))),
        ],
        if (itemsFrom.isNotEmpty) ...[
          SectionHead('Also from this step', sub: 'Open, but not gating it.'),
          for (final i in itemsFrom) Padding(padding: const EdgeInsets.only(bottom: 10), child: ItemCard(item: i, plan: plan, graph: graph, draft: draft, needs: needs, decisive: false, thread: threads?.forItem(i.id), onAsk: onAskItem == null ? null : () => onAskItem!(i))),
        ],
        if (closed.isNotEmpty) ...[
          SectionHead('Done for this step', sub: '${closed.length} closed. Reopen one if it was ticked by mistake.'),
          for (final i in closed) Padding(padding: const EdgeInsets.only(bottom: 10), child: ItemCard(item: i, plan: plan, graph: graph, draft: draft, needs: needs, decisive: false, thread: threads?.forItem(i.id), onAsk: onAskItem == null ? null : () => onAskItem!(i))),
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

/// What the controls on a step's sheet do — built by the screen for the
/// side it is on: the host calls its own hands, the phone sends host
/// commands and waits for the line. None of them needs a model, except
/// Start, which hands `/step <id>` to the session.
class StepActions {
  const StepActions({required this.sessionRunning, required this.startSession, required this.startStep, required this.blocks, required this.markDone});

  /// A session runs, so Start sends `/step`; else Start is offered first.
  final bool sessionRunning;

  /// Starts the session; the host's line.
  final Future<String> Function() startSession;

  /// Sends `/step <id>`; the host's line — `sent` or `queued` when it went.
  final Future<String> Function(String id) startStep;

  /// `kit blocks <id>` as the host renders it.
  final Future<String> Function(String id) blocks;

  /// `kit step done <id>`; the flip's line, or the refusal word for word.
  final Future<String> Function(String id) markDone;
}

/// The three controls a bubble's sheet carries — Start, Blocks, Mark done
/// — and the host's answer under them. Start reads START THE SESSION while
/// none runs; a done step keeps only Blocks.
class StepControls extends StatefulWidget {
  const StepControls({super.key, required this.view, required this.actions});
  final StepView view;
  final StepActions actions;

  @override
  State<StepControls> createState() => _StepControlsState();
}

class _StepControlsState extends State<StepControls> {
  /// Which control is running, while one is.
  String? _busy;
  String? _line;
  bool _lineIsError = false;
  bool _mono = false;

  Future<void> _run(String what, Future<String> Function() go, {bool mono = false, bool Function(String)? refused}) async {
    setState(() {
      _busy = what;
      _line = null;
    });
    try {
      final r = await go();
      if (!mounted) return;
      setState(() {
        _line = r.trim().isEmpty ? 'The host answered nothing.' : r.trim();
        _mono = mono;
        _lineIsError = refused?.call(_line!) ?? false;
      });
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _line = e.toString();
        _mono = false;
        _lineIsError = true;
      });
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  static bool _sendRefused(String r) => !(r.startsWith('sent') || r.startsWith('queued') || r.startsWith('started'));
  static bool _doneRefused(String r) => !r.contains(': done.');

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final v = widget.view;
    final a = widget.actions;
    final id = v.step.id;
    final done = v.state == StepState.done;
    final busy = _busy != null;
    Widget icon(String what, IconData i) => _busy == what ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)) : Icon(i, size: 16);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (!done)
              SizedBox(
                height: 44,
                child: FilledButton.icon(
                  onPressed: busy
                      ? null
                      : a.sessionRunning
                          ? () => _run('start', () => a.startStep(id), refused: _sendRefused)
                          : () => _run('start', a.startSession, refused: _sendRefused),
                  icon: icon('start', Icons.play_arrow),
                  label: Text(a.sessionRunning ? 'START THIS STEP' : 'START THE SESSION', maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
              ),
            SizedBox(
              height: 44,
              child: OutlinedButton.icon(
                onPressed: busy ? null : () => _run('blocks', () => a.blocks(id), mono: true),
                icon: icon('blocks', Icons.account_tree_outlined),
                label: const Text('BLOCKS', maxLines: 1),
              ),
            ),
            if (!done)
              SizedBox(
                height: 44,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(foregroundColor: t.good, side: BorderSide(color: t.good.withValues(alpha: 0.5))),
                  onPressed: busy ? null : () => _run('done', () => a.markDone(id), refused: _doneRefused),
                  icon: icon('done', Icons.check_circle_outline),
                  label: const Text('MARK DONE', maxLines: 1),
                ),
              ),
          ],
        ),
        if (_line case final line?) ...[
          const SizedBox(height: 8),
          GestureDetector(
            onLongPress: () => Clipboard.setData(ClipboardData(text: line)),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: (_lineIsError ? t.critical : t.accent).withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
              child: Text(line, style: _mono ? t.mono(11.5, height: 1.4, color: t.ink) : TextStyle(fontSize: 13, color: _lineIsError ? t.critical : t.ink)),
            ),
          ),
        ],
      ],
    );
  }
}
