import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'studio_data.dart';
import 'studio_plans.dart';

// What belongs to a step besides its text: the pictures, sheets, videos and
// documents its text names (a folder named counts for its pictures), the mail
// that mentions it, its entries in the lane's decision log, and its own log.
// Read-only, found on disk; paths in the files are the MacBook's, so each is
// looked up in the lane's repo, the same repo under ~/StudioProjects, the
// game repo and the autopilot folder.

const _imageExt = {'.jpg', '.jpeg', '.png', '.gif', '.webp'};
const _videoExt = {'.mp4', '.mov', '.webm', '.m4v'};
const _docExt = {'.pdf', '.md', '.txt', '.json', '.csv', '.tsv'};

class StepResources {
  StepResources({this.images = const [], this.videos = const [], this.docs = const [], this.mails = const [], this.decisions = const [], this.log, this.missing = 0});

  final List<String> images;
  final List<String> videos;
  final List<String> docs;
  final List<Mail> mails;

  /// (heading, body) of each decision-log entry that names the step.
  final List<(String, String)> decisions;

  /// The step's own log, when its run is known and the file is here.
  final String? log;

  /// Files the text names that are not on this machine (pointers only, or
  /// on the MacBook).
  final int missing;

  bool get isEmpty => images.isEmpty && videos.isEmpty && docs.isEmpty && mails.isEmpty && decisions.isEmpty && log == null;

  /// "3 PICTURES · 2 MAILS · 1 DECISION · LOG".
  String get label => [
        if (images.isNotEmpty) '${images.length} PICTURE${images.length == 1 ? '' : 'S'}',
        if (videos.isNotEmpty) '${videos.length} VIDEO${videos.length == 1 ? '' : 'S'}',
        if (docs.isNotEmpty) '${docs.length} DOC${docs.length == 1 ? '' : 'S'}',
        if (mails.isNotEmpty) '${mails.length} MAIL${mails.length == 1 ? '' : 'S'}',
        if (decisions.isNotEmpty) '${decisions.length} DECISION${decisions.length == 1 ? '' : 'S'}',
        if (log != null) 'LOG',
      ].join(' · ');
}

/// File paths a text names: `docs/art/x/sheet.jpg`, `../docs/ADR-037.md`,
/// a folder like `docs/art/mine-kit/rock-surface/`.
List<String> namedPaths(String text) => {
      for (final m in RegExp(r'(?:\.\./|\./)?(?:[A-Za-z0-9_.-]+/)+[A-Za-z0-9_.-]*').allMatches(text))
        // Part of a URL (after "https://" or another path's "/") is not a file of ours.
        if ((m.start == 0 || !RegExp(r'[:/A-Za-z0-9]').hasMatch(text[m.start - 1])) && _looksLikePath(m.group(0)!)) m.group(0)!,
    }.toList();

bool _looksLikePath(String s) {
  if (s.startsWith('http') || s.contains('//')) return false;
  final ext = p.extension(s).toLowerCase();
  if (s.endsWith('/')) return s.split('/').where((x) => x.isNotEmpty).length >= 2;
  return _imageExt.contains(ext) || _videoExt.contains(ext) || _docExt.contains(ext);
}

/// Finds a step's resources. [roots] are the folders to resolve names in, in
/// order; [mailDir] and [decisionsFile] are the autopilot's mail and the
/// lane's decision log.
class ResourceFinder {
  ResourceFinder({required this.roots, this.mailDir, this.logDir});
  final List<String> roots;
  final String? mailDir;
  final String? logDir;

  /// Mail file → its text, kept while the file is unchanged.
  final Map<String, ({DateTime m, String text})> _mail = {};

  String? resolve(String rel) {
    final clean = rel.replaceFirst(RegExp(r'^(\.\./)+|^\./'), '');
    for (final r in roots) {
      for (final c in [p.join(r, clean), p.join(r, 'production', rel)]) {
        final n = p.normalize(c);
        if (FileSystemEntity.typeSync(n) != FileSystemEntityType.notFound) return n;
      }
    }
    return null;
  }

