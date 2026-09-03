import 'dart:math';
import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';

/// Bytes that are not rows. One door to Firebase Storage on the relay —
/// owner-only rules, the client SDK on both roles, no key — and a memory
/// twin for tests. Paths under the bucket:
///
/// ```
/// projects/{slug}/uploads/{id}/{name}     a file from the phone, deleted by the host once saved
/// projects/{slug}/frames/live.jpg         the mirror's newest frame
/// projects/{slug}/builds/{sha}.apk        a build for the phone
/// projects/{slug}/shots/{id}.jpg          a picture a push points at
/// projects/{slug}/files/{id}              a file too big for a row
/// ```
abstract class BlobStore {
  /// Writes [bytes] at [path]; [onProgress] hears 0…1 as they go.
  Future<void> put(String path, Uint8List bytes, {String? contentType, void Function(double fraction)? onProgress});

  /// Throws [StateError] when nothing is at [path].
  Future<Uint8List> get(String path);

  /// Quiet when nothing is there.
  Future<void> delete(String path);

  /// Every object under [prefix], at any depth.
  Future<List<BlobEntry>> list(String prefix);
}

/// One object in the bucket.
class BlobEntry {
  const BlobEntry({required this.path, required this.size, this.updatedAt});
  final String path;
  final int size;
  final DateTime? updatedAt;
}

/// The most the host reads back in one piece — an attachment is 32 MB at
/// the picker; a build for the phone is the exception and streams later.
const maxBlobBytes = 64 * 1024 * 1024;

/// Where a phone's upload lives: the id keeps two files of one name apart,
/// the name keeps the extension the Read tool wants.
String uploadBlobPath(String slug, String id, String name) => '${uploadsPrefix(slug)}/$id/${safeBlobName(name)}';
String uploadsPrefix(String slug) => 'projects/$slug/uploads';

/// A name with nothing a path or a URL would trip on.
String safeBlobName(String name) {
  final s = name.replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_');
  return RegExp('[A-Za-z0-9]').hasMatch(s) ? s : 'file';
}

/// A short id for an upload: time first, so a listing reads in order.
String newBlobId([Random? random]) {
  final r = random ?? Random.secure();
  const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
  final tail = List.generate(6, (_) => chars[r.nextInt(chars.length)]).join();
  return '${DateTime.now().toUtc().millisecondsSinceEpoch.toRadixString(36)}-$tail';
}

/// Firebase Storage on the relay bucket. Retries are short: a phone in a
/// tunnel should hear "could not send" in under a minute, not in ten.
class FirebaseBlobStore implements BlobStore {
  FirebaseBlobStore([FirebaseStorage? storage]) : storage = storage ?? FirebaseStorage.instance {
    this.storage.setMaxUploadRetryTime(const Duration(seconds: 45));
    this.storage.setMaxDownloadRetryTime(const Duration(seconds: 45));
    this.storage.setMaxOperationRetryTime(const Duration(seconds: 30));
  }

  final FirebaseStorage storage;

  @override
  Future<void> put(String path, Uint8List bytes, {String? contentType, void Function(double fraction)? onProgress}) async {
    final task = storage.ref(path).putData(bytes, contentType == null ? null : SettableMetadata(contentType: contentType));
    if (onProgress != null) {
      task.snapshotEvents.listen((s) => onProgress(s.totalBytes <= 0 ? 1 : s.bytesTransferred / s.totalBytes), onError: (Object _) {});
    }
    await task;
    onProgress?.call(1);
  }

  @override
  Future<Uint8List> get(String path) async {
    final Uint8List? data;
    try {
      data = await storage.ref(path).getData(maxBlobBytes);
    } on FirebaseException catch (e) {
      if (e.code == 'object-not-found') throw StateError('nothing at $path');
      rethrow;
    }
    if (data == null) throw StateError('nothing at $path');
    return data;
  }

  @override
  Future<void> delete(String path) async {
    try {
      await storage.ref(path).delete();
    } on FirebaseException catch (e) {
      if (e.code != 'object-not-found') rethrow;
    }
  }

  @override
  Future<List<BlobEntry>> list(String prefix) async {
    final out = <BlobEntry>[];
    Future<void> walk(Reference ref) async {
      final r = await ref.listAll();
      for (final item in r.items) {
        final m = await item.getMetadata();
        out.add(BlobEntry(path: item.fullPath, size: m.size ?? 0, updatedAt: m.updated));
      }
      for (final p in r.prefixes) {
        await walk(p);
      }
    }

    await walk(storage.ref(prefix));
    return out;
  }
}

/// The bucket in memory — what a test sends through.
class MemoryBlobStore implements BlobStore {
  MemoryBlobStore({DateTime Function()? now}) : _now = now ?? DateTime.now;

  final DateTime Function() _now;
  final Map<String, BlobObject> objects = {};

  /// Set to make the next [put] fail after it reported some progress — a
  /// phone that lost the network mid-upload.
  Object? failNextPutWith;

  /// Every progress fraction reported, per path.
  final Map<String, List<double>> progress = {};

  @override
  Future<void> put(String path, Uint8List bytes, {String? contentType, void Function(double fraction)? onProgress}) async {
    void report(double f) {
      progress.putIfAbsent(path, () => []).add(f);
      onProgress?.call(f);
    }

    report(0);
    if (bytes.isNotEmpty) report(0.5);
    final fail = failNextPutWith;
    if (fail != null) {
      failNextPutWith = null;
      throw fail;
    }
    objects[path] = BlobObject(Uint8List.fromList(bytes), contentType, _now());
    report(1);
  }

  @override
  Future<Uint8List> get(String path) async {
    final o = objects[path];
    if (o == null) throw StateError('nothing at $path');
    return Uint8List.fromList(o.bytes);
  }

  @override
  Future<void> delete(String path) async {
    objects.remove(path);
  }

  @override
  Future<List<BlobEntry>> list(String prefix) async {
    final p = prefix.endsWith('/') ? prefix : '$prefix/';
    return [
      for (final e in objects.entries)
        if (e.key.startsWith(p)) BlobEntry(path: e.key, size: e.value.bytes.length, updatedAt: e.value.at),
    ];
  }

  /// Backdates an object — for a prune test.
  void age(String path, DateTime to) {
    final o = objects[path];
    if (o != null) objects[path] = BlobObject(o.bytes, o.contentType, to);
  }
}

/// What the memory bucket holds for one path.
class BlobObject {
  const BlobObject(this.bytes, this.contentType, this.at);
  final Uint8List bytes;
  final String? contentType;
  final DateTime at;
}
