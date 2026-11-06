import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart' hide Step, StepState;
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import '../host/bridge_session.dart';
import '../screens/deck_tab.dart';
import '../theme.dart';
import 'studio_data.dart';
import 'studio_plans.dart';
import 'studio_media.dart';
import 'studio_media_view.dart';
import 'studio_schedule.dart';

/// The orchestrator as a session of this app: K.A.T.Y.A's own Deck (chat,
/// asks, MODEL and EFFORT dials, sessions to resume) on a `claude -p` bridge
/// in the orchestrator's folder, with the autopilot's commands one tap away.
/// One per app, like a project's session: it outlives the Studio screen and
/// stops on a clean quit.
class StudioOrchestrator {
  static BridgeSession? _bridge;
  static String? _dir;
  static ReviewLoop? _loop;

  /// The review loop that rides on the current session.
  static ReviewLoop? get loop => _loop;

  /// Timed orders, sent through the current session.
  static final StudioSchedule schedule = StudioSchedule()..load();

  /// The session for [dir] — made once; a different folder replaces it.
  static BridgeSession get(String dir, {required String autopilotDir}) {
    if (_bridge != null && _dir == dir) return _bridge!;
    final old = _bridge;
    if (old != null) {
      if (old.running) old.stop();
      old.dispose();
    }
    _loop?.dispose();
    _dir = dir;
    final b = _bridge = BridgeSession(dir: dir)..briefExtra = () => orchestratorBrief(autopilotDir: autopilotDir);
    _loop = ReviewLoop(bridge: b, autopilotDir: autopilotDir)..restore();
    schedule
      ..watch(b)
      ..start();
    return b;
  }

  /// A clean quit: the session stopped, within the app's quit budget.
  static Future<void> quit() async {
    _loop?.stopTimer();
    schedule.stop();
    final b = _bridge;
    if (b != null && b.running) await b.stop();
  }
}

/// What every orchestrator session is told about where it runs and how the
/// Studio talks to it (appended to the Deck's own brief).
String orchestratorBrief({required String autopilotDir}) => '''
You are the orchestrator and reviewer of the Sivas game autopilot, driven from K.A.T.Y.A's Studio on the Mac and the phone.
The autopilot folder is $autopilotDir (its README.md describes the lanes, mail, review files and the /autopilot-* commands).
The Studio shows the lanes as step tracks and sends you orders about one step as a message that starts with "[Studio · lane <x> · <step id>]".
For an order that changes a lane's plan (add, edit, remove, reorder or link a step), use the autopilot's own means — a /autopilot-tell note or mail to the lane, or an edit of the lane's step list committed on the lane's branch when the lane is not mid-step on that list — and say in one line what you changed and where.
A step may carry a dependency tag in its line, `after: <lane>/<STEP-ID>` (comma-separated for several); keep the tags you are given exactly as written.
The review loop is run by K.A.T.Y.A, not by a cron job in this session: while review/mode is present or afk and the Studio's loop is on, it sends /autopilot-review every 20 minutes when you are idle. When /autopilot-watch or /autopilot-afk says to make sure the loop exists, do not create a cron job or call the loop skill for /autopilot-review — say the Studio runs it. For a timed task (once, or every day / weekdays at a time — e.g. pause lane C before the user's play session, continue it after), do not create a cron job: end your reply with this block and the Studio sends the `send:` line to you at that time, starting or resuming this session when needed (the user sees it in the schedule and can cancel it):
```studio-timer
at: YYYY-MM-DD HH:MM   (local time)
repeat: once | daily | weekdays
send: the command or message to receive then, e.g. /wait-at-the-next-stop c
note: why, in a few words
```''';

/// What the bar's REVIEW LOOP switch needs — the Mac's loop, or the phone's
/// view of it.
abstract class LoopApi implements Listenable {
  bool get on;
  String get why;
  void set(bool value);
}

