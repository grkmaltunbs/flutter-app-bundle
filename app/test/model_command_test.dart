import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:kit_app/src/blobs.dart';
import 'package:flutter_kit/kit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kit_app/src/attachments.dart';
import 'package:kit_app/src/deck_commands.dart';
import 'package:kit_app/src/host/bridge_session.dart';
import 'package:kit_app/src/screens/deck_tab.dart';
import 'package:kit_app/src/theme.dart';
import 'package:kit_app/src/widgets/model_picker_sheet.dart';

Widget deck({
  bool running = true,
  String engine = 'codex',
  List<PendingAttachment> files = const [],
  Future<void> Function(String)? select,
  Future<void> Function(String, List<PendingAttachment>)? send,
  List<DeckMessage> messages = const [],
}) => MaterialApp(
  theme: kitTheme(KitTokens.light),
  home: Scaffold(
    body: DeckView(
      state: running ? BridgeState.ready : BridgeState.idle,
      facts: const [],
      messages: messages,
      running: running,
      canResume: false,
      onStart: () {},
      onResume: () {},
      onStop: () {},
      onSend:
          send ?? (_, _) async => fail('local command must not send or upload'),
      engine: engine,
      models: const ['alpha', 'beta'],
      initialFiles: files,
      onModelSelected: select,
    ),
  ),
);
String input(WidgetTester tester) =>
    tester.widget<TextField>(find.byType(TextField)).controller!.text;
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> submit(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextField), text);
  await tester.testTextInput.receiveAction(TextInputAction.send);
  await settle(tester);
}

