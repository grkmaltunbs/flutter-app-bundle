import 'dart:async';

import 'package:injectable/injectable.dart';
import 'package:okey_acar_mi/core/camera/viewfinder_service.dart';
import 'package:okey_acar_mi/features/capture/data/fakes/fake_capture_service.dart';
import 'package:okey_acar_mi/features/capture/data/services/device_capture_service.dart';
import 'package:okey_acar_mi/features/capture/domain/repositories/capture_repository.dart';

/// Releases the [DeviceCaptureService]'s camera controller when the DI
/// container resets (`getIt.reset()`).
FutureOr<void> disposeDeviceCaptureService(DeviceCaptureService instance) =>
    instance.releaseCamera();

/// DI module for the capture feature (D2): one concrete service per
/// environment, registered as itself, with both [CaptureRepository] and
/// [ViewfinderService] aliased to that single instance.
@module
abstract class CaptureBindings {
  /// The production capture service (real camera, picker, permissions).
  @Environment('prod')
  @LazySingleton(dispose: disposeDeviceCaptureService)
  DeviceCaptureService get deviceCaptureService => DeviceCaptureService();

  /// Aliases the prod [CaptureRepository] to the device service.
  @Environment('prod')
  @lazySingleton
  CaptureRepository prodCaptureRepository(DeviceCaptureService service) =>
      service;

  /// Aliases the prod [ViewfinderService] to the device service.
  @Environment('prod')
  @lazySingleton
  ViewfinderService prodViewfinderService(DeviceCaptureService service) =>
      service;

  /// The seeded demo capture fake (no hardware, deterministic, instant).
  @Environment('demo')
  @lazySingleton
  FakeCaptureService get fakeCaptureService => FakeCaptureService();

  /// Aliases the demo [CaptureRepository] to the fake.
  @Environment('demo')
  @lazySingleton
  CaptureRepository demoCaptureRepository(FakeCaptureService service) =>
      service;

  /// Aliases the demo [ViewfinderService] to the fake.
  @Environment('demo')
  @lazySingleton
  ViewfinderService demoViewfinderService(FakeCaptureService service) =>
      service;
}
