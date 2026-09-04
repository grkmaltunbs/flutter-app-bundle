// Files on their way to Claude: the type a name implies, a file into the
// bucket and back whole, a screenshot shrunk to the edge the API would
// shrink it to anyway.
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_selector/file_selector.dart';
import 'package:flutter_kit/kit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kit_app/src/attachment_picker.dart';
import 'package:kit_app/src/attachments.dart';
import 'package:kit_app/src/blobs.dart';
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

  test('a file goes into the bucket under the project and comes back whole; then it is gone', () async {
    final blobs = MemoryBlobStore();
    final r = Random(7);
    final bytes = Uint8List.fromList(List.generate(12 * 1024 * 1024 + 12345, (_) => r.nextInt(256)));
    final progress = <double>[];
    final up = await UploadSender(blobs, 'demo', newId: () => 'up1').send(PendingAttachment(name: 'my shot (1).png', mime: 'image/png', bytes: bytes), from: 'phone', onProgress: progress.add);
    expect(up['id'], 'up1');
    expect(up['path'], 'projects/demo/uploads/up1/my_shot_1_.png', reason: 'a name a path and a URL can carry');
    expect(up['name'], 'my shot (1).png', reason: 'the file keeps its own name');
    expect(up['mime'], 'image/png');
    expect(up['size'], bytes.length);
    expect(up['from'], 'phone');
    expect(progress.first, 0);
    expect(progress.last, 1);
    expect(blobs.objects.keys, ['projects/demo/uploads/up1/my_shot_1_.png']);
    expect(blobs.objects.values.single.contentType, 'image/png');

    final reader = UploadReader(blobs, 'demo');
    final back = await reader.fetch(up);
    expect(back.name, 'my shot (1).png');
    expect(back.mime, 'image/png');
    expect(back.bytes, bytes);

    await reader.delete(up);
    expect(blobs.objects, isEmpty);
    expect(() => reader.fetch(up), throwsA(isA<StateError>().having((e) => e.message, 'message', 'upload up1 is gone')));
    await reader.delete(up);
  });

  test('an upload is refused when it is not the size the phone said, or not under this project', () async {
    final blobs = MemoryBlobStore();
    final up = await UploadSender(blobs, 'demo', newId: () => 'u').send(PendingAttachment(name: 'a.txt', mime: 'text/plain', bytes: Uint8List(0)), from: 'phone');
    expect((await UploadReader(blobs, 'demo').fetch(up)).size, 0, reason: 'an empty file is a file');
    expect(() => UploadReader(blobs, 'demo').fetch({...up, 'size': 3}), throwsA(isA<StateError>().having((e) => e.message, 'message', contains('came to 0 bytes, not 3'))));
    expect(() => UploadReader(blobs, 'other').fetch(up), throwsA(isA<StateError>().having((e) => e.message, 'message', contains('not under this project'))));
    expect(() => UploadReader(blobs, 'demo').fetch({'path': '/etc/passwd'}), throwsStateError);
    expect(blobs.objects, hasLength(1), reason: 'a refused fetch deletes nothing');
  });

  test('a put that dies mid-way leaves nothing in the bucket and throws', () async {
    final blobs = MemoryBlobStore()..failNextPutWith = StateError('the network went');
    final progress = <double>[];
    await expectLater(
      UploadSender(blobs, 'demo').send(PendingAttachment(name: 'b.pdf', mime: 'application/pdf', bytes: Uint8List(10)), from: 'phone', onProgress: progress.add),
      throwsStateError,
    );
    expect(blobs.objects, isEmpty);
    expect(progress, isNotEmpty);
    expect(progress.last, lessThan(1));
  });

  test('uploads nobody collected go after a day', () async {
    final blobs = MemoryBlobStore();
    final old = await UploadSender(blobs, 'demo', newId: () => 'old').send(PendingAttachment(name: 'a', mime: 'text/plain', bytes: Uint8List(1)), from: 'phone');
    await UploadSender(blobs, 'demo', newId: () => 'new').send(PendingAttachment(name: 'b', mime: 'text/plain', bytes: Uint8List(1)), from: 'phone');
    await UploadSender(blobs, 'other', newId: () => 'old').send(PendingAttachment(name: 'c', mime: 'text/plain', bytes: Uint8List(1)), from: 'phone');
    blobs.age(old['path'].toString(), DateTime.utc(2026, 9, 1));
    blobs.age('projects/other/uploads/old/c', DateTime.utc(2026, 9, 1));
    final n = await UploadReader(blobs, 'demo').prune(now: DateTime.utc(2026, 9, 2, 10));
    expect(n, 1);
    expect(blobs.objects.keys, unorderedEquals(['projects/demo/uploads/new/b', 'projects/other/uploads/old/c']), reason: 'another project\'s leftovers are its own');
  });

  test('a blob id sorts by time and a name is made safe', () {
    final a = newBlobId(Random(1));
    final b = newBlobId(Random(2));
    expect(a, matches(RegExp(r'^[0-9a-z]+-[a-z0-9]{6}$')));
    expect(int.parse(b.split('-').first, radix: 36) - int.parse(a.split('-').first, radix: 36), inInclusiveRange(0, 50), reason: 'time first: two ids made together sort together');
    expect(safeBlobName('İş planı v2 (final).PDF'), '_plan_v2_final_.PDF', reason: 'a run of anything else is one underscore; the dot and the extension stay');
    expect(safeBlobName('???'), 'file');
    expect(uploadBlobPath('demo', 'x', 'a b.png'), 'projects/demo/uploads/x/a_b.png');
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
