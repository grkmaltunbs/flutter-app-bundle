// Pictures and videos the autopilot shows: found in the orchestrator's and
// the desk's replies (and in a Preview command), new in review/, kept,
// published for the phone — and shown in the Mac's gallery and the phone's.
import 'dart:io';
import 'dart:typed_data';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart' hide Step, StepState;
import 'package:flutter_test/flutter_test.dart';
import 'package:kit_app/src/blobs.dart';
import 'package:kit_app/src/studio/studio_desk.dart';
import 'package:kit_app/src/studio/studio_media.dart';
import 'package:kit_app/src/studio/studio_media_view.dart';
import 'package:kit_app/src/theme.dart';
import 'package:path/path.dart' as p;

import 'helpers/fake_claude.dart';

// The smallest PNG there is: one transparent pixel.
final png = Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 13, 73, 72, 68, 82, 0, 0, 0, 1, 0, 0, 0, 1, 8, 6, 0, 0, 0, 31, 21, 196, 137, 0, 0, 0, 13, 73, 68, 65, 84, 120, 156, 99, 248, 15, 4, 0, 9, 251, 3, 253, 167, 160, 103, 72, 0, 0, 0, 0, 73, 69, 78, 68, 174, 66, 96, 130]);

class _Recorder implements MediaPublisher {
  final published = <(String, int, bool)>[];
  @override
  Future<void> publish(MediaItem item, Uint8List bytes, Uint8List? thumb) async {
    item
      ..remote = 'studio/media/${item.id}/${item.name}'
      ..thumb = thumb == null ? null : 'studio/media/${item.id}/thumb.png';
    published.add((item.name, bytes.length, thumb != null));
  }
}

class _Flaky implements MediaPublisher {
  _Flaky(this.failing);
  final bool Function() failing;
  @override
  Future<void> publish(MediaItem item, Uint8List bytes, Uint8List? thumb) async {
    if (failing()) throw Exception('no network');
    item.remote = 'studio/media/${item.id}/${item.name}';
  }
}

