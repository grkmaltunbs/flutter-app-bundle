// The Deck at phone width and Mac width, at every text scale the project's
// qa policy names, with a long transcript and both kinds of ask pinned.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart' hide Step, StepState;
import 'package:flutter_test/flutter_test.dart';
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
        final list = find.byType(Scrollable).first;
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
        await tester.tap(find.text('Public, documented'));
        await tester.pump();
        await tester.ensureVisible(answer);
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
}
