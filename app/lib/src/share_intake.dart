import 'dart:io';

import 'package:receive_sharing_intent/receive_sharing_intent.dart';

import 'attachments.dart';

/// What a share brought: pictures as pending attachments, and a line of
/// text for the composer.
class Shared {
  const Shared({this.files = const [], this.text});
  final List<PendingAttachment> files;
  final String? text;
  bool get isEmpty => files.isEmpty && (text == null || text!.isEmpty);
}

/// The files Android's share sheet handed over, read into attachments —
/// a screenshot of the app under test, most days. Text comes as text.
Shared sharedFrom(List<SharedMediaFile> media) {
  final files = <PendingAttachment>[];
  final texts = <String>[];
  for (final m in media) {
    if (m.type == SharedMediaType.text || m.type == SharedMediaType.url) {
      if (m.path.trim().isNotEmpty) texts.add(m.path.trim());
      continue;
    }
    final f = File(m.path);
    if (!f.existsSync()) continue;
    final name = f.uri.pathSegments.isEmpty ? 'shared' : f.uri.pathSegments.last;
    final mime = m.mimeType ?? mimeFor(name);
    try {
      files.add(PendingAttachment(name: name, mime: mime, bytes: f.readAsBytesSync()));
    } on Object {
      // A file the share sheet named but the app cannot read — skipped.
    }
  }
  return Shared(files: files, text: texts.isEmpty ? null : texts.join('\n'));
}

/// The mime a name suggests, for a share that came without one.
String mimeFor(String name) {
  final n = name.toLowerCase();
  if (n.endsWith('.png')) return 'image/png';
  if (n.endsWith('.jpg') || n.endsWith('.jpeg')) return 'image/jpeg';
  if (n.endsWith('.gif')) return 'image/gif';
  if (n.endsWith('.webp')) return 'image/webp';
  if (n.endsWith('.txt') || n.endsWith('.log') || n.endsWith('.md')) return 'text/plain';
  if (n.endsWith('.pdf')) return 'application/pdf';
  return 'application/octet-stream';
}

/// The phone's door for shares: what the app was opened with, and what
/// arrives while it runs.
class ShareIntake {
  ShareIntake({required this.onShared});
  final void Function(Shared shared) onShared;
  bool _started = false;

  void start() {
    if (_started) return;
    _started = true;
    final r = ReceiveSharingIntent.instance;
    r.getInitialMedia().then((m) {
      final s = sharedFrom(m);
      if (!s.isEmpty) onShared(s);
      r.reset();
    }, onError: (Object _) {});
    r.getMediaStream().listen((m) {
      final s = sharedFrom(m);
      if (!s.isEmpty) onShared(s);
    }, onError: (Object _) {});
  }
}
