import 'dart:io';

import 'package:flutter_kit/kit.dart';

import 'codex_cli.dart';
import 'engine.dart';

/// Codex over `codex app-server --stdio` — JSON-RPC both ways, translated
/// by [CodexTranslator]. The handshake runs itself: the process answers
/// `initialize`, and the engine queues `initialized`, `model/list`,
/// `skills/list` and the `thread/start` (or `thread/resume`) whose
/// response is the session's init. Mode, model and effort ride on every
/// `turn/start`, so nothing restarts; `/compact` is `thread/compact/start`
/// and `/clear` a fresh thread. The plan card is the turn's `plan` item,
/// raised by the translator at the turn's end — IMPLEMENT sends the next
/// turn in default mode.
class CodexEngine extends Engine {
  CodexEngine({Future<String?> Function()? findBinary, Future<String?> Function(String bin)? versionOf, Future<List<String>> Function()? sandboxRoots, CodexTranslator? translator, this.clientVersion = ''})
      : _findBinary = findBinary ?? CodexCli.findBinary,
        _versionOf = versionOf ?? ((bin) => CodexCli.version(bin)),
        _sandboxRoots = sandboxRoots ?? CodexCli.sandboxRoots,
        translator = translator ?? CodexTranslator();

  final Future<String?> Function() _findBinary;
  final Future<String?> Function(String bin) _versionOf;
  final Future<List<String>> Function() _sandboxRoots;
  final CodexTranslator translator;
  final String clientVersion;
  EngineStart? _start;
  final List<String> _outbox = [];

  /// What the workspace-write sandbox may also write: the SDK's cache and
  /// the pub cache ([CodexCli.sandboxRoots]), and the plugin's `kit/` —
  /// found from where Codex listed the kit skills — for its binary.
  List<String> _roots = const [];
  List<String> get writableRoots {
    final roots = [..._roots];
    for (final path in translator.skills.values) {
      // …/<plugin root>/skills/<name>/SKILL.md → <plugin root>/kit
      final parts = path.split('/');
      final i = parts.lastIndexOf('skills');
      if (i <= 0) continue;
      final kit = realPath('${parts.sublist(0, i).join('/')}/kit');
      if (!roots.contains(kit)) roots.add(kit);
      break;
    }
    return roots;
  }

  /// Codex refuses a writable root with a symlink in it ("symlinked
  /// writable roots are not supported", 0.153.4) — and its plugin cache is
  /// one while this checkout is symlinked into it (README). The real path
  /// is accepted, and a write through the symlink still lands (probed
  /// 2026-09-10). A path that does not exist goes as it is.
  static String realPath(String path) {
    try {
      return Directory(path).resolveSymbolicLinksSync();
    } on Object {
      return path;
    }
  }

  @override
  String get id => 'codex';
  @override
  String get provenOn => codexProvenOn;
  @override
  bool get readyOnInit => true;
  @override
  bool get namesSession => true;
  @override
  bool get restartsOnEffort => false;
  @override
  bool get hasChrome => false;
  @override
  bool get switchesByRequest => false;
  @override
  Future<String?> findBinary() => _findBinary();
  @override
  Future<String?> versionOf(String bin) => _versionOf(bin);
  @override
  String get whereLooked => CodexCli.whereLooked;
  @override
  bool canResume(String sessionId) => true;
  @override
  List<String>? readTranscript(String sessionId) => null;
  @override
  List<String> args(EngineStart s) => codexArgs();

  @override
  Future<List<String>> opening(EngineStart s) async {
    _start = s;
    try {
      _roots = await _sandboxRoots();
    } on Object {
      _roots = const [];
    }
    return [translator.initializeLine(version: clientVersion)];
  }

