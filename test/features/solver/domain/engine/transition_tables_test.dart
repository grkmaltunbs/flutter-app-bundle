import 'package:flutter_test/flutter_test.dart';
import 'package:okey_acar_mi/features/solver/domain/engine/transition_tables.dart';

/// (real variant, secondary variant) pairs that differ by exactly one cell
/// downgraded from real to secondary — the dominance dimension.
const _dominancePairs = <(int, int)>[
  (moveOpenReal, moveOpenSec),
  (moveExtendReal, moveExtendSec),
  (moveComp1Real, moveComp1Sec),
  (moveComp2RealReal, moveComp2RealSec),
  (moveComp2RealReal, moveComp2SecReal),
  (moveComp2RealSec, moveComp2SecSec),
  (moveComp2SecReal, moveComp2SecSec),
];

int _binomial(int n, int k) {
  var result = 1;
  for (var i = 1; i <= k; i++) {
    result = result * (n - k + i) ~/ i;
  }
  return result;
}

void main() {
  group('setCloseFeasible (§1 lemma) boundaries', () {
    test('total below 3 is never feasible', () {
      expect(setCloseFeasible(0, 0), isFalse);
      expect(setCloseFeasible(1, 1), isFalse);
      expect(setCloseFeasible(2, 1), isFalse);
      expect(setCloseFeasible(2, 2), isFalse);
    });

    test('total = 5 is infeasible for every maxPerColor', () {
      for (var maxPerColor = 0; maxPerColor <= 5; maxPerColor++) {
        expect(
          setCloseFeasible(5, maxPerColor),
          isFalse,
          reason: 'maxPerColor $maxPerColor',
        );
      }
    });

    test('maxPerColor exceeding ⌊total/3⌋ is infeasible', () {
      expect(setCloseFeasible(6, 3), isFalse); // 3 > ⌊6/3⌋ = 2
      expect(setCloseFeasible(6, 2), isTrue); //  2 ≤ 2 — boundary holds
      expect(setCloseFeasible(9, 4), isFalse); // 4 > ⌊9/3⌋ = 3
      expect(setCloseFeasible(9, 3), isTrue);
    });

    test('pure-wild closings (maxPerColor = 0): totals 3 and 4 feasible', () {
      expect(setCloseFeasible(3, 0), isTrue);
      expect(setCloseFeasible(4, 0), isTrue);
    });

    test('k-range nonempty/empty boundary pair at total = 11', () {
      // kLow = max(3, ⌈11/4⌉ = 3) = 3 ≤ ⌊11/3⌋ = 3 → nonempty.
      expect(setCloseFeasible(11, 3), isTrue);
      // kLow = 4 > 3 → empty range.
      expect(setCloseFeasible(11, 4), isFalse);
    });

    test('canonical k realizes every feasible closing with sizes 3–4', () {
      for (var total = 3; total <= 16; total++) {
        for (var maxPerColor = 0; maxPerColor <= 4; maxPerColor++) {
          if (!setCloseFeasible(total, maxPerColor)) continue;
          final k = setCloseCanonicalK(total, maxPerColor);
          expect(k * 3, lessThanOrEqualTo(total));
          expect(k * 4, greaterThanOrEqualTo(total));
          expect(k, greaterThanOrEqualTo(maxPerColor));
        }
      }
    });
  });

  group('ColorTupleSpace', () {
    test('stateCount == C(slots + 3, 3) for slots 0..7', () {
      for (var slots = 0; slots <= 7; slots++) {
        expect(
          ColorTupleSpace.of(slots).stateCount,
          _binomial(slots + 3, 3),
          reason: '$slots slots',
        );
      }
    });
  });

  group('real-before-wild dominance', () {
    test('each pair downgrades exactly one real cell to secondary', () {
      for (final (real, sec) in _dominancePairs) {
        expect(moveRealCells[sec], moveRealCells[real] - 1);
        expect(moveSecCells[sec], moveSecCells[real] + 1);
      }
    });

    test('real variants precede their secondary counterparts in every '
        'canonical move list', () {
      const lists = [movesForEmpty, movesForShort, movesForComplete];
      for (final moves in lists) {
        for (final (real, sec) in _dominancePairs) {
          final realIndex = moves.indexOf(real);
          final secIndex = moves.indexOf(sec);
          if (realIndex == -1 || secIndex == -1) continue;
          expect(
            realIndex,
            lessThan(secIndex),
            reason: 'move $real must precede $sec in $moves',
          );
        }
      }
    });

    test('movesForValue routes each slot value to its canonical list', () {
      expect(movesForValue(0), same(movesForEmpty));
      expect(movesForValue(1), same(movesForShort));
      expect(movesForValue(2), same(movesForShort));
      expect(movesForValue(3), same(movesForComplete));
    });
  });
}
