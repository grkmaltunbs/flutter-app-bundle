import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart' hide Step, StepState;
import 'package:path/path.dart' as p;

import 'studio_desk.dart';
import 'studio_draft.dart';
import 'studio_orchestrator.dart';
import 'studio_screen.dart';
import 'studio_source.dart';

/// The one draft of the app — it outlives the Studio screen and a relaunch.
final StudioDraft studioDraft = StudioDraft()..restore();

/// Opens the Studio: the folders saved last time, else the usual places
/// under ~/StudioProjects, else asks.
Future<void> openStudio(BuildContext context) async {
  final saved = await StudioSettings.load();
  final home = Platform.environment['HOME'] ?? '';
  String? firstThat(List<String?> dirs, bool Function(String) ok) {
    for (final d in dirs) {
      if (d != null && ok(d)) return d;
    }
    return null;
  }

  var autopilot = firstThat([
    saved.autopilot,
    p.join(home, 'StudioProjects', 'sivas-autopilot'),
    p.join(home, 'StudioProjects', 'sivas-autopilot-snapshot'),
  ], StudioSettings.looksLikeAutopilot);
  var game = firstThat([saved.game, p.join(home, 'StudioProjects', 'sivas-the-game')], StudioSettings.looksLikeGame);
  if (!context.mounted) return;
  if (autopilot == null) {
    autopilot = await _pick(context, 'Pick the autopilot folder (the one with lane-a, mail and review).', StudioSettings.looksLikeAutopilot);
    if (autopilot == null) return;
  }
  await StudioSettings.save(autopilot: autopilot, game: game);
  if (!context.mounted) return;
  final source = StudioSource(autopilotDir: autopilot, gameDir: game)..start();
  StudioSource.current = source;
  // The orchestrator runs where the person says, else in the game repo — the
  // folder its terminal session works in on the MacBook.
  final orchDir = saved.orchestrator != null && Directory(saved.orchestrator!).existsSync() ? saved.orchestrator : game;
  final orchestrator = orchDir == null ? null : StudioOrchestrator.get(orchDir, autopilotDir: autopilot);
  // The step desk works in the same folder, on its own record.
  final desk = orchDir == null ? null : StudioDesk.get(orchDir, autopilotDir: autopilot);
  await Navigator.of(context).push(MaterialPageRoute<void>(
    builder: (context) => StudioScreen(source: source, orchestrator: orchestrator, draft: studioDraft, desk: desk, threads: StudioDesk.threads, onSettings: () => _folders(context, autopilot!, game, orchDir)),
  ));
  source.dispose();
}

Future<String?> _pick(BuildContext context, String why, bool Function(String) ok) async {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(why)));
  final dir = await getDirectoryPath(confirmButtonText: 'Use this folder');
  if (dir == null) return null;
  if (!ok(dir)) {
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${p.basename(dir)} does not look right: $why')));
    return null;
  }
  return dir;
}

/// Shows where the Studio reads from and lets the person change either folder;
/// a change reopens the Studio.
Future<void> _folders(BuildContext context, String autopilot, String? game, String? orchestrator) async {
  final choice = await showModalBottomSheet<String>(
    context: context,
    builder: (context) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(leading: const Icon(Icons.smart_toy_outlined), title: const Text('Autopilot folder'), subtitle: Text(autopilot), onTap: () => Navigator.pop(context, 'autopilot')),
        ListTile(leading: const Icon(Icons.videogame_asset_outlined), title: const Text('Game repo'), subtitle: Text(game ?? 'not set'), onTap: () => Navigator.pop(context, 'game')),
        ListTile(leading: const Icon(Icons.hub_outlined), title: const Text('Orchestrator folder'), subtitle: Text(orchestrator ?? 'not set — the game repo'), onTap: () => Navigator.pop(context, 'orchestrator')),
      ]),
    ),
  );
  if (choice == null || !context.mounted) return;
  if (choice == 'autopilot') {
    final d = await _pick(context, 'Pick the autopilot folder (the one with lane-a, mail and review).', StudioSettings.looksLikeAutopilot);
    if (d == null) return;
    await StudioSettings.save(autopilot: d);
  } else if (choice == 'orchestrator') {
    final d = await _pick(context, 'Pick the folder the orchestrator session works in.', (d) => Directory(d).existsSync());
    if (d == null) return;
    await StudioSettings.save(orchestrator: d);
  } else {
    final d = await _pick(context, 'Pick the game repo (the one with production/production-plan.md).', StudioSettings.looksLikeGame);
    if (d == null) return;
    await StudioSettings.save(game: d);
  }
  if (!context.mounted) return;
  Navigator.of(context).pop();
  await openStudio(context);
}
