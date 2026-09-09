// Worktrees on the screens: the Git card of a project offers NEW TREE
// and takes a name; a worktree's card offers MERGE INTO MAIN — a conflict
// becomes the offer to send the resolution to the main session — and
// REMOVE, which a dirty tree turns into a forced removal behind a
// confirm. At phone width, every text scale, no overflow.
import 'package:flutter/material.dart' hide Step, StepState;
import 'package:flutter_test/flutter_test.dart';
import 'package:kit_app/src/host/host_actions.dart';
import 'package:kit_app/src/theme.dart';
import 'package:kit_app/src/widgets/git_card.dart';

Widget _app(Widget child, {double scale = 1.0}) => MaterialApp(
      theme: kitTheme(KitTokens.light),
      home: MediaQuery(data: MediaQueryData(size: const Size(360, 780), textScaler: TextScaler.linear(scale)), child: Scaffold(body: SingleChildScrollView(child: child))),
    );

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// A snackbar lasts four seconds and the next waits behind it; its exit
/// animation needs frames of its own before the row under it takes a tap.
Future<void> _toastGone(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 5));
  await _settle(tester);
}

void main() {
  for (final scale in [1.0, 2.0, 3.12]) {
    testWidgets('at ${scale}x: NEW TREE on a project takes a name; MERGE and REMOVE on a worktree, with the conflict offer and the forced removal — no overflow', (tester) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final calls = <String>[];
      var merge = 'merged: 1a2b3c4 Merge branch \'settings\'';
      var remove = 'dirty: 2 changed files in the tree';
      Future<String> op(String o, {String? message, String? path}) async {
        calls.add('$o ${message ?? ''}'.trim());
        return switch (o) {
          'worktree_add' => 'worktree $message is listed under the project',
          'merge' => merge,
          'worktree_remove' => message == 'force' ? 'worktree settings removed — its branch stays' : remove,
          'resolve_merge' => 'sent',
          _ => 'ok',
        };
      }

      // A project of its own: NEW TREE, a name, the command.
      await tester.pumpWidget(_app(GitCard(git: const GitStatus(branch: 'main', lastCommit: 'first'), onOp: op, canAddWorktree: true), scale: scale));
      await _settle(tester);
      expect(find.text('NEW TREE'), findsOneWidget);
      expect(find.text('MERGE INTO MAIN'), findsNothing);
      expect(find.text('WORKTREE'), findsNothing);
      await tester.ensureVisible(find.text('NEW TREE'));
      await tester.tap(find.text('NEW TREE'));
      await _settle(tester);
      await tester.enterText(find.byType(TextField), 'settings');
      await tester.tap(find.text('CREATE'));
      await _settle(tester);
      expect(calls, ['worktree_add settings']);
      expect(find.text('worktree settings is listed under the project'), findsOneWidget, reason: 'toasted');
      await _toastGone(tester);
      expect(tester.takeException(), isNull);

      // A worktree: MERGE INTO MAIN, clean.
      await tester.pumpWidget(_app(GitCard(git: const GitStatus(branch: 'settings', lastCommit: 'settings: on'), onOp: op, worktree: 'settings'), scale: scale));
      await _settle(tester);
      expect(find.text('WORKTREE'), findsOneWidget);
      expect(find.text('NEW TREE'), findsNothing);
      await tester.ensureVisible(find.text('MERGE INTO MAIN'));
      await tester.tap(find.text('MERGE INTO MAIN'));
      await _settle(tester);
      expect(calls.last, 'merge');
      expect(find.textContaining('merged: 1a2b3c4'), findsOneWidget);
      await _toastGone(tester);

      // A conflict: the offer, declined, then accepted.
      merge = 'conflict: 1 file — settings.txt';
      await tester.ensureVisible(find.text('MERGE INTO MAIN'));
      await tester.tap(find.text('MERGE INTO MAIN'));
      await _settle(tester);
      expect(find.text('Merge conflict'), findsOneWidget);
      expect(find.textContaining('resolve the merge of settings'), findsOneWidget);
      await tester.tap(find.text('LEAVE IT'));
      await _settle(tester);
      expect(calls.where((c) => c == 'resolve_merge'), isEmpty);
      await tester.ensureVisible(find.text('MERGE INTO MAIN'));
      await tester.tap(find.text('MERGE INTO MAIN'));
      await _settle(tester);
      await tester.tap(find.text('SEND'));
      await _settle(tester);
      expect(calls.last, 'resolve_merge');
      expect(find.text('sent'), findsOneWidget);
      await _toastGone(tester);
      expect(tester.takeException(), isNull);

      // REMOVE: dirty asks; CANCEL leaves it; FORCE removes.
      await tester.ensureVisible(find.text('REMOVE'));
      await tester.tap(find.text('REMOVE'));
      await _settle(tester);
      expect(calls.last, 'worktree_remove');
      expect(find.text('Remove the worktree?'), findsOneWidget);
      expect(find.textContaining('2 changed files'), findsOneWidget);
      await tester.tap(find.text('CANCEL'));
      await _settle(tester);
      expect(calls.where((c) => c == 'worktree_remove force'), isEmpty);
      await tester.ensureVisible(find.text('REMOVE'));
      await tester.tap(find.text('REMOVE'));
      await _settle(tester);
      await tester.tap(find.text('FORCE'));
      await _settle(tester);
      expect(calls.last, 'worktree_remove force');
      expect(find.textContaining('its branch stays'), findsOneWidget);
      await _toastGone(tester);
      remove = 'worktree settings removed — its branch stays';
      await tester.ensureVisible(find.text('REMOVE'));
      await tester.tap(find.text('REMOVE'));
      await _settle(tester);
      expect(find.text('Remove the worktree?'), findsNothing, reason: 'a clean tree goes without asking');
      expect(tester.takeException(), isNull);
    });
  }
}
