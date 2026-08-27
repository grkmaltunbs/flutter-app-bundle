/// A layered layout for the step graph — the bubbles on the board.
///
/// Columns are dependency depth (a step sits one column right of the deepest
/// step it depends on); rows inside a column follow `rank`, centred so the
/// picture reads left-to-right as "what had to happen before what". Nothing
/// clever about crossings: the graph is small, edges are faint until a
/// bubble is selected, and a deterministic layout that never surprises beats
/// a pretty one that moves every time a step is added.
library;

import 'dart:math' as math;

import 'model.dart';

class NodePos {
  NodePos(this.id, {required this.col, required this.row, required this.x, required this.y});
  final String id;
  final int col;
  final int row;
  final double x;
  final double y;
}

class DagLayout {
  DagLayout({required this.nodes, required this.edges, required this.width, required this.height});

  /// Positions by step id, in rank order.
  final Map<String, NodePos> nodes;

  /// `(from, to)` pairs: `from` is the dependency, `to` depends on it.
  final List<(String, String)> edges;
  final double width;
  final double height;
}

const kColGap = 168.0;
const kRowGap = 76.0;
const kMargin = 56.0;

DagLayout layoutDag(List<Step> steps, {bool Function(Step)? include}) {
  final chosen = [for (final s in steps) if (include == null || include(s)) s];
  final ids = {for (final s in chosen) s.id};
  final byId = {for (final s in chosen) s.id: s};

  final depthMemo = <String, int>{};
  int depth(String id, Set<String> stack) {
    final memo = depthMemo[id];
    if (memo != null) return memo;
    if (!stack.add(id)) return 0; // a cycle — validate() reports it; do not hang
    final s = byId[id]!;
    var d = 0;
    for (final dep in s.dependsOn) {
      if (ids.contains(dep)) d = math.max(d, depth(dep, stack) + 1);
    }
    stack.remove(id);
    depthMemo[id] = d;
    return d;
  }

  final columns = <int, List<Step>>{};
  for (final s in chosen) {
    columns.putIfAbsent(depth(s.id, {}), () => []).add(s);
  }
  final maxRows = columns.values.fold<int>(0, (m, c) => math.max(m, c.length));
  final height = kMargin * 2 + math.max(0, maxRows - 1) * kRowGap;
  final cols = columns.keys.toList()..sort();
  final nodes = <String, NodePos>{};
  for (final c in cols) {
    final list = columns[c]!; // already in rank order — `steps` is sorted
    final n = list.length;
    for (var r = 0; r < n; r++) {
      final y = height / 2 + (r - (n - 1) / 2) * kRowGap;
      nodes[list[r].id] = NodePos(list[r].id, col: c, row: r, x: kMargin + c * kColGap, y: y);
    }
  }
  final edges = <(String, String)>[];
  for (final s in chosen) {
    for (final dep in s.dependsOn) {
      if (ids.contains(dep)) edges.add((dep, s.id));
    }
  }
  final width = kMargin * 2 + (cols.isEmpty ? 0 : cols.last) * kColGap;
  return DagLayout(nodes: nodes, edges: edges, width: width, height: height);
}
