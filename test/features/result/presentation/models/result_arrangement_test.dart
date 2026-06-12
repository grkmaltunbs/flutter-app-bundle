import 'package:checks/checks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:okey_acar_mi/core/game/game_tile.dart';
import 'package:okey_acar_mi/core/game/tile_color.dart';
import 'package:okey_acar_mi/core/theme/app_accent.dart';
import 'package:okey_acar_mi/core/theme/app_palette.dart';
import 'package:okey_acar_mi/core/theme/app_theme.dart';
import 'package:okey_acar_mi/core/theme/tile_style.dart';
import 'package:okey_acar_mi/core/widgets/tile_data.dart';
import 'package:okey_acar_mi/features/result/presentation/models/result_arrangement.dart';
import 'package:okey_acar_mi/features/result/presentation/widgets/result_rack_layout.dart';
import 'package:okey_acar_mi/features/solver/domain/entities/solve_result.dart';
import 'package:okey_acar_mi/features/solver/domain/entities/solve_verdict.dart';
import 'package:okey_acar_mi/features/solver/domain/entities/solved_meld.dart';
import 'package:okey_acar_mi/features/solver/domain/entities/solved_pair.dart';
import 'package:okey_acar_mi/features/solver/domain/entities/solved_spot.dart';

GameTile _t(TileColor color, int number) =>
    GameTile(color: color, number: number);

const GameTile _joker = GameTile(color: TileColor.joker);

SolvedSpot _rack(TileColor color, int number, int rackIndex) =>
    SolvedSpot.rackTile(
      physical: _t(color, number),
      rackIndex: rackIndex,
      playsAs: _t(color, number),
    );

SolvedSpot _wild(TileColor playsColor, int playsNumber, int rackIndex) =>
    SolvedSpot.wild(
      physical: _joker,
      rackIndex: rackIndex,
      playsAs: _t(playsColor, playsNumber),
    );

SolvedSpot _needed(TileColor color, int number) =>
    SolvedSpot.needed(playsAs: _t(color, number));

SolvedMeld _run(List<SolvedSpot> spots, int points) =>
    SolvedMeld(kind: MeldKind.run, spots: spots, points: points);

SolvedMeld _set(List<SolvedSpot> spots, int points) =>
    SolvedMeld(kind: MeldKind.set, spots: spots, points: points);

SolvedPair _pair(SolvedSpot first, SolvedSpot second) {
  final identity = switch (first) {
    RackSpot(:final playsAs) => playsAs,
    WildSpot(:final playsAs) => playsAs,
    NeededSpot(:final playsAs) => playsAs,
  };
  return SolvedPair(identity: identity, first: first, second: second);
}

SolveResult _result({
  List<SolvedMeld> melds = const [],
  List<SolvedPair> pairs = const [],
  List<SolvedSpot> leftovers = const [],
  SolveVerdict verdict = const SolveVerdict.opens101(
    score: 104,
    via: OpenPath.melds,
  ),
  int totalScore = 104,
  GameTile? discardSuggested,
  int? discardRackIndex,
}) {
  return SolveResult(
    melds: melds,
    pairs: pairs,
    leftovers: leftovers,
    totalScore: totalScore,
    verdict: verdict,
    reasoning: const [],
    discardSuggested: discardSuggested,
    discardRackIndex: discardRackIndex,
  );
}