/// The reviewer's 20-minute pass, run by the app instead of a cron job in
/// the session (a `claude -p` bridge has no session cron). Each minute it
/// looks: the loop is on, `review/mode` is present or afk, the last review
/// (`review/last-review`) is at least [period] old, and the orchestrator is
/// between turns — then it sends `/autopilot-review`. It never starts a
/// session on its own, so a second reviewer cannot appear behind the
/// person's back.
class ReviewLoop extends ChangeNotifier implements LoopApi {
  ReviewLoop({required this.bridge, required this.autopilotDir, this.period = const Duration(minutes: 20), DateTime Function()? now}) : _now = now ?? DateTime.now;

  final BridgeSession bridge;
  final String autopilotDir;
  final Duration period;
  final DateTime Function() _now;

  static const _prefKey = 'studio.reviewLoop';

  @override
  bool on = false;
  DateTime? lastSent;
  Timer? _timer;

  /// Why it did not send at the last look, for the bar's tooltip.
  @override
  String why = 'off';

  Future<void> restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_prefKey) == true) set(true, persist: false);
    } catch (_) {}
  }

  @override
  void set(bool value, {bool persist = true}) {
    on = value;
    if (on) {
      _timer ??= Timer.periodic(const Duration(minutes: 1), (_) => tick());
      tick();
    } else {
      stopTimer();
      why = 'off';
    }
    if (persist) SharedPreferences.getInstance().then((p) => p.setBool(_prefKey, value)).catchError((Object _) => false);
    notifyListeners();
  }

  void stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  String _read(String rel) {
    final f = File(p.join(autopilotDir, rel));
    return f.existsSync() ? f.readAsStringSync().trim() : '';
  }

  /// The mode the reviewer last wrote: present, afk or off.
  String get mode => _read(p.join('review', 'mode'));

  DateTime? get lastReview => parseStamp(_read(p.join('review', 'last-review')));

  /// When the next pass is due, from the newer of the reviewer's own stamp
  /// and the last send.
  DateTime? get nextDue {
    final last = [lastReview, lastSent].whereType<DateTime>().fold<DateTime?>(null, (a, b) => a == null || b.isAfter(a) ? b : a);
    return last?.add(period);
  }

  /// One look. Returns true when it sent.
  bool tick() {
    if (!on) return false;
    final m = mode;
    if (m != 'present' && m != 'afk' && m != 'watch') {
      why = 'review/mode is ${m.isEmpty ? 'not set' : m} — tap WATCH or AWAY';
      notifyListeners();
      return false;
    }
    final due = nextDue;
    if (due != null && _now().isBefore(due)) {
      why = 'next pass at ${_two(due.hour)}:${_two(due.minute)}';
      notifyListeners();
      return false;
    }
    if (!bridge.running) {
      why = 'the orchestrator is not running — Start it on the Deck';
      notifyListeners();
      return false;
    }
    if (bridge.state != BridgeState.ready) {
      why = 'waiting for the current turn to end';
      notifyListeners();
      return false;
    }
    bridge.send('/autopilot-review');
    lastSent = _now();
    why = 'sent /autopilot-review';
    notifyListeners();
    return true;
  }

  @override
  void dispose() {
    stopTimer();
    super.dispose();
  }
}

String _two(int n) => n.toString().padLeft(2, '0');

/// A message about one lane step, as the Studio sends it.
String stepPrompt({required String lane, required StepItem item, required String text}) => '''
[Studio · lane ${lane.toUpperCase()} · ${item.id}] $text

--- the step as its list holds it${item.section == null ? '' : ' (under "${item.section}")'} ---
${item.done ? '[x]' : '[ ]'} ${item.text.trim()}
--- end ---''';

/// A message about one roadmap item, as the Studio sends it.
String roadmapPrompt({required RoadmapItem item, required String text}) => '''
[Studio · roadmap · ${item.id}] $text

--- the item as production/production-plan.md holds it (${item.milestone}) ---
${item.id} · ${item.task} · size ${item.size ?? '?'} · owner ${item.owner ?? '?'}
Status: ${item.statusText}
${item.summary}
--- end ---''';

