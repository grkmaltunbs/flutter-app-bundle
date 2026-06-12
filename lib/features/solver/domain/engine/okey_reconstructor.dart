import 'package:okey_acar_mi/core/game/game_tile.dart';
import 'package:okey_acar_mi/core/game/tile_color.dart';
import 'package:okey_acar_mi/features/solver/domain/engine/meld_validator.dart';
import 'package:okey_acar_mi/features/solver/domain/engine/okey_win_dp.dart';
import 'package:okey_acar_mi/features/solver/domain/engine/rack_normalizer.dart';
import 'package:okey_acar_mi/features/solver/domain/engine/transition_tables.dart';
import 'package:okey_acar_mi/features/solver/domain/entities/solved_meld.dart';
import 'package:okey_acar_mi/features/solver/domain/entities/solved_pair.dart';
import 'package:okey_acar_mi/features/solver/domain/entities/solved_spot.dart';

/// A reconstructed okey win template: melds (padded to 14 cells with
/// all-phantom runs), the optional final pair, and binding info.
class OkeyArrangement {
  /// Creates an [OkeyArrangement].
  const OkeyArrangement({
    required this.melds,
    required this.pair,
    required this.usedRackIndices,
    required this.matched,
  });

  /// Melds in formation order; phantom cells are [NeededSpot]s.
  final List<SolvedMeld> melds;

  /// The final pair, when the winning template uses one.
  final SolvedPair? pair;

  /// Rack indices bound into the template.
  final Set<int> usedRackIndices;

  /// Real rack tiles placed (equals the DP's best matched).
  final int matched;
}

/// Replays the okey DP chain and pads the terminal gap canonically.
class OkeyReconstructor {
  /// Creates an [OkeyReconstructor].
  const OkeyReconstructor();

  /// Rebuilds the winning template of [result] for [rack].
  OkeyArrangement reconstruct(NormalizedRack rack, OkeyWinDpResult result) {
    const dp = OkeyWinDp();
    final spaces = dp.spacesFor(rack);

    final keys = List<int>.filled(15, 0);
    keys[14] = result.winnerKey;
    for (var n = 13; n >= 1; n--) {
      keys[n] = result.parents[n + 1]![keys[n + 1]]!;
    }
    final chainValues = [
      0,
      for (var n = 1; n <= 14; n++) result.values[n]![keys[n]]!,
    ];

    final builder = _OkeyBuilder(rack);
    final values = [
      for (var c = 0; c < 4; c++) List<int>.filled(spaces[c].slotCount, 0),
    ];

    for (var n = 1; n <= 13; n++) {
      OkeyColumnPlan? plan;
      dp.enumerateColumn(
        rack: rack,
        spaces: spaces,
        n: n,
        key: keys[n],
        value: chainValues[n],
        buildPlan: true,
        visit: (newKey, newValue, candidate) {
          if (newKey == keys[n + 1] && newValue == chainValues[n + 1]) {
            plan = candidate;
            return true;
          }
          return false;
        },
      );
      builder.applyColumn(n, plan!, values);
    }
    builder
      ..flushAll(values)
      ..pad();

    assert(
      builder.matched == result.bestMatched,
      'reconstructed matched count must equal the DP value',
    );
    assert(
      builder.melds.every(const MeldValidator().isValidMeld),
      'every reconstructed okey meld must pass MeldValidator',
    );
    assert(
      builder.pair == null || const MeldValidator().isValidPair(builder.pair!),
      'the final pair must pass MeldValidator',
    );

    return OkeyArrangement(
      melds: builder.melds,
      pair: builder.pair,
      usedRackIndices: builder.used,
      matched: builder.matched,
    );
  }
}

class _OkeyBuilder {
  _OkeyBuilder(this.rack)
    : queuePos = List.generate(4, (_) => List<int>.filled(14, 0)),
      phantomUsed = List.generate(4, (_) => List<int>.filled(14, 0)),
      buffers = [
        for (var c = 0; c < 4; c++)
          List<List<SolvedSpot>?>.filled(rack.okeySlots[c], null),
      ];

  final NormalizedRack rack;
  final List<List<int>> queuePos;
  final List<List<int>> phantomUsed;
  final List<List<List<SolvedSpot>?>> buffers;
  final List<SolvedMeld> melds = [];
  final Set<int> used = {};
  SolvedPair? pair;
  int matched = 0;

  SolvedSpot _realSpot(int c, int n) {
    final index = rack.instanceQueues[c][n][queuePos[c][n]++];
    used.add(index);
    matched++;
    return SolvedSpot.rackTile(
      physical: rack.tiles[index],
      rackIndex: index,
      playsAs: GameTile(color: TileColor.values[c], number: n),
    );
  }

  SolvedSpot _phantomSpot(int c, int n) {
    phantomUsed[c][n]++;
    return SolvedSpot.needed(
      playsAs: GameTile(color: TileColor.values[c], number: n),
    );
  }

  SolvedSpot _cell(int c, int n, {required bool isPhantom}) =>
      isPhantom ? _phantomSpot(c, n) : _realSpot(c, n);

