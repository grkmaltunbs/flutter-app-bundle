import 'package:okey_acar_mi/core/game/game_tile.dart';
import 'package:okey_acar_mi/core/game/tile_color.dart';
import 'package:okey_acar_mi/features/solver/domain/engine/meld_score_dp.dart';
import 'package:okey_acar_mi/features/solver/domain/engine/meld_validator.dart';
import 'package:okey_acar_mi/features/solver/domain/engine/rack_normalizer.dart';
import 'package:okey_acar_mi/features/solver/domain/engine/transition_tables.dart';
import 'package:okey_acar_mi/features/solver/domain/entities/solved_meld.dart';
import 'package:okey_acar_mi/features/solver/domain/entities/solved_spot.dart';

/// A reconstructed meld arrangement plus the rack indices it consumed.
class MeldArrangement {
  /// Creates a [MeldArrangement].
  const MeldArrangement({required this.melds, required this.usedRackIndices});

  /// Melds in deterministic formation order (column ascending).
  final List<SolvedMeld> melds;

  /// Rack indices bound into [melds].
  final Set<int> usedRackIndices;
}

/// §2 reconstruction: backtracks the DP parent chain, re-enumerates each
/// column transition canonically, and binds physical tiles.
class MeldReconstructor {
  /// Creates a [MeldReconstructor].
  const MeldReconstructor();

  /// Rebuilds the winning arrangement of [result] for [rack].
  MeldArrangement reconstruct(NormalizedRack rack, MeldScoreDpResult result) {
    const dp = MeldScoreDp();
    final spaces = dp.spacesFor(rack);

    // Backtrack the parent chain: keys/values at levels 1..14.
    final keys = List<int>.filled(15, 0);
    keys[14] = result.winnerKey;
    for (var n = 13; n >= 1; n--) {
      keys[n] = result.parents[n + 1]![keys[n + 1]]!;
    }
    final chainValues = [
      0,
      for (var n = 1; n <= 14; n++) result.values[n]![keys[n]]!,
    ];

    final builder = _ArrangementBuilder(rack);
    final values = [
      for (var c = 0; c < 4; c++) List<int>.filled(spaces[c].slotCount, 0),
    ];
    final idx = List<int>.filled(4, 0);

    for (var n = 1; n <= 13; n++) {
      // The replayed tuples must match the DP state exactly.
      dp.unpackKey(spaces, keys[n], rack.wildCount, idx);
      assert(
        () {
          for (var c = 0; c < 4; c++) {
            final tuple = spaces[c].tuples[idx[c]];
            for (var s = 0; s < tuple.length; s++) {
              if (tuple[s] != values[c][s]) return false;
            }
          }
          return true;
        }(),
        'replayed slot tuples diverged from the DP chain at column $n',
      );

      ColumnPlan? plan;
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
      // Parent pointers are written only on realized transitions, so a
      // canonical chain always reproduces (key, ΔV).
      builder.applyColumn(n, plan!, values);
    }

    builder.flushAll(values);

    assert(
      builder.melds.fold<int>(0, (sum, m) => sum + m.points) == result.best,
      'reconstructed meld points must equal the DP value',
    );
    assert(
      builder.melds.every(const MeldValidator().isValidMeld),
      'every reconstructed meld must pass MeldValidator',
    );

    return MeldArrangement(
      melds: builder.melds,
      usedRackIndices: builder.used,
    );
  }
}

class _ArrangementBuilder {
  _ArrangementBuilder(this.rack)
    : queuePos = List.generate(4, (_) => List<int>.filled(14, 0)),
      buffers = [
        for (var c = 0; c < 4; c++)
          List<List<SolvedSpot>?>.filled(rack.scoreSlots[c], null),
      ];

  final NormalizedRack rack;
  final List<List<int>> queuePos;
  final List<List<List<SolvedSpot>?>> buffers;
  final List<SolvedMeld> melds = [];
  final Set<int> used = {};
  int wildPos = 0;