/// Asks the person for a question about [subject] and sends what [build]
/// makes of it to the orchestrator; a toast says what came of it.
Future<void> askOrchestrator(BuildContext context, BridgeSession? bridge, {required String subject, required String Function(String text) build}) async {
  final messenger = ScaffoldMessenger.of(context);
  if (bridge == null) {
    messenger.showSnackBar(const SnackBar(content: Text('Set the orchestrator folder under Folders first.')));
    return;
  }
  final ctrl = TextEditingController();
  final text = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Ask about $subject'),
      content: TextField(controller: ctrl, autofocus: true, minLines: 2, maxLines: 6, decoration: const InputDecoration(hintText: 'Why is this next? What does it wait on? …', border: OutlineInputBorder())),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
        FilledButton(onPressed: () => Navigator.pop(context, ctrl.text.trim()), child: const Text('SEND')),
      ],
    ),
  );
  ctrl.dispose();
  if (text == null || text.isEmpty) return;
  final said = await sendToOrchestrator(bridge, build(text));
  messenger.showSnackBar(SnackBar(content: Text('$said — the answer is on the ORCHESTRATOR tab')));
}

/// One autopilot command as a button: what it sends and whether it needs a
/// lane, a note or a number first.
class AutopilotCommand {
  const AutopilotCommand(this.label, this.command, this.what, {this.group = 'Look', this.lane = false, this.allLanes = true, this.note = false, this.number});
  final String label;
  final String command;
  final String what;
  final String group;

  /// Asks for a lane first (`/autopilot-tell a …`).
  final bool lane;

  /// The lane picker offers "all lanes" (sends the command without a lane).
  final bool allLanes;

  /// Asks for a note after the lane.
  final bool note;

  /// Asks for a number, with this default (`/autopilot-approve-meshy 200`).
  final int? number;
}

/// The autopilot README's commands (the user's, in any Claude Code session).
const kAutopilotCommands = [
  AutopilotCommand('STATUS', '/autopilot-status', 'What each lane is doing, ticked steps, latest decisions, flags, Meshy spend'),
  AutopilotCommand('CHECK', '/autopilot-check', 'Which Claude sessions are alive, step sessions labelled by lane and step'),
  AutopilotCommand('TELL A LANE', '/autopilot-tell', 'A note the lane\'s next step follows — it outranks the plan', group: 'Steer', lane: true, allLanes: false, note: true),
  AutopilotCommand('WAIT AT NEXT STOP', '/wait-at-the-next-stop', 'The running step finishes and commits, then the lane waits', group: 'Steer', lane: true),
  AutopilotCommand('CONTINUE', '/autopilot-continue', 'Clears pause and stop flags, restarts any lane loop that is not running', group: 'Steer', lane: true),
  AutopilotCommand('WATCH', '/autopilot-watch', 'Review loop, present mode: fixes defects, asks you about taste', group: 'Review'),
  AutopilotCommand('AWAY', '/autopilot-afk', 'Review loop, away mode: decides taste from your preferences, logs what it decided', group: 'Review'),
  AutopilotCommand('STOP WATCHING', '/autopilot-watch-stop', 'Stops the review loop; the lanes keep running', group: 'Review'),
  AutopilotCommand('APPROVE MESHY', '/autopilot-approve-meshy', 'Raises the Meshy allowance and tells lane B by mail', group: 'Meshy', number: 200),
];

/// Sends [text] to the orchestrator, starting (or resuming) the session
/// first when it is not running. Returns what happened, for a toast.
Future<String> sendToOrchestrator(BridgeSession b, String text) async {
  if (!b.running) {
    await b.start(resume: b.sessionId != null);
    final ok = await b.awaitReady(timeout: const Duration(seconds: 30));
    if (!ok) return 'The orchestrator did not start — see the Deck';
  }
  final queued = b.send(text);
  return queued ? 'Queued — it goes when the current turn ends' : 'Sent to the orchestrator';
}

/// The orchestrator tab: the autopilot's commands over the Deck.
class OrchestratorTab extends StatelessWidget {
  const OrchestratorTab({super.key, required this.bridge, required this.lanes, this.media});
  final BridgeSession bridge;
  final List<Lane> lanes;
  final StudioMedia? media;

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      AutopilotBar(send: (text) => sendToOrchestrator(bridge, text), lanes: lanes, loop: StudioOrchestrator.loop, schedule: StudioOrchestrator.schedule),
      if (media != null) MediaStrip(media: media!),
      Expanded(child: DeckTab(bridge: bridge, title: 'ORCHESTRATOR', planControls: false)),
    ]);
  }
}

