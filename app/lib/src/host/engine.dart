import 'package:flutter_kit/kit.dart';

import 'claude_cli.dart';

/// What Start hands an engine: the folder, the dials, the brief, and the
/// session to resume — or `/clear`'s fresh conversation.
class EngineStart {
  const EngineStart({required this.dir, required this.mode, this.model, this.effort, this.chrome = false, this.brief, this.sessionId, this.resume = false, this.clear = false});
  final String dir;
  final String mode;
  final String? model;
  final String? effort;
  final bool chrome;
  final String? brief;
  final String? sessionId;
  final bool resume;
  final bool clear;
}

/// The dials as one turn runs under them — Codex takes them per turn.
class EngineTurn {
  const EngineTurn({required this.mode, this.model, this.effort});
  final String mode;
  final String? model;
  final String? effort;
}

/// One engine behind the bridge: the process to start, the lines to write
/// for a message, an answer, a brake, and what its stdout means. The
/// runner ([BridgeSession]) owns the process, the record, the queue, the
/// asks, the options and the relay; an engine only translates. Two live
/// here: [ClaudeEngine] over `claude -p` (the stream-json control
/// protocol) and `CodexEngine` over `codex app-server` (JSON-RPC).
abstract class Engine {
  /// `claude` or `codex` — one of [engineChoices].
  String get id;
  String get label => engineLabel(id);

  /// The version the protocol was captured on; the facts line shows the
  /// one actually started beside it.
  String get provenOn;

  /// The engine's first reply makes the session ready, and a process
  /// alive without one is still starting (Codex: the thread/start
  /// response). Claude says nothing until the first message, so the
  /// runner's grace timer flips it ready instead.
  bool get readyOnInit;

  /// The engine names the session (Codex's thread id comes with the
  /// init); Claude takes the id the runner chooses.
  bool get namesSession;

  /// Effort is a flag of the process — a change restarts it on the same
  /// conversation (Claude); or rides on the next turn (Codex).
  bool get restartsOnEffort;

  /// The engine has the Drive Chrome switch (`--chrome`).
  bool get hasChrome;

  /// The mode and the model switch with a control request mid-session
  /// (Claude) rather than on the next turn (Codex).
  bool get switchesByRequest;

  Future<String?> findBinary();
  Future<String?> versionOf(String bin);

  /// Where the runner looks when the binary is missing, for the error.
  String get whereLooked;

  /// Whether [sessionId] has anything to resume — Claude wrote it down on
  /// its first turn; Codex keeps every thread and says when asked.
  bool canResume(String sessionId);

  /// The session's own file, line by line, for the rows a resume brings
  /// back on the Deck; null when the engine has no such file.
  List<String>? readTranscript(String sessionId);

  List<String> args(EngineStart s);

  /// Lines to write the moment the process is up — and the engine's
  /// chance to look around first (where the SDK is, for the sandbox).
  Future<List<String>> opening(EngineStart s);

  /// One stdout line → the events it means; null for a line that is not
  /// protocol at all (it goes to the log).
  List<BridgeEvent>? feed(String line);

  /// Lines the engine wants written after a feed — its own replies to
  /// requests nobody on a phone can answer, the handshake's next step.
  List<String> drain();

  /// Rows a resume brought back, once.
  List<DeckMessage> takeRestored();

  /// The line for a user message, or null while the engine cannot take
  /// one yet (no thread) — the runner queues it and asks again.
  String? userMessage(String prompt, {List<InlineImage> images = const [], List<String> imagePaths = const [], required EngineTurn turn});

  /// The line that answers [ask]; null when the engine has nothing to
  /// write for it (a card the runner raised itself).
  String? answer(Ask ask, AskAnswer a);

  /// A message to send after an answer nothing was written for — IMPLEMENT
  /// on a Codex plan card.
  String? followUp(Ask ask, AskAnswer a);

  String? interrupt(String requestId);
  String? setMode(String requestId, String mode);
  String? setModel(String requestId, String model);

  /// The request that compacts, or null when `/compact` goes as a message.
  String? compact();

  /// The request that empties the context, or null when `/clear` goes as
  /// a message.
  String? clear(EngineStart s);

  /// The models the engine reported, for the dial; empty until it has.
  List<String> get models;

  /// MCP server → status, as the engine reported.
  Map<String, String> get mcp;

  /// Whether `/<name>` is a command this engine can run here — null when
  /// the engine cannot tell yet.
  bool? knowsCommand(String name);
}

/// Claude Code over `claude -p --input-format stream-json …` — the pure
/// functions of `kit/lib/src/bridge.dart`, behind the interface.
class ClaudeEngine extends Engine {
  ClaudeEngine({Future<String?> Function()? findBinary, Future<String?> Function(String bin)? versionOf, bool Function(String sessionId)? transcriptExists, List<String>? Function(String sessionId)? readTranscript})
      : _findBinary = findBinary ?? ClaudeCli.findBinary,
        _versionOf = versionOf ?? ClaudeCli.versionOf,
        _transcriptExists = transcriptExists ?? ((_) => true),
        _readTranscript = readTranscript ?? ((_) => null);

  final Future<String?> Function() _findBinary;
  final Future<String?> Function(String bin) _versionOf;
  final bool Function(String sessionId) _transcriptExists;
  final List<String>? Function(String sessionId) _readTranscript;

  @override
  String get id => 'claude';
  @override
  String get provenOn => bridgeProvenOn;
  @override
  bool get readyOnInit => false;
  @override
  bool get namesSession => false;
  @override
  bool get restartsOnEffort => true;
  @override
  bool get hasChrome => true;
  @override
  bool get switchesByRequest => true;
  @override
  Future<String?> findBinary() => _findBinary();
  @override
  Future<String?> versionOf(String bin) => _versionOf(bin);
  @override
  String get whereLooked => 'your shell PATH, ~/.local/bin, /opt/homebrew/bin';
  @override
  bool canResume(String sessionId) => _transcriptExists(sessionId);
  @override
  List<String>? readTranscript(String sessionId) => _readTranscript(sessionId);
  @override
  List<String> args(EngineStart s) => bridgeArgs(sessionId: s.sessionId ?? '', resume: s.resume, model: s.model, effort: s.effort, permissionMode: s.mode, chrome: s.chrome, appendSystemPrompt: s.brief);
  @override
  Future<List<String>> opening(EngineStart s) async => const [];
  @override
  List<BridgeEvent>? feed(String line) {
    final e = parseBridgeLine(line);
    return e == null ? null : [e];
  }

  @override
  List<String> drain() => const [];
  @override
  List<DeckMessage> takeRestored() => const [];
  @override
  String? userMessage(String prompt, {List<InlineImage> images = const [], List<String> imagePaths = const [], required EngineTurn turn}) => encodeUserMessage(prompt, images: images);
  @override
  String? answer(Ask ask, AskAnswer a) => encodeControlResponse(ask.requestId, a.response);
  @override
  String? followUp(Ask ask, AskAnswer a) => null;
  @override
  String? interrupt(String requestId) => encodeInterrupt(requestId);
  @override
  String? setMode(String requestId, String mode) => encodeSetPermissionMode(requestId, mode);
  @override
  String? setModel(String requestId, String model) => encodeSetModel(requestId, model);
  @override
  String? compact() => null;
  @override
  String? clear(EngineStart s) => null;
  @override
  List<String> get models => const [];
  @override
  Map<String, String> get mcp => const {};
  @override
  bool? knowsCommand(String name) => null;
}
