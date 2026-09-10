import 'package:flutter/material.dart' hide Step, StepState;
import 'package:flutter_kit/kit.dart';

import '../theme.dart';

/// Sessions: every conversation this folder had — the one on the Deck on
/// the card, the whole list in a sheet. RESUME switches the Deck to one
/// (a running session stops first, between turns); NEW starts a fresh
/// conversation and keeps the old in the list; the bin takes one off the
/// list, never the CLI's file. [onResume], [onNew] and [onDelete] return
/// the line to toast, or null for none.
class SessionsCard extends StatelessWidget {
  const SessionsCard({super.key, required this.sessions, this.currentId, required this.running, required this.turnOpen, required this.onResume, required this.onNew, required this.onDelete, this.now});

  /// Any order; the card and the sheet show the newest first.
  final List<SessionEntry> sessions;
  final String? currentId;
  final bool running;
  final bool turnOpen;
  final Future<String?> Function(String id) onResume;
  final Future<String?> Function() onNew;
  final Future<String?> Function(String id) onDelete;
  final DateTime Function()? now;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final sorted = sortedSessions(sessions);
    SessionEntry? cur;
    for (final s in sorted) {
      if (s.id == currentId) cur = s;
    }
    final at = now?.call() ?? DateTime.now();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(color: t.surface, borderRadius: BorderRadius.circular(10), border: Border.all(color: t.line)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('SESSIONS · ${sorted.length}', style: t.readout(11, color: t.ink2)),
              TextButton(
                style: TextButton.styleFrom(visualDensity: VisualDensity.compact, padding: const EdgeInsets.symmetric(horizontal: 8)),
                onPressed: turnOpen ? null : () => _toast(context, onNew()),
                child: const Text('NEW'),
              ),
              TextButton(
                style: TextButton.styleFrom(visualDensity: VisualDensity.compact, padding: const EdgeInsets.symmetric(horizontal: 8)),
                onPressed: sorted.isEmpty ? null : () => showSessionsSheet(context, sessions: sorted, currentId: currentId, running: running, turnOpen: turnOpen, onResume: onResume, onDelete: onDelete, now: now),
                child: const Text('ALL'),
              ),
            ],
          ),
          if (cur != null) ...[
            const SizedBox(height: 4),
            Text(cur.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, color: t.ink)),
            const SizedBox(height: 2),
            Text('${sessionLine(cur, now: at, running: running && cur.id == currentId)}${cur.isCodex ? ' · codex' : ''}', style: t.readout(10.5)),
          ] else ...[
            const SizedBox(height: 4),
            Text(sorted.isEmpty ? 'No conversation yet — Start opens one.' : 'Nothing on the Deck — pick a conversation from the list, or start new.', style: TextStyle(fontSize: 12.5, color: t.ink2)),
          ],
        ],
      ),
    );
  }
}

/// Newest first.
List<SessionEntry> sortedSessions(List<SessionEntry> sessions) => [...sessions]..sort((a, b) => b.startedAt.compareTo(a.startedAt));

/// `today 14:05 · 3 turns · claude-fable-5-1 · live`.
String sessionLine(SessionEntry s, {required DateTime now, bool running = false}) => [
      whenLabel(s.startedAt, now: now),
      '${s.turns} turn${s.turns == 1 ? '' : 's'}',
      ?s.model,
      if (running) 'live' else if (s.endedAt == null) 'open',
    ].join(' · ');

/// `today 14:05`, `yesterday 09:12`, `3 Sep 18:40`.
String whenLabel(DateTime at, {required DateTime now}) {
  final l = at.toLocal();
  final n = now.toLocal();
  final hm = '${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}';
  final day = DateTime(l.year, l.month, l.day);
  final today = DateTime(n.year, n.month, n.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return 'today $hm';
  if (diff == 1) return 'yesterday $hm';
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${l.day} ${months[l.month - 1]}${l.year == n.year ? '' : ' ${l.year}'} $hm';
}

void _toast(BuildContext context, Future<String?> line) async {
  String? text;
  try {
    text = await line;
  } on Object catch (e) {
    text = 'Could not: $e';
  }
  if (text == null || !context.mounted) return;
  ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(text)));
}

/// The list: every session, newest first, each with RESUME and the bin.
Future<void> showSessionsSheet(
  BuildContext context, {
  required List<SessionEntry> sessions,
  String? currentId,
  required bool running,
  required bool turnOpen,
  required Future<String?> Function(String id) onResume,
  required Future<String?> Function(String id) onDelete,
  DateTime Function()? now,
}) {
  final t = context.tokens;
  final at = now?.call() ?? DateTime.now();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: t.surface,
    builder: (sheet) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.8),
        child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.only(bottom: 8),
                itemCount: sessions.length + 1,
                itemBuilder: (_, index) {
                  if (index == 0) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(18, 16, 18, 6),
                          child: Text('SESSIONS', style: t.display(16, weight: FontWeight.w600, ls: 2)),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(18, 0, 18, 8),
                          child: Text('Resume switches the Deck to that conversation; a running one stops first. The bin takes a session off this list — its file stays on the Mac.', style: TextStyle(fontSize: 12.5, color: t.ink2)),
                        ),
                      ],
                    );
                  }
                  final i = index - 1;
                  final s = sessions[i];
                  final isCurrent = s.id == currentId;
                  final live = isCurrent && running;
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(18, 6, 18, 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(top: 3, right: 8),
                              child: Icon(isCurrent ? Icons.radio_button_checked : Icons.radio_button_off, size: 14, color: isCurrent ? t.accent : t.muted),
                            ),
                            Expanded(child: Text(s.title, maxLines: 3, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13.5, color: t.ink))),
                          ],
                        ),
                        Padding(
                          padding: const EdgeInsets.only(left: 22, top: 2),
                          child: Text('${sessionLine(s, now: at, running: live)}${s.mode == null ? '' : ' · ${modeLabel(s.mode!)}'}${s.isCodex ? ' · codex' : ''}', style: t.readout(10.5)),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(left: 14),
                          child: Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              if (!live)
                                TextButton(
                                  style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                                  onPressed: turnOpen
                                      ? null
                                      : () {
                                          Navigator.of(sheet).pop();
                                          _toast(context, onResume(s.id));
                                        },
                                  child: const Text('RESUME'),
                                ),
                              IconButton(
                                tooltip: 'Remove from the list',
                                visualDensity: VisualDensity.compact,
                                icon: Icon(Icons.delete_outline, size: 18, color: live ? t.muted : t.ink2),
                                onPressed: live
                                    ? null
                                    : () async {
                                        final ok = await showDialog<bool>(
                                          context: sheet,
                                          builder: (d) => AlertDialog(
                                            title: const Text('Remove from the list?'),
                                            content: const Text('The conversation stays on the Mac; only the list forgets it.'),
                                            actions: [
                                              TextButton(onPressed: () => Navigator.of(d).pop(false), child: const Text('CANCEL')),
                                              TextButton(onPressed: () => Navigator.of(d).pop(true), child: const Text('REMOVE')),
                                            ],
                                          ),
                                        );
                                        if (ok != true || !sheet.mounted) return;
                                        Navigator.of(sheet).pop();
                                        if (context.mounted) _toast(context, onDelete(s.id));
                                      },
                              ),
                            ],
                          ),
                        ),
                        if (i < sessions.length - 1) Divider(height: 8, color: t.line),
                      ],
                    ),
                  );
                },
              ),
      ),
    ),
  );
}
