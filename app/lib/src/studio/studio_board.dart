import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import 'studio_data.dart';

// The messaging board: Fırat's AIs and Görkem's AIs talk on the game repo's
// `messaging-board` branch, one file, newest first. The agents read it at the
// start of every session; the Studio shows it to the person too, and tells
// the phone when Fırat's side writes to them. Read-only: posting stays with
// the orchestrator (/send-team-message).

/// The slug a board push carries: its tap opens the Studio's board.
const kBoardSlug = 'studio-board';

class BoardMessage {
  const BoardMessage({required this.from, required this.to, required this.text, this.at});
  final DateTime? at;

  /// "Fırat's AI (develop)", "Görkem's AI (claude/mine-room-layouts)", "Fırat's box AI (nightly)".
  final String from;

  /// "Görkem's AIs", "Fırat's AIs", "everyone".
  final String to;
  final String text;

  /// From Fırat's side.
  bool get fromFirat => RegExp('f[ıi]rat', caseSensitive: false).hasMatch(from);

  /// To this side: Görkem's AIs, or everyone.
  bool get toUs => RegExp('g[öo]rkem|everyone', caseSensitive: false).hasMatch(to);

  /// Fırat's side writing to this one — what the person is told about.
  bool get forYou => fromFirat && toUs;

  /// A stable id: the stamp and the start of the text.
  String get id => '${at?.toIso8601String() ?? ''}|${text.length > 40 ? text.substring(0, 40) : text}';
}

/// Parses MESSAGING_BOARD.md's `## Messages` list:
/// `- 2026-11-06 22:43 · Fırat's AI (develop) → Görkem's AIs: the message`.
List<BoardMessage> parseBoard(String raw) {
  final out = <BoardMessage>[];
  final start = raw.indexOf('## Messages');
  final body = start < 0 ? raw : raw.substring(start);
  for (final l in body.split('\n')) {
    final m = RegExp(r'^- (\d{4}-\d{2}-\d{2} \d{2}:\d{2}) · (.+?) (?:→|->) (.+?): (.*)$').firstMatch(l);
    if (m == null) continue;
    out.add(BoardMessage(at: parseStamp(m.group(1)!), from: m.group(2)!.trim(), to: m.group(3)!.trim(), text: m.group(4)!.trim()));
  }
  return out;
}

/// Keeps a copy of the board on this Mac: a tiny bare repository holding
/// only the `messaging-board` branch (the lanes' own clones are not
/// touched), fetched every [period], the file written where the Studio reads
/// it. [onNew] hears the messages from Fırat's side to this one that were
/// not there at the last fetch.
class BoardWatcher extends ChangeNotifier {
  BoardWatcher({required this.gameDir, String? home, this.period = const Duration(minutes: 5), this.onNew, Future<ProcessResult> Function(List<String> args)? git})
      : home = home ?? p.join(Platform.environment['HOME'] ?? '.', '.flutter_kit', 'studio'),
        _git = git ?? ((args) => Process.run('git', args));

  final String gameDir;
  final String home;
  final Duration period;
  final void Function(List<BoardMessage> fresh)? onNew;
  final Future<ProcessResult> Function(List<String> args) _git;

  String get repo => p.join(home, 'board.git');

  /// Where the Studio reads the board.
  String get file => p.join(home, 'board.md');
  String get _seenFile => p.join(home, 'board.seen');

  Timer? _timer;
  String? error;
  DateTime? fetchedAt;

  void start() {
    unawaited(fetch());
    _timer ??= Timer.periodic(period, (_) => fetch());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  /// One fetch: the board's latest text to [file]; the new messages for this
  /// side to [onNew]. The first fetch only marks what is there.
  Future<void> fetch() async {
    try {
      if (!Directory(repo).existsSync()) {
        final url = (await _git(['-C', gameDir, 'remote', 'get-url', 'origin'])).stdout.toString().trim();
        if (url.isEmpty) throw StateError('the game repo has no origin');
        Directory(repo).createSync(recursive: true);
        await _run(['init', '--bare', '-q', repo]);
        await _run(['-C', repo, 'remote', 'add', 'origin', url]);
      }
      await _run(['-C', repo, 'fetch', '-q', '--depth', '1', 'origin', '+messaging-board:refs/heads/messaging-board']);
      final text = (await _run(['-C', repo, 'show', 'messaging-board:MESSAGING_BOARD.md'])).stdout.toString();
      File(file).writeAsStringSync(text);
      fetchedAt = DateTime.now();
      error = null;
      _announce(parseBoard(text));
    } catch (e) {
      error = '$e';
    }
    notifyListeners();
  }

  Future<ProcessResult> _run(List<String> args) async {
    final r = await _git(args);
    if (r.exitCode != 0) throw StateError('git ${args.where((a) => !a.startsWith('/')).take(3).join(' ')}: ${r.stderr.toString().trim()}');
    return r;
  }

  void _announce(List<BoardMessage> all) {
    final seenFile = File(_seenFile);
    final known = seenFile.existsSync() ? seenFile.readAsLinesSync().toSet() : null;
    final ids = [for (final m in all) m.id];
    seenFile.writeAsStringSync(ids.take(400).join('\n'));
    if (known == null) return; // the first look marks; it does not announce
    final fresh = [for (final m in all) if (m.forYou && !known.contains(m.id)) m];
    if (fresh.isNotEmpty) onNew?.call(fresh);
  }
}
