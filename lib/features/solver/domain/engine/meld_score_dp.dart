import 'package:okey_acar_mi/features/solver/domain/engine/rack_normalizer.dart';
import 'package:okey_acar_mi/features/solver/domain/engine/transition_tables.dart';

/// One color's share of a column transition (reconstruction detail).
class ColorPlan {
  /// Creates a [ColorPlan].
  const ColorPlan({required this.moveCodes, required this.sigma});

  /// Per-slot move codes, parallel to the sorted slot tuple.
  final List<int> moveCodes;

  /// Real copies of this color committed to sets at this column.
  final int sigma;
}

/// Full detail of one column transition, for replay.
class ColumnPlan {
  /// Creates a [ColumnPlan].
  const ColumnPlan({required this.colors, required this.wildsForSets});

  /// Per-color plans in `TileColor` enum order (4 entries).
  final List<ColorPlan> colors;

  /// Wilds committed to sets at this column (`ws`).
  final int wildsForSets;
}

/// Visitor for column transitions. Return `true` to stop enumeration.
typedef TransitionVisitor =
    bool Function(
      int newKey,
      int newValue,
      ColumnPlan? plan,
    );

/// Output of the 101 max-score column DP (§1).
class MeldScoreDpResult {
  /// Creates a [MeldScoreDpResult].
  const MeldScoreDpResult({
    required this.best,
    required this.winnerKey,
    required this.initialKey,
    required this.values,
    required this.parents,
  });

  /// Best meld total over all legal partitions.
  final int best;

  /// Winning terminal key at level 14 (smallest key on ties).
  final int winnerKey;

  /// The all-zero initial state key at level 1.
  final int initialKey;

  /// `values[n]` = packed state → best score using columns `< n`
  /// (levels 1..14; index 0 unused).
  final List<Map<int, int>?> values;

  /// `parents[n]` = packed state at level `n` → its parent at `n − 1`
  /// (levels 2..14).
  final List<Map<int, int>?> parents;
}

/// §1 column DP: max-score meld partition with wilds, columns 1 → 13.
///
/// State before column `n`: per-color sorted tuple of open-run suffix
/// lengths (capped at 3) + wilds remaining. Score accrues at placement
/// (pay-as-you-go); set members score at the set-close layer.
class MeldScoreDp {
  /// Creates a [MeldScoreDp].
  const MeldScoreDp();

  /// Tuple spaces for [rack], in color enum order.
  List<ColorTupleSpace> spacesFor(NormalizedRack rack) => [
    for (var c = 0; c < 4; c++) ColorTupleSpace.of(rack.scoreSlots[c]),
  ];

  /// Packs per-color tuple indices + wilds left into a state key.
  int packKey(List<ColorTupleSpace> spaces, List<int> idx, int w, int wMax) {
    var r = 0;
    for (var c = 0; c < 4; c++) {
      r = r * spaces[c].stateCount + idx[c];
    }
    return r * (wMax + 1) + w;
  }

  /// Decodes [key] into per-color tuple indices; returns wilds left.
  int unpackKey(
    List<ColorTupleSpace> spaces,
    int key,
    int wMax,
    List<int> idxOut,
  ) {
    final w = key % (wMax + 1);
    var r = key ~/ (wMax + 1);
    for (var c = 3; c >= 0; c--) {
      idxOut[c] = r % spaces[c].stateCount;
      r ~/= spaces[c].stateCount;
    }
    return w;
  }

  /// Runs the DP and returns the best score plus the relaxation tables
  /// needed for reconstruction.
  MeldScoreDpResult run(NormalizedRack rack) {
    final spaces = spacesFor(rack);
    final wMax = rack.wildCount;
    final zeroIdx = [for (final s in spaces) s.zeroIndex];
    final initialKey = packKey(spaces, zeroIdx, wMax, wMax);

    final values = List<Map<int, int>?>.filled(15, null);
    final parents = List<Map<int, int>?>.filled(15, null);
    values[1] = {initialKey: 0};

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
          visit: (newKey, newValue, _) {
            final existing = next[newKey];
            if (existing == null || newValue > existing) {
              next[newKey] = newValue;
              par[newKey] = entry.key;
            }
            return false;
          },
        );
      }
      values[n + 1] = next;
      parents[n + 1] = par;
    }

    var best = -1;
    var winnerKey = -1;
    final idx = List<int>.filled(4, 0);
    for (final entry in values[14]!.entries) {
      unpackKey(spaces, entry.key, wMax, idx);
      if (!_isTerminal(spaces, idx)) continue;
      if (entry.value > best ||
          (entry.value == best && entry.key < winnerKey)) {
        best = entry.value;
        winnerKey = entry.key;
      }
    }
    assert(winnerKey >= 0, 'the all-stay terminal always exists');

    return MeldScoreDpResult(
      best: best,
      winnerKey: winnerKey,
      initialKey: initialKey,
      values: values,
      parents: parents,
    );
  }

  bool _isTerminal(List<ColorTupleSpace> spaces, List<int> idx) {
    for (var c = 0; c < 4; c++) {
      for (final v in spaces[c].tuples[idx[c]]) {
        if (v == 1 || v == 2) return false;
      }
    }
    return true;
  }

  /// Enumerates every transition of column [n] from state [key] in the
  /// fixed canonical order (slots descending; per-slot move table order;
  /// σ ascending; ws ascending). When [buildPlan] is set, each emission
  /// carries a [ColumnPlan] for replay.
  void enumerateColumn({
    required NormalizedRack rack,
    required List<ColorTupleSpace> spaces,
    required int n,
    required int key,
    required int value,
    required bool buildPlan,
    required TransitionVisitor visit,
  }) {
    _ColumnEnumerator(
      rack: rack,
      spaces: spaces,
      n: n,
      buildPlan: buildPlan,
      visit: visit,
    ).enumerate(key, value);
  }
}