void main() {
  test('only exact slash token is local', () {
    for (final value in [
      '/model',
      ' /model alpha ',
      '/model\nalpha',
      '/model alpha beta',
    ]) {
      expect(isDeckModelCommand(value), isTrue);
    }
    for (final value in ['/modelish', 'please /model', '/models', '/MODEL']) {
      expect(isDeckModelCommand(value), isFalse);
    }
  });
  testWidgets('idle /model opens locally, selects and retains attachments', (
    tester,
  ) async {
    String? selected;
    await tester.pumpWidget(
      deck(
        running: false,
        select: (value) async => selected = value,
        files: [
          PendingAttachment(
            name: 'notes.txt',
            mime: 'text/plain',
            bytes: Uint8List(1),
          ),
        ],
      ),
    );
    await submit(tester, '/model');
    expect(find.byType(ModelPickerSheet), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('model-choice-beta')));
    await settle(tester);
    expect(selected, 'beta');
    expect(input(tester), isEmpty);
    expect(find.textContaining('notes.txt'), findsOneWidget);
    expect(find.textContaining('Selected for next turn: beta'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('cancelling the picker keeps the command and attachments', (
    tester,
  ) async {
    await tester.pumpWidget(
      deck(
        select: (_) async => fail('cancelled'),
        files: [
          PendingAttachment(
            name: 'keep.txt',
            mime: 'text/plain',
            bytes: Uint8List(1),
          ),
        ],
      ),
    );
    await submit(tester, '/model');
    Navigator.of(tester.element(find.byType(ModelPickerSheet))).pop();
    await settle(tester);
    expect(input(tester), '/model');
    expect(find.textContaining('keep.txt'), findsOneWidget);
  });
  testWidgets('direct valid ID clears text only after selection succeeds', (
    tester,
  ) async {
    String? selected;
    final ack = Completer<void>();
    await tester.pumpWidget(
      deck(
        select: (value) {
          selected = value;
          return ack.future;
        },
      ),
    );
    await tester.enterText(find.byType(TextField), '/model beta');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pump();
    expect(selected, 'beta');
    expect(input(tester), '/model beta');
    ack.complete();
    await settle(tester);
    expect(input(tester), isEmpty);
    expect(find.text('Selected for next turn: beta.'), findsOneWidget);
  });
  testWidgets(
    'direct selection awaits acknowledgement; errors keep input and files',
    (tester) async {
      final ack = Completer<void>();
      await tester.pumpWidget(
        deck(
          select: (_) => ack.future,
          files: [
            PendingAttachment(
              name: 'notes.txt',
              mime: 'text/plain',
              bytes: Uint8List(1),
            ),
          ],
        ),
      );
      await tester.enterText(find.byType(TextField), '/model alpha');
      await tester.testTextInput.receiveAction(TextInputAction.send);
      await tester.pump();
      expect(input(tester), '/model alpha');
      ack.completeError(StateError('host rejected selection'));
      await settle(tester);
      expect(input(tester), '/model alpha');
      expect(find.textContaining('notes.txt'), findsOneWidget);
      expect(find.textContaining('host rejected selection'), findsOneWidget);
    },
  );
  testWidgets('malformed and unknown commands remain local', (tester) async {
    await tester.pumpWidget(deck(select: (_) async => fail('invalid model')));
    await submit(tester, '/model alpha beta');
    expect(input(tester), '/model alpha beta');
    expect(find.text('Use /model or /model <model-id>.'), findsOneWidget);
    await submit(tester, '/model bogus');
    expect(input(tester), '/model bogus');
  });
  testWidgets('typing the next message clears selection feedback off the composer', (tester) async {
    final sent = <String>[];
    await tester.pumpWidget(deck(select: (_) async {}, send: (text, _) async => sent.add(text)));
    await submit(tester, '/model beta');
    expect(find.text('Selected for next turn: beta.'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Next message');
    await tester.pump();
    expect(find.text('Selected for next turn: beta.'), findsNothing);
    await tester.tap(find.byIcon(Icons.arrow_forward));
    await settle(tester);
    expect(sent, ['Next message']);
  });

  testWidgets('/modelish sends unchanged; idle ordinary text cannot send', (
    tester,
  ) async {
    final sent = <String>[];
    await tester.pumpWidget(deck(send: (text, _) async => sent.add(text)));
    await submit(tester, '/modelish');
    expect(sent, ['/modelish']);
    await tester.pumpWidget(
      deck(running: false, send: (text, _) async => sent.add(text)),
    );
    await submit(tester, 'hello');
    expect(sent, ['/modelish']);
    expect(input(tester), 'hello');
  });
  testWidgets('Claude /model retains original behavior', (tester) async {
    String? sent;
    await tester.pumpWidget(
      deck(engine: 'claude', send: (text, _) async => sent = text),
    );
    await submit(tester, '/model');
    expect(sent, '/model');
    expect(find.byType(ModelPickerSheet), findsNothing);
  });
  testWidgets(
    'phone picker sends one acknowledged options command without a chat or upload',
    (tester) async {
      final db = FakeFirebaseFirestore();
      final project = db.collection('projects').doc('scratch');
      final blobs = MemoryBlobStore();
      await project.set({
        'session': {
          'engine': 'codex',
          'mode': 'idle',
          'state': 'idle',
          'models': ['alpha', 'beta'],
          'modelChoice': 'alpha',
        },
      });
      await tester.pumpWidget(
        MaterialApp(
          theme: kitTheme(KitTokens.light),
          home: Scaffold(
            body: RemoteDeckTab(
              db: db,
              slug: 'scratch',
              blobs: blobs,
              initialFiles: [
                PendingAttachment(
                  name: 'keep.txt',
                  mime: 'text/plain',
                  bytes: Uint8List(1),
                ),
              ],
            ),
          ),
        ),
      );
      await settle(tester);
      await submit(tester, '/model');
      expect((await project.collection('commands').get()).docs, isEmpty);
      expect(blobs.objects, isEmpty);
      await tester.tap(find.byKey(const ValueKey('model-choice-beta')));
      await settle(tester);
      final commands = (await project.collection('commands').get()).docs;
      expect(commands, hasLength(1));
      expect(commands.single.data()['type'], 'options');
      expect(commands.single.data()['model'], 'beta');
      expect(input(tester), '/model');
      expect(find.byType(ModelPickerSheet), findsOneWidget);
      // Firestore's stream cancellation completes outside the widget fake clock.
      await tester.runAsync(() async {
        await commands.single.reference.set({
          'doneAt': FieldValue.serverTimestamp(),
          'result': 'applies to the next turn',
        }, SetOptions(merge: true));
        await Future<void>.delayed(const Duration(milliseconds: 20));
      });
      await settle(tester);
      expect(find.byType(ModelPickerSheet), findsNothing);
      expect(input(tester), isEmpty);
      expect(find.textContaining('keep.txt'), findsOneWidget);
      expect(blobs.objects, isEmpty);
      expect((await project.collection('chat').get()).docs, isEmpty);
      await tester.pumpWidget(const SizedBox());
      await settle(tester);
    },
  );

  testWidgets('only persisted assistant model gets provenance', (tester) async {
    await tester.pumpWidget(
      deck(
        messages: [
          DeckMessage(
            id: 'old',
            role: DeckRole.assistant,
            text: 'Old response',
            at: DateTime(2026),
          ),
          DeckMessage(
            id: 'new',
            role: DeckRole.assistant,
            text: 'New response',
            at: DateTime(2026),
            model: 'actual-server-model',
          ),
        ],
      ),
    );
    await settle(tester);
    expect(find.text('Model: actual-server-model'), findsOneWidget);
    expect(find.textContaining('Model:'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
