import 'package:okey_acar_mi/core/error/failure.dart';
import 'package:okey_acar_mi/core/game/game_mode.dart';
import 'package:okey_acar_mi/core/game/game_tile.dart';
import 'package:okey_acar_mi/core/game/tile_color.dart';
import 'package:okey_acar_mi/core/time/clock.dart';
import 'package:okey_acar_mi/features/history/data/datasources/scan_remote_data_source.dart';
import 'package:okey_acar_mi/features/history/data/dtos/scan_dto.dart';
import 'package:okey_acar_mi/features/solver/domain/entities/solve_verdict.dart';

GameTile _t(TileColor color, int number) =>
    GameTile(color: color, number: number);

List<GameTile> _run(TileColor color, int from, int to) => [
  for (var n = from; n <= to; n++) _t(color, n),
];

List<GameTile> _set(int number, List<TileColor> colors) => [
  for (final color in colors) _t(color, number),
];

const TileColor _r = TileColor.red;
const TileColor _b = TileColor.black;
const TileColor _y = TileColor.yellow;
const TileColor _l = TileColor.blue;
const GameTile _joker = GameTile(color: TileColor.joker);

ScanSummaryDto _opens({required int score, required OpenPath via}) =>
    ScanSummaryDto(
      kind: 'opens101',
      opened: true,
      score: score,
      openPath: via.name,
    );

ScanSummaryDto _doesNotOpen({required int score}) => ScanSummaryDto(
  kind: 'doesNotOpen101',
  opened: false,
  score: score,
  pointsShort: 101 - score,
);

ScanSummaryDto _okey({
  required int tilesToWin,
  required OkeyPath via,
  required int score,
}) => ScanSummaryDto(
  kind: 'okeyOutcome',
  opened: tilesToWin == 0,
  score: score,
  tilesToWin: tilesToWin,
  okeyPath: via.name,
);

/// In-memory, seeded [ScanRemoteDataSource] for the demo flavor.
///
/// Deterministic, offline, instant — no Firestore. Seeded with 26 scans for
/// the seeded signed-in demo user (`FakeAuthRepository`'s `demo-oyuncu`):
/// 14 × opens101 (best 142, one via pairs, one 21-tile rack), 8 ×
/// doesNotOpen101 (varied shortfalls), 4 × okeyOutcome (two winning now,
/// one 1 away, one 2 away). Every seed's `(tiles, indicator, mode)`
/// re-solves to exactly its seeded summary — guaranteed by
/// `fake_scan_remote_data_source_seed_test.dart`.
///
/// [failNextFetch] / [failNextUpload] are demo/test seams that make the next
/// matching call throw `Failure.network` once, so offline/sync-retry paths
/// are exercisable without a backend. [uploadedScans] records every uploaded
/// DTO in order.
class FakeScanRemoteDataSource implements ScanRemoteDataSource {
  /// Creates a [FakeScanRemoteDataSource] with the demo seeds in place.
  FakeScanRemoteDataSource() {
    reset();
  }

  /// The seeded owner — `FakeAuthRepository`'s verified demo account uid.
  static const String seededOwnerId = 'demo-oyuncu';

  /// When `true`, the next [fetchAll] throws `Failure.network` (and resets
  /// the flag). Demo/test seam.
  bool failNextFetch = false;

  /// When `true`, the next [uploadAll] throws `Failure.network` (and resets
  /// the flag). Demo/test seam.
  bool failNextUpload = false;

  final Map<String, ScanDto> _docs = <String, ScanDto>{};
  final List<ScanDto> _uploaded = <ScanDto>[];

  /// Every DTO passed to [uploadAll], in call order (test seam).
  List<ScanDto> get uploadedScans => List.unmodifiable(_uploaded);

  /// Restores the seeded docs and clears the failure toggles + upload log.
  void reset() {
    failNextFetch = false;
    failNextUpload = false;
    _uploaded.clear();
    _docs
      ..clear()
      ..addEntries(seedScans().map((dto) => MapEntry(dto.id, dto)));
  }

