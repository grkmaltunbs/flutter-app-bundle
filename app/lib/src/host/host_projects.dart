import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path/path.dart' as p;

import '../blobs.dart';
import 'host_actions.dart' show worktreePath;
import 'host_presence.dart';
import 'host_project.dart';
import 'login_item.dart';
import 'power.dart';
import 'push_sender.dart';

/// Open projects outlive their screens: a Remote Control session must not
/// die because the person tapped Back.
class HostProjects {
  static final Map<String, HostProject> open = {};

  /// One sender for the Mac: the key and the phones are not per project.
  static final PushSender push = PushSender(db: FirebaseFirestore.instance);

  /// One door to the bucket for every project.
  static final BlobStore blobs = FirebaseBlobStore();

  /// The Mac's heartbeat to the phone — one row for every open project.
  static final HostPresence presence = HostPresence(
    db: FirebaseFirestore.instance,
    machine: Platform.localHostname,
    sessions: () => {
      for (final p in open.values)
        if (p.slug != null) p.slug!: p.bridge.running || p.session.running,
    },
  );

  /// The power assertion while any session runs.
  static final PowerHold power = PowerHold();

  /// The LaunchAgent that starts this app at login.
  static final LoginItem loginItem = LoginItem();

  static HostProject get(String dir) => open.putIfAbsent(dir, () => _make(dir)..start());

  /// A project's worktree as an open project of its own, under its parent.
  static HostProject getWorktree(HostProject parent, String name) {
    final dir = worktreePath(parent.slug ?? p.basename(parent.dir), name);
    return open.putIfAbsent(dir, () => _make(dir, parent: parent, worktreeName: name)..start());
  }

  /// The open worktrees of the project at [dir].
  static List<HostProject> worktreesOf(String dir) => [for (final h in open.values) if (h.parent?.dir == dir) h];

  static HostProject _make(String dir, {HostProject? parent, String? worktreeName}) => HostProject(dir: dir, db: FirebaseFirestore.instance, push: push, blobs: blobs, power: power, parent: parent, worktreeName: worktreeName)
    ..worktreeOpener = getWorktree
    ..worktreeCloser = (child) => close(child.dir);

  /// A clean quit of the app: every open project's session stopped and
  /// the relay told, within a few seconds — a quit must not hang.
  static Future<void> quitAll() => Future.wait(open.values.map((p) => p.quit())).timeout(const Duration(seconds: 12), onTimeout: () => const []);

  static Future<void> close(String dir) async {
    final h = open.remove(dir);
    if (h == null) return;
    await h.session.stop();
    if (h.bridge.running) await h.bridge.stop();
    h.dispose();
  }
}
