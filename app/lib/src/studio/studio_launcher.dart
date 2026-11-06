import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart' hide Step, StepState;
import 'package:path/path.dart' as p;

import 'package:cloud_firestore/cloud_firestore.dart';

import '../host/bridge_session.dart';
import '../host/host_projects.dart';
import 'studio_desk.dart';
import 'studio_media.dart';
import 'studio_draft.dart';
import 'studio_orchestrator.dart';
import 'studio_relay.dart';
import 'studio_screen.dart';
import 'studio_source.dart';

/// The pictures and videos the autopilot shows — one per app, published to
/// the relay for the phone.
StudioMedia? _media;
StudioMedia studioMediaFor({required String autopilot, required String? Function(String) resolve}) {
  final m = _media ??= (StudioMedia(publisher: FirebaseMediaPublisher(db: FirebaseFirestore.instance, blobs: HostProjects.blobs))..load());
  m
    ..reviewDir = p.join(autopilot, 'review')
    ..resolve = resolve
    ..start();
  return m;
}

/// Stops the Studio's background work on a clean quit.
void stopStudioMedia() {
  StudioHost.current?.stop();
  _media?.stop();
}

/// The one draft of the app — it outlives the Studio screen and a relaunch.
final StudioDraft studioDraft = StudioDraft()..restore();

/// The Studio's background work, started with the app on the Mac: reading
/// the autopilot folder, publishing it for the phone, gathering media, and
/// (through the orchestrator) timed orders and the review loop — whether or
/// not the Studio screen is open. Opening the Studio only shows it.
class StudioHost {
  StudioHost._(this.autopilot, this.game, this.orchDir) {
    source = StudioSource(autopilotDir: autopilot, gameDir: game)..start();
    StudioSource.current = source;
    // The orchestrator runs where the person says, else in the game repo.
    orchestrator = orchDir == null ? null : StudioOrchestrator.get(orchDir!, autopilotDir: autopilot);
    // The step desk works in the same folder, on its own record.
    desk = orchDir == null ? null : StudioDesk.get(orchDir!, autopilotDir: autopilot);
    media = studioMediaFor(autopilot: autopilot, resolve: source.finderFor(null).resolve);
    if (orchestrator != null) media.watch(orchestrator!, source: 'orchestrator');
    if (desk != null) media.watch(desk!, source: 'desk');
    publisher = StudioPublisher(db: FirebaseFirestore.instance, source: source, machine: Platform.localHostname)..start();
  }

  final String autopilot;
  final String? game;
  final String? orchDir;
  late final StudioSource source;
  BridgeSession? orchestrator;
  BridgeSession? desk;
  late final StudioMedia media;
  late final StudioPublisher publisher;

  static StudioHost? current;

  /// The host for the saved (or usual) folders; null when no autopilot
  /// folder is known yet. A change of folders replaces it.
  static Future<StudioHost?> ensure({String? autopilotOverride}) async {
    final saved = await StudioSettings.load();
    final home = Platform.environment['HOME'] ?? '';
    String? firstThat(List<String?> dirs, bool Function(String) ok) {
      for (final d in dirs) {
        if (d != null && ok(d)) return d;
      }
      return null;
    }

    final autopilot = firstThat([autopilotOverride, saved.autopilot, p.join(home, 'StudioProjects', 'sivas-autopilot'), p.join(home, 'StudioProjects', 'sivas-autopilot-snapshot')], StudioSettings.looksLikeAutopilot);
    if (autopilot == null) return null;
    final game = firstThat([saved.game, p.join(home, 'StudioProjects', 'sivas-the-game')], StudioSettings.looksLikeGame);
    final orchDir = saved.orchestrator != null && Directory(saved.orchestrator!).existsSync() ? saved.orchestrator : game;
    final cur = current;
    if (cur != null && cur.autopilot == autopilot && cur.game == game && cur.orchDir == orchDir) return cur;
    cur?.stop();
    await StudioSettings.save(autopilot: autopilot, game: game);
    return current = StudioHost._(autopilot, game, orchDir);
  }

  void stop() {
    publisher.stop();
    source.dispose();
    media.stop();
    if (identical(current, this)) current = null;
  }
}

/// Opens the Studio: the folders saved last time, else the usual places
/// under ~/StudioProjects, else asks.
Future<void> openStudio(BuildContext context) async {
  var host = await StudioHost.ensure();
  if (!context.mounted) return;
  if (host == null) {
    final picked = await _pick(context, 'Pick the autopilot folder (the one with lane-a, mail and review).', StudioSettings.looksLikeAutopilot);
    if (picked == null) return;
    host = await StudioHost.ensure(autopilotOverride: picked);
    if (host == null || !context.mounted) return;
  }
  final h = host;
  await Navigator.of(context).push(MaterialPageRoute<void>(
    builder: (context) => StudioScreen(source: h.source, orchestrator: h.orchestrator, draft: studioDraft, desk: h.desk, threads: StudioDesk.threads, media: h.media, onSettings: () => _folders(context, h.autopilot, h.game, h.orchDir)),
  ));
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
