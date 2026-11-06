import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart' hide Step, StepState;
import 'package:flutter_kit/kit.dart' show DeckRole;
import 'package:path/path.dart' as p;

import '../host/bridge_session.dart';
import '../theme.dart';
import 'studio_data.dart';

// Timed orders: "do this at a time". A `-p` bridge has no session cron, so
// the reviewer's one-off timers ("stop lane C before the 19:00 play
// session, resume it after 03:00") live here instead. The person schedules
// them from the ORCHESTRATOR tab; the orchestrator schedules them by ending
// a reply with a ```studio-timer block. At the time, the app sends the order
// to the orchestrator — starting or resuming it when it is not running —
// and notes it in the Deck. An order the app could not send within [grace]
// (the Mac asleep, the app closed) is marked missed, not sent late.

enum Repeat { once, daily, weekdays }

class TimedOrder {
  TimedOrder({required this.id, required this.at, required this.text, this.repeat = Repeat.once, this.by = 'you', this.note, this.lastRun, this.status = 'scheduled'});

  final String id;

  /// The next time it is due (local time).
  DateTime at;

  /// What is sent to the orchestrator: a command line or a message.
  final String text;
  final Repeat repeat;

  /// 'you' or 'orchestrator'.
  final String by;

  /// Why, in a few words.
  final String? note;
  DateTime? lastRun;

  /// scheduled · sent · missed · cancelled.
  String status;

  bool get active => status == 'scheduled';

  Map<String, Object?> toJson() => {'id': id, 'at': at.toIso8601String(), 'text': text, 'repeat': repeat.name, 'by': by, 'note': note, 'lastRun': lastRun?.toIso8601String(), 'status': status};

  static TimedOrder fromJson(Map<String, Object?> j) => TimedOrder(
        id: j['id'] as String,
        at: DateTime.parse(j['at'] as String),
        text: j['text'] as String,
        repeat: Repeat.values.byName((j['repeat'] as String?) ?? 'once'),
        by: (j['by'] as String?) ?? 'you',
        note: j['note'] as String?,
        lastRun: j['lastRun'] == null ? null : DateTime.parse(j['lastRun'] as String),
        status: (j['status'] as String?) ?? 'scheduled',
      );

  /// The next time after [from] for a repeating order.
  DateTime nextAfter(DateTime from) {
    var n = DateTime(from.year, from.month, from.day, at.hour, at.minute);
    if (!n.isAfter(from)) n = n.add(const Duration(days: 1));
    if (repeat == Repeat.weekdays) {
      while (n.weekday == DateTime.saturday || n.weekday == DateTime.sunday) {
        n = n.add(const Duration(days: 1));
      }
    }
    return n;
  }

  String get repeatLabel => switch (repeat) { Repeat.once => 'once', Repeat.daily => 'every day', Repeat.weekdays => 'weekdays' };
}

/// The first time on or after [from] that is [hour]:[minute], skipping
/// weekends for [Repeat.weekdays].
DateTime firstAt(DateTime from, int hour, int minute, Repeat repeat) {
  var n = DateTime(from.year, from.month, from.day, hour, minute);
  if (n.isBefore(from)) n = n.add(const Duration(days: 1));
  if (repeat == Repeat.weekdays) {
    while (n.weekday == DateTime.saturday || n.weekday == DateTime.sunday) {
      n = n.add(const Duration(days: 1));
    }
  }
  return n;
}

/// A ```studio-timer block from the orchestrator:
///   at: 2026-11-07 18:45
///   repeat: once | daily | weekdays
///   send: /wait-at-the-next-stop c
///   note: before the user's 19:00 play session
TimedOrder? parseTimer(String block, {required String id}) {
  final f = <String, String>{};
  for (final l in block.split('\n')) {
    final m = RegExp(r'^(\w+):\s*(.*)$').firstMatch(l.trim());
    if (m != null) f[m.group(1)!] = m.group(2)!.trim();
  }
  final at = parseStamp(f['at'] ?? '');
  final send = f['send'];
  if (at == null || send == null || send.isEmpty) return null;
  final repeat = Repeat.values.where((r) => r.name == f['repeat']).firstOrNull ?? Repeat.once;
  return TimedOrder(id: id, at: at, text: send, repeat: repeat, by: 'orchestrator', note: f['note']);
}

