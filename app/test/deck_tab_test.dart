// The Deck at phone width and Mac width, at every text scale the project's
// qa policy names, with a long transcript and both kinds of ask pinned.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart' hide Step, StepState;
import 'package:flutter/services.dart';
import 'package:flutter_kit/kit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kit_app/src/attachments.dart';
import 'package:kit_app/src/host/bridge_session.dart';
import 'package:kit_app/src/screens/deck_tab.dart';
import 'package:kit_app/src/theme.dart';

import 'helpers/fake_claude.dart';

Widget _app(Widget child, {required Size size, required double scale, bool dark = false}) => MaterialApp(
      theme: kitTheme(dark ? KitTokens.dark : KitTokens.light),
      home: MediaQuery(data: MediaQueryData(size: size, textScaler: TextScaler.linear(scale)), child: Scaffold(body: child)),
    );

const _scales = [1.0, 2.0, 3.12];

/// Lets the fake process's streams and the session's listeners run — the
/// widget test's clock is fake, so a real delay would never return.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump();
  }
}
const _sizes = {'phone': Size(360, 780), 'mac': Size(1440, 900)};

void main() {
  late Directory home;
  late Directory project;
  setUp(() {
    home = Directory.systemTemp.createTempSync('kit_deck_home_');
    project = Directory.systemTemp.createTempSync('kit_deck_project_');
  });
  tearDown(() {
    home.deleteSync(recursive: true);
    project.deleteSync(recursive: true);
  });

  for (final size in _sizes.entries) {
    for (final scale in _scales) {
      testWidgets('${size.key} at ${scale}x: a long transcript, a permission and a question, no overflow', (tester) async {
        tester.view.physicalSize = size.value;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final fake = FakeClaude();
        final s = fakeSession(fake, dir: project.path, home: home.path);
        await tester.pumpWidget(_app(DeckTab(bridge: s), size: size.value, scale: scale, dark: scale == 2.0));
        await tester.pump();
        expect(find.text('START'), findsOneWidget);

        await s.start();
        s.send('Why is step 29 still open, and what is the very long reason that it stays open for so long on this narrow screen?');
        scriptTurn(fake, sessionId: s.sessionId!, text: 'It is **code complete** — analyze, tests and QA passed on 28 Aug. Three of your boxes hold it:\n\n- the Play data-safety confirmation\n- the presence decision\n- a look at the launch path at 3.12×\n\nThe presence decision also blocks `store-submission`.');
        await _settle(tester);
        expect(tester.takeException(), isNull, reason: 'transcript');
        // The list follows the newest row; at the largest scale the reply is
        // taller than the viewport, so scroll back up to it.
        final list = find.byType(ListView);
        final reply = find.textContaining('code complete', findRichText: true);
        await tester.dragUntilVisible(reply, list, const Offset(0, 200));
        expect(reply, findsOneWidget, reason: 'rows: ${s.transcript.messages.map((m) => '${m.role.name}:${m.text.length}').join(' ')}');
        await tester.dragUntilVisible(find.textContaining('kit.sh next --step', findRichText: true), list, const Offset(0, -200));
        expect(find.textContaining('kit.sh next --step', findRichText: true), findsOneWidget);

        s.send('touch a marker');
        scriptBashAsk(fake, command: 'firebase deploy --only firestore:rules --project nahmatik-1c548 --non-interactive --force --debug-a-very-long-flag');
        await _settle(tester);
        expect(tester.takeException(), isNull, reason: 'permission card');
        expect(find.text('AUTHORIZATION REQUESTED'), findsOneWidget);
        // The bottom pane scrolls at large scales; bring the button into view.
        await tester.ensureVisible(find.text('DENY'));
        await tester.pump(); // a viewport's offset lands on the next frame
        await tester.tap(find.text('DENY'));
        await _settle(tester);
        final deny = jsonDecode(fake.written.last) as Map;
        expect(deny['response']['response']['behavior'], 'deny');
        expect(find.text('AUTHORIZATION REQUESTED'), findsNothing);

        scriptQuestionAsk(fake);
        await _settle(tester);
        expect(tester.takeException(), isNull, reason: 'question card');
        expect(find.text('CLAUDE ASKS'), findsOneWidget);
        final answer = find.widgetWithText(FilledButton, 'ANSWER');
        expect(tester.widget<FilledButton>(answer).onPressed, isNull, reason: 'nothing picked yet');
        await tester.ensureVisible(find.text('Public, documented'));
        await tester.pump(); // a viewport's offset lands on the next frame
        await tester.tap(find.text('Public, documented'));
        await tester.pump();
        await tester.ensureVisible(answer);
        await tester.pump(); // a viewport's offset lands on the next frame
        await tester.tap(answer);
        await _settle(tester);
        final ans = jsonDecode(fake.written.last) as Map;
        expect(ans['response']['response']['updatedInput']['answers'], {'Friends-only presence, or public and documented?': 'Public, documented'});
        expect(find.text('CLAUDE ASKS'), findsNothing);

        for (var i = 0; i < 6; i++) {
          await tester.drag(list, const Offset(0, -500));
          await tester.pump();
          expect(tester.takeException(), isNull, reason: 'scroll $i');
        }
        await s.stop();
        await _settle(tester);
        expect(find.textContaining('RESUME'), findsOneWidget, reason: 'the record offers the session back');
      });
    }
  }

  testWidgets('reading above while Claude writes stays put; LATEST takes you down', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final fake = FakeClaude();
    final s = fakeSession(fake, dir: project.path, home: home.path);
    await tester.pumpWidget(_app(DeckTab(bridge: s), size: const Size(390, 844), scale: 1.0));
    await s.start();
    s.send('Tell me everything.');
    scriptTurn(fake, sessionId: s.sessionId!, text: List.generate(40, (i) => 'Line $i of a long reply that fills the screen.').join('\n\n'));
    await _settle(tester);
    final list = find.byType(ListView);
    final pos = tester.widget<ListView>(find.byType(ListView)).controller!.position;
    expect(pos.pixels, pos.maxScrollExtent, reason: 'follows the newest row while pinned');
    expect(find.text('LATEST'), findsNothing);

    // Read something above.
    await tester.drag(list, const Offset(0, 400));
    await tester.pump();
    final reading = pos.pixels;
    expect(reading, lessThan(pos.maxScrollExtent - 48));

    // Claude keeps writing.
    s.send('And more?');
    for (var i = 0; i < 12; i++) {
      fake.emitJson({'type': 'stream_event', 'event': {'type': 'content_block_delta', 'index': 0, 'delta': {'type': 'text_delta', 'text': 'More words, line $i.\n\n'}}});
    }
    await _settle(tester);
    expect(pos.pixels, reading, reason: 'the list did not move while the user was reading');
    expect(find.text('LATEST'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('LATEST'));
    // A ticker counts from its first frame: one pump starts the glide, the
    // next lands it, the last runs the after-layout check.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    await tester.pump();
    expect(pos.pixels, pos.maxScrollExtent);
    expect(find.text('LATEST'), findsNothing);

    fake.emitJson({'type': 'assistant', 'message': {'role': 'assistant', 'content': [{'type': 'text', 'text': 'Done, at last.'}]}});
    fake.emitJson({'type': 'result', 'subtype': 'success', 'is_error': false, 'duration_ms': 1, 'num_turns': 1, 'result': 'Done.', 'session_id': s.sessionId, 'stop_reason': 'end_turn'});
    await _settle(tester);
    expect(pos.pixels, pos.maxScrollExtent, reason: 'pinned again, so the end of the turn is in view');
    expect(find.textContaining('Done, at last', findRichText: true), findsOneWidget);
  });

  testWidgets('a picked file rides with the message: a chip, the image inline, the row shows it', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final fake = FakeClaude();
    final s = fakeSession(fake, dir: project.path, home: home.path);
    final png = base64Decode(onePixelPng);
    final picked = [
      PendingAttachment(name: 'shot.png', mime: 'image/png', bytes: png),
      PendingAttachment(name: 'huge.bin', mime: 'application/octet-stream', bytes: Uint8List(maxAttachmentBytes + 1)),
    ];
    await tester.pumpWidget(_app(DeckTab(bridge: s, pick: () async => picked), size: const Size(390, 844), scale: 1.0));
    await tester.pump();
    expect(tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.attach_file)).onPressed, isNull, reason: 'nothing to attach to before Start');
    await s.start();
    await _settle(tester);
    await tester.tap(find.byIcon(Icons.attach_file));
    await _settle(tester);
    expect(find.text('shot.png'), findsOneWidget, reason: 'the chip');
    expect(find.text('huge.bin'), findsNothing);
    expect(find.textContaining('the limit is 32.0 MB'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'What is on this screen?');
    await tester.tap(find.byIcon(Icons.arrow_forward));
    await _settle(tester);
    final content = (((jsonDecode(fake.written.single) as Map)['message'] as Map)['content']) as List;
    expect(content[0]['type'], 'image');
    expect(content[0]['source']['data'], onePixelPng);
    expect(content[1]['text'], startsWith('What is on this screen?'));
    expect(content[1]['text'], contains('shot.png'));
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, isEmpty);
    // The composer's chip is gone; the row's tile is there, with its size.
    expect(find.text('shot.png'), findsOneWidget, reason: 'the row');
    expect(find.textContaining('IMAGE'), findsOneWidget);
    expect(find.byIcon(Icons.close), findsNothing, reason: 'no pending chip remains');
    expect(tester.takeException(), isNull);
  });

  testWidgets('on the Mac, a file dropped on the Deck lands in the composer', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final fake = FakeClaude();
    final s = fakeSession(fake, dir: project.path, home: home.path);
    final dropped = File('${project.path}/Screenshot 2026-09-02.png')..writeAsBytesSync(base64Decode(onePixelPng));
    await tester.pumpWidget(_app(DeckTab(bridge: s), size: const Size(1440, 900), scale: 1.0));
    await tester.pump();
    // What the plugin's macOS side sends up: a drag over the window, then the paths.
    Future<void> platform(String method, Object? args) => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.handlePlatformMessage('desktop_drop', const StandardMethodCodec().encodeMethodCall(MethodCall(method, args)), (_) {});

    // Before Start: the veil says so, and the drop is refused.
    await platform('entered', [700.0, 400.0]);
    await tester.pump();
    expect(find.text('START A SESSION FIRST'), findsOneWidget);
    await platform('performOperation', [dropped.path]);
    await tester.pump();
    expect(find.text('START A SESSION FIRST'), findsNothing);
    expect(find.textContaining('Start the session first'), findsOneWidget);
    // Clear that toast (its timer only starts once it has fully appeared),
    // so the next one has the floor.
    tester.state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger)).clearSnackBars();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.textContaining('Start the session first'), findsNothing);

    await s.start();
    await _settle(tester);
    await platform('entered', [700.0, 400.0]);
    await tester.pump();
    expect(find.text('DROP TO ATTACH'), findsOneWidget);
    await platform('exited', null);
    await tester.pump();
    expect(find.text('DROP TO ATTACH'), findsNothing);

    await platform('entered', [700.0, 400.0]);
    await tester.pump();
    // Reading the file and shrinking it is real I/O.
    await tester.runAsync(() async {
      await platform('performOperation_macos', [{'path': project.path, 'isDirectory': true}, {'path': dropped.path, 'isDirectory': false}]);
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pump();
    expect(find.text('DROP TO ATTACH'), findsNothing);
    expect(find.text('Screenshot 2026-09-02.png'), findsOneWidget, reason: 'the chip');
    expect(find.textContaining('A folder does not travel'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Why is this red?');
    await tester.tap(find.byIcon(Icons.arrow_forward));
    await _settle(tester);
    final content = (((jsonDecode(fake.written.single) as Map)['message'] as Map)['content']) as List;
    expect(content[0]['type'], 'image');
    expect(content[0]['source']['data'], onePixelPng);
    expect(content[1]['text'], contains('Screenshot 2026-09-02.png'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('the option pills flip the record before Start and freeze while running', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final fake = FakeClaude();
    final s = fakeSession(fake, dir: project.path, home: home.path);
    var pushes = 0;
    await tester.pumpWidget(_app(DeckTab(bridge: s, testPush: () async => 'sent to ${++pushes} phone'), size: const Size(390, 844), scale: 1.0));
    await tester.pump();
    expect(find.text('PERMISSIONS · ASK'), findsNothing, reason: 'the pill is gone; the mode dial holds bypass');
    expect(find.text('CHROME · OFF'), findsOneWidget);
    await tester.tap(find.text('PUSH · TEST'));
    await tester.pump();
    await tester.pump();
    expect(pushes, 1);
    expect(find.text('sent to 1 phone'), findsOneWidget, reason: 'what came of it, toasted');
    expect(find.text('MODE · DEFAULT'), findsOneWidget);
    // The mode dial's last notch is bypass — what the Skip permissions pill did.
    await tester.drag(find.byType(Slider).last, const Offset(400, 0));
    await tester.pump();
    expect(find.text('MODE · BYPASS'), findsOneWidget);
    expect(s.previous()!.mode, 'bypassPermissions', reason: 'written to the record at once');
    await tester.tap(find.text('CHROME · OFF'));
    await tester.pump();
    expect(find.text('CHROME · ON'), findsOneWidget);
    // The dials: drag to the end, one write when the finger lifts.
    expect(find.text('MODEL · DEFAULT'), findsOneWidget);
    expect(find.text('EFFORT · DEFAULT'), findsOneWidget);
    await tester.drag(find.byType(Slider).first, const Offset(400, 0));
    await tester.pump();
    expect(find.text('MODEL · FABLE'), findsOneWidget);
    expect(s.previous()!.model, 'fable');
    await tester.drag(find.byType(Slider).at(1), const Offset(400, 0));
    await tester.pump();
    expect(find.text('EFFORT · MAX'), findsOneWidget);
    expect(s.previous()!.effort, 'max');

    await s.start();
    fake.emitJson({'type': 'system', 'subtype': 'init', 'session_id': s.sessionId, 'model': 'm', 'permissionMode': 'bypassPermissions', 'mcp_servers': [{'name': 'claude-in-chrome', 'status': 'connected'}]});
    await _settle(tester);
    expect(fake.startedWith, contains('--chrome'));
    // Running: the controls fold so the transcript has the screen; the
    // chevron (or the title) brings them back.
    expect(find.text('PUSH · TEST'), findsNothing, reason: 'folded while running');
    expect(find.byType(Slider), findsNothing);
    await tester.tap(find.byTooltip('Show session controls'));
    await tester.pump();
    expect(find.text('CHROME · CONNECTED'), findsOneWidget, reason: 'while running, what init said');
    expect(fake.startedWith, containsAllInOrder(['--model', 'fable', '--effort', 'max']));
    expect(tester.widget<Slider>(find.byType(Slider).first).onChanged, isNotNull, reason: 'dials move while live');
    expect(find.textContaining('restart the session on the same conversation'), findsOneWidget);
    expect(find.textContaining('BYPASS MODE'), findsOneWidget, reason: 'the facts line shows the mode the CLI reported');
    await tester.tap(find.textContaining('SESSION '));
    await tester.pump();
    expect(find.byType(Slider), findsNothing, reason: 'a tap on the title row folds them again');
    await s.stop();
    await _settle(tester);
    expect(find.text('START'), findsOneWidget, reason: 'idle: open again on its own');
    expect(tester.takeException(), isNull);
  });

  testWidgets('the composer sends and clears; chips fill it', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final fake = FakeClaude();
    final s = fakeSession(fake, dir: project.path, home: home.path);
    await tester.pumpWidget(_app(DeckTab(bridge: s), size: const Size(390, 844), scale: 1.0));
    await s.start();
    await _settle(tester);
    await tester.tap(find.text('/next'));
    await tester.pump();
    expect(find.widgetWithText(TextField, '/next'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.arrow_forward));
    await _settle(tester);
    expect(jsonDecode(fake.written.single)['message']['content'], '/next');
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, isEmpty);
    expect(find.text('/next'), findsWidgets);
  });

  testWidgets('on a phone the ask is the last row of one scroll, and a drag up folds the chrome to a status row', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final hidden = <bool>[];
    final messages = [
      for (var i = 0; i < 40; i++)
        DeckMessage(id: 'm$i', role: i.isEven ? DeckRole.user : DeckRole.assistant, text: 'Row $i of the conversation, long enough to wrap onto a second line on a phone.', at: DateTime(2026, 9, 4, 10, i)),
    ];
    await tester.pumpWidget(_app(
      DeckView(
        state: BridgeState.ready,
        title: 'Nahmatik',
        facts: const ['session abc'],
        messages: messages,
        running: true,
        canResume: false,
        onStart: () {},
        onResume: () {},
        onStop: () {},
        onSend: (_, _) async {},
        nowSlot: const Text('NOW LINE'),
        askSlot: const Text('ASK CARD'),
        foldOnScroll: true,
        onChromeHidden: hidden.add,
      ),
      size: const Size(390, 844),
      scale: 1.0,
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('NOW LINE'), findsOneWidget);
    expect(find.text('NAHMATIK'), findsOneWidget);
    final list = find.byType(ListView);
    // A short drag folds it a little — the chrome shrinks with the finger,
    // it does not snap: the whole header is still there, the row not yet.
    await tester.drag(list, const Offset(0, -40));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('NAHMATIK'), findsOneWidget);
    expect(find.text('NAHMATIK · LIVE'), findsNothing);
    expect(hidden, isEmpty, reason: 'not folded yet');
    // The rest of the way: one row; the screen is told once.
    await tester.drag(list, const Offset(0, -600));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('NOW LINE'), findsNothing);
    expect(find.text('NAHMATIK'), findsNothing);
    expect(find.text('NAHMATIK · LIVE'), findsOneWidget);
    expect(find.byTooltip('Stop'), findsOneWidget, reason: 'Stop stays one tap away');
    expect(hidden, [true]);
    // Down to the end: the ask is the last row of the same scroll.
    await tester.drag(list, const Offset(0, -8000));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.descendant(of: list, matching: find.text('ASK CARD')), findsOneWidget, reason: 'the ask is a row of the transcript');
    expect(hidden, [true], reason: 'still folded');
    // Finger down: it grows back with the drag, wherever the list is.
    await tester.drag(list, const Offset(0, 600));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('NOW LINE'), findsOneWidget);
    expect(find.text('NAHMATIK'), findsOneWidget);
    expect(hidden, [true, false]);
    // The chevron on the row is the other way back.
    await tester.drag(list, const Offset(0, -600));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('NAHMATIK · LIVE'), findsOneWidget);
    await tester.tap(find.byTooltip('Show the header'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('NOW LINE'), findsOneWidget);
    expect(hidden, [true, false, true, false]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reading up on a phone: the drag grows the chrome and then scrolls the list, and new rows do not pull it back', (tester) async {
    final messages = [for (var i = 0; i < 40; i++) DeckMessage(id: 'm$i', role: DeckRole.assistant, text: 'Row $i, long enough to wrap onto a second line.', at: DateTime(2026, 9, 4, 10, i))];
    DeckView deck(List<DeckMessage> rows) => DeckView(
          state: BridgeState.busy,
          title: 'Nahmatik',
          facts: const ['session abc'],
          messages: rows,
          running: true,
          canResume: false,
          turnOpen: true,
          onStart: () {},
          onResume: () {},
          onStop: () {},
          onSend: (_, _) async {},
          foldOnScroll: true,
        );
    // The rows arrive after the first build, as they do over the relay:
    // the list follows them to the end.
    await tester.pumpWidget(_app(deck(messages.sublist(0, 5)), size: const Size(390, 844), scale: 1.0));
    await tester.pump();
    await tester.pumpWidget(_app(deck(messages), size: const Size(390, 844), scale: 1.0));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Row 39, long enough to wrap onto a second line.'), findsOneWidget, reason: 'pinned at the end');
    final list = find.byType(ListView);
    // Fold it, then read up: one long drag the other way.
    await tester.drag(list, const Offset(0, -600));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('NAHMATIK · WORKING'), findsOneWidget);
    await tester.drag(list, const Offset(0, 900));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('NAHMATIK'), findsOneWidget, reason: 'the chrome grew back first');
    expect(find.text('Row 39, long enough to wrap onto a second line.'), findsNothing, reason: 'then the list scrolled up');
    // Rows keep coming while the turn runs: the list stays where the
    // finger left it; the chip offers the way down.
    await tester.pumpWidget(_app(deck([...messages, DeckMessage(id: 'm40', role: DeckRole.assistant, text: 'Row 40, new.', at: DateTime(2026, 9, 4, 11))]), size: const Size(390, 844), scale: 1.0));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Row 40, new.'), findsNothing, reason: 'not pulled back to the end');
    expect(find.text('LATEST'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('on the Mac nothing folds on a drag', (tester) async {
    final hidden = <bool>[];
    final messages = [for (var i = 0; i < 40; i++) DeckMessage(id: 'm$i', role: DeckRole.assistant, text: 'Row $i, long enough to wrap onto a second line.', at: DateTime(2026, 9, 4, 10, i))];
    await tester.pumpWidget(_app(
      DeckView(state: BridgeState.ready, title: 'Nahmatik', facts: const [], messages: messages, running: true, canResume: false, onStart: () {}, onResume: () {}, onStop: () {}, onSend: (_, _) async {}, nowSlot: const Text('NOW LINE'), foldOnScroll: false, onChromeHidden: hidden.add),
      size: const Size(390, 844),
      scale: 1.0,
    ));
    await tester.pump();
    await tester.drag(find.byType(ListView), const Offset(0, -120));
    await tester.pump();
    expect(find.text('NOW LINE'), findsOneWidget);
    expect(hidden, isEmpty);
  });

  testWidgets('INTERRUPT sits on the title row while a turn runs; a row sent meanwhile says it waits and can be withdrawn', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final fake = FakeClaude();
    final s = fakeSession(fake, dir: project.path, home: home.path);
    await tester.pumpWidget(_app(DeckTab(bridge: s), size: const Size(390, 844), scale: 1.0));
    await s.start();
    fake.emitJson({'type': 'system', 'subtype': 'init', 'session_id': s.sessionId, 'model': 'm', 'permissionMode': 'default'});
    await _settle(tester);
    expect(find.text('INTERRUPT'), findsNothing, reason: 'nothing runs');
    s.send('count to 200');
    await _settle(tester);
    expect(find.text('INTERRUPT'), findsOneWidget);
    await tester.tap(find.text('INTERRUPT'));
    await _settle(tester);
    await fake.writtenLines(2);
    expect(((jsonDecode(fake.written.last) as Map)['request'] as Map)['subtype'], 'interrupt');
    // Sent while the turn still runs: held, and said so.
    s.send('and then say done');
    await _settle(tester);
    expect(find.text('QUEUED · AFTER THIS TURN'), findsOneWidget);
    await tester.tap(find.text('WITHDRAW'));
    await _settle(tester);
    expect(find.text('QUEUED · AFTER THIS TURN'), findsNothing);
    expect(find.text('and then say done'), findsNothing);
    expect(fake.written.length, 2, reason: 'never sent');
    expect(tester.takeException(), isNull);
  });
}
