import 'package:flutter/material.dart' hide Step, StepState;
import 'package:flutter/services.dart';
import 'package:flutter_kit/kit.dart' show PoolWindow, autopilotLine, mirrorLine, modeChoices, modeLabel, thousands, untilLabel;
import 'package:url_launcher/url_launcher.dart';

import '../host/host_presence.dart';
import '../host/host_project.dart';
import '../widgets/git_card.dart';
import '../widgets/run_card.dart';
import 'log_sheet.dart';
import 'mirror_sheet.dart';
import '../host/login_item.dart';
import '../host/power.dart';
import '../host/remote_control.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Host only: start and stop the Remote Control server for this folder,
/// hand the phone its link, and watch what the session is doing.
class SessionTab extends StatefulWidget {
  const SessionTab({super.key, required this.host, this.presence, this.power, this.loginItem});
  final HostProject host;

  /// Mac-wide, not per project: the heartbeat, the power hold, the login
  /// item. Null in a test that has none.
  final HostPresence? presence;
  final PowerHold? power;
  final LoginItem? loginItem;
  @override
  State<SessionTab> createState() => _SessionTabState();
}

class _SessionTabState extends State<SessionTab> {
  late final _name = TextEditingController(text: widget.host.session.name);

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final h = widget.host;
    final s = h.session;
    final existing = s.running ? null : s.existing();
    return ListenableBuilder(
      listenable: Listenable.merge([h, s, h.hooks, ?h.push, ?widget.presence, ?widget.power, ?widget.loginItem]),
      builder: (context, _) {
        final presence = widget.presence;
        final power = widget.power;
        final login = widget.loginItem;
        return ListView(
          padding: const EdgeInsets.all(18),
          children: [
            if (presence != null || power != null || login != null) ...[
              Text('THIS MAC', style: t.display(16, weight: FontWeight.w600, ls: 2)),
              const SizedBox(height: 6),
              Text('The phone hears from this app every half minute; without it, the phone says the Mac is unreachable and queues what you send.', style: TextStyle(fontSize: 13, color: t.ink2)),
              const SizedBox(height: 10),
              if (presence != null) _check(context, ok: presence.error == null && presence.lastBeat != null, text: presence.status),
              if (power != null) _check(context, ok: power.error == null, text: power.status),
              if (login != null)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: login.enabled,
                  onChanged: (v) async {
                    final ok = v ? await login.enable() : await login.disable();
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ok ? (v ? 'Starts at the next login.' : 'Login item removed.') : (login.error ?? 'Could not change the login item'))));
                  },
                  title: Text('Start at login', style: t.display(15, weight: FontWeight.w600, ls: 0.4)),
                  subtitle: Text(login.status, style: TextStyle(fontSize: 12.5, color: t.ink2)),
                ),
              const SizedBox(height: 18),
            ],
            Row(children: [
              Expanded(child: Text('REMOTE CONTROL', style: t.display(16, weight: FontWeight.w600, ls: 2))),
              Pill(s.state.name, color: s.running ? t.good : (s.state == RcState.failed ? t.critical : t.muted), filled: s.running),
            ]),
            const SizedBox(height: 6),
            Text('Starts `claude remote-control` in this folder, on your own login. Every command — /step, /qa, /compact, permissions — is then available in the Claude app on your phone.', style: TextStyle(fontSize: 13, color: t.ink2)),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(child: TextField(controller: _name, enabled: !s.running, decoration: const InputDecoration(labelText: 'Session name'), onChanged: (v) => s.name = v.trim().isEmpty ? s.name : v.trim())),
              const SizedBox(width: 10),
              if (!s.running) FilledButton.icon(onPressed: () => s.start(), icon: const Icon(Icons.play_arrow), label: const Text('START')),
              if (!s.running && existing != null) ...[const SizedBox(width: 8), OutlinedButton(onPressed: () => s.start(reattach: true), child: const Text('REATTACH'))],
              if (s.running) FilledButton.tonalIcon(onPressed: () => s.stop(), icon: const Icon(Icons.stop), label: const Text('STOP')),
            ]),
            if (s.error != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(s.error!, style: TextStyle(color: t.critical, fontSize: 13))),
            if (existing != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text('A server from an earlier start is still running (pid ${existing.pid}). Reattach keeps its sessions.', style: TextStyle(color: t.warn, fontSize: 13))),
            if (s.sessionUrl != null || s.environmentUrl != null) ...[
              const SectionHead('Open on the phone', sub: 'The Claude app lists this environment on its own; the links are the direct way in.'),
              if (s.sessionUrl != null) _Link(label: 'Session', url: s.sessionUrl!),
              if (s.environmentUrl != null) _Link(label: 'Environment', url: s.environmentUrl!),
            ],
            const SectionHead('Checks'),
            _check(context, ok: h.hooksInstalled, text: h.hooksInstalled ? 'Hooks are installed — the phone sees what Claude is doing.' : 'No kit hook in .claude/settings.json — the session works, but the "now" line stays empty. Add `kit hook` to PostToolUse, Stop, UserPromptSubmit and Notification.'),
            _check(context, ok: h.relayError == null, text: h.relayError ?? 'Mirror: ${h.relayStatus}'),
            if (h.push != null) _check(context, ok: h.push!.ready && h.push!.lastError == null, text: h.push!.status),
            if (h.applied.isNotEmpty) ...[
              const SectionHead('From the phone', sub: 'Batches applied to plan/.'),
              for (final a in h.applied) Text(a, style: TextStyle(fontSize: 12.5, color: t.ink2)),
            ],
            ListenableBuilder(
              listenable: h.bridge,
              builder: (context, _) {
                final b = h.bridge;
                final rules = b.alwaysApplied;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SectionHead('Session options', sub: b.running ? 'How claude -p runs in this folder. The mode switches in place; Chrome waits for a stop. The phone can flip these too.' : 'How Start runs claude -p in this folder. The phone can flip these too.'),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Mode', style: t.display(15, weight: FontWeight.w600, ls: 0.4)),
                          const SizedBox(height: 8),
                          SegmentedButton<String>(
                            showSelectedIcon: false,
                            style: const ButtonStyle(visualDensity: VisualDensity.compact),
                            segments: [for (final m in modeChoices) ButtonSegment(value: m, label: Text(modeLabel(m).toUpperCase()))],
                            selected: {b.modeChoice},
                            onSelectionChanged: (v) => b.setOptions(mode: v.first),
                          ),
                          const SizedBox(height: 6),
                          Text('${_modeNote(b.modeChoice)}${b.modePending ? ' Switches when this turn ends.' : ''}', style: TextStyle(fontSize: 12.5, color: b.modeChoice == 'bypassPermissions' ? t.warn : t.ink2)),
                        ],
                      ),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: b.chrome,
                      onChanged: b.running ? null : (v) => b.setOptions(chrome: v),
                      title: Text('Drive Chrome', style: t.display(15, weight: FontWeight.w600, ls: 0.4)),
                      subtitle: Text('--chrome: the session gets the Claude in Chrome tools and works in this Mac\'s own browser — App Store Connect, Play Console, RevenueCat, signed in as you. Each browser action asks unless permissions are skipped.${b.running && b.chromeStatus != null ? ' Now: ${b.chromeStatus}.' : ''}', style: TextStyle(fontSize: 12.5, color: t.ink2)),
                    ),
                    ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      title: Text('What every session is told', style: t.display(15, weight: FontWeight.w600, ls: 0.4)),
                      subtitle: Text('Appended to Claude Code\'s system prompt at Start: the phone, the browser, a sign-in as a question for you, store actions asked first.', style: TextStyle(fontSize: 12.5, color: t.ink2)),
                      children: [
                        Padding(padding: const EdgeInsets.only(bottom: 12), child: SelectableText(b.brief, style: t.mono(12, color: t.ink2))),
                      ],
                    ),
                    if (rules.isNotEmpty) ...[
                      const SectionHead('Allowed always', sub: 'Rules Claude Code wrote to this project because an ask was answered Always. Remove one and it asks again.'),
                      for (final r in rules)
                        Row(children: [
                        Expanded(child: Text('${r.ruleString}  ·  ${r.behavior}, ${r.destination}', maxLines: 2, overflow: TextOverflow.ellipsis, style: t.mono(12))),
                        IconButton(
                          tooltip: 'Remove',
                          icon: const Icon(Icons.close, size: 16),
                          onPressed: () {
                            final removed = h.bridge.forgetAlways(r);
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(removed ? 'Removed ${r.ruleString}' : '${r.ruleString} was not in ${r.destination} any more')));
                          },
                        ),
                        ]),
                    ],
                  ],
                );
              },
            ),
            const SectionHead('Instruments', sub: 'What the model last read against its window, and the subscription pool. Tokens, never dollars.'),
            ListenableBuilder(
              listenable: h.bridge,
              builder: (context, _) {
                final b = h.bridge;
                final tr = b.transcript;
                final pool = tr.pool;
                String window(PoolWindow? p) {
                  if (p == null) return '—';
                  final u = p.utilization == null ? '' : '${(p.utilization! * 100).round()} % used';
                  final r = p.resetsAt == null ? '' : 'resets ${_hm(p.resetsAt!)} (in ${untilLabel(p.resetsAt!)})';
                  final s = [u, r].where((x) => x.isNotEmpty).join(' · ');
                  return s.isEmpty ? '—' : s;
                }

                final pct = (tr.contextFraction * 100).round();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _reading(context, 'Context', b.running ? '${thousands(tr.contextUsed)} / ${thousands(tr.contextWindow)} tokens · $pct %${tr.compacting ? ' · compacting' : ''}' : '—', warn: tr.contextFraction >= 0.7),
                    _reading(context, 'Five-hour pool', pool == null ? '—' : window(pool.fiveHour ?? PoolWindow(resetsAt: pool.resetsAt))),
                    _reading(context, 'Weekly pool', window(pool?.sevenDay)),
                    if (pool?.exhausted == true) _reading(context, 'Status', 'Exhausted — nothing runs until a window resets', warn: true),
                    _reading(context, 'Autopilot', autopilotLine(h.autopilot.state) ?? (h.autopilot.state.stoppedFor == null ? 'off' : 'off · last run stopped: ${h.autopilot.state.stoppedFor}'), warn: h.autopilot.state.waiting),
                    Padding(
                      padding: const EdgeInsets.only(top: 4, bottom: 8),
                      child: OutlinedButton(
                        onPressed: b.running && !tr.turnOpen && !tr.compacting ? b.compact : null,
                        child: Text(tr.compacting ? 'COMPACTING…' : 'COMPACT'),
                      ),
                    ),
                  ],
                );
              },
            ),
            const SectionHead('Run bay', sub: 'flutter run from this Mac, no model: the device, reload, restart, the log. A session is told the URIs so the Dart MCP server reaches the same app.'),
            ListenableBuilder(
              listenable: Listenable.merge([h.run, h.mirror]),
              builder: (context, _) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RunCard(
                    run: h.run.state,
                    onAction: h.runAction,
                    onLog: h.run.state.runId == null ? null : () => showLogSheet(context, lines: h.run.logStream, initial: h.run.log.lines, title: 'Log · ${h.run.state.deviceName ?? ''}'),
                    onMirror: () => showMirrorSheet(context, h.mirrorHooks, title: 'Mirror · ${h.run.state.deviceName ?? ''}'),
                  ),
                  Padding(padding: const EdgeInsets.only(top: 6), child: Text(mirrorLine(h.mirror.state), style: TextStyle(fontSize: 12.5, color: h.mirror.state.error == null ? t.ink2 : t.warn))),
                ],
              ),
            ),
            const SectionHead('Git', sub: 'What the host reads after every turn. Commit and Push run here, no model; the session hears about them with the next message.'),
            GitCard(git: h.gitStatus, onOp: h.gitOp),
            const SectionHead('Activity', sub: 'From the hooks, newest first.'),
            if (h.hooks.events.isEmpty) Text('Nothing yet.', style: TextStyle(color: t.muted))
            else
              for (final e in h.hooks.events.reversed.take(40))
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    SizedBox(width: 46, child: Text(_hm(e.at), style: t.mono(11.5, color: t.muted))),
                    Expanded(child: Text(e.summary, style: TextStyle(fontSize: 12.5, color: e.needsYou ? t.warn : t.ink2))),
                  ]),
                ),
            const SectionHead('Process output'),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: t.bg, borderRadius: BorderRadius.circular(8), border: Border.all(color: t.line)),
              child: SelectableText(s.log.isEmpty ? '—' : s.log.reversed.take(30).toList().reversed.join('\n'), style: t.mono(11.5)),
            ),
          ],
        );
      },
    );
  }

  static String _hm(DateTime at) {
    final l = at.toLocal();
    return '${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}';
  }

  Widget _reading(BuildContext context, String label, String value, {bool warn = false}) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 118, child: Text(label.toUpperCase(), style: t.readout(10))),
        Expanded(child: Text(value, style: t.mono(12, color: warn ? t.warn : t.ink))),
      ]),
    );
  }

  Widget _check(BuildContext context, {required bool ok, required String text}) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(ok ? Icons.check_circle : Icons.warning_amber_rounded, size: 18, color: ok ? t.good : t.warn),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: TextStyle(fontSize: 13, color: t.ink2))),
      ]),
    );
  }
}

