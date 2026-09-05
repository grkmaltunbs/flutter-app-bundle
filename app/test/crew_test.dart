// The Deck crew: subagents as chips on a strip with their rows folded
// under, every tool row opening to its whole input and result, and the
// line above the first row not seen since the app was last in front.
import 'package:flutter/material.dart' hide Step, StepState;
import 'package:flutter_kit/kit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kit_app/src/host/bridge_session.dart';
import 'package:kit_app/src/screens/deck_tab.dart';
import 'package:kit_app/src/theme.dart';
import 'package:kit_app/src/widgets/tool_sheet.dart';

Widget _app(Widget child, {double scale = 1.0}) => MaterialApp(
      theme: kitTheme(KitTokens.light),
      home: MediaQuery(data: MediaQueryData(size: const Size(360, 780), textScaler: TextScaler.linear(scale)), child: Scaffold(body: child)),
    );

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump();
  }
}

Future<void> _openSheet(WidgetTester tester, Finder f) async {
  // A row far down the list is not built until scrolled to.
  if (f.evaluate().isEmpty) {
    // The list sits on its newest row; the row wanted is above it.
    await tester.drag(find.byType(ListView).first, const Offset(0, 4000));
    await tester.pump();
    if (f.evaluate().isEmpty) await tester.scrollUntilVisible(f, 200, scrollable: find.descendant(of: find.byType(ListView).first, matching: find.byType(Scrollable)).first);
  }
  await tester.ensureVisible(f);
  await tester.pump();
  await tester.tap(f, warnIfMissed: false);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> _closeSheet(WidgetTester tester) async {
  tester.state<NavigatorState>(find.byType(Navigator).first).pop();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

DeckView _deck(List<DeckMessage> messages, {String? lastSeenId, String? seenScope, bool markUnread = false, void Function(String)? onSeen, bool turnOpen = true}) => DeckView(
      state: turnOpen ? BridgeState.busy : BridgeState.ready,
      title: 'Nahmatik',
      facts: const ['session abcd1234'],
      messages: messages,
      running: true,
      canResume: false,
      turnOpen: turnOpen,
      onStart: () {},
      onResume: () {},
      onStop: () {},
      onSend: (_, _) async {},
      foldOnScroll: false,
      lastSeenId: lastSeenId,
      seenScope: seenScope,
      markUnread: markUnread,
      onSeen: onSeen,
    );

DeckMessage _msg(String id, DeckRole role, {String text = '', String? toolName, Map<String, Object?>? input, String? toolUseId, String? parent, String? result, DateTime? doneAt, Map<String, Object?>? progress, String? output, bool cut = false}) => DeckMessage(
      id: id,
      role: role,
      text: text,
      at: DateTime(2026, 9, 6, 2, 0, int.parse(id.substring(1)) % 60),
      toolName: toolName,
      toolInput: input,
      toolUseId: toolUseId,
      toolResult: result,
      doneAt: doneAt,
      parentToolUseId: parent,
      progress: progress,
      toolOutput: output,
      toolOutputCut: cut,
    );

List<DeckMessage> _crewTurn({bool done = false}) => [
      _msg('m00000', DeckRole.user, text: 'count the dart files'),
      _msg('m00001', DeckRole.tool, toolName: 'Agent', toolUseId: 'toolu_agent', input: const {'subagent_type': 'Explore', 'description': 'Count .dart files in kit/lib', 'prompt': 'Count them.'}, progress: const {'toolUses': 1, 'lastTool': 'Bash'}, result: done ? '18' : null, doneAt: done ? DateTime(2026, 9, 6, 2, 0, 9) : null),
      _msg('m00002', DeckRole.tool, toolName: 'Bash', toolUseId: 'toolu_sub', input: const {'command': 'find kit/lib -name *.dart | wc -l'}, parent: 'toolu_agent', result: '      18'),
      _msg('m00003', DeckRole.assistant, text: '18', parent: 'toolu_agent'),
      if (done) _msg('m00004', DeckRole.assistant, text: 'The Explore agent counted 18.'),
    ];

void main() {
  for (final scale in [1.0, 2.0, 3.12]) {
    testWidgets('at ${scale}x: the crew chip, its rows folded, the sheet, then done — no overflow', (tester) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_app(_deck(_crewTurn()), scale: scale));
      await _settle(tester);
      expect(tester.takeException(), isNull, reason: 'strip with a running chip');
      expect(find.byType(CrewChip), findsOneWidget);
      expect(find.textContaining('EXPLORE · Count .dart files'), findsOneWidget);
      // The subagent's rows are not in the main list.
      expect(find.textContaining('find kit/lib'), findsNothing);
      expect(find.text('18'), findsNothing);
      // The chip opens the member: running, its rows under it.
      await _openSheet(tester, find.byType(CrewChip));
      expect(find.textContaining('RUNNING · '), findsOneWidget);
      expect(find.text('ITS ROWS · 2'), findsOneWidget);
      expect(find.textContaining('find kit/lib'), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'crew sheet');
      await _closeSheet(tester);

      await tester.pumpWidget(_app(_deck(_crewTurn(done: true), turnOpen: false), scale: scale));
      await _settle(tester);
      expect(find.byType(CrewChip), findsOneWidget);
      await _openSheet(tester, find.byType(CrewChip));
      expect(find.textContaining('DONE · IN 0:08'), findsOneWidget);
      expect(find.text('REPORT'), findsOneWidget);
      await _closeSheet(tester);
      // The Agent row in the list opens the same member.
      await _openSheet(tester, find.textContaining('Explore · Count .dart files'));
      expect(find.text('REPORT'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('a tool row opens to its whole input and result, cut at 24 KB with the note', (tester) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final big = List.filled(toolOutputLimit, 'x').join();
    final rows = [
      _msg('m00000', DeckRole.user, text: 'cat it'),
      _msg('m00001', DeckRole.tool, toolName: 'Bash', toolUseId: 'toolu_b', input: const {'command': 'cat big.txt'}, result: '${big.substring(0, 599)}…', output: big, cut: true),
    ];
    await tester.pumpWidget(_app(_deck(rows, turnOpen: false)));
    await _settle(tester);
    await _openSheet(tester, find.text('cat big.txt'));
    expect(find.text('INPUT · BASH'), findsOneWidget);
    expect(find.text('RESULT'), findsOneWidget);
    expect(find.text(big), findsOneWidget);
    // The note sits under 24 KB of text: scroll the sheet to it.
    await tester.scrollUntilVisible(find.text('Cut at 24 KB — the rest is on the Mac.'), 600, scrollable: find.byType(Scrollable).last);
    expect(find.text('Cut at 24 KB — the rest is on the Mac.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  group('since you last looked', () {
    List<DeckMessage> six() => [for (var i = 0; i < 6; i++) _msg('m0000$i', i.isEven ? DeckRole.user : DeckRole.assistant, text: 'row $i')];

    testWidgets('the line sits above the first row not seen, and the newest row shown is remembered', (tester) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final seen = <String>[];
      await tester.pumpWidget(_app(_deck(six(), lastSeenId: 's1:m00002', seenScope: 's1', markUnread: true, onSeen: seen.add, turnOpen: false)));
      await _settle(tester);
      expect(find.text('SINCE YOU LAST LOOKED'), findsOneWidget);
      final line = tester.getTopLeft(find.text('SINCE YOU LAST LOOKED')).dy;
      expect(line, greaterThan(tester.getTopLeft(find.text('row 2')).dy));
      expect(line, lessThan(tester.getTopLeft(find.text('row 3')).dy));
      // Leaving remembers the newest row that was shown.
      for (final st in [AppLifecycleState.inactive, AppLifecycleState.hidden, AppLifecycleState.paused]) {
        tester.binding.handleAppLifecycleStateChanged(st);
      }
      await tester.pump();
      expect(seen, ['s1:m00005']);
      // Back, with two rows that arrived meanwhile: the line moves to the first of them.
      for (final st in [AppLifecycleState.hidden, AppLifecycleState.inactive, AppLifecycleState.resumed]) {
        tester.binding.handleAppLifecycleStateChanged(st);
      }
      final more = [...six(), _msg('m00006', DeckRole.user, text: 'row 6'), _msg('m00007', DeckRole.assistant, text: 'row 7')];
      await tester.pumpWidget(_app(_deck(more, lastSeenId: 's1:m00002', seenScope: 's1', markUnread: true, onSeen: seen.add, turnOpen: false)));
      await _settle(tester);
      expect(find.text('SINCE YOU LAST LOOKED'), findsOneWidget);
      final line2 = tester.getTopLeft(find.text('SINCE YOU LAST LOOKED')).dy;
      expect(line2, greaterThan(tester.getTopLeft(find.text('row 5')).dy));
      expect(line2, lessThan(tester.getTopLeft(find.text('row 6')).dy));
      await tester.pumpWidget(const SizedBox());
      expect(seen.last, 's1:m00007');
    });

    testWidgets('another session: everything is new; nothing remembered: no line; not asked: no line', (tester) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_app(_deck(six(), lastSeenId: 's0:m00005', seenScope: 's1', markUnread: true, turnOpen: false)));
      await _settle(tester);
      expect(find.text('SINCE YOU LAST LOOKED'), findsOneWidget);
      expect(tester.getTopLeft(find.text('SINCE YOU LAST LOOKED')).dy, lessThan(tester.getTopLeft(find.text('row 0')).dy));
      // Each case is its own Deck, as each open of the screen is.
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(_app(_deck(six(), seenScope: 's1', markUnread: true, turnOpen: false)));
      await _settle(tester);
      expect(find.text('SINCE YOU LAST LOOKED'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(_app(_deck(six(), lastSeenId: 's1:m00002', seenScope: 's1', turnOpen: false)));
      await _settle(tester);
      expect(find.text('SINCE YOU LAST LOOKED'), findsNothing);
    });
  });
}