  @override
  List<BridgeEvent>? feed(String line) {
    final t = line.trim();
    if (t.isEmpty || !t.startsWith('{')) return null;
    final before = translator.threadId;
    final events = translator.feed(line);
    _outbox.addAll(translator.outbox);
    translator.outbox.clear();
    // The handshake's next steps, once the server said hello.
    if (_handshake(line)) {
      final s = _start!;
      _outbox.add(translator.initializedLine());
      _outbox.add(translator.modelListLine());
      _outbox.add(translator.skillsListLine(s.dir));
      _outbox.add(translator.threadStartLine(cwd: s.dir, mode: s.mode, model: s.model, developerInstructions: s.brief, resume: s.resume ? s.sessionId : null));
    }
    if (before == null && translator.threadId != null) _outbox.add(translator.rateLimitsLine());
    return events;
  }

  /// The line is the response to our `initialize`.
  bool _handshake(String line) {
    if (_start == null || !line.contains('"codexHome"')) return false;
    final done = _initDone;
    _initDone = true;
    return !done;
  }

  bool _initDone = false;

  @override
  List<String> drain() {
    final out = List<String>.of(_outbox);
    _outbox.clear();
    return out;
  }

  @override
  List<DeckMessage> takeRestored() => translator.takeRestored();

  @override
  String? userMessage(String prompt, {List<InlineImage> images = const [], List<String> imagePaths = const [], required EngineTurn turn}) {
    if (translator.threadId == null) return null;
    // `/step x` becomes the skill the plugin ships as `kit-step` (or
    // `step`), with the words after it as the text; the mention names
    // the skill as Codex listed it.
    String text = prompt;
    String? skill;
    final m = RegExp(r'^[/$]([a-z][a-z0-9-]*)(\s[\s\S]*)?$').firstMatch(prompt.trim());
    if (m != null) {
      final name = m.group(1)!;
      final known = _skillFor(name);
      if (known != null) {
        skill = known;
        final rest = (m.group(2) ?? '').trim();
        final label = known.contains(':') ? known.substring(known.lastIndexOf(':') + 1) : known;
        text = rest.isEmpty ? 'Use the \$$label skill.' : 'Use the \$$label skill with: $rest';
      }
    }
    return translator.turnStartLine(text: text, imagePaths: imagePaths, skill: skill, mode: turn.mode, model: turn.model, effort: turn.effort, writableRoots: writableRoots);
  }

  /// The skill `/name` means, as `skills/list` names it — a plugin's
  /// skills come namespaced (`flutter-kit:kit-step` on 0.153.4), so the
  /// match is on the last segment: `kit-<name>` first, then `<name>`.
  String? _skillFor(String name) {
    for (final want in ['kit-$name', name]) {
      for (final listed in translator.skills.keys) {
        if (listed == want || listed.endsWith(':$want')) return listed;
      }
    }
    return null;
  }

  @override
  String? answer(Ask ask, AskAnswer a) => translator.answerLine(ask, a);

  @override
  String? followUp(Ask ask, AskAnswer a) {
    if (!ask.isPlan) return null;
    if (a.allowed) return 'Implement the plan.';
    // Revise: the plan card's words, for the next plan-mode turn.
    final message = (a.response['message'] ?? '').toString().replaceFirst(RegExp(r'\nRevise the plan and call ExitPlanMode again\.$'), '');
    return message.trim().isEmpty ? 'Revise the plan.' : '$message\nRevise the plan.';
  }

  @override
  String? interrupt(String requestId) => translator.interruptLine();
  @override
  String? setMode(String requestId, String mode) => null;
  @override
  String? setModel(String requestId, String model) => null;
  @override
  String? compact() => translator.compactLine();
  @override
  String? clear(EngineStart s) => translator.threadId == null ? null : translator.threadStartLine(cwd: s.dir, mode: s.mode, model: s.model, developerInstructions: s.brief, clear: true);
  @override
  List<String> get models => translator.models;
  @override
  Map<String, String> get mcp => translator.mcp;
  @override
  bool? knowsCommand(String name) => translator.skills.isEmpty ? null : _skillFor(name) != null;
}