class _Link extends StatelessWidget {
  const _Link({required this.label, required this.url});
  final String label;
  final String url;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(children: [
        SizedBox(width: 92, child: Text(label, style: TextStyle(fontSize: 13, color: t.muted))),
        Expanded(child: SelectableText(url, style: TextStyle(fontSize: 12.5, color: t.accent))),
        IconButton(tooltip: 'Copy', icon: const Icon(Icons.copy, size: 16), onPressed: () {
          Clipboard.setData(ClipboardData(text: url));
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied')));
        }),
        IconButton(tooltip: 'Open', icon: const Icon(Icons.open_in_new, size: 16), onPressed: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication)),
      ]),
    );
  }
}

/// What each position of the mode dial means, in the words of the flag.
String _modeNote(String mode) => switch (mode) {
      'plan' => '--permission-mode plan: the session reads and thinks but edits nothing. When its plan is ready it comes to the phone as a card — approve it there, or send back what to change.',
      'acceptEdits' => '--permission-mode acceptEdits: edits to files run without asking; commands still wait on Allow.',
      'bypassPermissions' => '--permission-mode bypassPermissions is --dangerously-skip-permissions: nothing waits on Allow, every command runs. Questions still reach the phone. Only for a folder you trust.',
      _ => '--permission-mode default: a command or an edit waits on Allow, on the phone or here.',
    };
