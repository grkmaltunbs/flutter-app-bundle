import 'package:okey_acar_mi/features/solver/domain/engine/rack_normalizer.dart';
import 'package:okey_acar_mi/features/solver/domain/engine/transition_tables.dart';

/// One color's share of an okey-mode column transition.
class OkeyColorPlan {
  /// Creates an [OkeyColorPlan].
  const OkeyColorPlan({
    required this.moveCodes,
    required this.sigma,
    required this.phantomSigma,
    required this.pairReal,
    required this.pairPhantom,
  });

  /// Per-slot move codes, parallel to the sorted slot tuple.
  final List<int> moveCodes;

  /// Real copies committed to sets at this column.
  final int sigma;

  /// Phantom copies committed to sets at this column.
  final int phantomSigma;

  /// Real cells of the final pair taken at this column (0–2).
  final int pairReal;

  /// Phantom cells of the final pair taken at this column (0–2).
  final int pairPhantom;
}

/// Full detail of one okey-mode column transition, for replay.
class OkeyColumnPlan {
  /// Creates an [OkeyColumnPlan].
  const OkeyColumnPlan({required this.colors});

  /// Per-color plans in `TileColor` enum order (4 entries).
  final List<OkeyColorPlan> colors;
}

/// Visitor for okey column transitions. Return `true` to stop.
typedef OkeyTransitionVisitor =
    bool Function(
      int newKey,
      int newValue,
      OkeyColumnPlan? plan,
    );

/// Output of the okey matched-DP.
class OkeyWinDpResult {
  /// Creates an [OkeyWinDpResult].
  const OkeyWinDpResult({
    required this.bestMatched,
    required this.winnerKey,
    required this.initialKey,
    required this.values,
    required this.parents,
  });

  /// Max real rack tiles placeable in any 14-cell win template
  /// (wilds excluded — added post hoc per the §3b reduction).
  final int bestMatched;

  /// Winning terminal key at level 14 (smallest key on composite ties).
  final int winnerKey;

  /// Initial state key at level 1.
  final int initialKey;

  /// Per-level relaxation maps (composite `matched·512 + score`).
  final List<Map<int, int>?> values;

  /// Per-level parent pointers (levels 2..14).
  final List<Map<int, int>?> parents;
}

/// §3b okey-mode DP: maximize matched real tiles over all win templates
/// (melds ≥ 3 + at most one pair, cells = 14), with phantom cells capped
/// by the 106-tile supply. Wilds are excluded (exact reduction):
/// `tilesToWin = 14 − min(14, bestMatched + W)`.
class OkeyWinDp {
  /// Creates an [OkeyWinDp].
  const OkeyWinDp();

  /// Composite objective stride: `score ≤ 182 < 512` ⇒ no interference.
  static const int matchedStride = 512;

  /// Tuple spaces for [rack] (okey slot widths), in color enum order.
  List<ColorTupleSpace> spacesFor(NormalizedRack rack) => [
    for (var c = 0; c < 4; c++) ColorTupleSpace.of(rack.okeySlots[c]),
  ];

  /// Packs tuple indices + cells + pairUsed into a state key.
  int packKey(
    List<ColorTupleSpace> spaces,
    List<int> idx,
    int cells,
    int pairUsed,
  ) {
    var r = 0;
    for (var c = 0; c < 4; c++) {
      r = r * spaces[c].stateCount + idx[c];
    }
    return (r * 15 + cells) * 2 + pairUsed;
  }

  /// Decodes [key]; fills [idxOut]; returns `(cells, pairUsed)`.
  (int, int) unpackKey(
    List<ColorTupleSpace> spaces,
    int key,
    List<int> idxOut,
  ) {
    final pairUsed = key % 2;
    var r = key ~/ 2;
    final cells = r % 15;
    r ~/= 15;
    for (var c = 3; c >= 0; c--) {
      idxOut[c] = r % spaces[c].stateCount;
      r ~/= spaces[c].stateCount;
    }
    return (cells, pairUsed);
  }

