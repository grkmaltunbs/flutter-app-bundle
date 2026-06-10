import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:okey_acar_mi/core/camera/viewfinder_service.dart';
import 'package:okey_acar_mi/core/error/failure.dart';
import 'package:okey_acar_mi/features/capture/domain/entities/permission_verdict.dart';
import 'package:okey_acar_mi/features/capture/domain/repositories/capture_repository.dart';
import 'package:path_provider/path_provider.dart';

/// The capture states the demo fake can be driven into, so every camera flow
/// (permissions, no-camera, capture errors, gallery denial/cancel) is
/// reachable on a simulator without real hardware behavior.
enum FakeCaptureMode {
  /// Camera permitted, captures succeed (default).
  ready,

  /// Camera permission is denied but re-promptable.
  cameraDenied,

  /// Camera permission is permanently denied (Settings-only escape).
  cameraPermanentlyDenied,

  /// The device has no camera: `initializeCamera` throws `Failure.noCamera`.
  noCamera,

  /// Still captures throw `Failure.captureFailed`.
  captureError,

  /// The gallery picker resolves as user-cancelled (`null`).
  galleryCancelled,

  /// The gallery picker throws a re-promptable `Failure.photoAccessDenied`.
  galleryDenied,

  /// The gallery picker throws a permanent `Failure.photoAccessDenied`.
  galleryPermanentlyDenied,
}

/// In-memory, seeded capture service for the demo flavor: implements both
/// [CaptureRepository] and [ViewfinderService] (D2).
///
/// Deterministic, offline, instant — no plugins, no hardware. Flip [mode]
/// (it is a `demo`-scoped singleton, so tests resolve it from the DI
/// container and set the mode) to drive denial/error paths, and [fixture] to
/// change the simulated scene. "Captured" files are real temp-file copies of
/// the bundled fixtures: the first capture of a camera session copies
/// [fixture] (the photo path) and every subsequent capture cycles the three
/// burst-frame fixtures, so a 5-frame burst deterministically yields
/// `[fixture, frame_1, frame_2, frame_3, frame_1]`.
class FakeCaptureService implements CaptureRepository, ViewfinderService {
  /// Creates a [FakeCaptureService] in [FakeCaptureMode.ready].
  FakeCaptureService();

  /// Controls the behavior of every operation. Defaults to
  /// [FakeCaptureMode.ready].
  FakeCaptureMode mode = FakeCaptureMode.ready;

  /// The asset shown in the viewfinder and copied by the session's first
  /// still capture.
  String fixture = rack101Fixture;

  /// How many times [openSystemSettings] was invoked (the fake never leaves
  /// the app, so integration tests assert on this counter instead).
  int openSystemSettingsCount = 0;

  /// The seeded 21-tile (101 mode) rack photo.
  static const String rack101Fixture =
      'assets/fixtures/capture/rack_101_21.png';

  /// The seeded 14-tile (Okey mode) rack photo.
  static const String rackOkeyFixture =
      'assets/fixtures/capture/rack_okey_14.png';

  /// The burst-frame fixtures, cycled by repeated still captures.
  static const List<String> frameFixtures = [
    'assets/fixtures/capture/rack_frame_1.png',
    'assets/fixtures/capture/rack_frame_2.png',
    'assets/fixtures/capture/rack_frame_3.png',
  ];

  bool _initialized = false;
  bool _flashOn = false;
  int _sessionCaptures = 0;
  int _fileCounter = 0;

  /// Whether the fake currently "holds" the camera.
  bool get isInitialized => _initialized;

  /// Whether the fake torch is on.
  bool get flashOn => _flashOn;

  /// Restores the fake to its defaults (ready, 101 fixture, counters reset).
  void reset() {
    mode = FakeCaptureMode.ready;
    fixture = rack101Fixture;
    openSystemSettingsCount = 0;
    _initialized = false;
    _flashOn = false;
    _sessionCaptures = 0;
    _fileCounter = 0;
  }

  PermissionVerdict get _cameraVerdict => switch (mode) {
    FakeCaptureMode.cameraDenied => PermissionVerdict.denied,
    FakeCaptureMode.cameraPermanentlyDenied =>
      PermissionVerdict.permanentlyDenied,
    _ => PermissionVerdict.granted,
  };

  @override
  Future<PermissionVerdict> checkCameraPermission() async => _cameraVerdict;

  /// The fake "prompt" changes nothing: a denied mode stays denied until a
  /// test flips [mode] and retries — that models the user answering the
  /// system dialog.
  @override
  Future<PermissionVerdict> requestCameraPermission() async => _cameraVerdict;

  @override
  Future<void> openSystemSettings() async => openSystemSettingsCount++;

  @override
  Future<void> initializeCamera({required bool frontCamera}) async {
    if (mode == FakeCaptureMode.noCamera) throw const Failure.noCamera();
    _initialized = true;
    _flashOn = false;
    _sessionCaptures = 0;
  }

  @override
  Future<void> releaseCamera() async {
    _initialized = false;
    _flashOn = false;
  }

  @override
  bool get isFlashAvailable => true;

  @override
  Future<void> setFlash({required bool enabled}) async => _flashOn = enabled;

  /// Contract divergence from `DeviceCaptureService` (deliberate): the fake
  /// succeeds even when [isInitialized] is false, whereas the device impl
  /// throws `Failure.captureFailed('camera-not-initialized')` without a live
  /// `initializeCamera` session. Camera-lifecycle bugs (capturing after a
  /// release) are therefore masked under the demo flavor and only reproduce
  /// on a real device.
  @override
  Future<String> captureStillToFile() async {
    if (mode == FakeCaptureMode.captureError) {
      throw const Failure.captureFailed('fake-capture-error');
    }
    final index = _sessionCaptures++;
    final source = index == 0
        ? fixture
        : frameFixtures[(index - 1) % frameFixtures.length];
    return _copyAssetToTemp(source);
  }

  @override
  Future<String?> pickImageFromGallery() async {
    switch (mode) {
      case FakeCaptureMode.galleryCancelled:
        return null;
      case FakeCaptureMode.galleryDenied:
        throw const Failure.photoAccessDenied(permanent: false);
      case FakeCaptureMode.galleryPermanentlyDenied:
        throw const Failure.photoAccessDenied(permanent: true);
      case FakeCaptureMode.ready:
      case FakeCaptureMode.cameraDenied:
      case FakeCaptureMode.cameraPermanentlyDenied:
      case FakeCaptureMode.noCamera:
      case FakeCaptureMode.captureError:
        return _copyAssetToTemp(fixture);
    }
  }

  /// Copies the bundled [asset] to a unique temp file so the payload carries
  /// a real, readable file path — exactly like a true capture.
  Future<String> _copyAssetToTemp(String asset) async {
    final bytes = await rootBundle.load(asset);
    final directory = await getTemporaryDirectory();
    final file = File(
      '${directory.path}/fake_capture_${++_fileCounter}_'
      '${asset.split('/').last}',
    );
    await file.writeAsBytes(
      bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
    );
    return file.path;
  }

  @override
  bool get hasLivePreview => false;

  @override
  Widget buildViewfinder(BuildContext context) {
    // The fixture scene under a dark radial scrim, standing in for the live
    // preview so the capture screen looks real on simulators.
    return DecoratedBox(
      position: DecorationPosition.foreground,
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          radius: 1.1,
          colors: [Color(0x33000000), Color(0xB3000000)],
        ),
      ),
      child: Image.asset(
        fixture,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
      ),
    );
  }
}
