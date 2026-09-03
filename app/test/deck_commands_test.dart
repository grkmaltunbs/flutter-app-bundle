// The Deck's command table against the plugin's own commands/ directory —
// the previews cannot drift — and the palette renders and hands a pick
// back at both text scales.
import 'dart:io';

import 'package:flutter/material.dart' hide Step, StepState;
import 'package:flutter_test/flutter_test.dart';
import 'package:kit_app/src/deck_commands.dart';
import 'package:kit_app/src/theme.dart';

Map<String, Map<String, String?>> _fromPlugin() {
  final dir = Directory('../commands');
  if (!dir.existsSync()) return const {};
  final out = <String, Map<String, String?>>{};
  for (final f in dir.listSync().whereType<File>()) {
    if (!f.path.endsWith('.md')) continue;
    final name = '/${f.uri.pathSegments.last.replaceAll('.md', '')}';
    String? description;
    String? args;
    for (final line in f.readAsLinesSync().take(10)) {
      if (line.startsWith('description: ')) description = line.substring(13).trim();
      if (line.startsWith('argument-hint: ')) args = line.substring(15).trim();
    }
    out[name] = {'description': description, 'args': args};
  }
  return out;
}

void main() {
  test('the table is the commands/ directory, word for word', () {
    final plugin = _fromPlugin();
    if (plugin.isEmpty) {
      markTestSkipped('no ../commands beside app/ — run from the repo checkout');
      return;
    }
    final table = {for (final c in kDeckCommands) c.name: c};
    expect(table.keys.toSet(), plugin.keys.toSet(), reason: 'every command previewed, none invented');
    for (final e in plugin.entries) {
      expect(table[e.key]!.what, e.value['description'], reason: '${e.key} description');
      expect(table[e.key]!.args, e.value['args'], reason: '${e.key} argument hint');
    }
    for (final c in kDeckCommands) {
      expect(kDeckCommandGroups, contains(c.group));
    }
  });

  for (final scale in [1.0, 3.12]) {
    testWidgets('at ${scale}x: the palette renders every group and hands back a pick', (tester) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      String? picked;
      await tester.pumpWidget(MaterialApp(
        theme: kitTheme(scale == 3.12 ? KitTokens.dark : KitTokens.light),
        home: MediaQuery(
          data: MediaQueryData(size: const Size(360, 780), textScaler: TextScaler.linear(scale)),
          child: Scaffold(body: DeckCommandsSheet(highlight: '/qa', onPick: (c) => picked = c)),
        ),
      ));
      await tester.pump();
      expect(find.text('COMMANDS'), findsOneWidget);
      final list = find.byType(Scrollable).first;
      // At the largest scale the header alone fills the fold.
      await tester.dragUntilVisible(find.text('/qa'), list, const Offset(0, -300));
      expect(find.text('/qa'), findsOneWidget, reason: 'the highlighted command leads, once');
      expect(tester.takeException(), isNull);
      for (final group in ['PLAN', 'BUILD', 'QUALITY', 'SETUP']) {
        await tester.dragUntilVisible(find.text(group), list, const Offset(0, -300));
        expect(find.text(group), findsOneWidget);
        expect(tester.takeException(), isNull, reason: group);
      }
      await tester.dragUntilVisible(find.text('/kit-sync'), list, const Offset(0, -300));
      await tester.tap(find.text('/kit-sync'));
      expect(picked, '/kit-sync');
    });
  }
}
