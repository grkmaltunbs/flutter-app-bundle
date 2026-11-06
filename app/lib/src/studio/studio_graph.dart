import 'dart:math' as math;
import 'dart:ui' show Offset, Size;

import 'studio_data.dart';
import 'studio_plans.dart';

// The two constellations as data: where every ring sits and which lines
// join them. No painting here — test/studio_graph_test.dart pins it.

enum NodeKind { done, current, next, held }

/// One step of one lane, placed: [row] is the lane, [col] the step's place
/// relative to NOW (0 is the step being worked on, or the next one).
class LaneNode {
  LaneNode({required this.lane, required this.item, required this.kind, required this.col, required this.row});
  final String lane;
  final StepItem item;
  final NodeKind kind;
  final int col;
  final int row;
  String get key => keyOf(lane, item.id);
  static String keyOf(String lane, String id) => '$lane/$id';
}

enum EdgeKind {
  /// The lane's own order — the next step follows the last.
  rail,

  /// An `after:` tag: a real dependency.
  after,

  /// A mention in the text ("lane C 468") — a link the app suggests.
  suggested,
}

class LaneEdge {
  const LaneEdge({required this.from, required this.to, required this.kind});

  /// Keys of [LaneNode]s; [from] must be done before [to] (for [EdgeKind.after]).
  final String from;
  final String to;
  final EdgeKind kind;
  bool get crossLane => from.split('/').first != to.split('/').first;
}

/// The lanes as one graph, every lane's NOW in one column.
class LaneGraph {
  LaneGraph({required this.lanes, required this.nodes, required this.edges, required this.minCol, required this.maxCol, this.offscreen = const {}});

  /// Lane ids, top to bottom.
  final List<String> lanes;
  final List<LaneNode> nodes;
  final List<LaneEdge> edges;
  final int minCol;
  final int maxCol;

  /// For a node, links whose other end is outside the window.
  final Map<String, List<DepRef>> offscreen;

  LaneNode? node(String key) => _byKey[key];
  late final Map<String, LaneNode> _byKey = {for (final n in nodes) n.key: n};

  /// The links into [key] and out of it.
  Iterable<LaneEdge> edgesOf(String key) => edges.where((e) => e.from == key || e.to == key);

  /// Builds the graph from each lane's track. [before] finished and [after]
  /// open steps are kept around NOW per lane; [all] keeps every step.
  static LaneGraph build(Map<String, LaneTrack> tracks, {int before = 8, int after = 12, bool all = false}) {
    final laneIds = tracks.keys.toList()..sort();
    final nodes = <LaneNode>[];
    // Every item of every lane, by id and by run — a link may point outside the window.
    final byId = <String, Map<String, StepItem>>{};
    final byRun = <String, Map<String, StepItem>>{};
    for (final l in laneIds) {
      final t = tracks[l]!;
      final items = [...t.done, if (t.current != null) t.current!, ...t.next];
      byId[l] = {for (final i in items) i.id: i};
      byRun[l] = {
        for (final i in items) ...{if (i.run != null) i.run!: i, if (RegExp(r'^\d+$').hasMatch(i.id)) i.id: i},
      };
    }
    var minCol = 0, maxCol = 0;
    for (final (row, l) in laneIds.indexed) {
      final t = tracks[l]!;
      final seq = <(StepItem, NodeKind)>[
        for (final d in t.done) (d, NodeKind.done),
        if (t.current != null) (t.current!, NodeKind.current),
        for (final n in t.next) (n, n.held ? NodeKind.held : NodeKind.next),
      ];
      final now = t.done.length;
      for (final (i, (item, kind)) in seq.indexed) {
        final col = i - now;
        if (!all && (col < -before || col > after)) continue;
        nodes.add(LaneNode(lane: l, item: item, kind: kind, col: col, row: row));
        minCol = math.min(minCol, col);
        maxCol = math.max(maxCol, col);
      }
    }
    final shown = {for (final n in nodes) n.key};
    final edges = <LaneEdge>[];
    final offscreen = <String, List<DepRef>>{};
    // The rails: each lane's shown steps in order.
    for (final l in laneIds) {
      final row = nodes.where((n) => n.lane == l).toList()..sort((a, b) => a.col.compareTo(b.col));
      for (var i = 1; i < row.length; i++) {
        edges.add(LaneEdge(from: row[i - 1].key, to: row[i].key, kind: EdgeKind.rail));
      }
    }
    String? resolve(DepRef r, String own) {
      final lane = r.lane ?? own;
      final StepItem? item;
      if (r.id != null) {
        item = byId[lane]?[r.id!];
      } else {
        item = byRun[lane]?[r.run];
      }
      return item == null ? null : LaneNode.keyOf(lane, item.id);
    }

    // Real links first; then a suggestion only where no link joins the pair.
    final linked = <String>{};
    String pairOf(String a, String b) => ([a, b]..sort()).join('|');
    for (final kind in [EdgeKind.after, EdgeKind.suggested]) {
      for (final n in nodes) {
        final refs = kind == EdgeKind.after ? n.item.after : parseLaneMentions(n.item.text, ownLane: n.lane);
        for (final r in refs) {
          final other = resolve(r, n.lane);
          if (other == n.key) continue;
          // A link to a step outside the window — or in no list at all, a
          // typo or a step not written yet — is said on the panel, not drawn.
          if (other == null || !shown.contains(other)) {
            if (kind == EdgeKind.after) offscreen.putIfAbsent(n.key, () => []).add(r);
            continue;
          }
          if (!linked.add(pairOf(other, n.key))) continue;
          edges.add(LaneEdge(from: other, to: n.key, kind: kind));
        }
      }
    }
    return LaneGraph(lanes: laneIds, nodes: nodes, edges: edges, minCol: minCol, maxCol: maxCol, offscreen: offscreen);
  }
}

