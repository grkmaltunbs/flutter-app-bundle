/// The bridge protocol — how the host talks to `claude -p` over stdio, and
/// the transcript both the host window and the phone render.
///
/// `claude -p --input-format stream-json --output-format stream-json
/// --permission-prompt-tool stdio` reads one JSON object per line on stdin
/// and writes one per line on stdout. A permission prompt or an
/// `AskUserQuestion` arrives as a `control_request`, and the session waits
/// on it until a `control_response` goes back — so an ask that nobody
/// answers is a session that hangs. This is the protocol Anthropic's Agent
/// SDK speaks to the CLI; it is not a documented CLI contract. Captured on
/// Claude Code [bridgeProvenOn], 2026-08-30 — the table in app/DESIGN.md.
///
/// Pure Dart: no dart:io. The host feeds process lines in; the phone
/// rebuilds the same [Transcript] from the relay.
library;

import 'dart:convert';

import 'snapshot.dart' show stableJson;

/// The Claude Code version the shapes below were captured on. The host
/// shows the version it actually started beside this one.
const bridgeProvenOn = '2.1.251';

/// The command line the host starts. `--session-id` names a fresh session;
/// `resume: true` reattaches to [sessionId] instead. `--verbose` is not a
/// choice: without it the CLI refuses `--output-format stream-json`.
///
/// [permissionMode] is one of [modeChoices]. `bypassPermissions` is
/// `--dangerously-skip-permissions` by another name: no `can_use_tool` for
/// permissions — but an `AskUserQuestion` still arrives on stdio (proven
/// 2026-09-03, 2.1.258). `plan` lets the session read and think; its plan
/// file under ~/.claude/plans is written without asking, and the plan
/// arrives as an `ExitPlanMode` ask (proven 2026-09-04, 2.1.260).
/// [chrome] adds the Claude in Chrome tools, which reach the Mac's own
/// browser through the extension; the `init` event then lists
/// `claude-in-chrome` among [InitEvent.mcpServers] (proven the same day).
/// The model dial: the CLI's aliases for the latest of each, and `default`
/// for whatever the CLI would pick on its own.
const modelChoices = ['default', 'haiku', 'sonnet', 'opus', 'fable'];

/// The effort dial: `--effort`'s levels, and `default` for the CLI's own.
const effortChoices = ['default', 'low', 'medium', 'high', 'xhigh', 'max'];

/// The mode dial: the CLI's `--permission-mode` values. `bypassPermissions`
/// is what the Skip permissions switch did before the dial absorbed it.
const modeChoices = ['default', 'plan', 'acceptEdits', 'bypassPermissions'];

/// A mode as the dial reads it: `accept edits`, `bypass`.
String modeLabel(String mode) => switch (mode) {
      'acceptEdits' => 'accept edits',
      'bypassPermissions' => 'bypass',
      _ => mode,
    };

/// A mode the dial knows, or `default` for anything else — an old record,
/// a word the relay carried that this build does not have.
String knownMode(Object? v) {
  final s = v?.toString().trim() ?? '';
  return modeChoices.contains(s) ? s : 'default';
}

/// The stdin line that switches a running session's mode in place. The CLI
/// answers with a `control_response` carrying `{mode}`, then a
/// `system/status` and a fresh `init` that name it (proven 2026-09-04,
/// 2.1.260) — no restart, nothing in the conversation lost.
String encodeSetPermissionMode(String requestId, String mode) => jsonEncode({
      'type': 'control_request',
      'request_id': requestId,
      'request': {'subtype': 'set_permission_mode', 'mode': mode},
    });

List<String> bridgeArgs({required String sessionId, bool resume = false, String? model, String? effort, String permissionMode = 'default', bool chrome = false, String? appendSystemPrompt}) => [
      '-p',
      '--verbose',
      '--input-format', 'stream-json',
      '--output-format', 'stream-json',
      '--include-partial-messages',
      '--replay-user-messages',
      '--permission-prompt-tool', 'stdio',
      '--permission-mode', permissionMode,
      if (chrome) '--chrome',
      if (appendSystemPrompt != null) ...['--append-system-prompt', appendSystemPrompt],
      resume ? '--resume' : '--session-id', sessionId,
      if (model != null) ...['--model', model],
      if (effort != null) ...['--effort', effort],
    ];

/// What every session the app starts is told, on top of Claude Code's own
/// system prompt (`--append-system-prompt`, honoured in stream mode —
/// proven 2026-09-03). The user reads on a phone; the browser, when it is
/// there, is the Mac's own signed-in Chrome; a sign-in is the user's to do,
/// over remote desktop, so it is asked for as a question; and what a store
/// cannot undo is asked about first.
/// The one option a sign-in question carries — the brief asks for it by
/// this exact label, and [Ask.isSignIn] recognises it, so a sign-in takes
/// its own road to the phone (its own notification text).
const signedInOption = 'Signed in — continue';

