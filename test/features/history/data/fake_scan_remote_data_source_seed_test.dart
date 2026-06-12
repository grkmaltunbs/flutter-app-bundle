import 'package:checks/checks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:okey_acar_mi/core/game/game_mode.dart';
import 'package:okey_acar_mi/core/time/clock.dart';
import 'package:okey_acar_mi/features/history/data/fakes/fake_scan_remote_data_source.dart';
import 'package:okey_acar_mi/features/history/domain/entities/scan_summary.dart';
import 'package:okey_acar_mi/features/solver/domain/engine/solver_engine.dart';
import 'package:okey_acar_mi/features/solver/domain/entities/solve_request.dart';
import 'package:okey_acar_mi/features/solver/domain/entities/solve_verdict.dart';

/// Replay-consistency guarantee for the demo history seeds: every seeded
/// `(tiles, indicator, mode)` must re-solve — through the real engine — to
/// exactly its seeded summary, so reopening a history entry can never
/// contradict the stored verdict. If a seed disagrees, fix the seed hand,
/// not the assertion.
void main() {
  const engine = DpSolverEngine();
  final seeds = FakeScanRemoteDataSource.seedScans();

  group('FakeScanRemoteDataSource seeds', () {
    test('there are exactly 26 seeds, all owned by the seeded demo user', () {
      check(seeds.length).equals(26);
      for (final dto in seeds) {
        check(dto.ownerId).equals(FakeScanRemoteDataSource.seededOwnerId);
      }
    });

    test('ids are unique', () {
      check(seeds.map((dto) => dto.id).toSet().length).equals(seeds.length);
    });

    test('dates are distinct, deterministic, and spread from the seed', () {
      final dates = [for (final dto in seeds) dto.createdAtMs];
      check(dates.toSet().length).equals(seeds.length);
      // Deterministic: a second build yields the identical timestamps + ids.
      final rebuilt = FakeScanRemoteDataSource.seedScans();
      check([
        for (final dto in rebuilt) '${dto.id}@${dto.createdAtMs}',
      ]).deepEquals([for (final dto in seeds) '${dto.id}@${dto.createdAtMs}']);
      // Newest is 20 hours before the pinned demo clock; the rest sit
      // within the 2–45 day window behind it.
      final newest = dates.reduce((a, b) => a > b ? a : b);
      final seedMs = FakeClock.seed.millisecondsSinceEpoch;
      check(newest).equals(
        seedMs - const Duration(hours: 20).inMilliseconds,
      );
      for (final ms in dates.where((ms) => ms != newest)) {
        check(seedMs - ms).isGreaterOrEqual(
          const Duration(days: 2).inMilliseconds,
        );
        check(seedMs - ms).isLessOrEqual(
          const Duration(days: 45).inMilliseconds,
        );
      }
      for (final dto in seeds) {
        check(dto.updatedAtMs).equals(dto.createdAtMs);
      }
    });

    test('every seed re-solves to exactly its seeded summary', () {
      for (final dto in seeds) {
        final scan = dto.toEntity();
        final result = engine.solve(
          SolveRequest(
            tiles: scan.tiles,
            indicator: scan.indicator,
            mode: scan.gameMode,
          ),
        );
        check(
          because: '${dto.id} must replay to its stored verdict',
          ScanSummary.fromResult(result),
        ).equals(scan.summary);
      }
    });

    test('the verdict distribution matches the seeded spec', () {
      final scans = [for (final dto in seeds) dto.toEntity()];
      final opens = scans
          .where((s) => s.summary.kind == ScanVerdictKind.opens101)
          .toList();
      final closed = scans
          .where((s) => s.summary.kind == ScanVerdictKind.doesNotOpen101)
          .toList();
      final okey = scans
          .where((s) => s.summary.kind == ScanVerdictKind.okeyOutcome)
          .toList();
      check(opens.length).equals(14);
      check(closed.length).equals(8);
      check(okey.length).equals(4);
      // Every opener opened; scores within 101–142 (except the pairs path,
      // whose score is the meld total).
      for (final scan in opens) {
        check(scan.summary.opened).isTrue();
        if (scan.summary.openPath == OpenPath.melds) {
          check(scan.summary.score).isGreaterOrEqual(101);
          check(scan.summary.score).isLessOrEqual(142);
        }
      }
      check(
        opens.where((s) => s.summary.openPath == OpenPath.pairs),
      ).isNotEmpty();
      // Non-openers carry their exact shortfall, varied.
      for (final scan in closed) {
        check(scan.summary.opened).isFalse();
        check(scan.summary.pointsShort).equals(101 - scan.summary.score);
      }
      check(
        closed.map((s) => s.summary.pointsShort).toSet().length,
      ).equals(closed.length);
      // Okey outcomes: at least one winning now and one exactly 2 away.
      check(okey.where((s) => s.summary.tilesToWin == 0)).isNotEmpty();
      check(okey.where((s) => s.summary.tilesToWin == 2)).isNotEmpty();
      for (final scan in okey) {
        check(scan.summary.opened).equals(scan.summary.tilesToWin == 0);
      }
      // The best score across all seeds is exactly 142.
      final best = scans
          .map((s) => s.summary.score)
          .reduce((a, b) => a > b ? a : b);
      check(best).equals(142);
      // At least one full 21-tile 101 rack.
      check(
        scans.where(
          (s) => s.gameMode == GameMode.oneZeroOne && s.tiles.length == 21,
        ),
      ).isNotEmpty();
      // Rack sizes are mode-legal throughout.
      for (final scan in scans) {
        check(scan.tiles.length).isGreaterOrEqual(scan.gameMode.minTiles);
        check(scan.tiles.length).isLessOrEqual(scan.gameMode.maxTiles);
      }
    });

    test(
      'fetchAll returns the seeds newest-first for the seeded owner',
      () async {
        final fake = FakeScanRemoteDataSource();
        final fetched = await fake.fetchAll(
          FakeScanRemoteDataSource.seededOwnerId,
        );
        check(fetched.length).equals(26);
        for (var i = 1; i < fetched.length; i++) {
          check(
            fetched[i - 1].createdAtMs,
          ).isGreaterOrEqual(fetched[i].createdAtMs);
        }
        check(await fake.fetchAll('someone-else')).isEmpty();
      },
    );
  });
}
