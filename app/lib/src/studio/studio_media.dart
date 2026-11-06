import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_kit/kit.dart' show DeckMessage, DeckRole;
import 'package:path/path.dart' as p;

import '../blobs.dart';
import '../host/bridge_session.dart';
import 'studio_desk.dart';
import 'studio_resources.dart';

// Pictures and videos the autopilot shows the person — the orchestrator's
// and the step desk's replies (a file the reviewer opens in Preview in
// watch mode counts), and what the reviewer writes into review/ — gathered
// in one place: the Mac shows them in the Studio, and each is published to
// the relay (the bytes to Storage, a row to Firestore) so the phone shows
// them too.

const kImageExt = {'.png', '.jpg', '.jpeg', '.gif', '.webp'};
const kVideoExt = {'.mp4', '.mov', '.webm', '.m4v'};

/// The largest original the phone gets; a bigger file stays on the Mac.
const kMaxImageUpload = 25 * 1024 * 1024;
const kMaxVideoUpload = 150 * 1024 * 1024;

class MediaItem {
  MediaItem({required this.id, required this.path, required this.source, required this.at, this.caption, this.step, this.remote, this.thumb, this.tooBig = false, this.error, this.uploading = false});

  final String id;

  /// The file on this Mac.
  final String path;

  /// orchestrator · desk · review.
  final String source;
  final DateTime at;

  /// The words around it in the reply, or how it came.
  final String? caption;

  /// For the desk: `a/ROOMLAB-1C` or `M3.22`.
  final String? step;

  /// Its Storage path once published; [thumb] the small picture's.
  String? remote;
  String? thumb;

  /// Too big to publish: it stays on the Mac.
  bool tooBig;

  /// Why the last upload failed — shown on its tile; null when fine.
  String? error;

  /// An upload is under way.
  bool uploading;

  /// Where it stands with the phone, for its tile.
  String get phoneState => tooBig ? 'MAC ONLY' : (uploading ? 'UPLOADING' : (remote != null ? 'ON THE PHONE' : (error != null ? 'UPLOAD FAILED' : 'NOT SENT')));

  bool get isVideo => kVideoExt.contains(p.extension(path).toLowerCase());
  String get name => p.basename(path);

  Map<String, Object?> toJson() => {'id': id, 'path': path, 'source': source, 'at': at.toIso8601String(), 'caption': caption, 'step': step, 'remote': remote, 'thumb': thumb, 'tooBig': tooBig, 'error': error};
  static MediaItem fromJson(Map<String, Object?> j) => MediaItem(
        id: j['id'] as String,
        path: j['path'] as String,
        source: j['source'] as String,
        at: DateTime.parse(j['at'] as String),
        caption: j['caption'] as String?,
        step: j['step'] as String?,
        remote: j['remote'] as String?,
        thumb: j['thumb'] as String?,
        tooBig: j['tooBig'] == true,
        error: j['error'] as String?,
      );
}

/// Media paths a reply or a command names: absolute paths, and paths
/// relative to a repo (resolved by [resolve]); only files that exist here.
List<String> mediaPathsIn(String text, {String? Function(String rel)? resolve}) {
  final out = <String>[];
  bool media(String s) {
    final e = p.extension(s).toLowerCase();
    return kImageExt.contains(e) || kVideoExt.contains(e);
  }

  for (final m in RegExp(r'''(/(?:Users|private|tmp|Volumes|var)/[^\s`"'()\[\]<>]+)''').allMatches(text)) {
    final s = m.group(1)!.replaceAll(RegExp(r'[.,;:]+$'), '');
    if (media(s) && File(s).existsSync()) out.add(s);
  }
  if (resolve != null) {
    for (final rel in namedPaths(text)) {
      if (rel.startsWith('/') || !media(rel)) continue;
      final at = resolve(rel);
      if (at != null && File(at).existsSync()) out.add(at);
    }
  }
  return out.toSet().toList();
}

/// The line of [text] that names [path] — the caption a picture keeps.
String? captionFor(String text, String path) {
  final name = p.basename(path);
  for (final l in text.split('\n')) {
    if (l.contains(name)) {
      final c = l.replaceAll(RegExp(r'[`*#>]|!\[[^\]]*\]\([^)]*\)'), '').replaceAll(RegExp(r'\s+'), ' ').trim();
      return c.length > 200 ? '${c.substring(0, 197)}…' : c;
    }
  }
  return null;
}