String deckBrief({required bool chrome, required String mode}) => [
      'You are driven from K.A.T.Y.A, a phone app that talks to this Claude Code session on the user\'s Mac. The user reads you on a phone screen: answer short and concrete, and lead with the result.',
      '',
      if (chrome)
        'Browser: this session has the Claude in Chrome tools. The browser is the Mac\'s own Chrome, already signed in as the user — use it for anything that needs a website (App Store Connect, Google Play Console, RevenueCat, documentation). Downloads land in ~/Downloads on the Mac; a file the user attached is saved under ~/.flutter_kit/attachments/ and its path is in the message; file_upload takes a Mac path.'
      else
        'Browser: this session has no browser tools. If a task needs a website, say so in one line — the user can turn on Drive Chrome under Start and start the session again.',
      '',
      'When a site wants a sign-in, a second factor, a captcha, or a payment confirmation: stop and ask with the AskUserQuestion tool — one question naming the site and the tab, with the single option "$signedInOption". The user reaches the Mac over remote desktop, signs in there, and answers; then look at the page again. Never type or guess a password, and never work around a sign-in.',
      '',
      'Before anything a store cannot undo — submitting for review, publishing a release, changing a price or an in-app product, deleting anything — ask with AskUserQuestion first, in one line.',
      '',
      if (mode == 'bypassPermissions')
        'Permissions: every command runs without asking. Be deliberate with anything destructive.'
      else if (mode == 'plan')
        'Permissions: this session starts in plan mode. Read and think; when the plan is ready call ExitPlanMode — the user reads the plan on the phone and approves it there, or sends back what to change. After approval a command may wait for the user to allow it on the phone; that is expected.'
      else
        'Permissions: a command may wait for the user to allow it on the phone; that is expected.',
      '',
      '',
      'Notifications: the app tells the user itself when you ask something, when a turn ends, and when something fails. To tell the user something at a point mid-task — a build uploaded, tests green before a long release step — run `kit notify "one line"` in this folder; it reaches the phone as a notification. Use it when the user asked to be told, not for every step. The PushNotification tool has no route from this session — do not use it, and do not offer to.',
      '',
      'If you hand work to a subagent that will use the browser, put these rules in its prompt.',
    ].join('\n');

/// A tool's name as a row shows it: `Bash` stays `Bash`; an MCP tool —
/// `mcp__claude-in-chrome__find` — becomes `chrome · find`.
String toolLabel(String name) {
  if (!name.startsWith('mcp__')) return name;
  final parts = name.split('__');
  if (parts.length < 3) return name;
  var server = parts[1];
  if (server == 'claude-in-chrome') server = 'chrome';
  if (server.startsWith('plugin_')) server = server.substring(7);
  return '$server · ${parts.sublist(2).join('__')}';
}

/// An image the model sees inline: the file's base64, as the API takes it.
class InlineImage {
  const InlineImage({required this.mediaType, required this.data});
  final String mediaType;
  final String data;
}

/// The user message line. With [images] the content becomes the API's
/// block list — the images first, then the text — which is what the
/// terminal sends for a pasted screenshot. Proven on Claude Code 2.1.258,
/// 2026-09-02: a red square went in, "red" came back.
String encodeUserMessage(String text, {List<InlineImage> images = const []}) => jsonEncode({
      'type': 'user',
      'message': {
        'role': 'user',
        'content': images.isEmpty
            ? text
            : [
                for (final i in images)
                  {
                    'type': 'image',
                    'source': {'type': 'base64', 'media_type': i.mediaType, 'data': i.data},
                  },
                {'type': 'text', 'text': text},
              ],
      },
    });

/// A file that travelled with a message: what it is called, what it is,
/// how big — and, once the host saved it, where it sits on the Mac.
class DeckAttachment {
  const DeckAttachment({required this.name, required this.mime, required this.size, this.path});

  factory DeckAttachment.fromMap(Map<String, Object?> m) => DeckAttachment(
        name: (m['name'] ?? '').toString(),
        mime: (m['mime'] ?? 'application/octet-stream').toString(),
        size: (m['size'] as num?)?.toInt() ?? 0,
        path: m['path']?.toString(),
      );

  final String name;
  final String mime;
  final int size;
  final String? path;

  bool get isImage => mime.startsWith('image/');

  Map<String, Object?> toMap() => {'name': name, 'mime': mime, 'size': size, if (path != null) 'path': path};
}

/// What the model reads when files travel with a message: the text, then
/// where each file sits on the Mac so the Read tool can open it. An image
/// the message already shows inline (its index in [inline]) says so. No
/// text at all becomes "See the attached file."
String attachmentsPrompt(String text, List<DeckAttachment> files, {Set<int> inline = const {}}) {
  if (files.isEmpty) return text;
  final head = text.trim().isEmpty ? 'See the attached file${files.length == 1 ? '' : 's'}.' : text;
  return [
    head,
    '',
    '--- attached (saved on the Mac; open one with the Read tool when you need it) ---',
    for (var i = 0; i < files.length; i++)
      '- ${files[i].name} — ${files[i].mime}, ${formatBytes(files[i].size)}${files[i].path == null ? '' : ' — ${files[i].path}'}${inline.contains(i) ? ' (shown above)' : ''}',
    '--- end ---',
  ].join('\n');
}

/// `412 KB`, `1.3 MB` — what a chip says about a file.
String formatBytes(int n) {
  if (n < 1024) return '$n B';
  if (n < 1024 * 1024) return '${(n / 1024).round()} KB';
  return '${(n / (1024 * 1024)).toStringAsFixed(1)} MB';
}

String encodeControlResponse(String requestId, Map<String, Object?> response) => jsonEncode({
      'type': 'control_response',
      'response': {'subtype': 'success', 'request_id': requestId, 'response': response},
    });

