/// Derived state. Nothing here is stored; everything is recomputed from the
/// files every time, which is what keeps "the next step is 29" from being a
/// sentence somebody has to remember to update.
library;

import 'model.dart';

/// What a step looks like from the outside, once dependencies, gates and
/// items have been taken into account.
enum StepState {
  /// Done — status `done`.
  done,

  /// Cannot start: a dependency is not done.
  blocked,

  /// Could start now: pending, every dependency done.
  ready,

  /// Being worked: status `active`, gates not all passed.
  active,

  /// Claude's half is finished and only human items stand in the way.
  codeComplete,

  /// Gates passed, no open items — should be flipped to done.
  flippable,

  /// Pending and not yet reachable in order (a dependency is ready/active but
  /// not done). Same as blocked, kept separate only for wording.
  waiting,
}

class StepView {
  StepView(this.step, this.state, {required this.missingDeps, required this.openBlockers, required this.pendingGates});
  final Step step;
  final StepState state;

  /// Direct dependencies that are not done.
  final List<Step> missingDeps;

  /// Open items naming this step in `blocks:`.
  final List<Item> openBlockers;

  /// Gates not yet passed.
  final List<Gate> pendingGates;

}

class Graph {
  Graph(this.plan);
  final Plan plan;

  StepView view(Step s) {
    final missing = <Step>[];
    for (final d in s.dependsOn) {
      final dep = plan.step(d);
      if (dep == null || dep.status != StepStatus.done) {
        missing.add(dep ?? Step(id: d, title: '(missing) $d', rank: -1));
      }
    }
    final blockers = plan.blockersOf(s.id);
    final pendingGates = [for (final g in s.gates.values) if (g.status != GateStatus.passed) g];

    StepState state;
    if (s.status == StepStatus.done) {
      state = StepState.done;
    } else if (s.status == StepStatus.active) {
      if (pendingGates.isNotEmpty) {
        state = StepState.active;
      } else if (blockers.isNotEmpty) {
        state = StepState.codeComplete;
      } else {
        state = StepState.flippable;
      }
    } else if (missing.isNotEmpty) {
      state = StepState.blocked;
    } else {
      state = StepState.ready;
    }
    return StepView(s, state, missingDeps: missing, openBlockers: blockers, pendingGates: pendingGates);
  }

  List<StepView> views() => [for (final s in plan.steps) view(s)];

  /// The step Claude should work: the active one if any, else the first
  /// ready one in rank order.
  StepView? nextStep() {
    final vs = views();
    for (final v in vs) {
      if (v.state == StepState.active) return v;
    }
    for (final v in vs) {
      if (v.state == StepState.ready) return v;
    }
    return null;
  }

  /// Steps that are done except for open human items.
  List<StepView> codeComplete() =>
      [for (final v in views()) if (v.state == StepState.codeComplete) v];

  /// Items whose completion would change a step's state right now — the
  /// last thing standing between a step and done, or between a step and
  /// startable.
  ///
  /// An item is "decisive" for step S if S's only remaining obstacles are
  /// open items (no missing deps, no pending gates) — so closing all of S's
  /// blockers flips it.
  Set<String> decisiveItemIds() {
    final out = <String>{};
    for (final v in views()) {
      if (v.state == StepState.codeComplete) {
        out.addAll(v.openBlockers.map((i) => i.id));
      }
    }
    return out;
  }

  /// Everything between [stepId] and done, one level deep on dependencies
  /// but transitive on *why* a dependency is not done (so "G12 is blocked by
  /// G2, and G2 is waiting on you" comes out in one call).
  BlocksReport blocks(String stepId) {
    final s = plan.step(stepId);
    if (s == null) throw ArgumentError('Unknown step "$stepId"');
    final v = view(s);
    final depReports = <StepView>[];
    for (final d in v.missingDeps) {
      if (d.rank >= 0) depReports.add(view(d));
    }
    return BlocksReport(v, depReports);
  }

  /// Steps that a given item stands in front of, with what else each is
  /// waiting on — the "what did I just unblock" answer for `kit done`.
  List<StepView> stepsGatedBy(String itemId) {
    final item = plan.item(itemId);
    if (item == null) return const [];
    return [for (final id in item.blocks) if (plan.step(id) != null) view(plan.step(id)!)];
  }

  /// The chain of steps between [fromId] and the release step, if any —
  /// used to decide whether an item is on the launch path.
  bool isOnReleasePath(String stepId) {
    final release = plan.manifest.releaseStep;
    if (release == null) return false;
    if (stepId == release) return true;
    final seen = <String>{};
    bool reaches(String id) {
      if (id == stepId) return true;
      if (!seen.add(id)) return false;
      final st = plan.step(id);
      if (st == null) return false;
      for (final d in st.dependsOn) {
        if (reaches(d)) return true;
      }
      return false;
    }

    return reaches(release);
  }

  /// Sort key for items on the board: dated deadlines first, then items that
  /// would flip a step today, then launch-path blockers, then the rest —
  /// inside each group, oldest first.
  int urgency(Item i) {
    if (i.deadline != null) return 0;
    if (decisiveItemIds().contains(i.id)) return 1;
    if (i.blocks.any(isOnReleasePath)) return 2;
    if (i.blocks.isNotEmpty) return 3;
    return 4;
  }

  List<Item> openItemsByUrgency() {
    final open = [for (final i in plan.items) if (i.isOpen) i];
    open.sort((a, b) {
      final u = urgency(a).compareTo(urgency(b));
      if (u != 0) return u;
      final d = (a.deadline ?? '').compareTo(b.deadline ?? '');
      if (d != 0) return d;
      return (a.added ?? '').compareTo(b.added ?? '');
    });
    return open;
  }

  /// Open items grouped by their first `need` — the sittings on the board.
  Map<String, List<Item>> sittings() {
    final out = <String, List<Item>>{};
    for (final i in openItemsByUrgency()) {
      final key = i.needs.isEmpty ? 'unsorted' : i.needs.first;
      out.putIfAbsent(key, () => []).add(i);
    }
    return out;
  }
}

class BlocksReport {
  BlocksReport(this.step, this.missingDeps);
  final StepView step;

  /// Views of the direct dependencies that are not done.
  final List<StepView> missingDeps;

  bool get isClear =>
      step.missingDeps.isEmpty && step.pendingGates.isEmpty && step.openBlockers.isEmpty;
}