void main() {
  late Directory root, home, proj, store;
  late String shot, clip;
  setUp(() {
    root = Directory.systemTemp.createTempSync('media_root_');
    home = Directory.systemTemp.createTempSync('media_home_');
    proj = Directory.systemTemp.createTempSync('media_proj_');
    store = Directory.systemTemp.createTempSync('media_store_');
    shot = p.join(root.path, 'docs', 'art', 'saw', 'saw_face.png');
    clip = p.join(root.path, 'review', 'videos', 'tour.mp4');
    (File(shot)..createSync(recursive: true)).writeAsBytesSync(png);
    (File(clip)..createSync(recursive: true)).writeAsBytesSync([0, 0, 0, 1]);
  });
  tearDown(() {
    for (final d in [root, home, proj, store]) {
      d.deleteSync(recursive: true);
    }
  });

  String? resolve(String rel) {
    final f = p.join(root.path, rel);
    return File(f).existsSync() ? f : null;
  }

  test('mediaPathsIn: absolute and repo-relative files that exist here, nothing else', () {
    final text = 'Look at `docs/art/saw/saw_face.png` and $clip. Also docs/art/gone.png, notes.md and /Users/nobody/x.jpg.';
    expect(mediaPathsIn(text, resolve: resolve), [clip, shot]);
    expect(captionFor('Intro\nThe new face — `docs/art/saw/saw_face.png` — keeps its texture.\nEnd', shot), 'The new face — docs/art/saw/saw_face.png — keeps its texture.');
  });

  test('collect: a reply and a Preview command each bring their picture, published with a small one; desk media keeps its step', () async {
    final rec = _Recorder();
    final media = StudioMedia(file: p.join(store.path, 'media.json'), publisher: rec, resolve: resolve, makeThumb: (b) async => Uint8List.fromList([1, 2, 3]));
    final fake = FakeClaude();
    final b = fakeSession(fake, dir: proj.path, home: home.path);
    media.watch(b, source: 'orchestrator');
    media.watch(b, source: 'orchestrator');
    await b.start();
    await pumpEventQueue();
    b.send('show me the saw');
    await fake.writtenLines(1);
    fake.emitJson({'type': 'assistant', 'message': {'id': 'm1', 'role': 'assistant', 'content': [{'type': 'tool_use', 'id': 't1', 'name': 'Bash', 'input': {'command': 'open -a Preview "$clip"'}}]}, 'session_id': b.sessionId});
    fake.emitJson({'type': 'user', 'message': {'role': 'user', 'content': [{'type': 'tool_result', 'tool_use_id': 't1', 'content': ''}]}, 'session_id': b.sessionId});
    fake.emitJson({'type': 'assistant', 'message': {'id': 'm2', 'role': 'assistant', 'content': [{'type': 'text', 'text': 'The face keeps its texture: `docs/art/saw/saw_face.png`.'}]}, 'session_id': b.sessionId});
    fake.emitJson({'type': 'result', 'subtype': 'success', 'is_error': false, 'duration_ms': 5, 'num_turns': 1, 'result': 'ok', 'session_id': b.sessionId});
    await pumpEventQueue();
    await media.settled();
    expect(media.newestFirst.map((m) => m.name).toSet(), {'saw_face.png', 'tour.mp4'});
    expect(media.items.firstWhere((m) => m.name == 'tour.mp4').caption, 'opened by the orchestrator');
    expect(media.items.firstWhere((m) => m.name == 'saw_face.png').caption, 'The face keeps its texture: docs/art/saw/saw_face.png.');
    expect(rec.published.map((e) => (e.$1, e.$3)).toSet(), {('saw_face.png', true), ('tour.mp4', false)}, reason: 'pictures get a small copy, videos do not; watched once');
    final again = StudioMedia(file: p.join(store.path, 'media.json'))..load();
    expect(again.items.where((m) => m.remote != null), hasLength(2), reason: 'kept with where they went');
    await b.stop();

    // The desk: its media remembers the step it was about.
    final fake2 = FakeClaude();
    final d = fakeSession(fake2, dir: proj.path, home: Directory.systemTemp.createTempSync('media_home2_').path);
    media.watch(d, source: 'desk');
    await d.start();
    await pumpEventQueue();
    d.send('which picture?', about: stepAbout('a', 'SAW-FACE'));
    await fake2.writtenLines(1);
    fake2.emitJson({'type': 'assistant', 'message': {'id': 'm1', 'role': 'assistant', 'content': [{'type': 'text', 'text': 'This one: $shot'}]}, 'session_id': d.sessionId});
    fake2.emitJson({'type': 'result', 'subtype': 'success', 'is_error': false, 'duration_ms': 5, 'num_turns': 1, 'result': 'ok', 'session_id': d.sessionId});
    await pumpEventQueue();
    expect(media.items.firstWhere((m) => m.source == 'desk').step, 'a/SAW-FACE');
    await d.stop();
  });

  test('review/: the first look only marks; what appears after it is gathered', () async {
    var clock = DateTime.now();
    final media = StudioMedia(file: p.join(store.path, 'media.json'), reviewDir: p.join(root.path, 'review'), now: () => clock);
    media.scanReview();
    expect(media.items, isEmpty, reason: 'old files are not a flood of news');
    final fresh = File(p.join(root.path, 'review', 'evidence', 'trap.png'))..createSync(recursive: true);
    fresh.writeAsBytesSync(png);
    fresh.setLastModifiedSync(clock.add(const Duration(seconds: 5)));
    clock = clock.add(const Duration(seconds: 30));
    media.scanReview();
    expect(media.items.single.name, 'trap.png');
    expect(media.items.single.caption, 'new in review/evidence');
    expect(media.items.single.source, 'review');
  });

  testWidgets('the Mac gallery: tiles by source; a picture opens full screen', (tester) async {
    tester.view.physicalSize = const Size(900, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final media = StudioMedia(file: p.join(store.path, 'media.json'));
    media.items.addAll([
      MediaItem(id: '1', path: shot, source: 'orchestrator', at: DateTime.now(), caption: 'the saw face'),
      MediaItem(id: '2', path: clip, source: 'review', at: DateTime.now().subtract(const Duration(minutes: 1))),
    ]);
    await tester.pumpWidget(MaterialApp(theme: kitTheme(KitTokens.light), home: Scaffold(body: MediaGallery(media: media))));
    await tester.pump();
    expect(find.text('ALL · 2'), findsOneWidget);
    expect(find.text('REVIEW FOLDER · 1'), findsOneWidget);
    expect(find.byIcon(Icons.play_arrow), findsOneWidget, reason: 'the video tile');
    await tester.tap(find.text('ORCHESTRATOR · 1'));
    await tester.pump();
    expect(find.byIcon(Icons.play_arrow), findsNothing);
    await tester.tap(find.textContaining('the saw face'));
    await tester.pumpAndSettle();
    expect(find.byType(InteractiveViewer), findsOneWidget);
    expect(find.text('the saw face'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('added by the person: pictures and videos only; a failed upload says why and can be retried', () async {
    var fail = true;
    final pub = _Flaky(() => fail);
    final media = StudioMedia(file: p.join(store.path, 'media.json'), publisher: pub, makeThumb: (b) async => null);
    expect(media.addFiles([shot, clip, p.join(root.path, 'notes.md')]), 2);
    await media.settled();
    final item = media.items.firstWhere((m) => m.name == 'saw_face.png');
    expect(item.source, 'you');
    expect(item.phoneState, 'UPLOAD FAILED');
    expect(item.error, contains('no network'));
    fail = false;
    media.retry(item);
    await media.settled();
    expect(item.phoneState, 'ON THE PHONE');
    expect(item.error, isNull);
  });

  testWidgets('the phone gallery: rows from the relay, small pictures from the bucket', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final db = FakeFirebaseFirestore();
    final blobs = MemoryBlobStore();
    await blobs.put('studio/media/1/thumb.png', png);
    await db.collection('studio').doc('main').collection('media').doc('1').set({'name': 'saw_face.png', 'kind': 'image', 'path': 'studio/media/1/saw_face.png', 'thumb': 'studio/media/1/thumb.png', 'caption': 'the saw face', 'source': 'orchestrator', 'at': DateTime.now().toUtc().toIso8601String()});
    await db.collection('studio').doc('main').collection('media').doc('2').set({'name': 'tour.mp4', 'kind': 'video', 'path': 'studio/media/2/tour.mp4', 'source': 'review', 'at': DateTime.now().subtract(const Duration(minutes: 1)).toUtc().toIso8601String()});
    await tester.pumpWidget(MaterialApp(theme: kitTheme(KitTokens.light), home: PhoneMediaScreen(db: db, blobs: blobs)));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.text('STUDIO MEDIA'), findsOneWidget);
    expect(find.textContaining('the saw face'), findsOneWidget);
    expect(find.textContaining('REVIEW'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget, reason: 'the picture\'s small copy');
    expect(find.byIcon(Icons.play_arrow), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