// ---------------------------------------------------------------- asks

/// One option of one question in an `AskUserQuestion`.
class AskOption {
  const AskOption({required this.label, this.description = '', this.preview});
  final String label;
  final String description;

  /// Markdown the terminal shows in a monospace box beside the option — a
  /// mockup, a snippet, a layout to compare. Null when the option has none.
  final String? preview;
  Map<String, Object?> toMap() => {'label': label, 'description': description, if (preview != null) 'preview': preview};
}

class AskQuestion {
  const AskQuestion({required this.question, required this.header, required this.options, this.multiSelect = false});

  factory AskQuestion.fromMap(Map<String, Object?> m) => AskQuestion(
        question: (m['question'] ?? '').toString(),
        header: (m['header'] ?? '').toString(),
        multiSelect: m['multiSelect'] == true,
        options: [
          for (final o in (m['options'] as List? ?? const []))
            if (o is Map) AskOption(label: (o['label'] ?? '').toString(), description: (o['description'] ?? '').toString(), preview: _text(o['preview'])),
        ],
      );

  final String question;
  final String header;
  final List<AskOption> options;
  final bool multiSelect;
}

/// A `control_request` of subtype `can_use_tool`: a permission prompt, or
/// an `AskUserQuestion` (which Claude Code routes through the same channel).
class Ask {
  Ask({
    required this.requestId,
    required this.toolName,
    required this.toolUseId,
    required this.input,
    required this.at,
    this.description,
    this.displayName,
    this.blockedPath,
    this.suggestions = const [],
    this.requiresUserInteraction = false,
  });

  factory Ask.fromMap(Map<String, Object?> m) => Ask(
        requestId: (m['requestId'] ?? '').toString(),
        toolName: (m['toolName'] ?? '').toString(),
        toolUseId: (m['toolUseId'] ?? '').toString(),
        input: _map(m['input']),
        at: DateTime.tryParse((m['at'] ?? '').toString()) ?? DateTime.fromMillisecondsSinceEpoch(0),
        description: m['description']?.toString(),
        displayName: m['displayName']?.toString(),
        blockedPath: m['blockedPath']?.toString(),
        suggestions: [for (final s in (m['suggestions'] as List? ?? const [])) if (s is Map) _map(s)],
        requiresUserInteraction: m['requiresUserInteraction'] == true,
      );

  final String requestId;
  final String toolName;
  final String toolUseId;
  final Map<String, Object?> input;
  final DateTime at;
  final String? description;
  final String? displayName;
  final String? blockedPath;

  /// The CLI's `permission_suggestions`: rules that, written to
  /// `.claude/settings.json`, would stop this request from asking again.
  final List<Map<String, Object?>> suggestions;
  final bool requiresUserInteraction;

  bool get isQuestion => toolName == 'AskUserQuestion';

  /// An `ExitPlanMode`: the session finished planning and waits for the
  /// plan to be approved. [plan] is the markdown it wrote — `input.plan`,
  /// beside `planFilePath` (proven 2026-09-04, 2.1.260).
  bool get isPlan => toolName == 'ExitPlanMode';
  String get plan => (input['plan'] ?? '').toString();

  /// The plan's first line, without its heading marks — what a
  /// notification and a folded card say.
  String get planTitle {
    for (final line in plan.split('\n')) {
      final t = line.replaceFirst(RegExp(r'^\s*#+\s*'), '').trim();
      if (t.isNotEmpty) return t;
    }
    return '';
  }

  /// A question the brief shaped: one option, [signedInOption] — the
  /// session is parked on a website until the user signs in on the Mac.
  bool get isSignIn => isQuestion && questions.any((q) => q.options.length == 1 && q.options.single.label.trim().toLowerCase() == signedInOption.toLowerCase());

  /// What "this session" remembers: the tool and its exact input. A second
  /// request with the same key is the same request.
  String get key => '$toolName ${stableJson(input)}';

  List<AskQuestion> get questions => [
        for (final q in (input['questions'] as List? ?? const []))
          if (q is Map) AskQuestion.fromMap(_map(q)),
      ];

  /// What the card shows in one line: the command for Bash, the question
  /// for a question, the tool and its input otherwise.
  String get summary {
    if (isQuestion) return questions.map((q) => q.question).join(' · ');
    if (isPlan) return planTitle.isEmpty ? 'A plan is ready' : planTitle;
    if (toolName == 'Bash') return (input['command'] ?? '').toString();
    final path = input['file_path'] ?? input['path'] ?? input['pattern'] ?? input['url'];
    final name = toolLabel(toolName);
    return path != null ? '$name $path' : '$name ${_clip(jsonEncode(input), 120)}';
  }

  Map<String, Object?> toMap() => {
        'requestId': requestId,
        'toolName': toolName,
        'toolUseId': toolUseId,
        'input': input,
        'at': at.toUtc().toIso8601String(),
        if (description != null) 'description': description,
        if (displayName != null) 'displayName': displayName,
        if (blockedPath != null) 'blockedPath': blockedPath,
        'suggestions': suggestions,
        'requiresUserInteraction': requiresUserInteraction,
      };
}

/// What a session wants a person for, as a notification says it.
enum NoticeKind {
  /// A tool waits on Allow.
  permission,

  /// An `AskUserQuestion`.
  question,

  /// A question with the single option [signedInOption].
  signIn,