/// Where a media item goes on the relay.
abstract class MediaPublisher {
  Future<void> publish(MediaItem item, Uint8List bytes, Uint8List? thumb);
}

class FirebaseMediaPublisher implements MediaPublisher {
  FirebaseMediaPublisher({required this.db, required this.blobs});
  final FirebaseFirestore db;
  final BlobStore blobs;

  @override
  Future<void> publish(MediaItem item, Uint8List bytes, Uint8List? thumb) async {
    final base = 'studio/media/${item.id}';
    final remote = '$base/${safeBlobName(item.name)}';
    await blobs.put(remote, bytes, contentType: _mime(item.path));
    String? thumbPath;
    if (thumb != null) {
      thumbPath = '$base/thumb.png';
      await blobs.put(thumbPath, thumb, contentType: 'image/png');
    }
    item
      ..remote = remote
      ..thumb = thumbPath;
    final doc = db.collection('studio').doc('main');
    await doc.collection('media').doc(item.id).set({
      'name': item.name,
      'kind': item.isVideo ? 'video' : 'image',
      'path': remote,
      'thumb': thumbPath,
      'caption': item.caption,
      'source': item.source,
      'step': item.step,
      'size': bytes.length,
      'at': item.at.toUtc().toIso8601String(),
    });
    await doc.set({'updatedAt': FieldValue.serverTimestamp(), 'media': FieldValue.increment(1)}, SetOptions(merge: true));
  }
}

String _mime(String path) => switch (p.extension(path).toLowerCase()) {
      '.png' => 'image/png',
      '.jpg' || '.jpeg' => 'image/jpeg',
      '.gif' => 'image/gif',
      '.webp' => 'image/webp',
      '.mov' => 'video/quicktime',
      '.webm' => 'video/webm',
      _ => 'video/mp4',
    };

/// A small PNG of a picture, for the phone's gallery.
Future<Uint8List?> thumbnailOf(Uint8List bytes, {int width = 480}) async {
  try {
    final codec = await ui.instantiateImageCodec(bytes, targetWidth: width);
    final frame = await codec.getNextFrame();
    final data = await frame.image.toByteData(format: ui.ImageByteFormat.png);
    return data?.buffer.asUint8List();
  } catch (_) {
    return null;
  }
}

/// Everything gathered, newest first; kept in ~/.flutter_kit/studio/media.json.
class StudioMedia extends ChangeNotifier {
  StudioMedia({String? file, this.publisher, this.reviewDir, this.resolve, DateTime Function()? now, this.makeThumb = thumbnailOf})
      : file = file ?? p.join(Platform.environment['HOME'] ?? '.', '.flutter_kit', 'studio', 'media.json'),
        _now = now ?? DateTime.now;

  final String file;
  MediaPublisher? publisher;

  /// The reviewer's folder: new pictures and videos there are gathered.
  String? reviewDir;

  /// Resolves a repo-relative name to a file here.
  String? Function(String rel)? resolve;
  final DateTime Function() _now;
  final Future<Uint8List?> Function(Uint8List bytes) makeThumb;

  final List<MediaItem> items = [];
  final Set<String> _seen = {};

  /// Files in review/ newer than this are new.
  DateTime? _watermark;
  Timer? _timer;
  final List<Future<void>> _publishing = [];

  List<MediaItem> get newestFirst => [...items]..sort((a, b) => b.at.compareTo(a.at));

  void load() {
    try {
      final f = File(file);
      if (f.existsSync()) {
        final j = jsonDecode(f.readAsStringSync()) as Map<String, Object?>;
        items.addAll([for (final m in j['items'] as List) MediaItem.fromJson((m as Map).cast<String, Object?>())]);
        _seen.addAll([for (final s in (j['seen'] as List? ?? const [])) s as String]);
        final w = j['watermark'] as String?;
        if (w != null) _watermark = DateTime.parse(w);
      }
    } catch (_) {}
    notifyListeners();
  }

  void _save() {
    try {
      final f = File(file)..parent.createSync(recursive: true);
      final keep = newestFirst.take(500).toList();
      items
        ..clear()
        ..addAll(keep);
      f.writeAsStringSync(jsonEncode({'items': [for (final m in items) m.toJson()], 'seen': _seen.toList(), 'watermark': _watermark?.toIso8601String()}));
    } catch (_) {}
    notifyListeners();
  }