/// What the schedule sheet needs — the Mac's schedule, or the phone's view
/// of it (changed through commands).
abstract class ScheduleApi implements Listenable {
  List<TimedOrder> get orders;
  List<TimedOrder> get sorted;
  int get upcoming;
  Duration get grace;
  void add(TimedOrder o);
  void cancel(String id);
  void delete(String id);
}

/// The schedule: kept in a file, checked every [tick], sending through
/// [bridge] (set by the orchestrator holder).
class StudioSchedule extends ChangeNotifier implements ScheduleApi {
  StudioSchedule({String? file, this.tick = const Duration(seconds: 30), this.grace = const Duration(minutes: 30), DateTime Function()? now})
      : file = file ?? p.join(Platform.environment['HOME'] ?? '.', '.flutter_kit', 'studio', 'schedule.json'),
        _now = now ?? DateTime.now;

  final String file;
  final Duration tick;

  /// How late an order may still be sent.
  @override
  final Duration grace;
  final DateTime Function() _now;

  @override
  final List<TimedOrder> orders = [];
  BridgeSession? bridge;
  Timer? _timer;
  final Set<String> _seenBlocks = {};

  /// Upcoming first, then the rest newest first.
  @override
  List<TimedOrder> get sorted {
    final up = orders.where((o) => o.active).toList()..sort((a, b) => a.at.compareTo(b.at));
    final rest = orders.where((o) => !o.active).toList()..sort((a, b) => (b.lastRun ?? b.at).compareTo(a.lastRun ?? a.at));
    return [...up, ...rest];
  }

  @override
  int get upcoming => orders.where((o) => o.active).length;

  void load() {
    try {
      final f = File(file);
      if (!f.existsSync()) return;
      final j = jsonDecode(f.readAsStringSync()) as Map<String, Object?>;
      orders
        ..clear()
        ..addAll([for (final o in j['orders'] as List) TimedOrder.fromJson((o as Map).cast<String, Object?>())]);
      _seenBlocks.addAll([for (final s in (j['seen'] as List? ?? const [])) s as String]);
    } catch (_) {}
    notifyListeners();
  }

  void _save() {
    try {
      final f = File(file)..parent.createSync(recursive: true);
      // Keep the last 100 finished orders; all the scheduled ones.
      final done = orders.where((o) => !o.active).toList()..sort((a, b) => (b.lastRun ?? b.at).compareTo(a.lastRun ?? a.at));
      orders.removeWhere((o) => !o.active && done.indexOf(o) >= 100);
      f.writeAsStringSync(jsonEncode({'orders': [for (final o in orders) o.toJson()], 'seen': _seenBlocks.toList()}));
    } catch (_) {}
    notifyListeners();
  }