  /// An `ExitPlanMode`: a plan waits to be approved.
  plan,

  /// The session failed, or a turn ended in an error.
  problem,

  /// A turn ended well — the reply is on the phone.
  done,

  /// A line Claude sent on purpose, with `kit notify`.
  note,

  /// A step of the plan flipped to done — the constellation moved while
  /// the user was away.
  step,
}

/// One button on an ask's notification: [id] comes back as the action the
/// phone tapped, [label] is what it reads.
class NoticeAction {
  const NoticeAction(this.id, this.label);
  final String id;
  final String label;
}

/// Android shows three buttons at most, and a label longer than this wraps
/// to nothing useful on a lock screen.
const maxNoticeActions = 3;
const maxNoticeLabel = 24;

/// The one-tap answers an ask allows from the lock screen: Allow / Deny for
/// a permission; the single option of a sign-in; the options of a single
/// pick-one question when they are few and short. Anything else — several
/// questions, a multi-select, long labels — has no button: the tap opens
/// the card.
List<NoticeAction> noticeActions(Ask ask) {
  if (ask.isPlan) return const [NoticeAction('allow', 'Approve')];
  if (!ask.isQuestion) return const [NoticeAction('allow', 'Allow'), NoticeAction('deny', 'Deny')];
  final qs = ask.questions;
  if (qs.length != 1) return const [];
  final q = qs.single;
  if (q.multiSelect || q.options.isEmpty || q.options.length > maxNoticeActions) return const [];
  if (q.options.any((o) => o.label.trim().isEmpty || o.label.trim().length > maxNoticeLabel)) return const [];
  return [for (var i = 0; i < q.options.length; i++) NoticeAction('option:$i', q.options[i].label.trim())];
}

/// The answer a notification button stands for, or null when [actionId]
/// names nothing this ask offers — a stale button, or a tap on the body.
/// [here] is where the user was, for the deny message the model reads.
AskAnswer? answerForAction(Ask ask, String actionId, {String here = 'notification'}) {
  // Revise needs words; the lock screen has one button, Approve.
  if (ask.isPlan) return actionId == 'allow' ? AskAnswer.approvePlan(ask) : null;
  if (!ask.isQuestion) {
    return switch (actionId) {
      'allow' => AskAnswer.allow(ask),
      'deny' => AskAnswer.deny('The user declined from the $here.'),
      _ => null,
    };
  }
  if (!noticeActions(ask).any((a) => a.id == actionId)) return null;
  final i = int.tryParse(actionId.substring('option:'.length));
  final q = ask.questions.single;
  if (i == null || i < 0 || i >= q.options.length) return null;
  return AskAnswer.answers(ask, {q.question: q.options[i].label});
}

/// One notification: what to show, and what it is about, so a tap opens
/// the right project and a repeat of the same thing replaces the last.
class Notice {
  const Notice({required this.kind, required this.title, required this.body, this.requestId, this.actions = const []});

  final NoticeKind kind;
  final String title;
  final String body;

  /// The ask this is about — null for a problem.
  final String? requestId;

  /// The buttons a lock-screen notification offers for an ask — see
  /// [noticeActions]; empty for anything that is not an ask.
  final List<NoticeAction> actions;

  /// The Android channel — `asks`, `problems`, `done`, `steps` — one the user can
  /// silence without the others. Each kind keeps one notification a
  /// project: the newest ask replaces the last (only one is ever
  /// pending), a repeated problem does not stack.
  String get channel => switch (kind) {
        NoticeKind.problem => 'problems',
        NoticeKind.done || NoticeKind.note => 'done',
        NoticeKind.step => 'steps',
        NoticeKind.permission || NoticeKind.question || NoticeKind.signIn || NoticeKind.plan => 'asks',
      };

  bool get isAsk => channel == 'asks';

  Map<String, String> data(String slug) => {'slug': slug, 'kind': kind.name, if (requestId != null) 'requestId': requestId!};
}

/// The notification for an ask: the project in the title, the thing to
/// decide in the body, clipped for a lock screen.
Notice noticeForAsk(Ask ask, {required String project}) {
  if (ask.isPlan) {
    return Notice(kind: NoticeKind.plan, title: 'Plan ready · $project', body: _clip(ask.summary, 240), requestId: ask.requestId, actions: noticeActions(ask));
  }
  if (ask.isSignIn) {
    return Notice(kind: NoticeKind.signIn, title: 'Sign in needed · $project', body: _clip(ask.questions.map((q) => q.question).join(' · '), 240), requestId: ask.requestId, actions: noticeActions(ask));
  }
  if (ask.isQuestion) {
    return Notice(kind: NoticeKind.question, title: 'Claude asks · $project', body: _clip(ask.summary, 240), requestId: ask.requestId, actions: noticeActions(ask));
  }
  final what = ask.toolName == 'Bash' ? 'Run' : toolLabel(ask.toolName);
  return Notice(kind: NoticeKind.permission, title: 'Allow $what? · $project', body: _clip(ask.summary, 240), requestId: ask.requestId, actions: noticeActions(ask));
}

/// The notification for a step that flipped to done on disk — once, when
/// the mirror sees the change, on a channel of its own.
Notice noticeForStep({required String number, required String title, required String project}) =>
    Notice(kind: NoticeKind.step, title: 'Step $number done · $project', body: _clip(title.trim(), 240));

