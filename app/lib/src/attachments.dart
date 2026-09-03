import 'dart:typed_data';

import 'package:flutter_kit/kit.dart';

/// A file on its way to Claude: picked on this device, not yet on the Mac.
class PendingAttachment {
  PendingAttachment({required this.name, required this.mime, required this.bytes});
  final String name;
  final String mime;
  final Uint8List bytes;

  int get size => bytes.length;
  bool get isImage => mime.startsWith('image/');

  /// Small enough, and a type the API takes, to ride inline with the
  /// message — the model sees it without a tool call, as it does a pasted
  /// screenshot in the terminal. Anything else rides by path.
  bool get inlinable => apiImageTypes.contains(mime) && size <= maxInlineImageBytes;

  /// The row the deck shows for it — with [path] once the host saved it.
  DeckAttachment describe({String? path}) => DeckAttachment(name: name, mime: mime, size: size, path: path);
}

/// One file, after an image was shrunk. Bigger is refused at the picker —
/// the bytes sit in the phone's memory on their way to the bucket.
const maxAttachmentBytes = 32 * 1024 * 1024;

/// The API takes 5 MB per image; an image past this rides by path only.
const maxInlineImageBytes = 4 * 1024 * 1024;

/// The image types the API accepts as a block.
const apiImageTypes = {'image/png', 'image/jpeg', 'image/gif', 'image/webp'};

/// The type a name implies — the pickers do not always say.
String mimeFor(String name) {
  final dot = name.lastIndexOf('.');
  final ext = dot < 0 ? '' : name.substring(dot + 1).toLowerCase();
  return const {
        'png': 'image/png',
        'jpg': 'image/jpeg',
        'jpeg': 'image/jpeg',
        'gif': 'image/gif',
        'webp': 'image/webp',
        'heic': 'image/heic',
        'svg': 'image/svg+xml',
        'pdf': 'application/pdf',
        'txt': 'text/plain',
        'log': 'text/plain',
        'md': 'text/markdown',
        'csv': 'text/csv',
        'html': 'text/html',
        'json': 'application/json',
        'yaml': 'application/yaml',
        'yml': 'application/yaml',
        'dart': 'text/x-dart',
        'zip': 'application/zip',
        'mp4': 'video/mp4',
      }[ext] ??
      'application/octet-stream';
}