  /// Runs the DP; returns best matched + relaxation tables.
  OkeyWinDpResult run(NormalizedRack rack) {
    final spaces = spacesFor(rack);
    final zeroIdx = [for (final s in spaces) s.zeroIndex];
    final initialKey = packKey(spaces, zeroIdx, 0, 0);

    final values = List<Map<int, int>?>.filled(15, null);
    final parents = List<Map<int, int>?>.filled(15, null);
    values[1] = {initialKey: 0};
    // B&B seed (lossless): the seven-pairs greedy hand is itself a valid
    // 14-cell win template, so its matched count is a feasible lower
    // bound. Whenever the meld DP's true optimum is ≥ the seed, every
    // optimal chain has potential ≥ optimum ≥ bound and survives the
    // strict-< drop; when it is below the seed, the engine's final
    // max(keptMeld, kept7) is decided by the seven-pairs path anyway, so
    // an under-reported meld matched cannot change tilesToWin.
    var bound = _sevenPairsLowerBound(rack);
    // Future real cells at columns > n can only bind copies counted at
    // those columns — a sound cap on remaining matched.
    final suffixReals = List<int>.filled(15, 0);
    for (var n = 13; n >= 1; n--) {
      var column = 0;
      for (var c = 0; c < 4; c++) {
        column += rack.counts[c][n];
      }
      suffixReals[n] = suffixReals[n + 1] + column;
    }
    final idx = List<int>.filled(4, 0);

    for (var n = 1; n <= 13; n++) {
      final next = <int, int>{};
      final par = <int, int>{};
      for (final entry in values[n]!.entries) {
        enumerateColumn(
          rack: rack,
          spaces: spaces,
          n: n,
          key: entry.key,
          value: entry.value,
          buildPlan: false,
          bound: bound,
          visit: (newKey, newValue, _) {
            final matched = newValue ~/ matchedStride;
            final (cells, _) = unpackKey(spaces, newKey, idx);
            // Branch & bound: strict < so bound-achieving frozen chains
            // survive to the terminal level for reconstruction. The
            // all-stay state (== initialKey) is exempt so a completable
            // terminal always exists even when the seed exceeds the meld
            // optimum.
            final gap = 14 - cells;
            final cap = suffixReals[n + 1];
            final potential = matched + (gap < cap ? gap : cap);
            if (newKey != initialKey && potential < bound) return false;
            final existing = next[newKey];
            if (existing == null || newValue > existing) {
              next[newKey] = newValue;
              par[newKey] = entry.key;
              if (_isCompletable(spaces, newKey, idx)) {
                if (matched > bound) bound = matched;
              }
            }
            return false;
          },
        );
      }
      _pruneCellsDominated(next, par);
      values[n + 1] = next;
      parents[n + 1] = par;
    }

    var best = -1;
    var winnerKey = -1;
    for (final entry in values[14]!.entries) {
      if (!_isCompletable(spaces, entry.key, idx)) continue;
      if (entry.value > best ||
          (entry.value == best && entry.key < winnerKey)) {
        best = entry.value;
        winnerKey = entry.key;
      }
    }
    assert(winnerKey >= 0, 'the all-stay terminal always exists');

    return OkeyWinDpResult(
      bestMatched: best ~/ matchedStride,
      winnerKey: winnerKey,
      initialKey: initialKey,
      values: values,
      parents: parents,
    );
  }

  /// Cells-dominance prune (lossless — exchange argument): for the same
  /// slot tuple and pair flag, a state with ≥ 3 more cells and no more
  /// matched is dominated. The leaner state can replay the dominated
  /// state's entire remaining transition chain verbatim (every feasibility
  /// check — avail, budget, owed cells, ≤ 14 cells, B&B potential — is
  /// column-local or only relaxed by fewer cells), and its terminal gap is
  /// larger by ≥ 3, so post-terminal all-phantom padding still fills to 14
  /// at equal or better matched. Children are generated only after this
  /// prune, so no surviving chain references a dropped parent.
  void _pruneCellsDominated(Map<int, int> next, Map<int, int> par) {
    if (next.length < 2) return;
    // (r, pairUsed) group -> max matched per cells value.
    final groups = <int, List<int>>{};
    for (final entry in next.entries) {
      final key = entry.key;
      final cells = (key ~/ 2) % 15;
      final gid = ((key ~/ 2) ~/ 15) * 2 + key % 2;
      final matched = entry.value ~/ matchedStride;
      final byCells = groups.putIfAbsent(gid, () => List.filled(15, -1));
      if (matched > byCells[cells]) byCells[cells] = matched;
    }
    for (final byCells in groups.values) {
      // Prefix max: best matched at any cells value ≤ index.
      for (var c = 1; c < 15; c++) {
        if (byCells[c - 1] > byCells[c]) byCells[c] = byCells[c - 1];
      }
    }
    next.removeWhere((key, value) {
      final cells = (key ~/ 2) % 15;
      if (cells < 3) return false;
      final gid = ((key ~/ 2) ~/ 15) * 2 + key % 2;
      final dominated = groups[gid]![cells - 3] >= value ~/ matchedStride;
      if (dominated) par.remove(key);
      return dominated;
    });
  }

