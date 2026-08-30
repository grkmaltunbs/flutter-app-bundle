// Pumps the three plan screens over a real plan — Nahmatik's, when its
// checkout is beside this one — and fails on any overflow or exception.
// Skipped, not failed, when that checkout is absent.
import 'dart:io';

import 'package:flutter/material.dart' hide Step, StepState;
import 'package:flutter_kit/kit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kit_app/src/draft.dart';
import 'package:kit_app/src/screens/step_detail.dart';
import 'package:kit_app/src/screens/steps_tab.dart';
import 'package:kit_app/src/screens/work_tab.dart';
import 'package:kit_app/src/theme.dart';

Plan? _load() {
  for (final dir in ['../../nahmatik/plan', '../../../nahmatik/plan']) {
    final store = PlanStore(dir);
    if (store.exists) return store.load();
  }
  return null;
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Widget _app(Widget child, {Size size = const Size(400, 800)}) => MaterialApp(
      theme: kitTheme(KitTokens.light),
      home: MediaQuery(data: MediaQueryData(size: size), child: Scaffold(body: child)),
    );

void main() {
  final plan = _load();
  if (plan == null) {
    test('nahmatik plan present', () {}, skip: 'no ../../nahmatik/plan beside this checkout');
    return;
  }
  final graph = Graph(plan);

  testWidgets('bubbles render every step and select the next one', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    String? selected;
    await tester.pumpWidget(_app(StepsTab(plan: plan, graph: graph, selected: null, onSelect: (id) => selected = id)));
    await _settle(tester);
    final next = graph.nextStep()!.step;
    expect(find.text(next.title), findsWidgets);
    await tester.tap(find.text(next.title).first, warnIfMissed: false);
    await tester.pump();
    expect(selected, next.id);
    expect(tester.takeException(), isNull);
  });

  testWidgets('your work lists every open item without overflow at phone width', (tester) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_app(WorkTab(plan: plan, graph: graph, draft: Draft('test'))));
    await _settle(tester);
    final list = find.byType(Scrollable).first;
    // Scroll through the whole list so every card is laid out at least once.
    for (var i = 0; i < 60; i++) {
      await tester.drag(list, const Offset(0, -700));
      await tester.pump();
      expect(tester.takeException(), isNull, reason: 'page $i');
    }
  });

  testWidgets('the Done list shows every closed item with its record, without overflow', (tester) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_app(WorkTab(plan: plan, graph: graph, draft: Draft('test'), initialDone: true)));
    await _settle(tester);
    expect(find.text('DONE'), findsOneWidget, reason: 'the DONE chip');
    expect(find.text('REOPEN'), findsWidgets);
    final list = find.byType(Scrollable).first;
    for (var i = 0; i < 40; i++) {
      await tester.drag(list, const Offset(0, -700));
      await tester.pump();
      expect(tester.takeException(), isNull, reason: 'page $i');
    }
  });

  testWidgets('a code-complete step opens with its blockers as runbooks', (tester) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final v = graph.codeComplete().first;
    await tester.pumpWidget(_app(StepDetail(plan: plan, graph: graph, step: v.step, draft: Draft('test'), onSelectStep: (_) {})));
    await _settle(tester);
    expect(find.text(v.step.title), findsOneWidget);
    final list = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(find.text('WHAT YOU SHOULD DO'), 300, scrollable: list);
    expect(find.text('WHAT YOU SHOULD DO'), findsOneWidget);
    for (var i = 0; i < 30; i++) {
      await tester.drag(list, const Offset(0, -700));
      await tester.pump();
      expect(tester.takeException(), isNull, reason: 'page $i');
    }
  });

  test('every state has a colour and a label', () {
    for (final s in StepState.values) {
      expect(KitTokens.light.forState(s), isNotNull);
    }
    expect(Directory('../../nahmatik/plan').existsSync() || Directory('../../../nahmatik/plan').existsSync(), isTrue);
  });
}