  @override
  Future<List<ScanDto>> fetchAll(String ownerId) async {
    if (failNextFetch) {
      failNextFetch = false;
      throw const Failure.network();
    }
    final docs = _docs.values.where((dto) => dto.ownerId == ownerId).toList()
      ..sort((a, b) => b.createdAtMs.compareTo(a.createdAtMs));
    return docs;
  }

  @override
  Future<void> uploadAll(List<ScanDto> scans) async {
    if (failNextUpload) {
      failNextUpload = false;
      throw const Failure.network();
    }
    for (final dto in scans) {
      _docs[dto.id] = dto;
      _uploaded.add(dto);
    }
  }

  @override
  Future<void> deleteAllForOwner(String ownerId) async {
    _docs.removeWhere((_, dto) => dto.ownerId == ownerId);
  }

  /// Builds the 26 deterministic seed docs (newest first), timestamped
  /// relative to [FakeClock.seed]: the newest 20 hours ago, the rest spread
  /// 2–45 days back, all distinct.
  static List<ScanDto> seedScans() {
    var index = 0;
    ScanDto seed({
      required Duration age,
      required GameMode mode,
      required TileColor indicatorColor,
      required int indicatorNumber,
      required List<GameTile> tiles,
      required ScanSummaryDto summary,
    }) {
      index++;
      final at = FakeClock.seed.subtract(age).millisecondsSinceEpoch;
      return ScanDto(
        id: 'seed-scan-${index.toString().padLeft(2, '0')}',
        ownerId: seededOwnerId,
        createdAtMs: at,
        updatedAtMs: at,
        gameMode: mode.name,
        indicator: ScanIndicatorDto(
          color: indicatorColor.name,
          number: indicatorNumber,
        ),
        tiles: [for (final tile in tiles) ScanTileDto.fromTile(tile)],
        summary: summary,
      );
    }

    return [
      // 1 — the personal best: opens with exactly 142 via melds.
      seed(
        age: const Duration(hours: 20),
        mode: GameMode.oneZeroOne,
        indicatorColor: _b,
        indicatorNumber: 6,
        tiles: [
          ..._run(_l, 10, 13),
          ..._set(13, const [_r, _b, _y]),
          ..._set(10, const [_r, _b, _y]),
          ..._set(9, const [_r, _b, _y]),
          _t(_r, 1),
          _t(_y, 1),
          _t(_b, 2),
          _t(_l, 2),
          _t(_r, 4),
          _t(_y, 4),
          _t(_b, 5),
          _t(_r, 1), // dead leftover pair → 21 tiles
        ],
        summary: _opens(score: 142, via: OpenPath.melds),
      ),
      // 2 — close call: 87, fourteen short.
      seed(
        age: const Duration(days: 2),
        mode: GameMode.oneZeroOne,
        indicatorColor: _l,
        indicatorNumber: 10,
        tiles: [
          ..._run(_r, 5, 7),
          ..._run(_b, 9, 11),
          ..._set(13, const [_r, _y, _l]),
          _t(_r, 1),
          _t(_r, 3),
          _t(_r, 10),
          _t(_b, 2),
          _t(_b, 6),
          _t(_y, 1),
          _t(_y, 4),
          _t(_y, 6),
          _t(_l, 2),
          _t(_l, 5),
          _t(_l, 8),
          _t(_r, 1), // dead leftover pair → 21 tiles
        ],
        summary: _doesNotOpen(score: 87),
      ),
      // 3 — okey: winning hand right now (3+3+4+4).
      seed(
        age: const Duration(days: 3),
        mode: GameMode.okey,
        indicatorColor: _r,
        indicatorNumber: 12,
        tiles: [
          ..._run(_r, 1, 3),
          ..._run(_b, 1, 3),
          ..._run(_y, 5, 8),
          ..._run(_l, 9, 12),
        ],
        summary: _okey(tilesToWin: 0, via: OkeyPath.meldsAndPair, score: 80),
      ),
      // 4 — opens with 104.
      seed(
        age: const Duration(days: 4),
        mode: GameMode.oneZeroOne,
        indicatorColor: _y,
        indicatorNumber: 8,
        tiles: [
          ..._run(_b, 2, 5),
          ..._set(13, const [_r, _y, _l]),
          ..._set(10, const [_r, _y, _l]),
          ..._set(7, const [_r, _y, _l]),
          _t(_r, 1),
          _t(_y, 1),
          _t(_l, 6),
          _t(_r, 4),
          _t(_y, 4),
          _t(_l, 3),
          _t(_b, 8),
          _t(_r, 1), // dead leftover pair → 21 tiles
        ],
        summary: _opens(score: 104, via: OpenPath.melds),
      ),
      // 5 — nothing melds at all: the full 101 short.
      seed(
        age: const Duration(days: 5),
        mode: GameMode.oneZeroOne,
        indicatorColor: _y,
        indicatorNumber: 5,
        tiles: [
          for (final n in const [1, 1, 2, 4, 5, 7, 8]) _t(_r, n),
          for (final n in const [1, 2, 4, 5, 7, 8, 8]) _t(_b, n),
          for (final n in const [10, 11, 13]) _t(_y, n),
          for (final n in const [10, 11, 13]) _t(_l, n),
          _t(_r, 2), // dead leftover pair → 21 tiles
        ],
        summary: _doesNotOpen(score: 0),
      ),
      // 6 — opens via five pairs.
      seed(
        age: const Duration(days: 6),
        mode: GameMode.oneZeroOne,
        indicatorColor: _l,
        indicatorNumber: 13,
        tiles: [
          _t(_r, 2),
          _t(_r, 2),
          _t(_b, 4),
          _t(_b, 4),
          _t(_y, 6),
          _t(_y, 6),
          _t(_l, 8),
          _t(_l, 8),
          _t(_r, 11),
          _t(_r, 11),
          _t(_b, 1),
          _t(_y, 1),
          _t(_l, 3),
          _t(_r, 5),
          _t(_b, 7),
          _t(_y, 9),
          _t(_l, 11),
          _t(_b, 10),
          _t(_y, 12),
          _t(_l, 5),
          _t(_b, 10), // dead leftover pair → 21 tiles
        ],
        summary: _opens(score: 0, via: OpenPath.pairs),
      ),
      // 7 — okey: two exchanges away.
      seed(
        age: const Duration(days: 8),
        mode: GameMode.okey,
        indicatorColor: _b,
        indicatorNumber: 10,
        tiles: [
          ..._run(_r, 1, 3),
          ..._run(_b, 5, 7),
          ..._run(_y, 9, 11),
          _t(_l, 7),
          _t(_l, 8),
          _t(_b, 13),
          _t(_y, 1),
          _t(_r, 12),
        ],
        summary: _okey(tilesToWin: 2, via: OkeyPath.meldsAndPair, score: 54),
      ),
      // 8 — opens with 110.
      seed(
        age: const Duration(days: 9),
        mode: GameMode.oneZeroOne,
        indicatorColor: _b,
        indicatorNumber: 7,
        tiles: [
          ..._run(_r, 2, 5),
          ..._set(13, const [_b, _y, _l]),
          ..._set(10, const [_b, _y, _l]),
          ..._set(9, const [_b, _y, _l]),
          _t(_b, 1),
          _t(_l, 1),
          _t(_y, 2),
          _t(_l, 3),
          _t(_b, 4),
          _t(_y, 5),
          _t(_l, 6),
          _t(_l, 1), // dead leftover pair → 21 tiles
        ],
        summary: _opens(score: 110, via: OpenPath.melds),
      ),
      // 9 — a run and a set, still 35 short.
      seed(
        age: const Duration(days: 11),
        mode: GameMode.oneZeroOne,
        indicatorColor: _b,
        indicatorNumber: 11,
        tiles: [
          ..._run(_r, 11, 13),
          ..._set(10, const [_b, _y, _l]),
          _t(_r, 1),
          _t(_r, 3),
          _t(_r, 4),
          _t(_r, 7),
          _t(_b, 2),
          _t(_b, 3),
          _t(_b, 5),
          _t(_b, 8),
          _t(_y, 1),
          _t(_y, 4),
          _t(_y, 7),
          _t(_l, 2),
          _t(_l, 5),
          _t(_l, 8),
          _t(_r, 1), // dead leftover pair → 21 tiles
        ],
        summary: _doesNotOpen(score: 66),
      ),
      // 10 — opens with 116.
      seed(
        age: const Duration(days: 12),
        mode: GameMode.oneZeroOne,
        indicatorColor: _r,
        indicatorNumber: 8,
        tiles: [
          ..._run(_r, 2, 5),
          ..._set(13, const [_b, _y, _l]),
          ..._set(11, const [_b, _y, _l]),
          ..._set(10, const [_b, _y, _l]),
          _t(_b, 1),
          _t(_y, 1),
          _t(_l, 2),
          _t(_l, 5),
          _t(_b, 4),
          _t(_y, 4),
          _t(_y, 6),
          _t(_b, 1), // dead leftover pair → 21 tiles
        ],
        summary: _opens(score: 116, via: OpenPath.melds),
      ),
      // 11 — okey: one exchange away.
      seed(
        age: const Duration(days: 14),
        mode: GameMode.okey,
        indicatorColor: _r,
        indicatorNumber: 12,
        tiles: [
          ..._run(_r, 1, 3),
          ..._run(_b, 1, 3),
          ..._run(_y, 5, 8),
          ..._run(_l, 9, 11),
          _t(_y, 13),
        ],
        summary: _okey(tilesToWin: 1, via: OkeyPath.meldsAndPair, score: 68),
      ),
      // 12 — opens with exactly 101.
      seed(
        age: const Duration(days: 15),
        mode: GameMode.oneZeroOne,
        indicatorColor: _b,
        indicatorNumber: 8,
        tiles: [
          ..._run(_y, 9, 13),
          ..._run(_l, 10, 13),
          _t(_r, 1),
          _t(_b, 1),
          _t(_y, 2),
          _t(_l, 2),
          _t(_r, 3),
          _t(_b, 3),
          _t(_y, 4),
          _t(_l, 4),
          _t(_r, 6),
          _t(_b, 6),
          _t(_y, 5),
          _t(_r, 1), // dead leftover pair → 21 tiles
        ],
        summary: _opens(score: 101, via: OpenPath.melds),
      ),
      // 13 — a joker, but the hand still falls short.
      seed(
        age: const Duration(days: 17),
        mode: GameMode.oneZeroOne,
        indicatorColor: _l,
        indicatorNumber: 1,
        tiles: [
          _joker,
          _t(_r, 6),
          _t(_b, 6),
          ..._run(_y, 1, 3),
          ..._run(_l, 5, 7),
          _t(_r, 1),
          _t(_r, 9),
          _t(_r, 12),
          _t(_b, 3),
          _t(_b, 9),
          _t(_b, 12),
          _t(_y, 8),
          _t(_y, 11),
          _t(_l, 10),
          _t(_l, 13),
          _t(_y, 5),
          _t(_r, 1), // dead leftover pair → 21 tiles
        ],
        summary: _doesNotOpen(score: 60),
      ),
      // 14 — opens with 122.
      seed(
        age: const Duration(days: 18),
        mode: GameMode.oneZeroOne,
        indicatorColor: _y,
        indicatorNumber: 7,
        tiles: [
          ..._run(_y, 2, 5),
          ..._set(13, const [_r, _b, _l]),
          ..._set(12, const [_r, _b, _l]),
          ..._set(11, const [_r, _b, _l]),
          _t(_r, 1),
          _t(_b, 1),
          _t(_l, 2),
          _t(_r, 4),
          _t(_b, 4),
          _t(_l, 5),
          _t(_r, 7),
          _t(_r, 1), // dead leftover pair → 21 tiles
        ],
        summary: _opens(score: 122, via: OpenPath.melds),
      ),
      // 15 — long black run, thirteen short.
      seed(
        age: const Duration(days: 20),
        mode: GameMode.oneZeroOne,
        indicatorColor: _y,
        indicatorNumber: 9,
        tiles: [
          ..._run(_r, 9, 13),
          ..._set(11, const [_b, _y, _l]),
          _t(_r, 1),
          _t(_r, 4),
          _t(_r, 6),
          _t(_b, 2),
          _t(_b, 5),
          _t(_b, 8),
          _t(_y, 1),
          _t(_y, 4),
          _t(_y, 7),
          _t(_l, 2),
          _t(_l, 5),
          _t(_l, 8),
          _t(_r, 1), // dead leftover pair → 21 tiles
        ],
        summary: _doesNotOpen(score: 88),
      ),
      // 16 — the 21-tile rack: opens with 134.
      seed(
        age: const Duration(days: 21),
        mode: GameMode.oneZeroOne,
        indicatorColor: _r,
        indicatorNumber: 8,
        tiles: [
          ..._run(_y, 5, 8),
          ..._set(13, const [_r, _b, _l]),
          ..._set(12, const [_r, _b, _l]),
          ..._set(11, const [_r, _b, _l]),
          _t(_r, 1),
          _t(_b, 1),
          _t(_y, 2),
          _t(_l, 2),
          _t(_r, 4),
          _t(_b, 4),
          _t(_l, 5),
          _t(_y, 3),
        ],
        summary: _opens(score: 134, via: OpenPath.melds),
      ),
      // 17 — okey: winning now with a final pair.
      seed(
        age: const Duration(days: 23),
        mode: GameMode.okey,
        indicatorColor: _b,
        indicatorNumber: 7,
        tiles: [
          ..._run(_r, 1, 3),
          ..._run(_b, 1, 3),
          ..._run(_y, 1, 3),
          ..._run(_l, 1, 3),
          _t(_r, 9),
          _t(_r, 9),
        ],
        summary: _okey(tilesToWin: 0, via: OkeyPath.meldsAndPair, score: 24),
      ),
      // 18 — opens with 107.
      seed(
        age: const Duration(days: 25),
        mode: GameMode.oneZeroOne,
        indicatorColor: _b,
        indicatorNumber: 11,
        tiles: [
          ..._run(_l, 5, 8),
          ..._set(13, const [_r, _b, _y]),
          ..._set(10, const [_r, _b, _y]),
          ..._set(4, const [_r, _b, _y]),
          _t(_r, 1),
          _t(_b, 1),
          _t(_y, 2),
          _t(_l, 2),
          _t(_r, 7),
          _t(_b, 7),
          _t(_y, 5),
          _t(_r, 1), // dead leftover pair → 21 tiles
        ],
        summary: _opens(score: 107, via: OpenPath.melds),
      ),
      // 19 — barely anything melds: 77 short.
      seed(
        age: const Duration(days: 27),
        mode: GameMode.oneZeroOne,
        indicatorColor: _b,
        indicatorNumber: 13,
        tiles: [
          ..._run(_l, 4, 6),
          ..._set(3, const [_r, _b, _y]),
          _t(_r, 1),
          _t(_r, 5),
          _t(_r, 8),
          _t(_r, 12),
          _t(_b, 2),
          _t(_b, 6),
          _t(_b, 9),
          _t(_b, 12),
          _t(_y, 1),
          _t(_y, 4),
          _t(_y, 7),
          _t(_y, 11),
          _t(_l, 9),
          _t(_l, 11),
          _t(_r, 1), // dead leftover pair → 21 tiles
        ],
        summary: _doesNotOpen(score: 24),
      ),
      // 20 — opens with 119.
      seed(
        age: const Duration(days: 29),
        mode: GameMode.oneZeroOne,
        indicatorColor: _b,
        indicatorNumber: 10,
        tiles: [
          ..._run(_b, 5, 8),
          ..._set(13, const [_r, _y, _l]),
          ..._set(11, const [_r, _y, _l]),
          ..._set(7, const [_r, _y, _l]),
          _t(_r, 1),
          _t(_y, 1),
          _t(_l, 2),
          _t(_r, 4),
          _t(_y, 4),
          _t(_l, 5),
          _t(_y, 2),
          _t(_r, 1), // dead leftover pair → 21 tiles
        ],
        summary: _opens(score: 119, via: OpenPath.melds),
      ),
      // 21 — ten short despite the big run.
      seed(
        age: const Duration(days: 31),
        mode: GameMode.oneZeroOne,
        indicatorColor: _y,
        indicatorNumber: 3,
        tiles: [
          ..._run(_b, 9, 13),
          ..._set(12, const [_r, _y, _l]),
          _t(_r, 1),
          _t(_r, 4),
          _t(_r, 7),
          _t(_r, 10),
          _t(_y, 2),
          _t(_y, 5),
          _t(_y, 8),
          _t(_l, 1),
          _t(_l, 4),
          _t(_l, 7),
          _t(_b, 2),
          _t(_b, 5),
          _t(_r, 1), // dead leftover pair → 21 tiles
        ],
        summary: _doesNotOpen(score: 91),
      ),
      // 22 — opens with 113.
      seed(
        age: const Duration(days: 33),
        mode: GameMode.oneZeroOne,
        indicatorColor: _l,
        indicatorNumber: 11,
        tiles: [
          ..._run(_y, 5, 8),
          ..._set(13, const [_r, _b, _l]),
          ..._set(9, const [_r, _b, _l]),
          ..._set(7, const [_r, _b, _l]),
          _t(_r, 1),
          _t(_b, 1),
          _t(_y, 2),
          _t(_l, 2),
          _t(_r, 4),
          _t(_b, 4),
          _t(_l, 5),
          _t(_r, 1), // dead leftover pair → 21 tiles
        ],
        summary: _opens(score: 113, via: OpenPath.melds),
      ),
      // 23 — opens with 125.
      seed(
        age: const Duration(days: 35),
        mode: GameMode.oneZeroOne,
        indicatorColor: _y,
        indicatorNumber: 6,
        tiles: [
          ..._run(_l, 5, 8),
          ..._set(13, const [_r, _b, _y]),
          ..._set(11, const [_r, _b, _y]),
          ..._set(9, const [_r, _b, _y]),
          _t(_r, 1),
          _t(_b, 1),
          _t(_y, 2),
          _t(_l, 2),
          _t(_r, 4),
          _t(_b, 4),
          _t(_y, 5),
          _t(_r, 1), // dead leftover pair → 21 tiles
        ],
        summary: _opens(score: 125, via: OpenPath.melds),
      ),
      // 24 — a small run and a set: 56 short.
      seed(
        age: const Duration(days: 38),
        mode: GameMode.oneZeroOne,
        indicatorColor: _r,
        indicatorNumber: 3,
        tiles: [
          ..._run(_b, 6, 8),
          ..._set(8, const [_r, _y, _l]),
          _t(_r, 1),
          _t(_r, 5),
          _t(_r, 12),
          _t(_b, 1),
          _t(_b, 4),
          _t(_b, 12),
          _t(_y, 2),
          _t(_y, 4),
          _t(_y, 10),
          _t(_y, 13),
          _t(_l, 2),
          _t(_l, 5),
          _t(_l, 10),
          _t(_l, 13),
          _t(_r, 1), // dead leftover pair → 21 tiles
        ],
        summary: _doesNotOpen(score: 45),
      ),
      // 25 — opens with 128.
      seed(
        age: const Duration(days: 41),
        mode: GameMode.oneZeroOne,
        indicatorColor: _r,
        indicatorNumber: 2,
        tiles: [
          ..._run(_r, 5, 8),
          ..._set(13, const [_b, _y, _l]),
          ..._set(11, const [_b, _y, _l]),
          ..._set(10, const [_b, _y, _l]),
          _t(_b, 1),
          _t(_y, 1),
          _t(_l, 2),
          _t(_b, 4),
          _t(_y, 4),
          _t(_l, 5),
          _t(_y, 6),
          _t(_b, 1), // dead leftover pair → 21 tiles
        ],
        summary: _opens(score: 128, via: OpenPath.melds),
      ),
      // 26 — opens with 131.
      seed(
        age: const Duration(days: 45),
        mode: GameMode.oneZeroOne,
        indicatorColor: _b,
        indicatorNumber: 8,
        tiles: [
          ..._run(_b, 2, 5),
          ..._set(12, const [_r, _y, _l]),
          ..._set(11, const [_r, _y, _l]),
          ..._set(9, const [_r, _y, _l]),
          ..._set(7, const [_r, _y, _l]),
          _t(_r, 1),
          _t(_y, 1),
          _t(_l, 3),
          _t(_l, 5),
          _t(_r, 1), // dead leftover pair → 21 tiles
        ],
        summary: _opens(score: 131, via: OpenPath.melds),
      ),
    ];
  }
}
