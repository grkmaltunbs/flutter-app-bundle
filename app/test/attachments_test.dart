// Files on their way to Claude: the type a name implies, a file in parts
// over the relay and back in one piece, a screenshot shrunk to the edge
// the API would shrink it to anyway.
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter_kit/kit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kit_app/src/attachment_picker.dart';
import 'package:kit_app/src/attachments.dart';
import 'package:kit_app/src/relay.dart';

void main() {
  test('the type a name implies; the size a chip says; what may ride inline', () {
    expect(mimeFor('Screenshot_2026.png'), 'image/png');
    expect(mimeFor('photo.JPG'), 'image/jpeg');
    expect(mimeFor('spec.pdf'), 'application/pdf');
    expect(mimeFor('notes'), 'application/octet-stream');
    expect(formatBytes(900), '900 B');
    expect(formatBytes(412 * 1024), '412 KB');
    expect(formatBytes((1.3 * 1024 * 1024).round()), '1.3 MB');
    expect(PendingAttachment(name: 'a.png', mime: 'image/png', bytes: Uint8List(10)).inlinable, isTrue);
    expect(PendingAttachment(name: 'a.svg', mime: 'image/svg+xml', bytes: Uint8List(10)).inlinable, isFalse, reason: 'the API takes four image types');
    expect(PendingAttachment(name: 'a.png', mime: 'image/png', bytes: Uint8List(maxInlineImageBytes + 1)).inlinable, isFalse, reason: 'past the API size it rides by path');
  });

  test('files from a picker or a drop become attachments, typed by name when the source does not say', () async {
    // On a desktop or a phone an XFile's name is its path's last segment.
    final got = await attachmentsFrom([
      XFile.fromData(Uint8List.fromList([1, 2, 3]), path: '/tmp/notes.md'),
      XFile.fromData(Uint8List.fromList([4, 5]), path: '/tmp/blob', mimeType: 'application/pdf'),
      XFile.fromData(Uint8List.fromList([6]), path: '/tmp/x.csv', mimeType: 'application/octet-stream'),
    ]);
    expect(got.map((a) => a.mime), ['text/markdown', 'application/pdf', 'text/csv']);
    expect(got.map((a) => a.size), [3, 2, 1]);
  });

  test('a file goes up in parts and comes back in one piece; then it is gone', () async {
    final db = FakeFirebaseFirestore();
    final r = Random(7);
    final bytes = Uint8List.fromList(List.generate(uploadChunk * 2 + 12345, (_) => r.nextInt(256)));
    final id = await UploadSender(db, 'demo').send(PendingAttachment(name: 'shot.png', mime: 'image/png', bytes: bytes), from: 'phone');
    final uploads = db.collection('projects').doc('demo').collection('uploads');
    final head = (await uploads.doc(id).get()).data()!;
    expect(head['parts'], 3);
    expect(head['complete'], isTrue);
    expect(head['size'], bytes.length);
    expect(head['from'], 'phone');
    final parts = await uploads.doc(id).collection('parts').get();
    expect(parts.docs.length, 3);
    for (final d in parts.docs) {
      expect((d.data()['data'] as String).length, lessThan(1000 * 1000), reason: 'a document holds a megabyte');
    }

    final reader = UploadReader(db, 'demo');
    final back = await reader.fetch(id);
    expect(back.name, 'shot.png');
    expect(back.mime, 'image/png');
    expect(back.bytes, bytes);

    await reader.delete(id);
    expect((await uploads.get()).docs, isEmpty);
    expect((await uploads.doc(id).collection('parts').get()).docs, isEmpty);
    expect(() => reader.fetch(id), throwsStateError);
  });

  test('an empty file is one part; a half-written upload is refused', () async {
    final db = FakeFirebaseFirestore();
    final id = await UploadSender(db, 'demo').send(PendingAttachment(name: 'empty.txt', mime: 'text/plain', bytes: Uint8List(0)), from: 'phone');
    expect((await UploadReader(db, 'demo').fetch(id)).size, 0);
    await db.collection('projects').doc('demo').collection('uploads').doc(id).set({'complete': false}, SetOptions(merge: true));
    expect(() => UploadReader(db, 'demo').fetch(id), throwsStateError);
  });

  test('uploads nobody collected go after a day', () async {
    final db = FakeFirebaseFirestore();
    final coll = db.collection('projects').doc('demo').collection('uploads');
    await coll.doc('old').set({'name': 'a', 'sentAt': '2026-09-01T00:00:00.000Z', 'complete': true, 'parts': 0, 'size': 0});
    await coll.doc('old').collection('parts').doc('0000').set({'i': 0, 'data': ''});
    await coll.doc('new').set({'name': 'b', 'sentAt': '2026-09-02T09:00:00.000Z', 'complete': true, 'parts': 0, 'size': 0});
    final n = await UploadReader(db, 'demo').prune(now: DateTime.utc(2026, 9, 2, 10));
    expect(n, 1);
    expect((await coll.get()).docs.map((d) => d.id), ['new']);
    expect((await coll.doc('old').collection('parts').get()).docs, isEmpty);
  });

  testWidgets('a wide screenshot is shrunk to the API edge; a small or unreadable image is left alone', (tester) async {
    await tester.runAsync(() async {
      final big = PendingAttachment(name: 'wide.jpg', mime: 'image/jpeg', bytes: await _png(3136, 800));
      final s = await shrinkImage(big);
      expect(s.name, 'wide.png');
      expect(s.mime, 'image/png');
      expect(await _dims(s.bytes), (1568, 400));

      final small = PendingAttachment(name: 'small.png', mime: 'image/png', bytes: await _png(300, 200));
      expect(identical(await shrinkImage(small), small), isTrue);

      final junk = PendingAttachment(name: 'junk.png', mime: 'image/png', bytes: Uint8List.fromList([1, 2, 3]));
      expect(identical(await shrinkImage(junk), junk), isTrue, reason: 'undecodable here: sent as it is');
    });
  });
}

Future<Uint8List> _png(int w, int h) async {
  final rec = ui.PictureRecorder();
  final c = ui.Canvas(rec);
  c.drawRect(ui.Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()), ui.Paint()..color = const ui.Color(0xFF58D7FF));
  final img = await rec.endRecording().toImage(w, h);
  final data = await img.toByteData(format: ui.ImageByteFormat.png);
  img.dispose();
  return data!.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
}

Future<(int, int)> _dims(Uint8List bytes) async {
  final buf = await ui.ImmutableBuffer.fromUint8List(bytes);
  final d = await ui.ImageDescriptor.encoded(buf);
  final r = (d.width, d.height);
  d.dispose();
  buf.dispose();
  return r;
}
