import 'package:checks/checks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:okey_acar_mi/core/error/failure.dart';
import 'package:okey_acar_mi/core/time/clock.dart';
import 'package:okey_acar_mi/features/capture/domain/entities/capture_payload.dart';
import 'package:okey_acar_mi/features/capture/domain/repositories/capture_repository.dart';
import 'package:okey_acar_mi/features/capture/domain/usecases/capture_photo.dart';
import 'package:okey_acar_mi/features/capture/domain/usecases/capture_video_frames.dart';
import 'package:okey_acar_mi/features/capture/domain/usecases/pick_from_gallery.dart';

class _MockCaptureRepository extends Mock implements CaptureRepository {}

/// Pinned instant so `capturedAt` stamps are asserted exactly — never raw
/// `DateTime.now()`.
class _FixedClock implements Clock {
  const _FixedClock();

  static final DateTime instant = DateTime.utc(2026, 6, 10, 12);

  @override
  DateTime now() => instant;
}

void main() {
  late _MockCaptureRepository repository;

  setUp(() => repository = _MockCaptureRepository());

  group('CapturePhoto', () {
    test('stamps the still with capturedAt and source: photo', () async {
      when(
        repository.captureStillToFile,
      ).thenAnswer((_) async => '/captures/shot.png');
      final useCase = CapturePhoto(repository, const _FixedClock());

      final payload = await useCase();

      check(payload).equals(
        CapturePayload.still(
          imagePath: '/captures/shot.png',
          source: CaptureSource.photo,
          capturedAt: _FixedClock.instant,
        ),
      );
    });

    test('a capture failure propagates', () async {
      when(
        repository.captureStillToFile,
      ).thenThrow(const Failure.captureFailed('boom'));
      final useCase = CapturePhoto(repository, const _FixedClock());

      await check(useCase()).throws<CaptureFailedFailure>(
        (failure) => failure.has((f) => f.message, 'message').equals('boom'),
      );
    });
  });

  group('CaptureVideoFrames', () {
    CaptureVideoFrames buildUseCase() =>
        CaptureVideoFrames(repository, const _FixedClock());

    /// Stubs sequential captures: frame_1.png, frame_2.png, …
    void stubSequentialCaptures() {
      var frame = 0;
      when(
        repository.captureStillToFile,
      ).thenAnswer((_) async => '/captures/frame_${++frame}.png');
    }

    test('an uncancelled burst captures maxFrames frames and reports '
        'progress 1..5', () async {
      stubSequentialCaptures();
      final progress = <int>[];

      final payload = await buildUseCase()(
        onProgress: progress.add,
        isCancelled: () => false,
      );

      check(progress).deepEquals([1, 2, 3, 4, 5]);
      check(payload).equals(
        CapturePayload.frames(
          framePaths: const [
            '/captures/frame_1.png',
            '/captures/frame_2.png',
            '/captures/frame_3.png',
            '/captures/frame_4.png',
            '/captures/frame_5.png',
          ],
          capturedAt: _FixedClock.instant,
        ),
      );
      verify(repository.captureStillToFile).called(5);
    });

    test('honors a custom maxFrames', () async {
      stubSequentialCaptures();
      final progress = <int>[];

      final payload = await buildUseCase()(
        onProgress: progress.add,
        isCancelled: () => false,
        maxFrames: 3,
      );

      check(progress).deepEquals([1, 2, 3]);
      check(payload).equals(
        CapturePayload.frames(
          framePaths: const [
            '/captures/frame_1.png',
            '/captures/frame_2.png',
            '/captures/frame_3.png',
          ],
          capturedAt: _FixedClock.instant,
        ),
      );
    });

    test('a stop request between frames ends the burst early', () async {
      stubSequentialCaptures();
      final progress = <int>[];

      final payload = await buildUseCase()(
        onProgress: progress.add,
        // Cancel as soon as two frames have landed.
        isCancelled: () => progress.length >= 2,
      );

      check(progress).deepEquals([1, 2]);
      check(payload).equals(
        CapturePayload.frames(
          framePaths: const [
            '/captures/frame_1.png',
            '/captures/frame_2.png',
          ],
          capturedAt: _FixedClock.instant,
        ),
      );
      verify(repository.captureStillToFile).called(2);
    });

    test(
      'an immediate stop request still captures at least one frame',
      () async {
        stubSequentialCaptures();
        final progress = <int>[];

        final payload = await buildUseCase()(
          onProgress: progress.add,
          isCancelled: () => true,
        );

        check(progress).deepEquals([1]);
        check(payload).equals(
          CapturePayload.frames(
            framePaths: const ['/captures/frame_1.png'],
            capturedAt: _FixedClock.instant,
          ),
        );
      },
    );

    test('a capture failure mid-burst propagates', () async {
      when(
        repository.captureStillToFile,
      ).thenThrow(const Failure.captureFailed('boom'));

      await check(
        buildUseCase()(onProgress: (_) {}, isCancelled: () => false),
      ).throws<CaptureFailedFailure>();
    });
  });

  group('PickFromGallery', () {
    test(
      'stamps the picked image with capturedAt and source: gallery',
      () async {
        when(
          repository.pickImageFromGallery,
        ).thenAnswer((_) async => '/captures/picked.png');
        final useCase = PickFromGallery(repository, const _FixedClock());

        final payload = await useCase();

        check(payload).equals(
          CapturePayload.still(
            imagePath: '/captures/picked.png',
            source: CaptureSource.gallery,
            capturedAt: _FixedClock.instant,
          ),
        );
      },
    );

    test('a cancelled pick passes the null through (no failure)', () async {
      when(repository.pickImageFromGallery).thenAnswer((_) async => null);
      final useCase = PickFromGallery(repository, const _FixedClock());

      check(await useCase()).isNull();
    });

    test('a photo-access denial propagates', () async {
      when(
        repository.pickImageFromGallery,
      ).thenThrow(const Failure.photoAccessDenied(permanent: true));
      final useCase = PickFromGallery(repository, const _FixedClock());

      await check(useCase()).throws<PhotoAccessDeniedFailure>(
        (failure) => failure.has((f) => f.permanent, 'permanent').isTrue(),
      );
    });
  });
}
