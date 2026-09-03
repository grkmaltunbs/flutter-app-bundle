import 'package:flutter/material.dart' hide Step, StepState;
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../host/host_project.dart';
import '../host/remote_control.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Host only: start and stop the Remote Control server for this folder,
/// hand the phone its link, and watch what the session is doing.
class SessionTab extends StatefulWidget {
  const SessionTab({super.key, required this.host});
  final HostProject host;
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
      listenable: Listenable.merge([h, s, h.hooks]),
      builder: (context, _) {
        return ListView(
          padding: const EdgeInsets.all(18),
          children: [
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
                    SectionHead('Session options', sub: b.running ? 'How Start runs claude -p in this folder. Fixed while a session runs — stop it to change them.' : 'How Start runs claude -p in this folder. The phone can flip these too.'),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: b.skipPermissions,
                      onChanged: b.running ? null : (v) => b.setOptions(skipPermissions: v),
                      title: Text('Skip permissions', style: t.display(15, weight: FontWeight.w600, ls: 0.4)),
                      subtitle: Text('--dangerously-skip-permissions: nothing waits on Allow, every command runs. Questions still reach the phone. Only for a folder you trust.', style: TextStyle(fontSize: 12.5, color: t.ink2)),
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
