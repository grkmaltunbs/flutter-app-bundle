import 'dart:io';

import 'package:flutter_kit/kit.dart';
import 'package:path/path.dart' as p;

import '../attachments.dart';

/// Where the files that travel with a message land on the Mac:
/// `~/.flutter_kit/attachments/<claude project slug>/<stamp>-<name>`.
/// Kept — a Read tool call next week may want one back — and never inside
/// the project, so nothing lands in git.
class AttachmentStore {
  AttachmentStore({required this.dir, this.home});

  /// The project folder; the store is named after it the way the bridge
  /// record is.
  final String dir;

  /// Overrides `~/.flutter_kit` — tests keep their files in a temp folder.
  final String? home;

  Directory get folder => Directory(p.join(kitHome(home: home), 'attachments', claudeProjectSlug(dir)));

  /// Writes the bytes and returns the row the deck shows, with the path.
  DeckAttachment save(PendingAttachment a, {DateTime? at}) {
    folder.createSync(recursive: true);
    final t = at ?? DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    final stamp = '${t.year}${two(t.month)}${two(t.day)}-${two(t.hour)}${two(t.minute)}${two(t.second)}';
    final safe = a.name.replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_');
    var f = File(p.join(folder.path, '$stamp-$safe'));
    for (var i = 2; f.existsSync(); i++) {
      f = File(p.join(folder.path, '$stamp-$i-$safe'));
    }
    f.writeAsBytesSync(a.bytes);
    return a.describe(path: f.path);
  }
}