  void start() {
    _timer ??= Timer.periodic(tick, (_) => check());
    check();
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  void add(TimedOrder o) {
    orders.add(o);
    _save();
  }

  @override
  void cancel(String id) {
    final o = orders.where((o) => o.id == id).firstOrNull;
    if (o == null) return;
    o.status = 'cancelled';
    _save();
  }

  @override
  void delete(String id) {
    orders.removeWhere((o) => o.id == id);
    _save();
  }

  /// Sends what is due; marks what is too late. Returns the orders sent.
  Future<List<TimedOrder>> check() async {
    final now = _now();
    final sent = <TimedOrder>[];
    var changed = false;
    for (final o in orders.where((o) => o.active && !o.at.isAfter(now)).toList()) {
      final late = now.difference(o.at);
      if (late > grace) {
        o.lastRun = now;
        if (o.repeat == Repeat.once) {
          o.status = 'missed';
        } else {
          o.at = o.nextAfter(now);
        }
        // The schedule shows the miss; the Deck hears of it when a session runs.
        if (bridge?.running ?? false) bridge!.note('⏰ Missed: "${o.text}" was due ${_hhmm(o.lastRun!.subtract(late))} — the app could not send it in time.');
        changed = true;
        continue;
      }
      final b = bridge;
      if (b == null) continue;
      if (!b.running) {
        await b.start(resume: b.sessionId != null);
        if (!await b.awaitReady(timeout: const Duration(seconds: 30))) continue;
      }
      b.note('⏰ Timed order${o.note == null ? '' : ' (${o.note})'}: ${o.text}');
      b.send(o.text, by: 'schedule');
      o.lastRun = now;
      if (o.repeat == Repeat.once) {
        o.status = 'sent';
      } else {
        o.at = o.nextAfter(now);
      }
      sent.add(o);
      changed = true;
    }
    if (changed) _save();
    return sent;
  }

  /// Picks up ```studio-timer blocks from the orchestrator's replies.
  void watch(BridgeSession b) {
    bridge = b;
    b.addListener(() => collectTimers(b));
  }

  void collectTimers(BridgeSession b) {
    final sid = b.sessionId ?? 'x';
    var added = false;
    for (final m in b.transcript.messages) {
      if (m.role != DeckRole.assistant || m.streaming) continue;
      for (final (i, match) in RegExp(r'```studio-timer\n([\s\S]*?)```').allMatches(m.text).indexed) {
        final key = '$sid-${m.id}-$i';
        if (!_seenBlocks.add(key)) continue;
        final o = parseTimer(match.group(1)!, id: key);
        if (o == null) continue;
        orders.add(o);
        added = true;
      }
    }
    if (added) _save();
  }
}

String _hhmm(DateTime d) => '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

String whenText(DateTime at, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(at.year, at.month, at.day);
  final d = day.difference(today).inDays;
  final dayWord = d == 0 ? 'today' : (d == 1 ? 'tomorrow' : (d == -1 ? 'yesterday' : '${at.year}-${at.month.toString().padLeft(2, '0')}-${at.day.toString().padLeft(2, '0')}'));
  return '$dayWord ${_hhmm(at)}';
}

/// The schedule as a sheet: upcoming first, each with CANCEL; finished ones
/// below with what came of them; ADD at the top.
Future<void> showScheduleSheet(BuildContext context, ScheduleApi schedule, {required List<Lane> lanes, required Future<String?> Function(BuildContext) pickText}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheet) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.65,
      maxChildSize: 0.95,
      builder: (context, ctrl) => ListenableBuilder(
        listenable: schedule,
        builder: (context, _) {
          final t = context.tokens;
          final now = DateTime.now();
          return ListView(
            controller: ctrl,
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
            children: [
              Row(children: [
                Expanded(child: Text('TIMED ORDERS · ${schedule.upcoming} UPCOMING', style: t.readout(11, color: t.accent))),
                FilledButton.icon(
                  onPressed: () async {
                    final o = await showDialog<TimedOrder>(context: context, builder: (_) => _AddTimedOrder(pickText: pickText));
                    if (o != null) schedule.add(o);
                  },
                  icon: const Icon(Icons.add_alarm, size: 18),
                  label: const Text('ADD'),
                ),
              ]),
              const SizedBox(height: 4),
              Text('Sent to the orchestrator at the time — it is started or resumed if it is not running. An order more than ${schedule.grace.inMinutes} min late (the Mac asleep, the app closed) is marked missed instead. The orchestrator can schedule orders too.', style: TextStyle(fontSize: 12.5, color: t.ink2)),
              const SizedBox(height: 10),
              if (schedule.orders.isEmpty) const Padding(padding: EdgeInsets.all(16), child: Text('Nothing scheduled.')),
              for (final o in schedule.sorted)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    switch (o.status) { 'sent' => Icons.check_circle_outline, 'missed' => Icons.error_outline, 'cancelled' => Icons.cancel_outlined, _ => Icons.alarm },
                    color: switch (o.status) { 'sent' => t.good, 'missed' => t.warn, 'cancelled' => t.muted, _ => t.accent },
                  ),
                  title: Text(o.text, maxLines: 2, overflow: TextOverflow.ellipsis, style: t.mono(13, color: o.active ? t.ink : t.muted)),
                  subtitle: Text(
                    [
                      if (o.active) 'next ${whenText(o.at, now)}' else '${o.status} ${o.lastRun == null ? '' : whenText(o.lastRun!, now)}',
                      o.repeatLabel,
                      'set by ${o.by}',
                      if (o.note != null) o.note!,
                    ].join(' · '),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: o.active
                      ? TextButton(onPressed: () => schedule.cancel(o.id), child: const Text('CANCEL'))
                      : IconButton(tooltip: 'Remove from the list', icon: const Icon(Icons.close), onPressed: () => schedule.delete(o.id)),
                ),
            ],
          );
        },
      ),
    ),
  );
}

