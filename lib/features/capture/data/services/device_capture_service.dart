import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:image_picker/image_picker.dart';
import 'package:okey_acar_mi/core/camera/viewfinder_service.dart';
import 'package:okey_acar_mi/core/error/failure.dart';
import 'package:okey_acar_mi/features/capture/data/services/capture_error_mapper.dart';
import 'package:okey_acar_mi/features/capture/domain/entities/permission_verdict.dart';
import 'package:okey_acar_mi/features/capture/domain/repositories/capture_repository.dart';
import 'package:permission_handler/permission_handler.dart';

/// Production capture service: one concrete class implementing both the pure
/// [CaptureRepository] contract and the Flutter [ViewfinderService] (D2),
/// backed by the `camera`, `permission_handler`, and `image_picker` plugins.
///
/// Registered per-environment by `capture_bindings.dart` with a dispose
/// adapter that releases the [CameraController] when the DI container resets.
class DeviceCaptureService implements CaptureRepository, ViewfinderService {
  /// Creates a [DeviceCaptureService] backed by the real platform plugins.
  DeviceCaptureService() : _picker = ImagePicker();

  final ImagePicker _picker;

  CameraController? _controller;
  List<CameraDescription>? _cameras;

  static PermissionVerdict _verdictOf(PermissionStatus status) {
    return switch (status) {
      PermissionStatus.granted ||
      PermissionStatus.limited ||
      PermissionStatus.provisional => PermissionVerdict.granted,
      PermissionStatus.permanentlyDenied ||
      // Restricted (parental controls) cannot be prompted past either.
      PermissionStatus.restricted => PermissionVerdict.permanentlyDenied,
      PermissionStatus.denied => PermissionVerdict.denied,
    };
  }

  @override
  Future<PermissionVerdict> checkCameraPermission() async =>
      _verdictOf(await Permission.camera.status);

  @override
  Future<PermissionVerdict> requestCameraPermission() async =>
      _verdictOf(await Permission.camera.request());

  @override
  Future<void> openSystemSettings() => openAppSettings();

  @override
  Future<void> initializeCamera({required bool frontCamera}) async {
    await releaseCamera();
    try {
      final cameras = _cameras ??= await availableCameras();
      if (cameras.isEmpty) throw const Failure.noCamera();
      final wanted = frontCamera
          ? CameraLensDirection.front
          : CameraLensDirection.back;
      final description = cameras.firstWhere(
        (camera) => camera.lensDirection == wanted,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        description,
        ResolutionPreset.veryHigh,
        enableAudio: false,
      );
      await controller.initialize();
      _controller = controller;
    } on Object catch (error) {
      throw mapCameraError(error);
    }
  }

  @override
  Future<void> releaseCamera() async {
    final controller = _controller;
    _controller = null;
    if (controller == null) return;
    try {
      // Reset the torch so it never stays lit after the screen is left.
      if (controller.value.isInitialized) {
        await controller.setFlashMode(FlashMode.off);
      }
    } on Object {
      // Releasing anyway — a failed torch reset must not block disposal.
    }
    await controller.dispose();
  }

  /// Front cameras have no torch; the plugin exposes no capability query, so
  /// the back lens is the practical availability heuristic.
  @override
  bool get isFlashAvailable =>
      _controller?.description.lensDirection == CameraLensDirection.back;

  @override
  Future<void> setFlash({required bool enabled}) async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      throw const Failure.captureFailed('camera-not-initialized');
    }
    try {
      await controller.setFlashMode(
        enabled ? FlashMode.torch : FlashMode.off,
      );
    } on Object catch (error) {
      throw mapCameraError(error);
    }
  }

  @override
  Future<String> captureStillToFile() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      throw const Failure.captureFailed('camera-not-initialized');
    }
    try {
      final file = await controller.takePicture();
      return file.path;
    } on Object catch (error) {
      throw mapCameraError(error);
    }
  }

  @override
  Future<String?> pickImageFromGallery() async {
    try {
      final file = await _picker.pickImage(source: ImageSource.gallery);
      return file?.path;
    } on PlatformException catch (exception) {
      throw mapGalleryError(exception);
    }
  }

  @override
  bool get hasLivePreview => true;

  @override
  Widget buildViewfinder(BuildContext context) {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return const ColoredBox(color: Color(0xFF000000));
    }
    final previewSize = controller.value.previewSize;
    if (previewSize == null) return CameraPreview(controller);
    // Aspect-corrected cover: the preview reports a landscape sensor size, so
    // swap it for this portrait-locked app and let FittedBox crop the excess.
    return ClipRect(
      child: FittedBox(
        fit: BoxFit.cover,
        clipBehavior: Clip.hardEdge,
        child: SizedBox(
          width: previewSize.height,
          height: previewSize.width,
          child: CameraPreview(controller),
        ),
      ),
    );
  }
}