/// The autopilot's commands, wrapped onto as many lines as the width needs
/// so every one is in sight without a sideways scroll (a mouse wheel cannot
/// scroll sideways); a chevron folds them away to give the Deck the room.
/// A tap asks what the command needs (lane, note, number) and sends it.
class AutopilotBar extends StatefulWidget {
  const AutopilotBar({super.key, required this.send, required this.lanes, this.loop, this.schedule});

  /// Sends a command line to the orchestrator; returns what came of it.
  final Future<String> Function(String text) send;
  final List<Lane> lanes;
  final LoopApi? loop;
  final ScheduleApi? schedule;

  @override
  State<AutopilotBar> createState() => _AutopilotBarState();
}

class _AutopilotBarState extends State<AutopilotBar> {
  /// Null until the person folds or opens it: open by default, folded when
  /// large text would leave the Deck too little room.
  bool? _opened;

  List<Lane> get lanes => widget.lanes;
  LoopApi? get loop => widget.loop;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    const cs = kAutopilotCommands;
    final groups = <String>{for (final c in cs) c.group}.toList();
    // Open by default; folded on a phone or with large text, where the
    // commands would take the Deck's room.
    final open = _opened ?? (MediaQuery.textScalerOf(context).scale(10) <= 15 && MediaQuery.sizeOf(context).width >= 600);
    return Container(
      decoration: BoxDecoration(color: t.surface, border: Border(bottom: BorderSide(color: t.line))),
      padding: const EdgeInsets.fromLTRB(12, 6, 4, 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // The title row: the label and the two switches wrap onto a second
        // line when large text leaves no room; the fold stays at the end.
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
              Text('AUTOPILOT', overflow: TextOverflow.ellipsis, style: t.readout(10, color: t.accent)),
              if (loop != null)
                ListenableBuilder(
                  listenable: loop!,
                  builder: (context, _) => Tooltip(
                    message: 'The app sends /autopilot-review every 20 minutes while the review mode is on — ${loop!.why}',
                    child: FilterChip(
                      avatar: Icon(Icons.autorenew, size: 16, color: loop!.on ? t.accent : t.muted),
                      label: Text(loop!.on ? 'REVIEW LOOP · ON' : 'REVIEW LOOP · OFF', overflow: TextOverflow.ellipsis),
                      selected: loop!.on,
                      showCheckmark: false,
                      onSelected: (v) => loop!.set(v),
                    ),
                  ),
                ),
              if (widget.schedule != null)
                ListenableBuilder(
                  listenable: widget.schedule!,
                  builder: (context, _) {
                    final n = widget.schedule!.upcoming;
                    return Tooltip(
                      message: 'Timed orders: send a command or message to the orchestrator at a time',
                      child: ActionChip(
                        avatar: Icon(Icons.alarm, size: 16, color: n > 0 ? t.accent : t.muted),
                        label: Text(n == 0 ? 'SCHEDULE' : 'SCHEDULE · $n', overflow: TextOverflow.ellipsis),
                        onPressed: () => showScheduleSheet(context, widget.schedule!, lanes: lanes, pickText: (ctx) => pickAutopilotCommand(ctx, lanes)),
                      ),
                    );
                  },
                ),
            ]),
          ),
          IconButton(
            tooltip: open ? 'Fold the commands' : 'Show the commands',
            icon: Icon(open ? Icons.expand_less : Icons.expand_more),
            onPressed: () => setState(() => _opened = !open),
          ),
        ]),
        if (open)
          // At most a quarter of the window; past that it scrolls up and down,
          // which a mouse wheel can do.
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.25),
            child: SingleChildScrollView(child: Wrap(spacing: 6, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
            for (final g in groups) ...[
              Padding(padding: const EdgeInsets.only(left: 2, right: 2), child: Text(g.toUpperCase(), style: t.readout(9, color: t.muted))),
              for (final c in cs)
                if (c.group == g)
                  Tooltip(
                    message: '${c.command} — ${c.what}',
                    child: ActionChip(label: Text(c.label), onPressed: () => _run(context, c)),
                  ),
            ],
          ]))),
      ]),
    );
  }

  Future<void> _run(BuildContext context, AutopilotCommand c) async {
    final text = await askCommandText(context, c, lanes);
    if (text == null || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final said = await widget.send(text);
    // Watching and away mode want the loop; stopping the watch ends it.
    if (c.command == '/autopilot-watch' || c.command == '/autopilot-afk') loop?.set(true);
    if (c.command == '/autopilot-watch-stop') loop?.set(false);
    messenger.showSnackBar(SnackBar(content: Text('$text — $said')));
  }
}