class _ColumnEnumerator {
  _ColumnEnumerator({
    required this.rack,
    required this.spaces,
    required this.n,
    required this.buildPlan,
    required this.visit,
  }) : newIdx = List<int>.filled(4, 0),
       sigmaBuf = List<int>.filled(4, 0),
       moveBuf = [
         for (var c = 0; c < 4; c++) List<int>.filled(spaces[c].slotCount, 0),
       ],
       newValuesBuf = [
         for (var c = 0; c < 4; c++) List<int>.filled(spaces[c].slotCount, 0),
       ],
       sortScratch = List<int>.filled(RackNormalizer.maxSlots, 0);

  final NormalizedRack rack;
  final List<ColorTupleSpace> spaces;
  final int n;
  final bool buildPlan;
  final TransitionVisitor visit;

  final List<int> newIdx;
  final List<int> sigmaBuf;
  final List<List<int>> moveBuf;
  final List<List<int>> newValuesBuf;
  final List<int> sortScratch;

  late List<List<int>> tuples;
  late int baseValue;
  bool stopped = false;

  void enumerate(int key, int value) {
    baseValue = value;
    final idx = List<int>.filled(4, 0);
    final w = const MeldScoreDp().unpackKey(spaces, key, rack.wildCount, idx);
    tuples = [for (var c = 0; c < 4; c++) spaces[c].tuples[idx[c]]];
    for (var c = 0; c < 4; c++) {
      newIdx[c] = idx[c];
    }
    _colorLayer(0, w, 0, 0, 0);
  }

  void _colorLayer(int c, int wLeft, int sigmaSum, int sigmaMax, int score) {
    if (stopped) return;
    if (c == 4) {
      _setClose(wLeft, sigmaSum, sigmaMax, score);
      return;
    }
    _slotRec(c, 0, 0, 0, wLeft, sigmaSum, sigmaMax, score);
  }

  void _slotRec(
    int c,
    int s,
    int physUsed,
    int secUsed,
    int wLeft,
    int sigmaSum,
    int sigmaMax,
    int score,
  ) {
    if (stopped) return;
    final avail = rack.counts[c][n];
    if (s == spaces[c].slotCount) {
      final free = avail - physUsed;
      // Dominance (exact, §1): a wild plays (c, n) only when every real
      // copy is consumed by this column's allocation (runs + σ).
      final sigmaFrom = secUsed > 0 ? free : 0;
      for (var sigma = sigmaFrom; sigma <= free && !stopped; sigma++) {
        sigmaBuf[c] = sigma;
        newIdx[c] = _sortedIndex(c);
        _colorLayer(
          c + 1,
          wLeft - secUsed,
          sigmaSum + sigma,
          sigma > sigmaMax ? sigma : sigmaMax,
          score + n * (physUsed + secUsed),
        );
      }
      return;
    }
    final v = tuples[c][s];
    for (final move in movesForValue(v)) {
      if (stopped) return;
      final real = moveRealCells[move];
      final sec = moveSecCells[move];
      if (physUsed + real > avail) continue;
      if (secUsed + sec > wLeft) continue;
      newValuesBuf[c][s] = moveNewValue(move, v);
      moveBuf[c][s] = move;
      _slotRec(
        c,
        s + 1,
        physUsed + real,
        secUsed + sec,
        wLeft,
        sigmaSum,
        sigmaMax,
        score,
      );
    }
  }

  int _sortedIndex(int c) {
    final count = spaces[c].slotCount;
    for (var i = 0; i < count; i++) {
      sortScratch[i] = newValuesBuf[c][i];
    }
    // Insertion sort descending over ≤ 7 values.
    for (var i = 1; i < count; i++) {
      final v = sortScratch[i];
      var j = i - 1;
      while (j >= 0 && sortScratch[j] < v) {
        sortScratch[j + 1] = sortScratch[j];
        j--;
      }
      sortScratch[j + 1] = v;
    }
    var encoded = 0;
    for (var i = 0; i < count; i++) {
      encoded = (encoded << 2) | sortScratch[i];
    }
    return spaces[c].indexOfEncoded(encoded);
  }

  void _setClose(int wLeft, int sigmaSum, int sigmaMax, int score) {
    for (var ws = 0; ws <= wLeft && !stopped; ws++) {
      final total = sigmaSum + ws;
      if (total == 0) {
        _emit(score, wLeft, 0);
        continue;
      }
      if (!setCloseFeasible(total, sigmaMax)) continue;
      _emit(score + n * total, wLeft - ws, ws);
    }
  }

  void _emit(int scoreDelta, int wFinal, int ws) {
    var r = 0;
    for (var c = 0; c < 4; c++) {
      r = r * spaces[c].stateCount + newIdx[c];
    }
    final key = r * (rack.wildCount + 1) + wFinal;
    ColumnPlan? plan;
    if (buildPlan) {
      plan = ColumnPlan(
        colors: [
          for (var c = 0; c < 4; c++)
            ColorPlan(
              moveCodes: List<int>.of(moveBuf[c]),
              sigma: sigmaBuf[c],
            ),
        ],
        wildsForSets: ws,
      );
    }
    stopped = visit(key, baseValue + scoreDelta, plan);
  }
}