  /// Matched reals of the greedy seven-pairs hand (§3b: exact because the
  /// 7 pair slots are independent) — a feasible B&B lower bound.
  int _sevenPairsLowerBound(NormalizedRack rack) {
    final contributions = <int>[];
    for (var c = 0; c < 4; c++) {
      for (var n = 1; n <= 13; n++) {
        final count = rack.counts[c][n];
        for (var i = 0; i < count ~/ 2; i++) {
          contributions.add(2);
        }
        if (count.isOdd && rack.phantomBudget(c, n) >= 1) {
          contributions.add(1);
        }
      }
    }
    contributions.sort((a, b) => b.compareTo(a));
    var matched = 0;
    for (var i = 0; i < contributions.length && i < 7; i++) {
      matched += contributions[i];
    }
    return matched;
  }

  /// Terminal acceptance: all slots ∈ {0, 3} and `14 − cells` is 0 or ≥ 3
  /// (the gap is padded post-terminal with all-phantom runs).
  bool _isCompletable(List<ColorTupleSpace> spaces, int key, List<int> idx) {
    final (cells, _) = unpackKey(spaces, key, idx);
    final gap = 14 - cells;
    if (gap != 0 && gap < 3) return false;
    for (var c = 0; c < 4; c++) {
      for (final v in spaces[c].tuples[idx[c]]) {
        if (v == 1 || v == 2) return false;
      }
    }
    return true;
  }

  /// Enumerates every okey transition of column [n] from [key] in canonical
  /// order (slots descending; move table order; σ, ps, pair ascending).
  ///
  /// [bound] is the current B&B lower bound: partial allocations whose
  /// `matched + (14 − cells)` potential already fell strictly below it are
  /// cut mid-recursion (phantom cells decrease that potential
  /// monotonically, so no completion can recover — same strict-< semantics
  /// as the visitor-level drop). Pass 0 to enumerate everything (replay).
  void enumerateColumn({
    required NormalizedRack rack,
    required List<ColorTupleSpace> spaces,
    required int n,
    required int key,
    required int value,
    required bool buildPlan,
    required OkeyTransitionVisitor visit,
    int bound = 0,
  }) {
    _OkeyColumnEnumerator(
      rack: rack,
      spaces: spaces,
      n: n,
      buildPlan: buildPlan,
      visit: visit,
      bound: bound,
    ).enumerate(key, value);
  }
}

class _OkeyColumnEnumerator {
  _OkeyColumnEnumerator({
    required this.rack,
    required this.spaces,
    required this.n,
    required this.buildPlan,
    required this.visit,
    required this.bound,
  }) : newIdx = List<int>.filled(4, 0),
       sigmaBuf = List<int>.filled(4, 0),
       psBuf = List<int>.filled(4, 0),
       pairRealBuf = List<int>.filled(4, 0),
       pairPhantomBuf = List<int>.filled(4, 0),
       moveBuf = [
         for (var c = 0; c < 4; c++) List<int>.filled(spaces[c].slotCount, 0),
       ],
       newValuesBuf = [
         for (var c = 0; c < 4; c++) List<int>.filled(spaces[c].slotCount, 0),
       ];

  final NormalizedRack rack;
  final List<ColorTupleSpace> spaces;
  final int n;
  final bool buildPlan;
  final OkeyTransitionVisitor visit;
  final int bound;

  final List<int> newIdx;
  final List<int> sigmaBuf;
  final List<int> psBuf;
  final List<int> pairRealBuf;
  final List<int> pairPhantomBuf;
  final List<List<int>> moveBuf;
  final List<List<int>> newValuesBuf;

