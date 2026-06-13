import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:okey_acar_mi/core/error/failure.dart';

/// Decodes the image at [path], bakes in its EXIF orientation, downscales the
/// longest edge to [maxDimension] (a no-op when already smaller), and
/// re-encodes JPEG at [quality] — the payload uploaded to Gemini.
///
/// Runs on a background isolate so the decode/resize never janks the analyzing
/// screen. Throws [Failure.detectionFailed] when the file cannot be decoded.
Future<Uint8List> prepareRackJpeg(
  String path, {
  required int maxDimension,
  required int quality,
}) => Isolate.run(() => _prepareRackJpegSync(path, maxDimension, quality));

/// The synchronous body — top-level so the [Isolate.run] closure captures only
/// its sendable arguments, never a surrounding `this`.
Uint8List _prepareRackJpegSync(String path, int maxDimension, int quality) {
  final decoded = img.decodeImage(File(path).readAsBytesSync());
  if (decoded == null) {
    throw const Failure.detectionFailed('undecodable-image');
  }
  final oriented = img.bakeOrientation(decoded);
  final longest = oriented.width > oriented.height
      ? oriented.width
      : oriented.height;

  img.Image scaled;
  if (longest <= maxDimension) {
    scaled = oriented;
  } else if (oriented.width >= oriented.height) {
    scaled = img.copyResize(oriented, width: maxDimension);
  } else {
    scaled = img.copyResize(oriented, height: maxDimension);
  }

  return img.encodeJpg(scaled, quality: quality);
}