/// The notification for a problem: the session died, or a turn ended in
/// an error the user would otherwise find hours later.
Notice noticeForProblem(String error, {required String project}) => Notice(kind: NoticeKind.problem, title: 'Problem · $project', body: _clip(error.trim(), 240));

/// The notification for a turn that ended well: how long it took when
/// that is worth saying, and the start of the reply.
Notice noticeForDone(ResultEvent r, {required String project}) {
  final secs = r.durationMs ~/ 1000;
  final took = secs < 60 ? '' : ' in ${secs ~/ 60}m ${(secs % 60).toString().padLeft(2, '0')}s';
  return Notice(kind: NoticeKind.done, title: 'Done$took · $project', body: _clip(r.text.trim().isEmpty ? 'The turn ended.' : r.text.trim(), 240));
}

/// The notification for a line Claude sent with `kit notify`.
Notice noticeForNote(String text, {required String project}) => Notice(kind: NoticeKind.note, title: 'Claude · $project', body: _clip(text.trim(), 240));

/// The user's answer to an [Ask], as the `response` of a control_response.
class AskAnswer {
  const AskAnswer._(this.response, this.summary, this.allowed);

  /// Let the tool run with its input as proposed.
  factory AskAnswer.allow(Ask ask) => AskAnswer._({'behavior': 'allow', 'updatedInput': ask.input}, 'Allowed', true);

  /// Allow, and hand the CLI its own `permission_suggestions` back as
  /// `updatedPermissions` — it writes the rule to the settings file it
  /// named, exactly as "Yes, and don't ask again" does in the terminal.
  factory AskAnswer.always(Ask ask) =>
      AskAnswer._({'behavior': 'allow', 'updatedInput': ask.input, 'updatedPermissions': ask.suggestions}, 'Allowed, always', true);

  /// Refuse; [message] is what the model reads as the tool result.
  factory AskAnswer.deny(String message) => AskAnswer._({'behavior': 'deny', 'message': message}, 'Denied', false);

  /// Answer an `AskUserQuestion`: question text → chosen label(s). Several
  /// labels for a multi-select question are joined with ", ".
  factory AskAnswer.answers(Ask ask, Map<String, String> answers) =>
      AskAnswer._({'behavior': 'allow', 'updatedInput': {...ask.input, 'answers': answers}}, answers.values.join(' · '), true);

  /// Approve a plan and leave plan mode. [mode] is what the session runs
  /// in from here — `default` (edits ask) or `acceptEdits` — carried as a
  /// `setMode` update the CLI applies to the session at once, with no
  /// event to say so; an allow without one lands on `default` too (proven
  /// 2026-09-04, 2.1.260).
  factory AskAnswer.approvePlan(Ask ask, {String mode = 'default'}) => AskAnswer._(
        {
          'behavior': 'allow',
          'updatedInput': ask.input,
          'updatedPermissions': [
            {'type': 'setMode', 'mode': mode, 'destination': 'session'},
          ],
        },
        mode == 'acceptEdits' ? 'Approved — edits run without asking' : 'Approved',
        true,
      );

  /// Send a plan back with what to change. The session stays in plan
  /// mode, reads [message] as the tool result, and plans again.
  factory AskAnswer.revisePlan(String message) => AskAnswer._(
        {'behavior': 'deny', 'message': 'The user asks for changes to the plan: ${message.trim()}\nRevise the plan and call ExitPlanMode again.'},
        'Revise: ${_clip(message.trim(), 80)}',
        false,
      );

  /// An answer that travelled through the relay.
  factory AskAnswer.fromMap(Map<String, Object?> m) => AskAnswer._(_map(m['response']), (m['summary'] ?? '').toString(), m['allowed'] == true);

  final Map<String, Object?> response;
  final String summary;
  final bool allowed;

  /// Rules the CLI writes to a settings file — an Always answer. A
  /// `setMode` update is not one: it changes the session, not a file.
  bool get appliesAlways => _updates.any((u) => u['type'] != 'setMode');

  /// The mode a `setMode` update in this answer switches the session to —
  /// a plan approved, or "allow all edits" on an edit — or null.
  String? get modeAfter {
    for (final u in _updates) {
      if (u['type'] == 'setMode' && u['destination'] == 'session') return u['mode']?.toString();
    }
    return null;
  }

  List<Map<String, Object?>> get _updates => [for (final u in (response['updatedPermissions'] as List? ?? const [])) if (u is Map) _map(u)];

  Map<String, Object?> toMap() => {'response': response, 'summary': summary, 'allowed': allowed};
}

// -------------------------------------------------------------- events

sealed class BridgeEvent {
  const BridgeEvent();
}

/// `system` / `init` — the session exists.
class InitEvent extends BridgeEvent {
  const InitEvent({required this.sessionId, this.model, this.permissionMode, this.cwd, this.tools = const [], this.mcpServers = const {}});
  final String sessionId;
  final String? model;
  final String? permissionMode;
  final String? cwd;
  final List<String> tools;

  /// MCP server name → status (`connected`, `pending`, `failed`,
  /// `needs-auth`); `claude-in-chrome` is the browser.
  final Map<String, String> mcpServers;
}

/// A piece of the assistant's text, as it is written.
/// `system` / `status` — the CLI's mode changed (a `set_permission_mode`
/// honoured); a fresh `init` follows it.
class StatusEvent extends BridgeEvent {
  const StatusEvent({this.permissionMode});
  final String? permissionMode;
}