  late List<List<int>> tuples;
  late int baseValue;
  late int baseCells;

  /// Phantom cells this transition may still add before the state's
  /// `matched + (14 − cells)` potential drops strictly below [bound].
  late int phantomSlack;

  /// `availSuffix[c]` = real copies of column [n] over colors `≥ c`.
  late List<int> availSuffix;
  bool stopped = false;

  bool _realAheadAnywhere(int c) {
    for (var m = n + 1; m <= 13; m++) {
      if (rack.counts[c][m] > 0) return true;
    }
    return false;
  }

  void enumerate(int key, int value) {
    baseValue = value;
    final idx = List<int>.filled(4, 0);
    final (cells, pairUsed) = const OkeyWinDp().unpackKey(spaces, key, idx);
    baseCells = cells;
    phantomSlack = value ~/ OkeyWinDp.matchedStride + (14 - cells) - bound;
    availSuffix = List<int>.filled(5, 0);
    for (var c = 3; c >= 0; c--) {
      availSuffix[c] = availSuffix[c + 1] + rack.counts[c][n];
    }
    tuples = [for (var c = 0; c < 4; c++) spaces[c].tuples[idx[c]]];
    for (var c = 0; c < 4; c++) {
      newIdx[c] = idx[c];
    }
    _colorLayer(0, pairUsed == 1, 0, 0, 0, 0, 0);
  }

  void _colorLayer(
    int c,
    bool pairTaken,
    int cellsAdded,
    int matchedAdded,
    int setTotal,
    int setRealTotal,
    int setMaxPerColor,
  ) {
    if (stopped) return;
    if (c == 4) {
      // Set-close validation: members committed per color must form legal
      // sets; pure-phantom sets are pruned (covered by terminal padding).
      if (setTotal > 0) {
        if (setRealTotal == 0) return;
        if (!setCloseFeasible(setTotal, setMaxPerColor)) return;
      }
      _emit(cellsAdded, matchedAdded, pairTaken);
      return;
    }
    // Pure-phantom sets cannot be repaired once no remaining color holds
    // a real copy of this column — cut the cross-product early.
    if (setTotal > 0 && setRealTotal == 0 && availSuffix[c] == 0) return;
    _slotRec(
      c,
      0,
      0,
      0,
      pairTaken,
      cellsAdded,
      matchedAdded,
      setTotal,
      setRealTotal,
      setMaxPerColor,
    );
  }

  void _slotRec(
    int c,
    int s,
    int runReal,
    int runPhantom,
    bool pairTaken,
    int cellsAdded,
    int matchedAdded,
    int setTotal,
    int setRealTotal,
    int setMaxPerColor,
  ) {
    if (stopped) return;
    final avail = rack.counts[c][n];
    final budget = rack.phantomBudget(c, n);
    if (s == spaces[c].slotCount) {
      newIdx[c] = _sortedIndex(c);
      _commitColor(
        c,
        runReal,
        runPhantom,
        pairTaken,
        cellsAdded,
        matchedAdded,
        setTotal,
        setRealTotal,
        setMaxPerColor,
      );
      return;
    }
    final v = tuples[c][s];
    for (final move in movesForValue(v)) {
      if (stopped) return;
      final real = moveRealCells[move];
      final phantom = moveSecCells[move];
      if (runReal + real > avail) continue;
      if (runPhantom + phantom > budget) continue;
      if (phantom > 0 && !_phantomAllowed(move, c)) continue;
      if (baseCells + cellsAdded + real + phantom > 14) continue;
      if (cellsAdded - matchedAdded + phantom > phantomSlack) continue;
      newValuesBuf[c][s] = moveNewValue(move, v);
      moveBuf[c][s] = move;
      _slotRec(
        c,
        s + 1,
        runReal + real,
        runPhantom + phantom,
        pairTaken,
        cellsAdded + real + phantom,
        matchedAdded + real,
        setTotal,
        setRealTotal,
        setMaxPerColor,
      );
    }
  }

