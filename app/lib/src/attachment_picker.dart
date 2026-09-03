import 'dart:math';
import 'dart:ui' as ui;

import 'package:file_selector/file_selector.dart';

import 'attachments.dart';

/// The system picker — the phone's document picker (screenshots sit under
/// Images there), the Mac's open panel.
Future<List<PendingAttachment>> pickAttachments() async => attachmentsFrom(await openFiles());

/// The files, whichever way they arrived — the picker, or a drop on the
/// Mac window. Images come back shrunk to the API's long edge; anything
/// else comes back as it is.
Future<List<PendingAttachment>> attachmentsFrom(Iterable<XFile> files) async {
  final out = <PendingAttachment>[];
  for (final f in files) {
    final bytes = await f.readAsBytes();
    var a = PendingAttachment(name: f.name, mime: _mimeOf(f), bytes: bytes);
    if (a.isImage) a = await shrinkImage(a);
    out.add(a);
  }
  return out;
}

String _mimeOf(XFile f) {
  final m = f.mimeType;
  return m == null || m.isEmpty || m == 'application/octet-stream' ? mimeFor(f.name) : m;
}

/// The API scales any image past 1568 px on its long edge down to that
/// before the model sees it — so an image shrunk to [maxEdge] here loses
/// nothing, and a phone screenshot travels at a third of the bytes. Comes
/// back as PNG. An image that is small enough, or that this device cannot
/// decode, comes back untouched.
Future<PendingAttachment> shrinkImage(PendingAttachment a, {int maxEdge = 1568}) async {
  final ui.ImmutableBuffer buffer;
  final ui.ImageDescriptor desc;
  try {
    buffer = await ui.ImmutableBuffer.fromUint8List(a.bytes);
    desc = await ui.ImageDescriptor.encoded(buffer);
  } on Object {
    return a;
  }
  try {
    final edge = max(desc.width, desc.height);
    if (edge <= maxEdge) return a;
    final scale = maxEdge / edge;
    final codec = await desc.instantiateCodec(targetWidth: (desc.width * scale).round(), targetHeight: (desc.height * scale).round());
    final frame = await codec.getNextFrame();
    final png = await frame.image.toByteData(format: ui.ImageByteFormat.png);
    frame.image.dispose();
    codec.dispose();
    if (png == null) return a;
    final dot = a.name.lastIndexOf('.');
    final stem = dot <= 0 ? a.name : a.name.substring(0, dot);
    return PendingAttachment(name: '$stem.png', mime: 'image/png', bytes: png.buffer.asUint8List(png.offsetInBytes, png.lengthInBytes));
  } on Object {
    return a;
  } finally {
    desc.dispose();
    buffer.dispose();
  }
}
