/// Shared column-DP primitives: per-slot move tables, the per-color tuple
/// state space, and the set-closing feasibility lemma (§1).
library;

/// Extend the open run with a real tile of the column kind.
const int moveExtendReal = 0;

/// Extend the open run with a secondary cell (wild in §1, phantom in §3b).
const int moveExtendSec = 1;

/// Close a complete run (value 3); the run ended at column `n − 1`.
const int moveClose = 2;

/// Close at `n − 1`, reopen at `n` with one real cell.
const int moveComp1Real = 3;

/// Close at `n − 1`, reopen at `n` with one secondary cell.
const int moveComp1Sec = 4;

/// Extend into `n` (real), close, reopen at `n` (real) — 2 cells.
const int moveComp2RealReal = 5;

/// Extend into `n` (real), close, reopen at `n` (secondary).
const int moveComp2RealSec = 6;

/// Extend into `n` (secondary), close, reopen at `n` (real).
const int moveComp2SecReal = 7;

/// Extend into `n` (secondary), close, reopen at `n` (secondary).
const int moveComp2SecSec = 8;

/// Keep an empty slot empty.
const int moveStay = 9;

/// Open a new run at `n` with one real cell.
const int moveOpenReal = 10;

/// Open a new run at `n` with one secondary cell.
const int moveOpenSec = 11;

/// Canonical per-slot move order for an empty slot (value 0).
const List<int> movesForEmpty = [moveStay, moveOpenReal, moveOpenSec];

/// Canonical per-slot move order for a short run (value 1 or 2) —
/// must extend or the branch is not generated (pay-as-you-go soundness).
const List<int> movesForShort = [moveExtendReal, moveExtendSec];

/// Canonical per-slot move order for a complete run (value 3).
const List<int> movesForComplete = [
  moveExtendReal,
  moveExtendSec,
  moveClose,
  moveComp1Real,
  moveComp1Sec,
  moveComp2RealReal,
  moveComp2RealSec,
  moveComp2SecReal,
  moveComp2SecSec,
];

/// Real cells consumed at the current column, indexed by move code.
const List<int> moveRealCells = [1, 0, 0, 1, 0, 2, 1, 1, 0, 0, 1, 0];

/// Secondary cells consumed at the current column, indexed by move code.
const List<int> moveSecCells = [0, 1, 0, 0, 1, 0, 1, 1, 2, 0, 0, 1];

/// Canonical move list for a slot currently holding [value].
List<int> movesForValue(int value) => switch (value) {
  0 => movesForEmpty,
  1 || 2 => movesForShort,
  _ => movesForComplete,
};

/// New slot value after applying [move] to a slot holding [value].
int moveNewValue(int move, int value) => switch (move) {
  moveExtendReal || moveExtendSec => value >= 3 ? 3 : value + 1,
  moveClose || moveStay => 0,
  _ => 1,
};

/// Whether [move] flushes the currently open run.
bool moveCloses(int move) => move >= moveClose && move <= moveComp2SecSec;

/// Whether [move] extends the closing run into the current column first
/// (the composite 2-cell variants).
bool moveExtendsBeforeClose(int move) =>
    move >= moveComp2RealReal && move <= moveComp2SecSec;

/// Whether the cell that extends the run at this column is secondary.
bool moveExtendCellIsSec(int move) =>
    move == moveExtendSec ||
    move == moveComp2SecReal ||
    move == moveComp2SecSec;

/// Whether [move] opens a run at this column (open / composite reopen).
bool moveReopens(int move) =>
    move == moveOpenReal ||
    move == moveOpenSec ||
    (move >= moveComp1Real && move <= moveComp2SecSec);

/// Whether the cell that opens/reopens the run is secondary.
bool moveReopenCellIsSec(int move) =>
    move == moveOpenSec ||
    move == moveComp1Sec ||
    move == moveComp2RealSec ||
    move == moveComp2SecSec;

