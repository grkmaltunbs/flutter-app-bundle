import 'package:okey_acar_mi/core/game/game_tile.dart';
import 'package:okey_acar_mi/core/game/indicator.dart';
import 'package:okey_acar_mi/core/game/tile_color.dart';

/// A kind whose copies were clamped (degenerate edits), with the drop count.
class ClampedKind {
  /// Creates a [ClampedKind].
  const ClampedKind({required this.kind, required this.dropped});

  /// The over-supplied identity.
  final GameTile kind;

  /// How many copies beyond 4 were dropped (forced leftovers).
  final int dropped;
}

/// Normalized view of a rack: per-kind counts, wilds, slot widths and
/// deterministic instance queues for physical binding.
class NormalizedRack {
  /// Creates a [NormalizedRack]. Build via [RackNormalizer.normalize].
  const NormalizedRack({
    required this.tiles,
    required this.okeyTile,
    required this.counts,
    required this.wildCount,
    required this.falseJokerCount,
    required this.okeyCopyCount,
    required this.instanceQueues,
    required this.wildQueue,
    required this.scoreSlots,
    required this.okeySlots,
    required this.clamped,
    required this.forcedLeftoverIndices,
  });

  /// The original rack, in rack order.
  final List<GameTile> tiles;

  /// The okey identity for the round.
  final GameTile okeyTile;

  /// `counts[c][n]` for the 4 real colors (by enum index) × numbers 1–13,
  /// excluding wilds, clamped at 4 per kind. Index 0 unused.
  final List<List<int>> counts;

  /// Total wilds: false jokers + physical okey copies.
  final int wildCount;

  /// Physical joker tiles on the rack.
  final int falseJokerCount;

  /// Physical copies of the okey tile on the rack.
  final int okeyCopyCount;

  /// `instanceQueues[c][n]` → rack indices of that kind, ascending.
  final List<List<List<int>>> instanceQueues;

  /// Wild rack indices: false jokers first, then okey copies, each ascending.
  final List<int> wildQueue;

  /// 101-DP slot widths per color, overflow-capped:
  /// `min(max(2, ⌊(T_c + W) / 3⌋), T_c + designatedBonus)` where the
  /// designated color ([RackNormalizer.designatedColor]) gets `+1` when
  /// `W ≥ 5` (the only wild count whose optimum can need a pure-wild RUN —
  /// the run `9..13 = 55` beats the 4-set `52`; every other wild total
  /// melds at least as well via 13-sets, which close slot-free).
  /// Simultaneous real-containing runs of color c never exceed `T_c`
  /// (disjoint cells, each run holds ≥ 1 real c-tile), so the min is a
  /// pure search-space restriction — exactness is untouched.
  final List<int> scoreSlots;

  /// Okey-DP slot widths per color: `max(2, max_n rackCopies(c, n))`.
  final List<int> okeySlots;

  /// Kinds clamped at 4 copies (degenerate edits only).
  final List<ClampedKind> clamped;

  /// Rack indices dropped by clamping — forced leftovers.
  final List<int> forcedLeftoverIndices;

  /// Phantom supply for kind `(c, n)`: the 106-tile set holds 2 copies.
  /// Physical okey copies held on the rack count as wilds (not in
  /// [counts]) but still deplete the pool, so they are subtracted for the
  /// okey identity — displayed needed tiles must always stay drawable.
  int phantomBudget(int color, int number) {
    var remaining = 2 - counts[color][number];
    if (color == okeyTile.color.index && number == okeyTile.number) {
      remaining -= okeyCopyCount;
    }
    return remaining > 0 ? remaining : 0;
  }
}

/// Builds a [NormalizedRack] from raw tiles + indicator. Never throws.
class RackNormalizer {
  /// Creates a [RackNormalizer].
  const RackNormalizer();

  /// Slot-width safety cap: exact for any rack where `T_c + W ≤ 23`
  /// (every mode-legal rack, max 21 tiles, is well inside). Beyond that —
  /// absurd garbage only — the cap keeps the packed state key in 64 bits;
  /// results stay legal and deterministic.
  static const int maxSlots = 7;

  /// The color hosting the (at most one) pure-wild run slot when `W ≥ 5`.
  /// A pure-wild run is color-neutral (every cell is a wild, and wild
  /// substitution is supply-unconstrained), so it canonically lives here.
  static const TileColor designatedColor = TileColor.red;

  /// Normalizes [tiles] against [indicator].
  NormalizedRack normalize(List<GameTile> tiles, Indicator indicator) {
    final okeyTile = indicator.okeyTile;
    final counts = List.generate(4, (_) => List.filled(14, 0));
    final queues = List.generate(
      4,
      (_) => List.generate(14, (_) => <int>[]),
    );
    final jokerIndices = <int>[];
    final okeyCopyIndices = <int>[];
    final forcedLeftovers = <int>[];
    final clamped = <ClampedKind>[];

    for (var i = 0; i < tiles.length; i++) {
      final tile = tiles[i];
      if (tile.isJoker) {
        jokerIndices.add(i);
        continue;
      }
      if (tile == okeyTile) {
        okeyCopyIndices.add(i);
        continue;
      }
      final number = tile.number;
      if (number == null || number < 1 || number > 13) continue;
      final color = tile.color.index;
      if (counts[color][number] >= 4) {
        forcedLeftovers.add(i);
        final existing = clamped.indexWhere((c) => c.kind == tile);
        if (existing >= 0) {
          clamped[existing] = ClampedKind(
            kind: tile,
            dropped: clamped[existing].dropped + 1,
          );
        } else {
          clamped.add(ClampedKind(kind: tile, dropped: 1));
        }
        continue;
      }
      counts[color][number]++;
      queues[color][number].add(i);
    }

    final wildCount = jokerIndices.length + okeyCopyIndices.length;
    final scoreSlots = <int>[];
    final okeySlots = <int>[];
    for (var c = 0; c < 4; c++) {
      var total = 0;
      var maxCopies = 0;
      for (var n = 1; n <= 13; n++) {
        total += counts[c][n];
        if (counts[c][n] > maxCopies) maxCopies = counts[c][n];
      }
      final wide = (total + wildCount) ~/ 3;
      var slots = wide > 2 ? wide : 2;
      final designatedBonus = c == designatedColor.index && wildCount >= 5
          ? 1
          : 0;
      final realRunBound = total + designatedBonus;
      if (realRunBound < slots) slots = realRunBound;
      if (slots > maxSlots) slots = maxSlots;
      scoreSlots.add(slots);
      okeySlots.add(maxCopies > 2 ? maxCopies : 2);
    }

    return NormalizedRack(
      tiles: tiles,
      okeyTile: okeyTile,
      counts: counts,
      wildCount: wildCount,
      falseJokerCount: jokerIndices.length,
      okeyCopyCount: okeyCopyIndices.length,
      instanceQueues: queues,
      wildQueue: [...jokerIndices, ...okeyCopyIndices],
      scoreSlots: scoreSlots,
      okeySlots: okeySlots,
      clamped: clamped,
      forcedLeftoverIndices: forcedLeftovers,
    );
  }
}