  void _flushRun(int c, int s) {
    final spots = buffers[c][s]!;
    buffers[c][s] = null;
    melds.add(
      SolvedMeld(
        kind: MeldKind.run,
        spots: spots,
        points: spots.fold(0, (sum, spot) => sum + spot.playsAs.number!),
      ),
    );
  }

  void applyColumn(int n, OkeyColumnPlan plan, List<List<int>> values) {
    for (var c = 0; c < 4; c++) {
      final colorPlan = plan.colors[c];
      for (var s = 0; s < colorPlan.moveCodes.length; s++) {
        final move = colorPlan.moveCodes[s];
        final v = values[c][s];
        if (move == moveStay) continue;
        if (move == moveClose) {
          _flushRun(c, s);
          values[c][s] = 0;
          continue;
        }
        if (move == moveExtendReal || move == moveExtendSec) {
          buffers[c][s]!.add(_cell(c, n, isPhantom: move == moveExtendSec));
          values[c][s] = moveNewValue(move, v);
          continue;
        }
        if (move == moveOpenReal || move == moveOpenSec) {
          buffers[c][s] = [_cell(c, n, isPhantom: move == moveOpenSec)];
          values[c][s] = 1;
          continue;
        }
        if (moveExtendsBeforeClose(move)) {
          buffers[c][s]!.add(_cell(c, n, isPhantom: moveExtendCellIsSec(move)));
        }
        _flushRun(c, s);
        buffers[c][s] = [_cell(c, n, isPhantom: moveReopenCellIsSec(move))];
        values[c][s] = 1;
      }
      sortDescendingWith(values[c], buffers[c]);
    }
    _buildSets(n, plan);
    _buildPair(n, plan);
  }

  void _buildSets(int n, OkeyColumnPlan plan) {
    var total = 0;
    var maxPerColor = 0;
    for (final cp in plan.colors) {
      final members = cp.sigma + cp.phantomSigma;
      total += members;
      if (members > maxPerColor) maxPerColor = members;
    }
    if (total == 0) return;
    final k = setCloseCanonicalK(total, maxPerColor);
    final sets = List.generate(k, (_) => <SolvedSpot>[]);
    final setColors = List.generate(k, (_) => <int>{});
    for (var c = 0; c < 4; c++) {
      final cp = plan.colors[c];
      final members = cp.sigma + cp.phantomSigma;
      for (var j = 0; j < members; j++) {
        var target = -1;
        for (var i = 0; i < k; i++) {
          if (setColors[i].contains(c)) continue;
          if (target == -1 || sets[i].length < sets[target].length) {
            target = i;
          }
        }
        sets[target].add(_cell(c, n, isPhantom: j >= cp.sigma));
        setColors[target].add(c);
      }
    }
    for (final spots in sets) {
      spots.sort(
        (a, b) => a.playsAs.color.index.compareTo(b.playsAs.color.index),
      );
      melds.add(
        SolvedMeld(kind: MeldKind.set, spots: spots, points: n * spots.length),
      );
    }
  }

  void _buildPair(int n, OkeyColumnPlan plan) {
    for (var c = 0; c < 4; c++) {
      final cp = plan.colors[c];
      final cells = cp.pairReal + cp.pairPhantom;
      if (cells == 0) continue;
      assert(pair == null && cells == 2, 'exactly one final pair');
      final spots = [
        for (var j = 0; j < 2; j++) _cell(c, n, isPhantom: j >= cp.pairReal),
      ];
      pair = SolvedPair(
        identity: GameTile(color: TileColor.values[c], number: n),
        first: spots[0],
        second: spots[1],
      );
    }
  }

  void flushAll(List<List<int>> values) {
    for (var c = 0; c < 4; c++) {
      for (var s = 0; s < buffers[c].length; s++) {
        if (buffers[c][s] != null) {
          _flushRun(c, s);
          values[c][s] = 0;
        }
      }
    }
  }

  /// Pads the terminal gap (0 or ≥ 3) to exactly 14 cells with canonical
  /// all-phantom runs over kinds with remaining pool supply; degenerate
  /// racks fall back to the lowest kind — never crash.
  void pad() {
    var cells =
        melds.fold<int>(0, (sum, m) => sum + m.spots.length) +
        (pair == null ? 0 : 2);
    while (cells < 14) {
      final remaining = 14 - cells;
      final length = remaining == 4 || remaining == 5 ? remaining : 3;
      var placed = false;
      for (var c = 0; c < 4 && !placed; c++) {
        for (var start = 1; start <= 14 - length && !placed; start++) {
          var fits = true;
          for (var m = start; m < start + length; m++) {
            if (rack.phantomBudget(c, m) - phantomUsed[c][m] < 1) {
              fits = false;
              break;
            }
          }
          if (!fits) continue;
          _padRun(c, start, length);
          placed = true;
        }
      }
      if (!placed) _padRun(0, 1, length);
      cells += length;
    }
  }

  void _padRun(int c, int start, int length) {
    melds.add(
      SolvedMeld(
        kind: MeldKind.run,
        spots: [
          for (var m = start; m < start + length; m++) _phantomSpot(c, m),
        ],
        points: List.generate(
          length,
          (i) => start + i,
        ).fold(0, (sum, m) => sum + m),
      ),
    );
  }
}