/// Builds the command line for [c], asking for its lane, note or number.
/// Null when the person backs out.
Future<String?> askCommandText(BuildContext context, AutopilotCommand c, List<Lane> lanes) async {
  if (!c.lane && !c.note && c.number == null) return c.command;
  return showDialog<String>(context: context, builder: (_) => _CommandDialog(command: c, lanes: lanes));
}

class _CommandDialog extends StatefulWidget {
  const _CommandDialog({required this.command, required this.lanes});
  final AutopilotCommand command;
  final List<Lane> lanes;
  @override
  State<_CommandDialog> createState() => _CommandDialogState();
}

class _CommandDialogState extends State<_CommandDialog> {
  late String? _lane = widget.command.allLanes ? null : (widget.lanes.isEmpty ? 'a' : widget.lanes.first.id);
  final _note = TextEditingController();
  late final _number = TextEditingController(text: widget.command.number?.toString() ?? '');

  @override
  void dispose() {
    _note.dispose();
    _number.dispose();
    super.dispose();
  }

  String? get _line {
    final c = widget.command;
    final parts = [c.command];
    if (c.lane && _lane != null) parts.add(_lane!);
    if (c.note) {
      final n = _note.text.trim();
      if (n.isEmpty) return null;
      parts.add(n);
    }
    if (c.number != null) {
      final n = int.tryParse(_number.text.trim());
      if (n == null || n <= 0) return null;
      parts.add('$n');
    }
    return parts.join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final c = widget.command;
    final line = _line;
    return AlertDialog(
      title: Text(c.label),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(c.what, style: TextStyle(fontSize: 13, color: t.ink2)),
          if (c.lane) ...[
            const SizedBox(height: 14),
            Wrap(spacing: 6, runSpacing: 6, children: [
              if (c.allLanes) ChoiceChip(label: const Text('ALL LANES'), selected: _lane == null, onSelected: (_) => setState(() => _lane = null)),
              for (final l in widget.lanes) ChoiceChip(label: Text(l.name.toUpperCase()), selected: _lane == l.id, onSelected: (_) => setState(() => _lane = l.id)),
            ]),
          ],
          if (c.note) ...[
            const SizedBox(height: 14),
            TextField(controller: _note, minLines: 2, maxLines: 6, autofocus: true, decoration: const InputDecoration(labelText: 'Note for the lane', border: OutlineInputBorder()), onChanged: (_) => setState(() {})),
          ],
          if (c.number != null) ...[
            const SizedBox(height: 14),
            TextField(controller: _number, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Credits', border: OutlineInputBorder()), onChanged: (_) => setState(() {})),
          ],
          const SizedBox(height: 14),
          Text(line ?? '…', style: t.mono(12, color: t.accent)),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
        FilledButton(onPressed: line == null ? null : () => Navigator.pop(context, line), child: const Text('SEND')),
      ],
    );
  }
}


/// Lets the person pick one of the autopilot's commands (and what it needs)
/// and returns its line — for a timed order.
Future<String?> pickAutopilotCommand(BuildContext context, List<Lane> lanes) async {
  final c = await showDialog<AutopilotCommand>(
    context: context,
    builder: (context) => SimpleDialog(
      title: const Text('Autopilot command'),
      children: [
        for (final c in kAutopilotCommands)
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, c),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(c.command, style: context.tokens.mono(13, color: context.tokens.accent)),
              Text(c.what, style: TextStyle(fontSize: 12, color: context.tokens.ink2)),
            ]),
          ),
      ],
    ),
  );
  if (c == null || !context.mounted) return null;
  return askCommandText(context, c, lanes);
}
