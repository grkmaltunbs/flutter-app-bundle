import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import 'studio_data.dart';
import 'studio_plans.dart';
import 'studio_resources.dart';

/// Reads the autopilot folder into a [StudioSnapshot], again every [period]
/// — the loop writes plain files and nothing announces a change, so the
/// Studio polls as the reviewer does. Read-only: the Studio never writes
/// into the autopilot folder or the game repo.
class StudioSource extends ChangeNotifier {
  StudioSource({required this.autopilotDir, this.gameDir, this.period = const Duration(seconds: 15), DateTime Function()? now}) : _now = now ?? DateTime.now;

  /// The Studio open now — for pages that look up a step's resources.
  static StudioSource? current;

  final String autopilotDir;

  /// The game repo (roadmap, rules, concept); optional.
  final String? gameDir;
  final Duration period;
  final DateTime Function() _now;

  StudioSnapshot snapshot = StudioSnapshot.empty;
  String? error;
  Timer? _timer;

  /// Mail bodies are read once per file name; a mail file is written once.
  final Map<String, Mail> _mailCache = {};

  void start() {
    refresh();
    _timer ??= Timer.periodic(period, (_) => refresh());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> refresh() async {
    try {
      snapshot = await read();
      error = null;
    } catch (e) {
      error = '$e';
    }
    notifyListeners();
  }

  String _text(String rel) {
    final f = File(p.join(autopilotDir, rel));
    return f.existsSync() ? _decode(f.readAsBytesSync()) : '';
  }

  /// Agents write UTF-8 but a cut-off line can end mid-character.
  static String _decode(List<int> bytes) => utf8.decode(bytes, allowMalformed: true);

  /// One pass over the folder. Synchronous file reads: the files are small
  /// (the history logs are the largest, a few hundred KB) and local.
  Future<StudioSnapshot> read() async {
    final root = Directory(autopilotDir);
    if (!root.existsSync()) throw StateError('No folder at $autopilotDir');
    final laneDirs = root.listSync().whereType<Directory>().where((d) => RegExp(r'^lane-[a-z]$').hasMatch(p.basename(d.path))).toList()
      ..sort((a, b) => a.path.compareTo(b.path));
    final runLane = _text('run-lane.sh');
    final hosts = laneHosts(runLane);
    final repos = laneRepos(runLane);
    bool flag(String name) => File(p.join(autopilotDir, 'control', name)).existsSync();
    final lanes = <Lane>[
      for (final d in laneDirs)
        () {
          final id = p.basename(d.path).substring(5);
          String f(String n) => _text(p.join('lane-$id', n)).trim();
          return Lane(
            id: id,
            status: LaneStatus.parse(f('status')),
            history: parseHistory(_text(p.join('lane-$id', 'history.log'))),
            engine: f('engine'),
            model: f('model'),
            effort: f('effort'),
            inbox: _mdFiles(p.join('mail', 'to-$id')).length,
            paused: flag('PAUSE') || flag('PAUSE-$id'),
            stopping: flag('STOP') || flag('STOP-$id'),
            hostMachine: hosts[id],
          );
        }(),
    ];
    final mail = <Mail>[
      for (final f in _mdFiles(p.join('mail', 'to-user')))
        _mailCache.putIfAbsent(p.basename(f.path), () => Mail.parse(p.basename(f.path), _decode(f.readAsBytesSync()))),
    ]..sort((a, b) => (b.at ?? DateTime(0)).compareTo(a.at ?? DateTime(0)));
    final tracks = <String, LaneTrack>{
      for (final l in lanes)
        l.id: () {
          final f = stepsFileFor(l.id, repos[l.id] ?? const []);
          if (f == null) return LaneTrack.empty;
          return LaneTrack.from(_cached(f, parseStepList), running: l.status.state == LaneState.running, lastDoneId: leadingId(l.lastDone?.summary), source: f);
        }(),
    };
    final plan = gameDir == null ? null : p.join(gameDir!, 'production', 'production-plan.md');
    final roadmap = plan != null && File(plan).existsSync() ? _cached(plan, parseRoadmap) : const <Milestone>[];
    final digest = ReviewSection.parseAll(_text(p.join('review', 'digest.md')));
    final decisions = ReviewSection.parseAll(_text(p.join('review', 'afk-decisions.md'))).reversed.toList();
    final mode = _text(p.join('review', 'mode')).trim();
    return StudioSnapshot(
      lanes: lanes,
      userMail: mail,
      openIssues: OpenIssue.parseAll(_text(p.join('review', 'open-issues.md'))).reversed.toList(),
      decisions: decisions,
      digest: digest.isEmpty ? null : digest.last,
      mode: mode.isEmpty ? null : mode,
      lastReview: parseStamp(_text(p.join('review', 'last-review'))),
      readAt: _now(),
      tracks: tracks,
      roadmap: roadmap,
    );
  }

  /// Parsed files, kept until the file changes (the plan is 340 KB).
  final Map<String, ({DateTime modified, Object value})> _parsed = {};

  T _cached<T extends Object>(String path, T Function(String) parse) {
    final f = File(path);
    final m = f.lastModifiedSync();
    final hit = _parsed[path];
    if (hit != null && hit.modified == m && hit.value is T) return hit.value as T;
    final v = parse(_decode(f.readAsBytesSync()));
    _parsed[path] = (modified: m, value: v);
    return v;
  }

  /// Where a lane's step list is, first that exists:
  /// the autopilot's own copy (`lane-<x>/steps.md`), the lane's repo as
  /// `run-lane.sh` names it, the same repo under ~/StudioProjects (paths in
  /// the files are the MacBook's), then the game repo.
  String? stepsFileFor(String lane, List<String> repos) {
    // The loop's own copy, unless empty: status.sh refreshes it with
    // `git show … > steps.md`, which leaves an empty file when the branch
    // is not there.
    final own = p.join(autopilotDir, 'lane-$lane', 'steps.md');
    if (File(own).existsSync() && File(own).lengthSync() > 0) return own;
    final rel = stepsFileIn(_text(p.join('prompts', 'lane-$lane.md')));
    if (rel == null) return null;
    final home = Platform.environment['HOME'] ?? '';
    final candidates = [
      for (final r in repos) p.join(r, rel),
      for (final r in repos) p.join(home, 'StudioProjects', p.basename(r), rel),
      if (gameDir != null) p.join(gameDir!, rel),
    ];
    for (final c in candidates) {
      if (File(c).existsSync() && File(c).lengthSync() > 0) return c;
    }
    return null;
  }

  List<File> _mdFiles(String rel) {
    final d = Directory(p.join(autopilotDir, rel));
    if (!d.existsSync()) return const [];
    return d.listSync().whereType<File>().where((f) => f.path.endsWith('.md')).toList();
  }

  /// The last [lines] lines of a step's readable log, gzipped or not.
  String stepLog(String lane, String step, {int lines = 200}) {
    final dir = p.join(autopilotDir, 'lane-$lane', 'logs');
    final plain = File(p.join(dir, 'step-$step.log'));
    final gz = File(p.join(dir, 'step-$step.log.gz'));
    String text;
    if (plain.existsSync()) {
      text = _decode(plain.readAsBytesSync());
    } else if (gz.existsSync()) {
      text = _decode(gzip.decode(gz.readAsBytesSync()));
    } else {
      return '';
    }
    final all = text.split('\n');
    return all.length <= lines ? text : all.sublist(all.length - lines).join('\n');
  }

  final Map<String, ResourceFinder> _finders = {};

  /// Where a lane's names resolve: its repos (as run-lane.sh names them, and
  /// the same repo under ~/StudioProjects), the game repo, the autopilot folder.
  ResourceFinder finderFor(String? lane) => _finders.putIfAbsent(lane ?? '-', () {
        final home = Platform.environment['HOME'] ?? '';
        final repos = lane == null ? const <String>[] : (laneRepos(_text('run-lane.sh'))[lane] ?? const <String>[]);
        return ResourceFinder(
          roots: [
            for (final r in repos) r,
            for (final r in repos) p.join(home, 'StudioProjects', p.basename(r)),
            ?gameDir,
            autopilotDir,
          ],
          mailDir: p.join(autopilotDir, 'mail'),
          logDir: autopilotDir,
        );
      });

  final Map<String, ({DateTime at, StepResources r})> _resCache = {};

  /// [resourcesFor], kept for a minute — a panel asks on every rebuild.
  StepResources resourcesCached(String lane, StepItem item) {
    final k = '$lane/${item.id}';
    final hit = _resCache[k];
    if (hit != null && DateTime.now().difference(hit.at) < const Duration(minutes: 1)) return hit.r;
    final r = resourcesFor(lane, item);
    _resCache[k] = (at: DateTime.now(), r: r);
    return r;
  }

  /// A lane step's pictures, videos, documents, mail, decisions and log.
  StepResources resourcesFor(String lane, StepItem item) {
    final f = finderFor(lane);
    final rel = decisionsFileIn(_text(p.join('prompts', 'lane-$lane.md')));
    final decisions = rel == null ? (File(p.join(autopilotDir, 'lane-$lane', 'decisions.md')).existsSync() ? p.join(autopilotDir, 'lane-$lane', 'decisions.md') : null) : f.resolve(rel);
    return f.find(id: item.id, text: item.text, run: item.run, lane: lane, decisionsFile: decisions);
  }

  /// A roadmap item's resources: the files its row names, and mail naming it.
  StepResources resourcesForItem(RoadmapItem item) => itemResources(finderFor(null), item);

  /// A file of the game repo, or '' when there is none.
  String gameFile(String rel) {
    if (gameDir == null) return '';
    final f = File(p.join(gameDir!, rel));
    return f.existsSync() ? _decode(f.readAsBytesSync()) : '';
  }

  /// The game repo's `design/gdd/*.md`, sorted.
  List<String> gddFiles() {
    if (gameDir == null) return const [];
    final d = Directory(p.join(gameDir!, 'design', 'gdd'));
    if (!d.existsSync()) return const [];
    return (d.listSync().whereType<File>().map((f) => p.relative(f.path, from: gameDir)).where((r) => r.endsWith('.md')).toList())..sort();
  }
}

/// Where the Studio reads from, kept between launches.
class StudioSettings {
  static const _autopilot = 'studio.autopilotDir';
  static const _game = 'studio.gameDir';
  static const _orchestrator = 'studio.orchestratorDir';

  static Future<({String? autopilot, String? game, String? orchestrator})> load() async {
    final prefs = await SharedPreferences.getInstance();
    return (autopilot: prefs.getString(_autopilot), game: prefs.getString(_game), orchestrator: prefs.getString(_orchestrator));
  }

  static Future<void> save({String? autopilot, String? game, String? orchestrator}) async {
    final prefs = await SharedPreferences.getInstance();
    if (autopilot != null) await prefs.setString(_autopilot, autopilot);
    if (game != null) await prefs.setString(_game, game);
    if (orchestrator != null) await prefs.setString(_orchestrator, orchestrator);
  }

  /// A folder looks like the autopilot when it has a `lane-a`.
  static bool looksLikeAutopilot(String dir) => Directory(p.join(dir, 'lane-a')).existsSync();

  /// A folder looks like the game repo when it has the production plan.
  static bool looksLikeGame(String dir) => File(p.join(dir, 'production', 'production-plan.md')).existsSync();
}