class _AddTimedOrder extends StatefulWidget {
  const _AddTimedOrder({required this.pickText});
  final Future<String?> Function(BuildContext) pickText;
  @override
  State<_AddTimedOrder> createState() => _AddTimedOrderState();
}

class _AddTimedOrderState extends State<_AddTimedOrder> {
  final _text = TextEditingController();
  final _note = TextEditingController();
  late DateTime _day = DateTime.now();
  TimeOfDay _time = TimeOfDay.fromDateTime(DateTime.now().add(const Duration(hours: 1)));
  Repeat _repeat = Repeat.once;

  @override
  void dispose() {
    _text.dispose();
    _note.dispose();
    super.dispose();
  }

  DateTime get _at => _repeat == Repeat.once ? DateTime(_day.year, _day.month, _day.day, _time.hour, _time.minute) : firstAt(DateTime.now(), _time.hour, _time.minute, _repeat);

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final ok = _text.text.trim().isNotEmpty && (_repeat != Repeat.once || _at.isAfter(DateTime.now()));
    return AlertDialog(
      title: const Text('Timed order'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: TextField(controller: _text, minLines: 1, maxLines: 4, decoration: const InputDecoration(labelText: 'What to send the orchestrator', border: OutlineInputBorder()), onChanged: (_) => setState(() {}))),
              const SizedBox(width: 6),
              IconButton(
                tooltip: 'Pick an autopilot command',
                icon: const Icon(Icons.terminal),
                onPressed: () async {
                  final c = await widget.pickText(context);
                  if (c != null) setState(() => _text.text = c);
                },
              ),
            ]),
            const SizedBox(height: 12),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final r in Repeat.values) ChoiceChip(label: Text(switch (r) { Repeat.once => 'ONCE', Repeat.daily => 'EVERY DAY', Repeat.weekdays => 'WEEKDAYS' }), selected: _repeat == r, onSelected: (_) => setState(() => _repeat = r)),
            ]),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: [
              if (_repeat == Repeat.once)
                OutlinedButton.icon(
                  icon: const Icon(Icons.calendar_today, size: 16),
                  label: Text('${_day.year}-${_day.month.toString().padLeft(2, '0')}-${_day.day.toString().padLeft(2, '0')}'),
                  onPressed: () async {
                    final d = await showDatePicker(context: context, initialDate: _day, firstDate: DateTime.now().subtract(const Duration(days: 1)), lastDate: DateTime.now().add(const Duration(days: 365)));
                    if (d != null) setState(() => _day = d);
                  },
                ),
              OutlinedButton.icon(
                icon: const Icon(Icons.schedule, size: 16),
                label: Text(_time.format(context)),
                onPressed: () async {
                  final tm = await showTimePicker(context: context, initialTime: _time);
                  if (tm != null) setState(() => _time = tm);
                },
              ),
            ]),
            const SizedBox(height: 12),
            TextField(controller: _note, decoration: const InputDecoration(labelText: 'Why (optional)', border: OutlineInputBorder())),
            const SizedBox(height: 8),
            Text('First: ${whenText(_at, DateTime.now())}${_repeat == Repeat.once && !_at.isAfter(DateTime.now()) ? ' — that is in the past' : ''}', style: t.mono(11, color: t.muted)),
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
        FilledButton(
          onPressed: ok ? () => Navigator.pop(context, TimedOrder(id: 'u${DateTime.now().microsecondsSinceEpoch}', at: _at, text: _text.text.trim(), repeat: _repeat, note: _note.text.trim().isEmpty ? null : _note.text.trim())) : null,
          child: const Text('SCHEDULE'),
        ),
      ],
    );
  }
}