/// Set-closing feasibility lemma (§1): [total] committed members
/// (`Σσ + ws`) split into k legal sets iff `total ≥ 3` and
/// `k ∈ [max(maxPerColor, ⌈total/4⌉), ⌊total/3⌋]` is nonempty.
///
/// Proof sketch: deal each color's copies round-robin over k sets (≤ 1 per
/// color per set since `maxPerColor ≤ k`); sizes fill to 3–4. Excludes
/// `total = 5` automatically. Handles pure-wild sets (`Σσ = 0`).
bool setCloseFeasible(int total, int maxPerColor) {
  if (total < 3) return false;
  final kLow = maxPerColor > (total + 3) ~/ 4 ? maxPerColor : (total + 3) ~/ 4;
  return kLow <= total ~/ 3;
}

/// Canonical number of sets used when closing [total] members
/// (`max(maxPerColor, ⌈total/4⌉)` — the fewest, largest sets).
int setCloseCanonicalK(int total, int maxPerColor) {
  final bySize = (total + 3) ~/ 4;
  return maxPerColor > bySize ? maxPerColor : bySize;
}

/// The state space of one color's sorted slot tuple: all non-increasing
/// tuples of a given length over values {0, 1, 2, 3}, indexed densely.
class ColorTupleSpace {
  ColorTupleSpace._(this.slotCount, this.tuples, this._indexByEncoding);

  /// Returns the (cached) space for [slotCount] slots.
  factory ColorTupleSpace.of(int slotCount) =>
      _cache.putIfAbsent(slotCount, () => ColorTupleSpace._build(slotCount));

  factory ColorTupleSpace._build(int slotCount) {
    final tuples = <List<int>>[];
    final scratch = List<int>.filled(slotCount, 0);
    void recurse(int position, int maxValue) {
      if (position == slotCount) {
        tuples.add(List<int>.unmodifiable(scratch));
        return;
      }
      for (var v = maxValue; v >= 0; v--) {
        scratch[position] = v;
        recurse(position + 1, v);
      }
    }

    recurse(0, 3);
    final byEncoding = <int, int>{
      for (var i = 0; i < tuples.length; i++) encode(tuples[i]): i,
    };
    return ColorTupleSpace._(slotCount, tuples, byEncoding);
  }

  static final Map<int, ColorTupleSpace> _cache = {};

  /// Number of slots in each tuple.
  final int slotCount;

  /// All tuples, sorted-descending values, in canonical order.
  final List<List<int>> tuples;

  final Map<int, int> _indexByEncoding;

  /// Number of states: `C(slotCount + 3, 3)`.
  int get stateCount => tuples.length;

  /// 2-bits-per-slot encoding of a sorted-descending [tuple].
  static int encode(List<int> tuple) {
    var key = 0;
    for (final v in tuple) {
      key = (key << 2) | v;
    }
    return key;
  }

  /// Dense index of the sorted-descending [tuple].
  int indexOf(List<int> tuple) => _indexByEncoding[encode(tuple)]!;

  /// Dense index of a tuple already packed with [encode].
  int indexOfEncoded(int encoded) => _indexByEncoding[encoded]!;

  /// Index of the all-zero tuple (always the last one generated… or
  /// wherever it lies — resolved through the encoding map).
  int get zeroIndex => _indexByEncoding[0]!;
}

/// Sorts [values] descending in place (insertion sort — tuples are ≤ 7
/// long) and applies the identical stable permutation to [companions].
void sortDescendingWith(List<int> values, List<Object?> companions) {
  for (var i = 1; i < values.length; i++) {
    final value = values[i];
    final companion = companions[i];
    var j = i - 1;
    while (j >= 0 && values[j] < value) {
      values[j + 1] = values[j];
      companions[j + 1] = companions[j];
      j--;
    }
    values[j + 1] = value;
    companions[j + 1] = companion;
  }
}