void main() {
  // AppTheme resolves google_fonts text styles, which needs the binding.
  TestWidgetsFlutterBinding.ensureInitialized();

  group('group ordering', () {
    test('melds come first (formation order), then pairs, then leftovers; '
        'kinds and points map through', () {
      final arrangement = ResultArrangement.of(
        _result(
          melds: [
            _run(
              [
                _rack(TileColor.red, 1, 0),
                _rack(TileColor.red, 2, 1),
                _rack(TileColor.red, 3, 2),
              ],
              6,
            ),
            _set(
              [
                _rack(TileColor.red, 4, 3),
                _rack(TileColor.blue, 4, 4),
                _rack(TileColor.black, 4, 5),
              ],
              12,
            ),
          ],
          pairs: [
            _pair(_rack(TileColor.yellow, 5, 6), _rack(TileColor.yellow, 5, 7)),
          ],
          leftovers: [
            _rack(TileColor.black, 9, 8),
            _rack(TileColor.blue, 11, 9),
          ],
        ),
      );

      check(arrangement.groups.length).equals(3);
      check(arrangement.groups[0].kind).equals(ResultGroupKind.run);
      check(arrangement.groups[0].points).equals(6);
      check(arrangement.groups[1].kind).equals(ResultGroupKind.set);
      check(arrangement.groups[1].points).equals(12);
      check(arrangement.groups[2].kind).equals(ResultGroupKind.pair);
      // Pairs score no points — the legend renders "—".
      check(arrangement.groups[2].points).isNull();

      // Cells carry their owning group's index; leftovers carry -1.
      check(
        arrangement.groups[0].cells.map((c) => c.groupIndex),
      ).every((it) => it.equals(0));
      check(
        arrangement.groups[1].cells.map((c) => c.groupIndex),
      ).every((it) => it.equals(1));
      check(
        arrangement.groups[2].cells.map((c) => c.groupIndex),
      ).every((it) => it.equals(2));
      check(
        arrangement.leftovers.map((c) => c.groupIndex),
      ).every((it) => it.equals(-1));

      // allCells is the display order: group cells first, leftovers last.
      check(arrangement.allCells.length).equals(10);
      check(arrangement.allCells.sublist(8)).deepEquals(arrangement.leftovers);
      check(arrangement.allCells.first.tile).equals(
        const TileData(color: TileColor.red, number: 1),
      );
    });

    test('okey meldsAndPair populates BOTH melds and pairs, with the final '
        'pair as the last group', () {
      final arrangement = ResultArrangement.of(
        _result(
          melds: [
            _run(
              [
                _rack(TileColor.red, 5, 0),
                _rack(TileColor.red, 6, 1),
                _rack(TileColor.red, 7, 2),
              ],
              18,
            ),
            _run(
              [
                _rack(TileColor.black, 1, 3),
                _rack(TileColor.black, 2, 4),
                _rack(TileColor.black, 3, 5),
              ],
              6,
            ),
          ],
          pairs: [
            _pair(_rack(TileColor.yellow, 4, 6), _rack(TileColor.yellow, 4, 7)),
          ],
          verdict: const SolveVerdict.okeyOutcome(
            tilesToWin: 1,
            via: OkeyPath.meldsAndPair,
          ),
        ),
      );

      check(arrangement.groups.length).equals(3);
      check(arrangement.groups[0].kind).equals(ResultGroupKind.run);
      check(arrangement.groups[1].kind).equals(ResultGroupKind.run);
      check(arrangement.groups.last.kind).equals(ResultGroupKind.pair);
      check(arrangement.groups.last.cells.length).equals(2);
      check(
        arrangement.groups.last.cells.map((c) => c.groupIndex),
      ).every((it) => it.equals(2));
    });

    test('okey sevenPairs: seven pair groups, no melds, no points', () {
      final arrangement = ResultArrangement.of(
        _result(
          pairs: [
            for (var n = 1; n <= 7; n++)
              _pair(
                _rack(TileColor.blue, n, 2 * (n - 1)),
                _rack(TileColor.blue, n, 2 * (n - 1) + 1),
              ),
          ],
          verdict: const SolveVerdict.okeyOutcome(
            tilesToWin: 0,
            via: OkeyPath.sevenPairs,
          ),
        ),
      );

      check(arrangement.groups.length).equals(7);
      for (final group in arrangement.groups) {
        check(group.kind).equals(ResultGroupKind.pair);
        check(group.points).isNull();
        check(group.cells.length).equals(2);
      }
      check(arrangement.leftovers).isEmpty();
    });

    test('DoesNotOpen101 with zero melds: every cell is a leftover', () {
      final leftovers = [
        _rack(TileColor.red, 1, 0),
        _rack(TileColor.blue, 7, 1),
        _wild(TileColor.black, 9, 2),
      ];
      final arrangement = ResultArrangement.of(
        _result(
          leftovers: leftovers,
          verdict: const SolveVerdict.doesNotOpen101(
            score: 0,
            pointsShort: 101,
          ),
          totalScore: 0,
        ),
      );

      check(arrangement.groups).isEmpty();
      check(arrangement.leftovers.length).equals(3);
      check(arrangement.allCells).deepEquals(arrangement.leftovers);
      check(arrangement.neededCount).equals(0);
    });
  });

  group('ring color cycling', () {
    final palette = AppTheme.light(
      AppAccent.sage,
      TileStyle.classic,
    ).extension<AppPalette>()!;

    test('more than 4 groups: group indices keep counting while the ring '
        'color cycles mod 4', () {
      final arrangement = ResultArrangement.of(
        _result(
          melds: [
            for (var i = 0; i < 5; i++)
              _set(
                [
                  _rack(TileColor.red, i + 1, 3 * i),
                  _rack(TileColor.blue, i + 1, 3 * i + 1),
                  _rack(TileColor.black, i + 1, 3 * i + 2),
                ],
                3 * (i + 1),
              ),
          ],
        ),
      );

      check(arrangement.groups.length).equals(5);
      check(arrangement.groups[4].cells.first.groupIndex).equals(4);

      // The first four ring colors are pairwise distinct…
      final firstCycle = [
        for (var i = 0; i < 4; i++) resultGroupRingColor(palette, i),
      ];
      check(firstCycle.toSet().length).equals(4);
      // …and index 4/5 wrap back onto 0/1.
      check(resultGroupRingColor(palette, 4)).equals(firstCycle[0]);
      check(resultGroupRingColor(palette, 5)).equals(firstCycle[1]);
    });
  });

  group('spot → cell flag mapping', () {
    test('NeededSpot maps to isNeeded with the playsAs identity', () {
      final arrangement = ResultArrangement.of(
        _result(
          melds: [
            _set(
              [
                _rack(TileColor.red, 13, 0),
                _rack(TileColor.blue, 13, 1),
                _needed(TileColor.black, 13),
              ],
              39,
            ),
          ],
          verdict: const SolveVerdict.okeyOutcome(
            tilesToWin: 1,
            via: OkeyPath.meldsAndPair,
          ),
        ),
      );

      final needed = arrangement.groups[0].cells[2];
      check(needed.isNeeded).isTrue();
      check(needed.isWild).isFalse();
      check(needed.isDiscard).isFalse();
      check(needed.tile).equals(
        const TileData(color: TileColor.black, number: 13),
      );
      check(arrangement.neededCount).equals(1);
    });

    test('WildSpot maps to isWild rendering its playsAs identity', () {
      final arrangement = ResultArrangement.of(
        _result(
          melds: [
            _run(
              [
                _rack(TileColor.yellow, 11, 0),
                _wild(TileColor.yellow, 12, 1),
                _rack(TileColor.yellow, 13, 2),
              ],
              36,
            ),
          ],
        ),
      );

      final wild = arrangement.groups[0].cells[1];
      check(wild.isWild).isTrue();
      check(wild.isNeeded).isFalse();
      check(wild.tile).equals(
        const TileData(color: TileColor.yellow, number: 12),
      );
    });

    test('discardRackIndex flags the matching cell — including a leftover '
        '(groupIndex -1) and a wild', () {
      final arrangement = ResultArrangement.of(
        _result(
          melds: [
            _run(
              [
                _rack(TileColor.red, 5, 0),
                _rack(TileColor.red, 6, 1),
                _wild(TileColor.red, 7, 2),
              ],
              18,
            ),
          ],
          leftovers: [
            _rack(TileColor.black, 8, 3),
            _rack(TileColor.red, 13, 4),
          ],
          verdict: const SolveVerdict.okeyOutcome(
            tilesToWin: 2,
            via: OkeyPath.meldsAndPair,
          ),
          discardSuggested: _t(TileColor.red, 13),
          discardRackIndex: 4,
        ),
      );

      // The leftover at rackIndex 4 is the discard; its sibling is not.
      check(arrangement.leftovers[1].isDiscard).isTrue();
      check(arrangement.leftovers[1].groupIndex).equals(-1);
      check(arrangement.leftovers[0].isDiscard).isFalse();
      // No melded cell picked up the flag.
      for (final cell in arrangement.groups[0].cells) {
        check(cell.isDiscard).isFalse();
      }
    });

    test('a WildSpot sitting at the discard index carries both flags', () {
      final arrangement = ResultArrangement.of(
        _result(
          leftovers: [_wild(TileColor.blue, 9, 7)],
          verdict: const SolveVerdict.okeyOutcome(
            tilesToWin: 3,
            via: OkeyPath.meldsAndPair,
          ),
          discardSuggested: _joker,
          discardRackIndex: 7,
        ),
      );

      final cell = arrangement.leftovers.single;
      check(cell.isWild).isTrue();
      check(cell.isDiscard).isTrue();
    });

    test('neededCount only counts needed phantoms inside groups', () {
      final arrangement = ResultArrangement.of(
        _result(
          melds: [
            _set(
              [
                _rack(TileColor.red, 10, 0),
                _needed(TileColor.blue, 10),
                _needed(TileColor.black, 10),
              ],
              30,
            ),
          ],
          pairs: [
            _pair(_rack(TileColor.yellow, 2, 1), _needed(TileColor.yellow, 2)),
          ],
          leftovers: [_rack(TileColor.black, 5, 2)],
          verdict: const SolveVerdict.okeyOutcome(
            tilesToWin: 3,
            via: OkeyPath.meldsAndPair,
          ),
        ),
      );

      check(arrangement.neededCount).equals(3);
    });
  });
}