  /// Phantom guard (lossless — exchange argument): a phantom OPEN/REOPEN
  /// cell at `(c, n)` is generated only when a real c-tile exists at some
  /// column `> n`. If none exists, every later cell of that run is
  /// necessarily phantom too (no rack copies remain to bind), so the run
  /// is pure-phantom; dropping it from any template and re-adding its
  /// cells as post-terminal all-phantom padding preserves `matched`
  /// exactly (the terminal gap grows by the run length ≥ 3, so acceptance
  /// still holds). Phantom EXTEND cells are never guarded: a trailing pad
  /// on a run anchored at column 1 (e.g. Red 1-2-3-[4]) has no leading or
  /// split representation, so any extend guard cuts real optima — the old
  /// within-2-ahead guard overstated tilesToWin on exactly that shape.
  bool _phantomAllowed(int move, int c) =>
      !moveReopenCellIsSec(move) || _realAheadAnywhere(c);

  /// Enumerates σ (real set copies), ps (phantom set copies) and the pair
  /// allocation for color [c], then recurses to the next color.
  void _commitColor(
    int c,
    int runReal,
    int runPhantom,
    bool pairTaken,
    int cellsAdded,
    int matchedAdded,
    int setTotal,
    int setRealTotal,
    int setMaxPerColor,
  ) {
    final avail = rack.counts[c][n];
    final budget = rack.phantomBudget(c, n);
    for (var sigma = 0; sigma <= avail - runReal && !stopped; sigma++) {
      for (var ps = 0; ps <= budget - runPhantom && !stopped; ps++) {
        // Pair options, reals first: none, 2+0, 1+1, 0+2.
        for (final (pr, pp) in const [(0, 0), (2, 0), (1, 1), (0, 2)]) {
          if (stopped) return;
          if ((pr > 0 || pp > 0) && pairTaken) continue;
          if (runReal + sigma + pr > avail) continue;
          if (runPhantom + ps + pp > budget) continue;
          // Dominance (exact): any phantom of (c, n) requires every real
          // copy consumed by this column's allocation.
          final phantoms = runPhantom + ps + pp;
          final reals = runReal + sigma + pr;
          if (phantoms > 0 && reals != avail) continue;
          final added = sigma + ps + pr + pp;
          if (baseCells + cellsAdded + added > 14) continue;
          if (cellsAdded - matchedAdded + ps + pp > phantomSlack) continue;
          final members = sigma + ps;
          sigmaBuf[c] = sigma;
          psBuf[c] = ps;
          pairRealBuf[c] = pr;
          pairPhantomBuf[c] = pp;
          _colorLayer(
            c + 1,
            pairTaken || pr > 0 || pp > 0,
            cellsAdded + added,
            matchedAdded + sigma + pr,
            setTotal + members,
            setRealTotal + sigma,
            members > setMaxPerColor ? members : setMaxPerColor,
          );
        }
      }
    }
  }

  int _sortedIndex(int c) {
    final count = spaces[c].slotCount;
    final scratch = List<int>.of(newValuesBuf[c])
      ..sort((a, b) => b.compareTo(a));
    var encoded = 0;
    for (var i = 0; i < count; i++) {
      encoded = (encoded << 2) | scratch[i];
    }
    return spaces[c].indexOfEncoded(encoded);
  }

  void _emit(int cellsAdded, int matchedAdded, bool pairTaken) {
    final newCells = baseCells + cellsAdded;
    // Owed-cells filter: open runs must still be completable within 14.
    var owed = 0;
    for (var c = 0; c < 4; c++) {
      for (final v in spaces[c].tuples[newIdx[c]]) {
        if (v > 0 && v < 3) owed += 3 - v;
      }
    }
    if (newCells + owed > 14) return;
    var r = 0;
    for (var c = 0; c < 4; c++) {
      r = r * spaces[c].stateCount + newIdx[c];
    }
    final key = (r * 15 + newCells) * 2 + (pairTaken ? 1 : 0);
    final newValue =
        baseValue + matchedAdded * OkeyWinDp.matchedStride + n * cellsAdded;
    OkeyColumnPlan? plan;
    if (buildPlan) {
      plan = OkeyColumnPlan(
        colors: [
          for (var c = 0; c < 4; c++)
            OkeyColorPlan(
              moveCodes: List<int>.of(moveBuf[c]),
              sigma: sigmaBuf[c],
              phantomSigma: psBuf[c],
              pairReal: pairRealBuf[c],
              pairPhantom: pairPhantomBuf[c],
            ),
        ],
      );
    }
    stopped = visit(key, newValue, plan);
  }
}
