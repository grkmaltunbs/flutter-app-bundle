// The first consumer is the contract: a schema or engine change that breaks
// Nahmatik's real plan must fail here, in the bundle's own suite, before a
// Nahmatik session ever loads it. Skipped when the checkout is not beside
// this one.
import 'dart:io';

import 'package:flutter_kit/kit.dart';
import 'package:test/test.dart';

void main() {
  const candidates = ['../../nahmatik/plan', '../../../nahmatik/plan'];
  final dir = candidates.where((d) => Directory(d).existsSync()).firstOrNull;
  if (dir == null) {
    test('nahmatik plan present', () {}, skip: 'no nahmatik checkout beside this one');
    return;
  }

  test('Nahmatik\'s plan loads, validates without errors, and renders', () {
    final plan = PlanStore(dir).load();
    final problems = validate(plan);
    expect(problems.where((p) => p.isError).map((p) => p.toString()), isEmpty);
    expect(plan.steps.length, greaterThan(50));
    expect(plan.items.length, greaterThan(100));
    final g = Graph(plan);
    expect(g.nextStep(), isNotNull, reason: 'something must be ready or active');
    expect(renderPlanMarkdown(plan), contains('## Step'));
    expect(renderBoardHtml(plan, today: '2026-08-30'), contains('id="kit-src"'));
    expect(layoutDag(plan.steps).nodes.length, plan.steps.length);
    // The qa policy block the plugin's commands read.
    expect(plan.manifest.qa['runtime'], isNotNull);
    expect(plan.manifest.qa['backend'], isNotNull);
  });
}