  final Set<BridgeSession> _watched = {};

  /// Watches a session's replies (and the commands it runs) for media — once per session.
  void watch(BridgeSession b, {required String source}) {
    if (!_watched.add(b)) return;
    b.addListener(() => collect(b, source: source));
  }

  void collect(BridgeSession b, {required String source}) {
    final sid = b.sessionId ?? 'x';
    var added = false;
    for (final m in b.transcript.messages) {
      if (m.streaming || m.role == DeckRole.user || m.role == DeckRole.note) continue;
      if (m.role == DeckRole.tool && m.toolResult == null) continue;
      final key = '$sid-${m.id}';
      if (_seen.contains(key)) continue;
      _seen.add(key);
      final text = _textOf(m);
      for (final path in mediaPathsIn(text, resolve: resolve)) {
        added |= _add(path, source: source, caption: m.role == DeckRole.tool ? 'opened by the $source' : captionFor(text, path), step: _stepOf(m));
      }
    }
    if (added) _save();
  }

  String _textOf(DeckMessage m) => m.role == DeckRole.tool ? '${m.toolInput?['command'] ?? ''} ${m.toolInput?['file_path'] ?? ''}' : m.text;

  String? _stepOf(DeckMessage m) {
    final k = threadKeyOf(m.about);
    return k?.substring(k.indexOf(':') + 1);
  }

  /// Files the person adds — dropped on the gallery or picked — sent to the
  /// phone like the rest. Returns how many were new.
  int addFiles(Iterable<String> paths, {String source = 'you'}) {
    var n = 0;
    for (final path in paths) {
      final e = p.extension(path).toLowerCase();
      if (!kImageExt.contains(e) && !kVideoExt.contains(e)) continue;
      if (_add(path, source: source, caption: 'added on the Mac')) n++;
    }
    if (n > 0) _save();
    return n;
  }

  /// Tries a failed (or never sent) upload again.
  void retry(MediaItem item) {
    item.error = null;
    _publishing.add(_publish(item));
    notifyListeners();
  }

  bool _add(String path, {required String source, String? caption, String? step}) {
    if (items.any((i) => i.path == path && i.source == source && i.step == step)) return false;
    final item = MediaItem(id: '${_now().microsecondsSinceEpoch}-${items.length}', path: path, source: source, at: _now(), caption: caption, step: step);
    items.add(item);
    _publishing.add(_publish(item));
    return true;
  }

  /// Gathers pictures and videos the reviewer wrote into review/ since the
  /// last look (the first look only sets the mark: no flood of old files).
  void scanReview() {
    final dir = reviewDir;
    if (dir == null || !Directory(dir).existsSync()) return;
    final now = _now();
    final mark = _watermark;
    _watermark = now;
    if (mark == null) {
      _save();
      return;
    }
    var added = false;
    for (final f in Directory(dir).listSync(recursive: true).whereType<File>()) {
      final e = p.extension(f.path).toLowerCase();
      if (!kImageExt.contains(e) && !kVideoExt.contains(e)) continue;
      if (!f.lastModifiedSync().isAfter(mark)) continue;
      added |= _add(f.path, source: 'review', caption: 'new in review/${p.relative(p.dirname(f.path), from: dir)}');
    }
    _save();
    if (!added) return;
  }

  void start({Duration every = const Duration(seconds: 30)}) {
    _timer ??= Timer.periodic(every, (_) => scanReview());
    scanReview();
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  /// Uploads in flight finished — for tests.
  Future<void> settled() => Future.wait(List.of(_publishing));

  Future<void> _publish(MediaItem item) async {
    final pub = publisher;
    if (pub == null) return;
    item.uploading = true;
    notifyListeners();
    try {
      final f = File(item.path);
      final size = f.lengthSync();
      if (size > (item.isVideo ? kMaxVideoUpload : kMaxImageUpload)) {
        item.tooBig = true;
        _save();
        return;
      }
      final bytes = await f.readAsBytes();
      final thumb = item.isVideo ? null : await makeThumb(bytes);
      await pub.publish(item, bytes, thumb).timeout(Duration(seconds: item.isVideo ? 600 : 120));
      item.error = null;
    } catch (e) {
      // Offline, not signed in, a rule — the Mac still shows it; the tile says why the phone does not.
      item.error = '$e'.replaceFirst('Exception: ', '');
    } finally {
      item.uploading = false;
      _save();
    }
  }
}