// --- the roadmap constellation ----------------------------------------------------

/// Where each milestone star and each item sits, and the links between items.
class RoadmapLayout {
  RoadmapLayout({required this.size, required this.stars, required this.starRadius, required this.items, required this.links, required this.current});

  final Size size;

  /// Milestone key → centre.
  final Map<String, Offset> stars;

  /// Milestone key → the radius its items fill.
  final Map<String, double> starRadius;

  /// Item id → (its item, its centre).
  final Map<String, ({RoadmapItem item, Offset at})> items;

  /// Item links: (waits on, item).
  final List<(String, String)> links;

  /// The milestone the team is on: the first with open work.
  final String? current;

  /// Lays the milestones left to right along a spine, each item on rings
  /// around its milestone — what moves (in progress, built) on the inner
  /// rings, done on the outer — leaving a gap where the spine passes.
  static RoadmapLayout build(List<Milestone> milestones, {double spacing = 34, double inner = 74, double ringGap = 30, double gap = 70, double margin = 60}) {
    final stars = <String, Offset>{};
    final radius = <String, double>{};
    final items = <String, ({RoadmapItem item, Offset at})>{};
    final rings = <String, List<List<RoadmapItem>>>{};
    const order = {ItemStatus.inProgress: 0, ItemStatus.built: 1, ItemStatus.other: 2, ItemStatus.notStarted: 3, ItemStatus.done: 4};
    // The spine runs through 0 and π: keep a wedge of ±0.32 rad clear on each side.
    const clear = 0.32;
    for (final m in milestones) {
      final sorted = [...m.items]..sort((a, b) => order[a.status]!.compareTo(order[b.status]!));
      final out = <List<RoadmapItem>>[];
      var r = inner;
      var i = 0;
      while (i < sorted.length) {
        final usable = 2 * math.pi - 4 * clear;
        final slots = math.max(4, (usable * r / spacing).floor());
        out.add(sorted.sublist(i, math.min(sorted.length, i + slots)));
        i += slots;
        r += ringGap;
      }
      rings[m.key] = out;
      radius[m.key] = out.isEmpty ? 34 : inner + (out.length - 1) * ringGap + 18;
    }
    final maxR = radius.values.fold<double>(40, math.max);
    final cy = margin + maxR;
    var x = margin;
    for (final m in milestones) {
      final r = radius[m.key]!;
      x += r;
      final c = Offset(x, cy);
      stars[m.key] = c;
      final ringsOf = rings[m.key]!;
      for (final (k, ring) in ringsOf.indexed) {
        final rr = inner + k * ringGap;
        // Two arcs, above and below the spine, filled alternately so a
        // short ring sits balanced.
        final n = ring.length;
        final arc = math.pi - 2 * clear;
        final top = (n + 1) ~/ 2, bottom = n ~/ 2;
        for (var j = 0; j < n; j++) {
          final upper = j.isEven;
          final idx = j ~/ 2;
          final count = upper ? top : bottom;
          final t = count == 1 ? 0.5 : idx / (count - 1);
          final a = upper ? (math.pi + clear + arc * t) : (clear + arc * (1 - t));
          items[ring[j].id] = (item: ring[j], at: c + Offset(math.cos(a) * rr, math.sin(a) * rr));
        }
      }
      x += r + gap;
    }
    final links = <(String, String)>[
      for (final e in items.entries)
        for (final dep in e.value.item.after)
          if (items.containsKey(dep)) (dep, e.key),
    ];
    final current = milestones.where((m) => m.items.any((i) => i.status != ItemStatus.done)).map((m) => m.key).firstOrNull;
    return RoadmapLayout(size: Size(x - gap + margin, cy * 2), stars: stars, starRadius: radius, items: items, links: links, current: current);
  }
}

/// Lane steps that name a roadmap item, by item id.
Map<String, List<(String lane, StepItem step)>> stepsByRoadmapId(Map<String, LaneTrack> tracks) {
  final out = <String, List<(String, StepItem)>>{};
  for (final e in tracks.entries) {
    for (final s in [...e.value.done, if (e.value.current != null) e.value.current!, ...e.value.next]) {
      for (final id in s.roadmapIds) {
        out.putIfAbsent(id, () => []).add((e.key, s));
      }
    }
  }
  return out;
}

/// The lane a node belongs to, as the board names it.
String laneLabel(String id) => 'LANE ${id.toUpperCase()}';

/// For a lane's history: does it run right now?
bool laneWorking(Lane? l) => l?.status.state == LaneState.running;