  SolvedSpot _realSpot(int c, int n) {
    final index = rack.instanceQueues[c][n][queuePos[c][n]++];
    used.add(index);
    return SolvedSpot.rackTile(
      physical: rack.tiles[index],
      rackIndex: index,
      playsAs: GameTile(color: TileColor.values[c], number: n),
    );
  }

  SolvedSpot _wildSpot(GameTile playsAs) {
    final index = rack.wildQueue[wildPos++];
    used.add(index);
    return SolvedSpot.wild(
      physical: rack.tiles[index],
      rackIndex: index,
      playsAs: playsAs,
    );
  }

  SolvedSpot _cell(int c, int n, {required bool isSec}) => isSec
      ? _wildSpot(GameTile(color: TileColor.values[c], number: n))
      : _realSpot(c, n);

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

  /// Applies one column's replayed [plan]; mutates [values] in place.
  void applyColumn(int n, ColumnPlan plan, List<List<int>> values) {
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
          buffers[c][s]!.add(_cell(c, n, isSec: move == moveExtendSec));
          values[c][s] = moveNewValue(move, v);
          continue;
        }
        if (move == moveOpenReal || move == moveOpenSec) {
          buffers[c][s] = [_cell(c, n, isSec: move == moveOpenSec)];
          values[c][s] = 1;
          continue;
        }
        // Composites: optionally extend into n, close, reopen at n.
        if (moveExtendsBeforeClose(move)) {
          buffers[c][s]!.add(_cell(c, n, isSec: moveExtendCellIsSec(move)));
        }
        _flushRun(c, s);
        buffers[c][s] = [_cell(c, n, isSec: moveReopenCellIsSec(move))];
        values[c][s] = 1;
      }
      sortDescendingWith(values[c], buffers[c]);
    }
    _buildSets(n, plan);
  }

  void _buildSets(int n, ColumnPlan plan) {
    final sigmas = [for (final cp in plan.colors) cp.sigma];
    final ws = plan.wildsForSets;
    final total = sigmas.fold<int>(0, (a, b) => a + b) + ws;
    if (total == 0) return;
    final maxSigma = sigmas.fold<int>(0, (a, b) => a > b ? a : b);
    final k = setCloseCanonicalK(total, maxSigma);
    final sets = List.generate(k, (_) => <SolvedSpot>[]);
    final setColors = List.generate(k, (_) => <int>{});

    // Real copies: per color, deal to the fewest-member sets not already
    // holding that color (tie → lowest index).
    for (var c = 0; c < 4; c++) {
      for (var j = 0; j < sigmas[c]; j++) {
        var target = -1;
        for (var i = 0; i < k; i++) {
          if (setColors[i].contains(c)) continue;
          if (target == -1 || sets[i].length < sets[target].length) {
            target = i;
          }
        }
        sets[target].add(_realSpot(c, n));
        setColors[target].add(c);
      }
    }
    // Wilds: fewest-members-first; playsAs = lowest-enum missing color.
    for (var j = 0; j < ws; j++) {
      var target = 0;
      for (var i = 1; i < k; i++) {
        if (sets[i].length < sets[target].length) target = i;
      }
      var color = 0;
      while (setColors[target].contains(color)) {
        color++;
      }
      setColors[target].add(color);
      sets[target].add(
        _wildSpot(GameTile(color: TileColor.values[color], number: n)),
      );
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

  /// Flushes runs still open after column 13 (terminal slots of value 3).
  void flushAll(List<List<int>> values) {
    for (var c = 0; c < 4; c++) {
      for (var s = 0; s < buffers[c].length; s++) {
        if (buffers[c][s] != null) {
          assert(values[c][s] == 3, 'only complete runs survive column 13');
          _flushRun(c, s);
          values[c][s] = 0;
        }
      }
    }
  }
}