/// `control_response` — the CLI's answer to a control request the host
/// sent (`set_permission_mode`, `interrupt`): success with a body, or an
/// error.
class ControlResponseEvent extends BridgeEvent {
  const ControlResponseEvent({required this.requestId, required this.ok, this.response = const {}, this.error});
  final String requestId;
  final bool ok;
  final Map<String, Object?> response;
  final String? error;
}

class TextDeltaEvent extends BridgeEvent {
  const TextDeltaEvent(this.text);
  final String text;
}

/// A finished content block of the assistant's message.
class ContentBlock {
  const ContentBlock.text(this.text)
      : toolUseId = null,
        toolName = null,
        toolInput = null;
  const ContentBlock.toolUse({required this.toolUseId, required this.toolName, required this.toolInput}) : text = null;
  final String? text;
  final String? toolUseId;
  final String? toolName;
  final Map<String, Object?>? toolInput;
  bool get isToolUse => toolUseId != null;
}

class AssistantEvent extends BridgeEvent {
  const AssistantEvent(this.blocks);
  final List<ContentBlock> blocks;
}

/// The result of a tool call, as the model sees it.
class ToolResultEvent extends BridgeEvent {
  const ToolResultEvent({required this.toolUseId, required this.content, this.isError = false});
  final String toolUseId;
  final String content;
  final bool isError;
}

/// `--replay-user-messages`: our own message, acknowledged.
class UserEchoEvent extends BridgeEvent {
  const UserEchoEvent(this.text);
  final String text;
}

class AskEvent extends BridgeEvent {
  const AskEvent(this.ask);
  final Ask ask;
}

/// The turn ended.
class ResultEvent extends BridgeEvent {
  const ResultEvent({required this.subtype, required this.sessionId, this.stopReason, this.numTurns = 0, this.durationMs = 0, this.isError = false, this.text = ''});
  final String subtype;
  final String sessionId;
  final String? stopReason;
  final int numTurns;
  final int durationMs;
  final bool isError;
  final String text;
}

/// The subscription's pool, as the CLI reports it.
class RateLimitEvent extends BridgeEvent {
  const RateLimitEvent({required this.status, this.rateLimitType, this.resetsAt, this.overageStatus});
  final String status;
  final String? rateLimitType;
  final DateTime? resetsAt;
  final String? overageStatus;
}

/// Anything else — kept by type so a new shape shows up in the log.
class OtherEvent extends BridgeEvent {
  const OtherEvent(this.type, this.subtype);
  final String type;
  final String? subtype;
}

/// One stdout line → one event, or null for a blank or non-JSON line.
BridgeEvent? parseBridgeLine(String line) {
  final s = line.trim();
  if (s.isEmpty || !s.startsWith('{')) return null;
  final Object? raw;
  try {
    raw = jsonDecode(s);
  } on FormatException {
    return null;
  }
  if (raw is! Map) return null;
  final m = _map(raw);
  final type = (m['type'] ?? '').toString();
  switch (type) {
    case 'system':
      final sub = (m['subtype'] ?? '').toString();
      if (sub == 'init') {
        return InitEvent(
          sessionId: (m['session_id'] ?? '').toString(),
          model: m['model']?.toString(),
          permissionMode: m['permissionMode']?.toString(),
          cwd: m['cwd']?.toString(),
          tools: [for (final t in (m['tools'] as List? ?? const [])) t.toString()],
          mcpServers: {
            for (final srv in (m['mcp_servers'] as List? ?? const []))
              if (srv is Map && srv['name'] != null) srv['name'].toString(): (srv['status'] ?? '').toString(),
          },
        );
      }
      if (sub == 'status') return StatusEvent(permissionMode: m['permissionMode']?.toString());
      return OtherEvent(type, sub);
    case 'control_response':
      final r = _map(m['response']);
      return ControlResponseEvent(requestId: (r['request_id'] ?? '').toString(), ok: r['subtype'] == 'success', response: _map(r['response']), error: r['error']?.toString());
    case 'stream_event':
      final ev = _map(m['event']);
      if (ev['type'] == 'content_block_delta') {
        final d = _map(ev['delta']);
        if (d['type'] == 'text_delta') return TextDeltaEvent((d['text'] ?? '').toString());
      }
      return OtherEvent(type, ev['type']?.toString());
    case 'assistant':
      final msg = _map(m['message']);
      final blocks = <ContentBlock>[];
      for (final c in (msg['content'] as List? ?? const [])) {
        if (c is! Map) continue;
        final cm = _map(c);
        if (cm['type'] == 'text') {
          blocks.add(ContentBlock.text((cm['text'] ?? '').toString()));
        } else if (cm['type'] == 'tool_use') {
          blocks.add(ContentBlock.toolUse(toolUseId: (cm['id'] ?? '').toString(), toolName: (cm['name'] ?? '').toString(), toolInput: _map(cm['input'])));
        }
      }
      return AssistantEvent(blocks);
    case 'user':
      final msg = _map(m['message']);
      final content = msg['content'];
      if (content is String) return UserEchoEvent(content);
      if (content is List) {
        for (final c in content) {
          if (c is Map && c['type'] == 'tool_result') {
            return ToolResultEvent(toolUseId: (c['tool_use_id'] ?? '').toString(), content: _contentText(c['content']), isError: c['is_error'] == true);
          }
        }
        return UserEchoEvent(content.whereType<Map>().map((c) => (c['text'] ?? '').toString()).join());
      }
      return OtherEvent(type, null);
    case 'control_request':
      final req = _map(m['request']);
      if (req['subtype'] != 'can_use_tool') return OtherEvent(type, req['subtype']?.toString());
      return AskEvent(Ask(
        requestId: (m['request_id'] ?? '').toString(),
        toolName: (req['tool_name'] ?? '').toString(),
        toolUseId: (req['tool_use_id'] ?? '').toString(),
        input: _map(req['input']),
        at: DateTime.now(),
        description: req['description']?.toString(),
        displayName: req['display_name']?.toString(),
        blockedPath: req['blocked_path']?.toString(),
        suggestions: [for (final s in (req['permission_suggestions'] as List? ?? const [])) if (s is Map) _map(s)],
        requiresUserInteraction: req['requires_user_interaction'] == true,
      ));
    case 'result':
      return ResultEvent(
        subtype: (m['subtype'] ?? '').toString(),
        sessionId: (m['session_id'] ?? '').toString(),
        stopReason: m['stop_reason']?.toString(),
        numTurns: (m['num_turns'] as num?)?.toInt() ?? 0,
        durationMs: (m['duration_ms'] as num?)?.toInt() ?? 0,
        isError: m['is_error'] == true,
        text: (m['result'] ?? '').toString(),
      );
    case 'rate_limit_event':
      final info = _map(m['rate_limit_info']);
      final resets = (info['resetsAt'] as num?)?.toInt();
      return RateLimitEvent(
        status: (info['status'] ?? '').toString(),
        rateLimitType: info['rateLimitType']?.toString(),
        resetsAt: resets == null ? null : DateTime.fromMillisecondsSinceEpoch(resets * 1000, isUtc: true),
        overageStatus: info['overageStatus']?.toString(),
      );
    default:
      return OtherEvent(type, m['subtype']?.toString());
  }
}

