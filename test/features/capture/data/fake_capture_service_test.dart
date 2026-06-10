import 'dart:io';

import 'package:checks/checks.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:okey_acar_mi/core/error/failure.dart';
import 'package:okey_acar_mi/features/capture/data/fakes/fake_capture_service.dart';
import 'package:okey_acar_mi/features/capture/domain/entities/permission_verdict.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

/// Redirects `getTemporaryDirectory()` to a per-test host directory so the
/// fake's "captured files" land somewhere real and inspectable (no platform
/// channel exists under `flutter test`).
class _FakePathProviderPlatform extends Fake
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  _FakePathProviderPlatform(this.temporaryPath);

  final String temporaryPath;

  @override
  Future<String?> getTemporaryPath() async => temporaryPath;
}

/// The demo fake is the backend for every simulator capture flow, so every
/// [FakeCaptureMode] contract, the deterministic burst sourcing, and the
/// recorded side effects are asserted exhaustively here.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late FakeCaptureService fake;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('fake_capture_test');
    PathProviderPlatform.instance = _FakePathProviderPlatform(tempDir.path);
    fake = FakeCaptureService();
  });

  tearDown(() async => tempDir.delete(recursive: true));

  Future<List<int>> assetBytes(String asset) async {
    final data = await rootBundle.load(asset);
    return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  }

  group('defaults', () {
    test('a fresh fake is ready, on the 101 fixture, with zeroed counters '
        'and no camera held', () {
      check(fake.mode).equals(FakeCaptureMode.ready);
      check(fake.fixture).equals(FakeCaptureService.rack101Fixture);
      check(fake.openSystemSettingsCount).equals(0);
      check(fake.isInitialized).isFalse();
      check(fake.flashOn).isFalse();
      check(fake.isFlashAvailable).isTrue();
      check(fake.hasLivePreview).isFalse();
    });
  });

  group('camera permission per mode', () {
    test('ready grants on check and request', () async {
      check(
        await fake.checkCameraPermission(),
      ).equals(PermissionVerdict.granted);
      check(
        await fake.requestCameraPermission(),
      ).equals(PermissionVerdict.granted);
    });

    test('cameraDenied stays denied across check and request (the prompt '
        'changes nothing until the mode flips)', () async {
      fake.mode = FakeCaptureMode.cameraDenied;

      check(
        await fake.checkCameraPermission(),
      ).equals(PermissionVerdict.denied);
      check(
        await fake.requestCameraPermission(),
      ).equals(PermissionVerdict.denied);

      // Flipping the mode models the user answering the system dialog.
      fake.mode = FakeCaptureMode.ready;
      check(
        await fake.requestCameraPermission(),
      ).equals(PermissionVerdict.granted);
    });

    test('cameraPermanentlyDenied reports permanentlyDenied on check and '
        'request', () async {
      fake.mode = FakeCaptureMode.cameraPermanentlyDenied;

      check(
        await fake.checkCameraPermission(),
      ).equals(PermissionVerdict.permanentlyDenied);
      check(
        await fake.requestCameraPermission(),
      ).equals(PermissionVerdict.permanentlyDenied);
    });

    test('gallery-only modes leave the camera permission granted', () async {
      for (final mode in [
        FakeCaptureMode.noCamera,
        FakeCaptureMode.captureError,
        FakeCaptureMode.galleryCancelled,
        FakeCaptureMode.galleryDenied,
        FakeCaptureMode.galleryPermanentlyDenied,
      ]) {
        fake.mode = mode;
        check(
          because: '$mode must not affect the camera permission',
          await fake.checkCameraPermission(),
        ).equals(PermissionVerdict.granted);
      }
    });
  });

  group('initializeCamera / releaseCamera', () {
    test('ready acquires the camera', () async {
      await fake.initializeCamera(frontCamera: false);

      check(fake.isInitialized).isTrue();
    });

    test('noCamera throws Failure.noCamera and never acquires', () async {
      fake.mode = FakeCaptureMode.noCamera;

      await check(
        fake.initializeCamera(frontCamera: false),
      ).throws<NoCameraFailure>();
      check(fake.isInitialized).isFalse();
    });

    test('releaseCamera parks the camera and turns the torch off', () async {
      await fake.initializeCamera(frontCamera: false);
      await fake.setFlash(enabled: true);
      check(fake.flashOn).isTrue();

      await fake.releaseCamera();

      check(fake.isInitialized).isFalse();
      check(fake.flashOn).isFalse();
    });

    test('re-acquisition resets the torch', () async {
      await fake.initializeCamera(frontCamera: false);
      await fake.setFlash(enabled: true);

      await fake.initializeCamera(frontCamera: true);

      check(fake.isInitialized).isTrue();
      check(fake.flashOn).isFalse();
    });
  });

  group('captureStillToFile', () {
    test('writes a real, readable temp file with the fixture bytes', () async {
      await fake.initializeCamera(frontCamera: false);

      final path = await fake.captureStillToFile();

      final file = File(path);
      check(path).startsWith(tempDir.path);
      check(file.existsSync()).isTrue();
      check(
        file.readAsBytesSync(),
      ).deepEquals(await assetBytes(FakeCaptureService.rack101Fixture));
    });

    test(
      'captureError throws Failure.captureFailed and writes nothing',
      () async {
        await fake.initializeCamera(frontCamera: false);
        fake.mode = FakeCaptureMode.captureError;

        await check(fake.captureStillToFile()).throws<CaptureFailedFailure>();
        check(tempDir.listSync()).isEmpty();
      },
    );

    test('a 5-frame burst deterministically yields '
        '[fixture, frame_1, frame_2, frame_3, frame_1]', () async {
      await fake.initializeCamera(frontCamera: false);

      final paths = [
        for (var i = 0; i < 5; i++) await fake.captureStillToFile(),
      ];

      final expectedSources = [
        FakeCaptureService.rack101Fixture,
        FakeCaptureService.frameFixtures[0],
        FakeCaptureService.frameFixtures[1],
        FakeCaptureService.frameFixtures[2],
        FakeCaptureService.frameFixtures[0],
      ];
      for (var i = 0; i < 5; i++) {
        check(
          because: 'capture $i must copy ${expectedSources[i]}',
          paths[i],
        ).endsWith(expectedSources[i].split('/').last);
        check(
          File(paths[i]).readAsBytesSync(),
        ).deepEquals(await assetBytes(expectedSources[i]));
      }
      // Every copy is a distinct file, even when the source repeats.
      check(paths.toSet().length).equals(5);
    });

    test('re-initializing the camera starts a new session: the first capture '
        'copies the fixture again', () async {
      await fake.initializeCamera(frontCamera: false);
      await fake.captureStillToFile();
      await fake.captureStillToFile();

      await fake.initializeCamera(frontCamera: false);
      final path = await fake.captureStillToFile();

      check(path).endsWith(
        FakeCaptureService.rack101Fixture.split('/').last,
      );
    });

    test(
      'switching the fixture changes the first capture of the session',
      () async {
        fake.fixture = FakeCaptureService.rackOkeyFixture;
        await fake.initializeCamera(frontCamera: false);

        final path = await fake.captureStillToFile();

        check(path).endsWith(
          FakeCaptureService.rackOkeyFixture.split('/').last,
        );
        check(
          File(path).readAsBytesSync(),
        ).deepEquals(await assetBytes(FakeCaptureService.rackOkeyFixture));
      },
    );
  });

  group('pickImageFromGallery', () {
    test('ready copies the fixture to a real, readable temp file', () async {
      final path = await fake.pickImageFromGallery();

      check(path).isNotNull();
      check(path!).startsWith(tempDir.path);
      check(
        File(path).readAsBytesSync(),
      ).deepEquals(await assetBytes(FakeCaptureService.rack101Fixture));
    });

    test(
      'galleryCancelled resolves to null (user cancel, not a failure)',
      () async {
        fake.mode = FakeCaptureMode.galleryCancelled;

        check(await fake.pickImageFromGallery()).isNull();
      },
    );

    test('galleryDenied throws a re-promptable photoAccessDenied', () async {
      fake.mode = FakeCaptureMode.galleryDenied;

      await check(
        fake.pickImageFromGallery(),
      ).throws<PhotoAccessDeniedFailure>(
        (failure) => failure.has((f) => f.permanent, 'permanent').isFalse(),
      );
    });

    test(
      'galleryPermanentlyDenied throws a permanent photoAccessDenied',
      () async {
        fake.mode = FakeCaptureMode.galleryPermanentlyDenied;

        await check(
          fake.pickImageFromGallery(),
        ).throws<PhotoAccessDeniedFailure>(
          (failure) => failure.has((f) => f.permanent, 'permanent').isTrue(),
        );
      },
    );

    test(
      'the gallery escape still works while the camera is blocked '
      '(cameraDenied, cameraPermanentlyDenied, noCamera, captureError)',
      () async {
        for (final mode in [
          FakeCaptureMode.cameraDenied,
          FakeCaptureMode.cameraPermanentlyDenied,
          FakeCaptureMode.noCamera,
          FakeCaptureMode.captureError,
        ]) {
          fake.mode = mode;

          final path = await fake.pickImageFromGallery();

          check(because: '$mode must not block the gallery', path).isNotNull();
          check(File(path!).existsSync()).isTrue();
        }
      },
    );
  });

  group('openSystemSettings', () {
    test('increments openSystemSettingsCount on every call', () async {
      await fake.openSystemSettings();
      await fake.openSystemSettings();

      check(fake.openSystemSettingsCount).equals(2);
    });
  });

  group('reset', () {
    test('restores the defaults: mode, fixture, counters, camera, torch, '
        'and the burst session', () async {
      fake
        ..mode = FakeCaptureMode.captureError
        ..fixture = FakeCaptureService.rackOkeyFixture;
      await fake.openSystemSettings();
      fake.mode = FakeCaptureMode.ready;
      await fake.initializeCamera(frontCamera: true);
      await fake.setFlash(enabled: true);
      await fake.captureStillToFile();
      await fake.captureStillToFile();

      // A non-default mode right before the reset, so the reset provably
      // clears it.
      fake
        ..mode = FakeCaptureMode.cameraDenied
        ..reset();

      check(fake.mode).equals(FakeCaptureMode.ready);
      check(fake.fixture).equals(FakeCaptureService.rack101Fixture);
      check(fake.openSystemSettingsCount).equals(0);
      check(fake.isInitialized).isFalse();
      check(fake.flashOn).isFalse();

      // The burst session restarted: the next capture copies the fixture,
      // not the next burst frame.
      await fake.initializeCamera(frontCamera: false);
      final path = await fake.captureStillToFile();
      check(path).endsWith(
        FakeCaptureService.rack101Fixture.split('/').last,
      );
    });
  });
}