  StepResources find({required String id, required String text, String? run, String? lane, String? decisionsFile}) {
    final images = <String>[], videos = <String>[], docs = <String>[];
    var missing = 0;
    for (final rel in namedPaths(text)) {
      final at = resolve(rel);
      if (at == null) {
        missing++;
        continue;
      }
      if (FileSystemEntity.isDirectorySync(at)) {
        final inside = Directory(at).listSync().whereType<File>().where((f) => _imageExt.contains(p.extension(f.path).toLowerCase())).map((f) => f.path).toList()..sort();
        images.addAll(inside.take(12));
        continue;
      }
      final ext = p.extension(at).toLowerCase();
      if (_imageExt.contains(ext)) {
        images.add(at);
      } else if (_videoExt.contains(ext)) {
        videos.add(at);
      } else {
        docs.add(at);
      }
    }
    return StepResources(
      images: images.toSet().toList(),
      videos: videos.toSet().toList(),
      docs: docs.toSet().toList(),
      mails: _mailsNaming(id, run: run),
      decisions: decisionsFile == null ? const [] : _decisionsNaming(id, decisionsFile, run: run),
      log: _log(lane, run),
      missing: missing,
    );
  }

  /// A pattern that names the step: its id as a word; for a number-only id,
  /// "step 476" / "run 476".
  RegExp _naming(String id, {String? run}) {
    final alts = <String>[
      if (!RegExp(r'^\d+$').hasMatch(id) && id.length >= 4) '\\b${RegExp.escape(id)}\\b',
      if (run != null) '\\b(?:step|run) ?${RegExp.escape(run)}\\b',
    ];
    return RegExp(alts.isEmpty ? r'(?!)' : alts.join('|'), caseSensitive: false);
  }

  List<Mail> _mailsNaming(String id, {String? run}) {
    final dir = mailDir;
    if (dir == null || !Directory(dir).existsSync()) return const [];
    final re = _naming(id, run: run);
    final out = <Mail>[];
    for (final f in Directory(dir).listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.md'))) {
      final m = f.lastModifiedSync();
      final hit = _mail[f.path];
      final text = hit != null && hit.m == m ? hit.text : utf8.decode(f.readAsBytesSync(), allowMalformed: true);
      _mail[f.path] = (m: m, text: text);
      if (re.hasMatch(text)) out.add(Mail.parse(p.basename(f.path), text));
    }
    out.sort((a, b) => (b.at ?? DateTime(0)).compareTo(a.at ?? DateTime(0)));
    return out.take(20).toList();
  }

  List<(String, String)> _decisionsNaming(String id, String file, {String? run}) {
    final f = File(file);
    if (!f.existsSync()) return const [];
    final re = _naming(id, run: run);
    final out = <(String, String)>[];
    String? head;
    final buf = StringBuffer();
    void flush() {
      if (head != null && (re.hasMatch(head) || re.hasMatch(buf.toString()))) out.add((head, buf.toString().trim()));
      buf.clear();
    }

    for (final l in utf8.decode(f.readAsBytesSync(), allowMalformed: true).split('\n')) {
      if (l.startsWith('### ') || l.startsWith('## ')) {
        flush();
        head = l.replaceFirst(RegExp(r'^#+\s*'), '');
      } else if (head != null) {
        buf.writeln(l);
      }
    }
    flush();
    return out.reversed.take(8).toList();
  }

  String? _log(String? lane, String? run) {
    if (lane == null || run == null || logDir == null) return null;
    for (final n in ['step-$run.log', 'step-$run.log.gz']) {
      final f = p.join(logDir!, 'lane-$lane', 'logs', n);
      if (File(f).existsSync()) return f;
    }
    return null;
  }
}

/// The decision log a lane's prompt names: `production/autopilot/lane-a-decisions.md` …
String? decisionsFileIn(String prompt) => RegExp(r'[A-Za-z0-9_./-]*decisions\.md').firstMatch(prompt)?.group(0);

/// Resources for a roadmap item: the files its row names.
StepResources itemResources(ResourceFinder f, RoadmapItem item) => f.find(id: item.id, text: '${item.statusText}\n${item.summary}');
