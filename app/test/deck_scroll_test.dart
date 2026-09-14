import 'package:flutter/material.dart';
import 'package:flutter_kit/kit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kit_app/src/host/bridge_session.dart';
import 'package:kit_app/src/screens/deck_tab.dart';
import 'package:kit_app/src/theme.dart';

Widget _deck({List<DeckMessage>? messages, bool running = true}) => MaterialApp(
  theme: kitTheme(KitTokens.light).copyWith(platform: TargetPlatform.iOS),
  home: Scaffold(body: DeckView(
    state: running ? BridgeState.ready : BridgeState.idle,
    title: 'Scratch',
    facts: const ['session qa'],
    hostLine: 'Mac · just now',
    messages: messages ?? [for (var i = 0; i < 40; i++) DeckMessage(id: 'm$i', role: DeckRole.assistant, text: 'Conversation row $i on the scratch project.', at: DateTime(2026, 9, 14))],
    running: running,
    canResume: false,
    onStart: () {},
    onResume: () {},
    onStop: () {},
    onSend: (_, _) async {},
    onTestPush: () async => 'sent',
    onOptions: ({mode, chrome, model, effort, engine}) {},
    nowSlot: const SizedBox(height: 60, child: Text('NOW LINE')),
    foldOnScroll: true,
  )),
);

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  testWidgets('folding open controls preserves the transcript position and restores tappable controls', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_deck(running: false, messages: [
      DeckMessage(id: 'm', role: DeckRole.assistant, text: 'A short scratch conversation.', at: DateTime(2026, 9, 14)),
    ]));
    await _settle(tester);
    final list = find.byType(ListView);
    final position = tester.state<ScrollableState>(find.descendant(of: list, matching: find.byType(Scrollable)).first).position;
    final row = find.text('A short scratch conversation.');
    final origin = tester.getTopLeft(row).dy + position.pixels;
    final drag = await tester.startGesture(tester.getBottomRight(list) - const Offset(30, 30));
    for (var i = 0; i < 60; i++) {
      await drag.moveBy(const Offset(0, -10));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await drag.up();
    await _settle(tester);
    expect(find.text('NOW LINE'), findsNothing);
    expect(tester.getTopLeft(row).dy + position.pixels, closeTo(origin, 1),
      reason: 'collapsing controls must not change the full header inset and jump the transcript');
    expect(find.byTooltip('Show the header').hitTestable(), findsOneWidget);
    await tester.tap(find.byTooltip('Show the header'));
    await _settle(tester);
    expect(find.byTooltip('Hide session controls').hitTestable(), findsOneWidget);
    expect(find.text('PUSH · TEST').hitTestable(), findsOneWidget);
    await tester.tap(find.text('PUSH · TEST'));
    await _settle(tester);
    expect(find.text('sent'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a partial iOS fold reverses with the finger and header controls still scroll', (tester) async {
    tester.view.physicalSize = const Size(390, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_deck(running: false));
    await _settle(tester);
    final list = find.byType(ListView);
    final position = tester.state<ScrollableState>(find.descendant(of: list, matching: find.byType(Scrollable)).first).position;
    position.jumpTo(position.maxScrollExtent);
    await _settle(tester);
    final drag = await tester.startGesture(tester.getBottomRight(list) - const Offset(30, 20));
    for (var i = 0; i < 10; i++) {
      await drag.moveBy(const Offset(0, -10));
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(find.text('NOW LINE'), findsOneWidget);
    expect(find.text('SCRATCH · IDLE'), findsNothing, reason: 'a short drag only partially folds');
    for (var i = 0; i < 12; i++) {
      await drag.moveBy(const Offset(0, 10));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await drag.up();
    await _settle(tester);
    expect(find.byTooltip('Hide session controls').hitTestable(), findsOneWidget);
    expect(find.text('NOW LINE').hitTestable(), findsOneWidget, reason: 'reversing restores the entire header');
    final controls = find.ancestor(of: find.text('PUSH · TEST'), matching: find.byType(SingleChildScrollView));
    await tester.drag(controls, const Offset(0, -200));
    await _settle(tester);
    expect(find.text('MODE · DEFAULT').hitTestable(), findsOneWidget, reason: 'lower controls remain reachable');
    await tester.drag(controls, const Offset(0, 300));
    await _settle(tester);
    expect(find.byTooltip('Hide session controls').hitTestable(), findsOneWidget);
    await tester.tap(find.byTooltip('Hide session controls'));
    await _settle(tester);
    expect(find.text('PUSH · TEST'), findsNothing);
    expect(find.byTooltip('Show session controls').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('iOS edge bounce does not damp the finger-driven header fold', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_deck());
    await _settle(tester);
    final list = find.byType(ListView);
    final position = tester.state<ScrollableState>(find.descendant(of: list, matching: find.byType(Scrollable)).first).position;
    expect(position.physics.toString(), contains('BouncingScrollPhysics'));
    position.jumpTo(position.maxScrollExtent);
    await _settle(tester);
    final drag = await tester.startGesture(tester.getBottomRight(list) - const Offset(30, 30));
    // Small events reproduce touch movement after iOS applies edge friction.
    for (var i = 0; i < 24; i++) {
      await drag.moveBy(const Offset(0, -10));
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(find.text('SCRATCH · LIVE'), findsOneWidget,
      reason: 'the finger must fold the header even at the newest row');
    expect(find.text('NOW LINE'), findsNothing, reason: 'fully folded, not only crossfading');
    await drag.up();
    await _settle(tester);
    await tester.tap(find.byTooltip('Show the header'));
    await _settle(tester);
    expect(find.text('NOW LINE'), findsOneWidget);
    expect(find.byTooltip('Show session controls').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
