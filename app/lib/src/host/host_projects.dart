import 'package:cloud_firestore/cloud_firestore.dart';

import 'host_project.dart';

/// Open projects outlive their screens: a Remote Control session must not
/// die because the person tapped Back.
class HostProjects {
  static final Map<String, HostProject> open = {};

  static HostProject get(String dir) => open.putIfAbsent(dir, () => HostProject(dir: dir, db: FirebaseFirestore.instance)..start());

  static Future<void> close(String dir) async {
    final p = open.remove(dir);
    if (p == null) return;
    await p.session.stop();
    p.dispose();
  }
}
