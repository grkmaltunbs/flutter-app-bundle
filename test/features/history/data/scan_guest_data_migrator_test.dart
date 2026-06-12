import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:okey_acar_mi/core/logging/app_logger.dart';
import 'package:okey_acar_mi/features/history/data/services/scan_guest_data_migrator.dart';
import 'package:okey_acar_mi/features/history/data/services/scan_user_data_purger.dart';
import 'package:okey_acar_mi/features/history/domain/repositories/scan_repository.dart';

class _MockScanRepository extends Mock implements ScanRepository {}

class _MockAppLogger extends Mock implements AppLogger {}

void main() {
  late _MockScanRepository scans;
  late _MockAppLogger logger;

  setUp(() {
    scans = _MockScanRepository();
    logger = _MockAppLogger();
  });

  group('ScanGuestDataMigrator', () {
    test('adopts the guest scans to the new uid', () async {
      when(
        () => scans.adoptGuestScans(toUserId: any(named: 'toUserId')),
      ).thenAnswer((_) async {});

      await ScanGuestDataMigrator(
        scans,
        logger,
      ).migrateGuestData(toUserId: 'demo-oyuncu');

      verify(() => scans.adoptGuestScans(toUserId: 'demo-oyuncu')).called(1);
      verifyNever(() => logger.error(any(), any<Object?>(), any()));
    });

    test('a repository throw is logged, never rethrown (sign-in must not '
        'fail)', () async {
      when(
        () => scans.adoptGuestScans(toUserId: any(named: 'toUserId')),
      ).thenThrow(StateError('db down'));

      // Must complete normally.
      await ScanGuestDataMigrator(
        scans,
        logger,
      ).migrateGuestData(toUserId: 'demo-oyuncu');

      verify(
        () =>
            logger.error('Guest scan migration failed', any<Object?>(), any()),
      ).called(1);
    });
  });

  group('ScanUserDataPurger', () {
    test(
      'deletes all scans of the owner (local + remote via the repo)',
      () async {
        when(() => scans.deleteAllForOwner(any())).thenAnswer((_) async {});

        await ScanUserDataPurger(
          scans,
          logger,
        ).purgeUserData(ownerId: 'demo-oyuncu');

        verify(() => scans.deleteAllForOwner('demo-oyuncu')).called(1);
        verifyNever(() => logger.error(any(), any<Object?>(), any()));
      },
    );

    test('a repository throw is logged, never rethrown (the confirmed '
        'deletion must proceed)', () async {
      when(
        () => scans.deleteAllForOwner(any()),
      ).thenThrow(StateError('remote purge failed'));

      await ScanUserDataPurger(
        scans,
        logger,
      ).purgeUserData(ownerId: 'demo-oyuncu');

      verify(
        () => logger.error(
          'Scan purge before deletion failed',
          any<Object?>(),
          any(),
        ),
      ).called(1);
    });
  });
}
