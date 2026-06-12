import 'package:flutter/foundation.dart';
import 'package:okey_acar_mi/core/widgets/tile_data.dart';
import 'package:okey_acar_mi/features/solver/domain/entities/solve_result.dart';
import 'package:okey_acar_mi/features/solver/domain/entities/solved_meld.dart';
import 'package:okey_acar_mi/features/solver/domain/entities/solved_spot.dart';

/// The display kind of a [ResultGroup].
enum ResultGroupKind {
  /// A run meld (same color, consecutive numbers).
  run,

  /// A set meld (same number, distinct colors).
  set,

  /// A pair (pairs-path / okey final pair).
  pair,
}

/// One display cell of the arranged result rack.
///
/// [tile] always carries the **playsAs** identity (a wild renders the tile it
/// stands in for, with a wild badge), so the arrangement reads as the legal
/// hand it represents.
@immutable
class ResultCell {
  /// Creates a [ResultCell].
  const ResultCell({
    required this.tile,
    required this.groupIndex,
    this.isWild = false,
    this.isNeeded = false,
    this.isDiscard = false,
  });

  /// The identity to render (playsAs), as core tile data.
  final TileData tile;

  /// Index of the owning group in [ResultArrangement.groups], or `-1` for a
  /// leftover cell. The ring color is resolved from this index at render
  /// time.
  final int groupIndex;

  /// Whether a wild (joker or okey copy) occupies this cell.
  final bool isWild;

  /// Whether this cell is a still-needed phantom tile (okey mode only).
  final bool isNeeded;

  /// Whether this cell holds the suggested discard (matched by rack index).
  final bool isDiscard;

  @override
  bool operator ==(Object other) =>
      other is ResultCell &&
      other.tile == tile &&
      other.groupIndex == groupIndex &&
      other.isWild == isWild &&
      other.isNeeded == isNeeded &&
      other.isDiscard == isDiscard;

  @override
  int get hashCode =>
      Object.hash(tile, groupIndex, isWild, isNeeded, isDiscard);
}

/// A display group of the arranged result: a meld or a pair.
@immutable
class ResultGroup {
  /// Creates a [ResultGroup].
  const ResultGroup({
    required this.kind,
    required this.cells,
    this.points,
  });

  /// What the group is (run / set / pair).
  final ResultGroupKind kind;

  /// The group's cells in arranged order.
  final List<ResultCell> cells;

  /// The meld's face-value points; null for pairs (pairs score no points —
  /// the legend shows "—").
  final int? points;
}

/// Pure display mapping of a [SolveResult]: the groups (melds then pairs) in
/// arranged order plus the leftover cells, ready for the rack and list
/// layouts.
///
/// Covers every verdict shape: okey `meldsAndPair` populates both melds and
/// pairs (the final pair comes last), `DoesNotOpen101` may carry zero groups
/// (everything leftover).
@immutable
class ResultArrangement {
  const ResultArrangement._({required this.groups, required this.leftovers});

  /// Builds the arrangement from [result].
  factory ResultArrangement.of(SolveResult result) {
    final groups = <ResultGroup>[];
    var groupIndex = 0;

    ResultCell cellOf(SolvedSpot spot, int index) => switch (spot) {
      RackSpot(:final playsAs, :final rackIndex) => ResultCell(
        tile: TileData(color: playsAs.color, number: playsAs.number),
        groupIndex: index,
        isDiscard: rackIndex == result.discardRackIndex,
      ),
      WildSpot(:final playsAs, :final rackIndex) => ResultCell(
        tile: TileData(color: playsAs.color, number: playsAs.number),
        groupIndex: index,
        isWild: true,
        isDiscard: rackIndex == result.discardRackIndex,
      ),
      NeededSpot(:final playsAs) => ResultCell(
        tile: TileData(color: playsAs.color, number: playsAs.number),
        groupIndex: index,
        isNeeded: true,
      ),
    };

    for (final meld in result.melds) {
      groups.add(
        ResultGroup(
          kind: meld.kind == MeldKind.run
              ? ResultGroupKind.run
              : ResultGroupKind.set,
          cells: List.unmodifiable([
            for (final spot in meld.spots) cellOf(spot, groupIndex),
          ]),
          points: meld.points,
        ),
      );
      groupIndex++;
    }
    for (final pair in result.pairs) {
      groups.add(
        ResultGroup(
          kind: ResultGroupKind.pair,
          cells: List.unmodifiable([
            cellOf(pair.first, groupIndex),
            cellOf(pair.second, groupIndex),
          ]),
        ),
      );
      groupIndex++;
    }

    return ResultArrangement._(
      groups: List.unmodifiable(groups),
      leftovers: List.unmodifiable([
        for (final spot in result.leftovers) cellOf(spot, -1),
      ]),
    );
  }

  /// The display groups: melds in formation order, then pairs.
  final List<ResultGroup> groups;

  /// Unused rack tiles in rack order (groupIndex `-1`, rendered faded).
  final List<ResultCell> leftovers;

  /// Every cell in arranged order (groups first, then leftovers) — the order
  /// the result rack displays, **not** the physical rack order.
  List<ResultCell> get allCells => List.unmodifiable([
    for (final group in groups) ...group.cells,
    ...leftovers,
  ]);

  /// How many cells are still-needed phantoms (okey mode only).
  int get neededCount => groups
      .expand((group) => group.cells)
      .where((cell) => cell.isNeeded)
      .length;
}
