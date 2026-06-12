import 'package:checks/checks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:okey_acar_mi/core/game/game_mode.dart';
import 'package:okey_acar_mi/core/game/game_tile.dart';
import 'package:okey_acar_mi/core/game/indicator.dart';
import 'package:okey_acar_mi/core/game/tile_color.dart';
import 'package:okey_acar_mi/core/time/clock.dart';
import 'package:okey_acar_mi/features/auth/domain/entities/app_user.dart';
import 'package:okey_acar_mi/features/auth/domain/repositories/auth_repository.dart';
import 'package:okey_acar_mi/features/history/domain/entities/scan.dart';
import 'package:okey_acar_mi/features/history/domain/entities/scan_summary.dart';
import 'package:okey_acar_mi/features/history/domain/repositories/scan_repository.dart';
import 'package:okey_acar_mi/features/history/domain/usecases/save_scan.dart';
import 'package:okey_acar_mi/features/review/domain/entities/review_outcome.dart';
import 'package:okey_acar_mi/features/solver/domain/entities/solve_result.dart';
import 'package:okey_acar_mi/features/solver/domain/entities/solve_verdict.dart';

class _MockScanRepository extends Mock implements ScanRepository {}

class _MockAuthRepository extends Mock implements AuthRepository {}

class _MockClock extends Mock implements Clock {}

const _user = AppUser(
  id: 'demo-oyuncu',
  email: 'oyuncu@demo.app',
  emailVerified: true,
  providers: [AuthProvider.password],
);

const ReviewOutcome _outcome = ReviewOutcome(
  tiles: [
    GameTile(color: TileColor.red, number: 5),
    GameTile(color: TileColor.red, number: 6),
    GameTile(color: TileColor.joker),
  ],
  indicator: Indicator(color: TileColor.yellow, number: 13),
  gameMode: GameMode.oneZeroOne,
);

const SolveResult _result = SolveResult(
  melds: [],
  pairs: [],
  leftovers: [],
  totalScore: 104,
  verdict: SolveVerdict.opens101(score: 104, via: OpenPath.melds),
  reasoning: [],
);

/// RFC 4122 v4: version nibble 4, variant nibble 8/9/a/b.
final RegExp _uuidV4 = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
);

void main() {
  late _MockScanRepository scans;
  late _MockAuthRepository auth;
  late _MockClock clock;
  late SaveScan saveScan;

  setUpAll(() {
    registerFallbackValue(
      Scan(
        id: 'fallback',
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
        tiles: const [],
        indicator: const Indicator(color: TileColor.red, number: 1),
        gameMode: GameMode.oneZeroOne,
        summary: const ScanSummary(
          kind: ScanVerdictKind.opens101,
          opened: true,
          score: 0,
        ),
      ),
    );
  });

  setUp(() {
    scans = _MockScanRepository();
    auth = _MockAuthRepository();
    clock = _MockClock();
    saveScan = SaveScan(scans, auth, clock);
    when(() => scans.save(any())).thenAnswer((_) async {});
    when(clock.now).thenReturn(DateTime.utc(2026, 6, 11, 14, 30));
    when(() => auth.currentUser).thenReturn(null);
  });

  Future<Scan> call() => saveScan(outcome: _outcome, result: _result);

  group('SaveScan', () {
    test('a guest save carries ownerId null', () async {
      when(() => auth.currentUser).thenReturn(null);

      final scan = await call();

      check(scan.ownerId).isNull();
    });

    test('a signed-in save stamps the current uid', () async {
      when(() => auth.currentUser).thenReturn(_user);

      final scan = await call();

      check(scan.ownerId).equals('demo-oyuncu');
    });

    test('ids are uuid v4 and unique across calls', () async {
      final first = await call();
      final second = await call();

      check(first.id).matchesPattern(_uuidV4);
      check(second.id).matchesPattern(_uuidV4);
      check(first.id).not((it) => it.equals(second.id));
    });

    test('createdAt and updatedAt are the injected clock instant, in UTC '
        '(a local clock is converted)', () async {
      final localNow = DateTime(2026, 6, 11, 17, 45, 30);
      when(clock.now).thenReturn(localNow);

      final scan = await call();

      check(scan.createdAt.isUtc).isTrue();
      check(scan.createdAt).equals(localNow.toUtc());
      check(scan.updatedAt).equals(localNow.toUtc());
    });

    test('the summary is derived from the result and the outcome fields pass '
        'through verbatim', () async {
      final scan = await call();

      check(scan.summary).equals(ScanSummary.fromResult(_result));
      check(scan.tiles).deepEquals(_outcome.tiles);
      check(scan.indicator).equals(_outcome.indicator);
      check(scan.gameMode).equals(_outcome.gameMode);
    });

    test(
      'saves the built scan to the repository and returns that same scan',
      () async {
        final scan = await call();

        final captured =
            verify(() => scans.save(captureAny())).captured.single as Scan;
        check(captured).equals(scan);
      },
    );

    test(
      'a repository failure propagates (nothing is swallowed here)',
      () async {
        when(() => scans.save(any())).thenThrow(StateError('db down'));

        await check(call()).throws<StateError>();
      },
    );
  });
}