String _contentText(Object? content) {
  if (content is String) return content;
  if (content is List) return content.whereType<Map>().map((c) => (c['text'] ?? '').toString()).join('\n');
  return content?.toString() ?? '';
}

/// The thread a scoped message belongs to: `item:<id>` or `step:<id>`.
/// Null when [about] names neither.
String? threadKey(Map<String, Object?>? about) {
  if (about == null) return null;
  final item = about['item']?.toString();
  if (item != null && item.isNotEmpty) return 'item:$item';
  final step = about['step']?.toString();
  if (step != null && step.isNotEmpty) return 'step:$step';
  return null;
}

// ---------------------------------------------------------- transcript

enum DeckRole { user, assistant, tool, note }

/// One row of the deck. Mutable while it streams or its tool runs.
class DeckMessage {
  DeckMessage({
    required this.id,
    required this.role,
    required this.text,
    required this.at,
    this.toolName,
    this.toolInput,
    this.toolUseId,
    this.toolResult,
    this.isError = false,
    this.streaming = false,
    this.about,
    this.attachments = const [],
  });

  factory DeckMessage.fromMap(Map<String, Object?> m) => DeckMessage(
        id: (m['id'] ?? '').toString(),
        role: DeckRole.values.firstWhere((r) => r.name == m['role'], orElse: () => DeckRole.note),
        text: (m['text'] ?? '').toString(),
        at: DateTime.tryParse((m['at'] ?? '').toString()) ?? DateTime.fromMillisecondsSinceEpoch(0),
        toolName: m['toolName']?.toString(),
        toolInput: m['toolInput'] is Map ? _map(m['toolInput']) : null,
        toolUseId: m['toolUseId']?.toString(),
        toolResult: m['toolResult']?.toString(),
        isError: m['isError'] == true,
        streaming: m['streaming'] == true,
        about: m['about'] is Map ? _map(m['about']) : null,
        attachments: [for (final a in (m['attachments'] as List? ?? const [])) if (a is Map) DeckAttachment.fromMap(_map(a))],
      );

  final String id;
  final DeckRole role;
  String text;
  final DateTime at;
  final String? toolName;
  final Map<String, Object?>? toolInput;
  final String? toolUseId;
  String? toolResult;
  bool isError;
  bool streaming;

  /// `{item: id}` or `{step: id}` when the message is about one thing.
  final Map<String, Object?>? about;

  /// The files that travelled with a user message.
  final List<DeckAttachment> attachments;

  /// One line for a tool row: the command for Bash, the path for a file
  /// tool, the tool and its input otherwise.
  String get toolSummary {
    final input = toolInput ?? const {};
    final name = toolLabel(toolName ?? '');
    if (name == 'Bash') return (input['command'] ?? '').toString();
    final path = input['file_path'] ?? input['path'] ?? input['pattern'] ?? input['query'] ?? input['url'];
    if (path != null) return '$name · $path';
    if (name == 'AskUserQuestion') return 'asked you a question';
    if (name == 'ExitPlanMode') return 'proposed a plan';
    return input.isEmpty ? name : '$name · ${_clip(jsonEncode(input), 100)}';
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'role': role.name,
        'text': text,
        'at': at.toUtc().toIso8601String(),
        if (toolName != null) 'toolName': toolName,
        if (toolInput != null) 'toolInput': toolInput,
        if (toolUseId != null) 'toolUseId': toolUseId,
        if (toolResult != null) 'toolResult': toolResult,
        'isError': isError,
        'streaming': streaming,
        if (about != null) 'about': about,
        if (attachments.isNotEmpty) 'attachments': [for (final a in attachments) a.toMap()],
      };
}

/// The conversation with one session: what was said, what ran, what is
/// being asked. [apply] folds stdout events in; [answer] produces the
/// stdin line for a pending ask. No I/O here.
class Transcript {
  final List<DeckMessage> messages = [];
  Ask? pending;
  String? sessionId;
  String? model;
  String? permissionMode;
  RateLimitEvent? pool;
  ResultEvent? lastResult;

  /// From `init`: MCP server name → status. `claude-in-chrome` says
  /// whether the browser answered.
  Map<String, String> mcpServers = const {};

  /// True between a user message and the `result` that ends the turn.
  bool turnOpen = false;

  /// How many text deltas streamed in — the live test's proof that
  /// `--include-partial-messages` was honoured.
  int deltasSeen = 0;

  DeckMessage? _streaming;
  int _seq = 0;
  DateTime Function() now = DateTime.now;

  /// The scope of the turn now open: everything the session says or runs
  /// until the `result` belongs to the same item or step the user asked
  /// about. Cleared when the turn ends.
  Map<String, Object?>? _about;

  /// The last scope a user message carried — it outlives the turn, so a
  /// plan edit that lands just after the result still finds its thread.
  Map<String, Object?>? lastAbout;

  String _nextId() => 'm${(_seq++).toString().padLeft(5, '0')}';

  DeckMessage addUser(String text, {Map<String, Object?>? about, List<DeckAttachment> attachments = const []}) {
    final m = DeckMessage(id: _nextId(), role: DeckRole.user, text: text, at: now(), about: about, attachments: attachments);
    messages.add(m);
    turnOpen = true;
    _about = about;
    lastAbout = about;
    return m;
  }

  DeckMessage addNote(String text) {
    final m = DeckMessage(id: _nextId(), role: DeckRole.note, text: text, at: now());
    messages.add(m);
    return m;
  }

  void apply(BridgeEvent e) {
    switch (e) {
      case InitEvent():
        sessionId = e.sessionId;
        model = e.model;
        permissionMode = e.permissionMode;
        mcpServers = e.mcpServers;
      case TextDeltaEvent():
        deltasSeen++;
        final s = _streaming ??= _open();
        s.text += e.text;
      case AssistantEvent():
        for (final b in e.blocks) {
          if (b.isToolUse) {
            _closeStreaming();
            messages.add(DeckMessage(id: _nextId(), role: DeckRole.tool, text: '', at: now(), toolName: b.toolName, toolInput: b.toolInput, toolUseId: b.toolUseId, about: _about));
          } else {
            final text = b.text ?? '';
            final s = _streaming;
            if (s != null) {
              // The final block is authoritative; the deltas were its draft.
              s.text = text;
              s.streaming = false;
              _streaming = null;
            } else if (text.isNotEmpty) {
              messages.add(DeckMessage(id: _nextId(), role: DeckRole.assistant, text: text, at: now(), about: _about));
            }
          }
        }
      case ToolResultEvent():
        for (final m in messages.reversed) {
          if (m.role == DeckRole.tool && m.toolUseId == e.toolUseId) {
            m.toolResult = _clip(e.content, 600);
            m.isError = e.isError;
            break;
          }
        }
      case AskEvent():
        _closeStreaming();
        pending = e.ask;
      case ResultEvent():
        _closeStreaming();
        turnOpen = false;
        _about = null;
        lastResult = e;
        if (e.isError && e.text.isNotEmpty) addNote(e.text);
      case RateLimitEvent():
        pool = e;
      case StatusEvent():
        if (e.permissionMode != null) permissionMode = e.permissionMode;
      case ControlResponseEvent():
      case UserEchoEvent():
      case OtherEvent():
        break;
    }
  }

  /// Answers [pending]: records what was decided as a note ([note] replaces
  /// the default wording) and returns the stdin line. Throws [StateError]
  /// when nothing is pending.
  String answer(AskAnswer a, {String? note}) {
    final ask = pending;
    if (ask == null) throw StateError('nothing is pending');
    pending = null;
    addNote(note ?? (ask.isQuestion ? 'Answered: ${a.summary}' : '${a.summary}: ${_clip(ask.summary, 160)}'));
    return encodeControlResponse(ask.requestId, a.response);
  }

  DeckMessage _open() {
    final m = DeckMessage(id: _nextId(), role: DeckRole.assistant, text: '', at: now(), streaming: true, about: _about);
    messages.add(m);
    return m;
  }

  void _closeStreaming() {
    final s = _streaming;
    if (s == null) return;
    s.streaming = false;
    _streaming = null;
    if (s.text.isEmpty) messages.remove(s);
  }
}

Map<String, Object?> _map(Object? v) => v is Map ? {for (final e in v.entries) e.key.toString(): e.value} : <String, Object?>{};

String? _text(Object? v) {
  final s = v?.toString() ?? '';
  return s.trim().isEmpty ? null : s;
}

String _clip(String s, int n) => s.length <= n ? s : '${s.substring(0, n - 1)}…';
