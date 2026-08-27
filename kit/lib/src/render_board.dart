/// The board: two tabs over one plan.
///
/// **Steps** — every step as a bubble, laid out left-to-right by dependency
/// depth, with the lines between them. Tapping a bubble opens the step: what
/// it comes after, what it unlocks, what *you* should do (every item that
/// blocks it, as a runbook with what success and failure look like), and —
/// collapsed — what Claude does.
///
/// **Your work** — the same items grouped by what they need, with the ones
/// that would flip a step today first and decisions with the recommended
/// option first.
///
/// Generated from the plan, never hand-curated. Every bubble and every card
/// is an element with the step's or item's id, so a comment on the published
/// page is unambiguous once you see what it is attached to.
library;

import 'dart:convert';

import 'dag_layout.dart';
import 'graph.dart';
import 'import_md.dart' show humanBoxesMarker;
import 'mini_md.dart';
import 'model.dart';

const _defaultLight = {
  'bg': '#F6F7F4',
  'surface': '#FFFFFF',
  'ink': '#16201F',
  'ink2': '#4A5553',
  'muted': '#7C8886',
  'line': '#DDE2DF',
  'accent': '#2F5BEA',
  'accent_soft': '#E4EBFF',
  'good': '#1F8A4C',
  'good_soft': '#DDF3E5',
  'warn': '#B7791F',
  'warn_soft': '#FBEFD6',
  'critical': '#C53030',
  'critical_soft': '#FBE1E1',
};

const _defaultDark = {
  'bg': '#101413',
  'surface': '#181D1C',
  'ink': '#EEF1EF',
  'ink2': '#C3CAC7',
  'muted': '#8B9591',
  'line': '#2A3230',
  'accent': '#7FA3FF',
  'accent_soft': '#1B2748',
  'good': '#5FD08A',
  'good_soft': '#12301E',
  'warn': '#E4B25A',
  'warn_soft': '#3A2C0E',
  'critical': '#F28B82',
  'critical_soft': '#3B1717',
};

const _defaultFonts = {
  'display': 'Bricolage Grotesque',
  'body': 'Instrument Sans',
  'mono': 'JetBrains Mono',
};

String renderBoardHtml(Plan plan, {required String today, String? outbox}) {
  final m = plan.manifest;
  final g = Graph(plan);
  final needs = m.needs;
  final light = {..._defaultLight, ...?m.boardColors['light']};
  final dark = {..._defaultDark, ...?m.boardColors['dark']};
  final fonts = {..._defaultFonts, ...m.boardFonts};
  final title = m.boardTitle ?? '${m.projectName} Board';

  final views = g.views();
  final viewById = {for (final v in views) v.step.id: v};
  final done = views.where((v) => v.state == StepState.done).length;
  final open = g.openItemsByUrgency();
  final decisive = g.decisiveItemIds();
  final next = g.nextStep();
  final codeComplete = g.codeComplete();

  final flipToday = [for (final i in open) if (decisive.contains(i.id)) i];
  final decisions = [for (final i in open) if (!decisive.contains(i.id) && (i.question != null || i.needs.contains('decision'))) i];
  final placed = {...flipToday.map((i) => i.id), ...decisions.map((i) => i.id)};
  final unsorted = [for (final i in open) if (!placed.contains(i.id) && i.needs.isEmpty) i];
  placed.addAll(unsorted.map((i) => i.id));
  final sittings = <String, List<Item>>{};
  for (final i in open) {
    if (placed.contains(i.id)) continue;
    sittings.putIfAbsent(i.needs.first, () => []).add(i);
  }

  final b = StringBuffer();
  b.writeln('<title>${escapeHtml(title)}</title>');
  b.writeln('<meta name="viewport" content="width=device-width, initial-scale=1">');
  b.writeln(_fontLink(fonts));
  b.writeln('<style>');
  b.writeln(_css(light, dark, fonts));
  b.writeln('</style>');
  b.writeln('<main class="board">');

  // Header + summary strip — true on both tabs.
  b.writeln('<header class="head">');
  b.writeln('<p class="eyebrow">${escapeHtml(m.projectName)} · generated ${escapeHtml(today)}</p>');
  b.writeln('<h1>${escapeHtml(title)}</h1>');
  b.writeln('<div class="strip">');
  b.writeln(_stat('$done / ${views.length}', 'steps done'));
  b.writeln(_stat('${codeComplete.length}', 'code complete, waiting on you'));
  b.writeln(_stat('${open.length}', 'open item${open.length == 1 ? '' : 's'} for you'));
  b.writeln(_stat('${flipToday.length}', 'would flip a step today'));
  b.writeln('</div>');
  if (next != null) {
    b.writeln('<p class="next">Next for Claude: <a href="#step-${escapeHtml(next.step.id)}" data-step="${escapeHtml(next.step.id)}"><strong>${escapeHtml(next.step.title)}</strong></a> <code>${escapeHtml(next.step.id)}</code> — ${_stateLabel(next.state)}.</p>');
  } else {
    b.writeln('<p class="next">Nothing is startable for Claude — every pending step is blocked.</p>');
  }
  b.writeln('</header>');

  b.writeln('<nav class="tabs" role="tablist">');
  b.writeln('<button class="tab" role="tab" data-tab="steps" aria-selected="true">Steps</button>');
  b.writeln('<button class="tab" role="tab" data-tab="work" aria-selected="false">Your work <span class="tab-count">${open.length}</span></button>');
  b.writeln('</nav>');

  // ---- Tab 1: the steps, as bubbles.
  b.writeln('<section class="pane" id="pane-steps" data-pane="steps">');
  b.writeln(_stepsTab(plan, g, viewById, needs));
  b.writeln('</section>');

  // ---- Tab 2: the human's work, grouped.
  b.writeln('<section class="pane" id="pane-work" data-pane="work" hidden>');
  if (flipToday.isNotEmpty) {
    b.writeln(_sectionHead('Would flip a step today', 'The last open box on a step whose code is finished. Close one of these and the step is done.'));
    b.writeln('<div class="cards">');
    for (final i in flipToday) {
      b.writeln(_itemCard(i, needs, g, flip: true));
    }
    b.writeln('</div>');
  }
  if (decisions.isNotEmpty) {
    b.writeln(_sectionHead('Decisions that come back to Claude', 'Answer in a comment on the card, or tell Claude in the terminal. The recommended option is first.'));
    b.writeln('<div class="cards">');
    for (final i in decisions) {
      b.writeln(_itemCard(i, needs, g));
    }
    b.writeln('</div>');
  }
  if (sittings.isNotEmpty) {
    final n = sittings.length;
    b.writeln(_sectionHead('$n sitting${n == 1 ? '' : 's'}, not ${open.length} items', 'Grouped by what they need, so one evening at a console — or with a second phone — clears a whole group.'));
    for (final e in sittings.entries) {
      final kind = needs[e.key];
      final label = kind?.label ?? e.key;
      b.writeln('<details class="sitting" data-sitting="${escapeHtml(e.key)}">');
      b.writeln('<summary><span class="sitting-title">${escapeHtml(label)}</span><span class="count">${e.value.length}</span>');
      if (kind != null) b.writeln('<span class="sitting-desc">${escapeHtml(kind.description)}</span>');
      b.writeln('</summary>');
      b.writeln('<div class="cards">');
      for (final i in e.value) {
        b.writeln(_itemCard(i, needs, g));
      }
      b.writeln('</div></details>');
    }
  }
  if (unsorted.isNotEmpty) {
    b.writeln(_sectionHead('${unsorted.length} Claude could not sort', 'It could not tell what these need from you. A one-word comment — console, device, read, look, decision, store, money, secret, know — files it.'));
    b.writeln('<div class="cards">');
    for (final i in unsorted) {
      b.writeln(_itemCard(i, needs, g));
    }
    b.writeln('</div>');
  }
  if (open.isEmpty) b.writeln('<p class="empty">Nothing is waiting on you.</p>');
  b.writeln('</section>');

  b.writeln(_sendBar());
  b.writeln('<footer class="foot">Generated by <code>kit render board</code> from <code>plan/</code>. Ticks and notes stay in this browser until you press <strong>Send to Claude</strong>; a bubble or a card is the address.</footer>');
  b.writeln(_outboxScript(outbox));
  b.writeln('</main>');
  b.write(_script);
  final fragment = b.toString();
  // The page's own source, so `Send to Claude` can publish a new version of
  // the page with the batch inside it. Base64, so nothing in it can end the
  // block early or be mistaken for markup — the script decodes it.
  return '$fragment<script type="text/plain" id="kit-src">${base64.encode(utf8.encode(fragment))}</script>\n';
}

/// A batch of ticks and notes the viewer has sent but Claude has not yet
/// applied. Rendered into the page so a reload shows what is in flight.
String _outboxScript(String? outbox) => outbox == null
    ? ''
    : '<script type="application/json" id="kit-outbox">${outbox.replaceAll('<', r'\u003c')}</script>';

String _sendBar() => '''
<div class="sendbar" id="sendbar" hidden>
  <span class="sendbar-n" id="sendbar-n"></span>
  <button type="button" class="btn" id="send-clear">Clear</button>
  <button type="button" class="btn primary" id="send-btn">Send to Claude</button>
</div>
<div class="sendbar sendbar-msg" id="sendmsg" hidden><span id="sendmsg-t"></span><button type="button" class="btn" id="sendmsg-x">OK</button></div>
''';

// ---------------------------------------------------------------------------
// Steps tab

String _stepsTab(Plan plan, Graph g, Map<String, StepView> viewById, Map<String, NeedKind> needs) {
  final b = StringBuffer();
  final all = layoutDag(plan.steps);
  final left = layoutDag(plan.steps, include: (s) => s.status != StepStatus.done);

  b.writeln('<div class="graph-bar">');
  b.writeln('<div class="legend">');
  for (final e in const [
    ('done', 'done'),
    ('ready', 'ready'),
    ('active', 'in progress'),
    ('codeComplete', 'waiting on you'),
    ('blocked', 'blocked'),
  ]) {
    b.writeln('<span class="lg"><i class="dot st-${e.$1}"></i>${e.$2}</span>');
  }
  b.writeln('</div>');
  b.writeln('<label class="toggle"><input type="checkbox" id="only-left"> Only what\'s left <span class="tab-count">${left.nodes.length}</span></label>');
  b.writeln('</div>');

  b.writeln('<div class="graph-wrap">');
  b.writeln('<div class="graph-scroll" id="graph-all">');
  b.writeln(_svg(all, viewById, plan));
  b.writeln('</div>');
  b.writeln('<div class="graph-scroll" id="graph-left" hidden>');
  b.writeln(_svg(left, viewById, plan));
  b.writeln('</div>');
  b.writeln('<aside class="detail" id="detail">');
  b.writeln('<p class="detail-empty" id="detail-empty">Tap a bubble. Lines run from what had to happen first to what came after; a bubble\'s own lines light up when it is selected.</p>');
  for (final s in plan.steps) {
    b.writeln(_detailPanel(s, viewById[s.id]!, plan, g, needs));
  }
  b.writeln('</aside>');
  b.writeln('</div>');
  return b.toString();
}

const _r = 22.0;

String _svg(DagLayout lay, Map<String, StepView> viewById, Plan plan) {
  final b = StringBuffer();
  final w = lay.width.ceil();
  final h = lay.height.ceil();
  b.writeln('<svg class="graph" width="$w" height="$h" viewBox="0 0 $w $h" role="img" aria-label="Steps and their dependencies">');
  b.writeln('<g class="edges">');
  for (final (from, to) in lay.edges) {
    final a = lay.nodes[from]!;
    final c = lay.nodes[to]!;
    final x1 = a.x + _r;
    final x2 = c.x - _r;
    final mx = (x1 + x2) / 2;
    b.writeln('<path class="edge" data-from="${escapeHtml(from)}" data-to="${escapeHtml(to)}" d="M${_n(x1)},${_n(a.y)} C${_n(mx)},${_n(a.y)} ${_n(mx)},${_n(c.y)} ${_n(x2)},${_n(c.y)}"/>');
  }
  b.writeln('</g>');
  b.writeln('<g class="nodes">');
  for (final s in plan.steps) {
    final pos = lay.nodes[s.id];
    if (pos == null) continue;
    final v = viewById[s.id]!;
    final cls = _stateKey(v.state);
    final label = s.number ?? '';
    final short = _short(s.title, 20);
    b.writeln('<g class="node st-$cls" data-step="${escapeHtml(s.id)}" tabindex="0" role="button" aria-label="Step ${escapeHtml(label)} — ${escapeHtml(s.title)}, ${_stateLabel(v.state)}" transform="translate(${_n(pos.x)},${_n(pos.y)})">');
    b.writeln('<title>Step ${escapeHtml(label)} — ${escapeHtml(s.title)} (${_stateLabel(v.state)})</title>');
    b.writeln('<circle class="body" r="${_n(_r)}"/>');
    if (v.openBlockers.isNotEmpty && v.state != StepState.done) {
      b.writeln('<circle class="badge" cx="16" cy="-16" r="8"/><text class="badge-n" x="16" y="-12.5">${v.openBlockers.length}</text>');
    }
    b.writeln('<text class="num" y="4.5">${escapeHtml(label)}</text>');
    b.writeln('<text class="lbl" y="${_n(_r + 15)}">${escapeHtml(short)}</text>');
    b.writeln('</g>');
  }
  b.writeln('</g>');
  b.writeln('</svg>');
  return b.toString();
}

String _n(double v) => v.toStringAsFixed(1).replaceFirst(RegExp(r'\.0$'), '');

String _short(String s, int n) => s.length <= n ? s : '${s.substring(0, n - 1).trimRight()}…';

String _stateKey(StepState s) {
  switch (s) {
    case StepState.done:
      return 'done';
    case StepState.ready:
      return 'ready';
    case StepState.active:
      return 'active';
    case StepState.codeComplete:
      return 'codeComplete';
    case StepState.flippable:
      return 'flippable';
    case StepState.blocked:
    case StepState.waiting:
      return 'blocked';
  }
}

/// The panel that opens when a bubble is tapped: what the step waits on,
/// what *you* should do (every item that blocks it, as a runbook), and then
/// what Claude does (the step's own sections), collapsed.
String _detailPanel(Step s, StepView v, Plan plan, Graph g, Map<String, NeedKind> needs) {
  final b = StringBuffer();
  b.writeln('<article class="step-detail" id="step-${escapeHtml(s.id)}" data-step="${escapeHtml(s.id)}" hidden>');
  b.writeln('<div class="sd-head"><code class="num">${escapeHtml(s.number ?? '')}</code><span class="chip ${_stateClass(v.state)}">${_stateLabel(v.state)}</span></div>');
  b.writeln('<h2>${escapeHtml(s.title)}</h2>');
  b.writeln('<p class="sd-id"><code>${escapeHtml(s.id)}</code></p>');

  final waits = <String>[];
  for (final d in v.missingDeps) {
    final dv = d.rank >= 0 ? g.view(d) : null;
    final why = dv == null
        ? 'not in the plan'
        : dv.state == StepState.codeComplete
            ? 'waiting on you'
            : _stateLabel(dv.state);
    waits.add('<li><a href="#step-${escapeHtml(d.id)}" data-step="${escapeHtml(d.id)}">Step ${escapeHtml(d.number ?? d.id)}</a> <span class="why">— ${escapeHtml(d.title)} (${escapeHtml(why)})</span></li>');
  }
  if (waits.isNotEmpty) {
    b.writeln('<h3 class="sd-h">Comes after</h3><ul class="sd-list">${waits.join()}</ul>');
  }
  final dependents = [for (final o in plan.steps) if (o.dependsOn.contains(s.id)) o];
  if (dependents.isNotEmpty) {
    b.writeln('<h3 class="sd-h">Unlocks</h3><ul class="sd-list">');
    for (final o in dependents) {
      b.writeln('<li><a href="#step-${escapeHtml(o.id)}" data-step="${escapeHtml(o.id)}">Step ${escapeHtml(o.number ?? o.id)}</a> <span class="why">— ${escapeHtml(o.title)}</span></li>');
    }
    b.writeln('</ul>');
  }
  if (s.status == StepStatus.active) {
    b.writeln('<h3 class="sd-h">Gates</h3><p class="sd-gates">');
    b.writeln(s.gates.values
        .map((x) => '<span class="chip ${x.status == GateStatus.passed ? 'good' : x.status == GateStatus.failed ? 'critical' : 'muted'}">${escapeHtml(x.name)} · ${x.status.name}</span>')
        .join(' '));
    b.writeln('</p>');
  }

  final items = [for (final i in plan.items) if (i.blocks.contains(s.id)) i];
  final openItems = items.where((i) => i.isOpen).toList();
  final closedItems = items.where((i) => !i.isOpen).toList();
  b.writeln('<h3 class="sd-h">What you should do</h3>');
  if (openItems.isEmpty) {
    b.writeln(v.state == StepState.done
        ? '<p class="sd-none">Nothing — this step is done.</p>'
        : '<p class="sd-none">Nothing on this step is yours. It is Claude\'s to build.</p>');
  } else {
    b.writeln('<div class="cards">');
    for (final i in openItems) {
      b.writeln(_itemCard(i, needs, g, flip: v.state == StepState.codeComplete));
    }
    b.writeln('</div>');
  }
  if (closedItems.isNotEmpty) {
    b.writeln('<details class="more"><summary>${closedItems.length} already handled</summary><ul class="sd-list">');
    for (final i in closedItems) {
      b.writeln('<li class="${i.status == ItemStatus.dropped ? 'dropped' : 'closed'}">${inlineMd(i.title)}${i.doneAt != null ? ' <span class="why">${escapeHtml(i.doneAt!)}</span>' : ''}</li>');
    }
    b.writeln('</ul></details>');
  }

  if (s.sections.isNotEmpty) {
    b.writeln('<details class="more sd-spec"><summary>What Claude does — the step\'s own spec</summary><div class="body">');
    for (final sec in s.sections) {
      final body = sec.body.replaceAll(humanBoxesMarker, '');
      if (body.trim().isEmpty) continue;
      b.writeln('<h3>${escapeHtml(sec.title)}</h3>');
      b.writeln(mdToHtml(body));
    }
    b.writeln('</div></details>');
  }
  b.writeln('<div class="act act-step" data-step="${escapeHtml(s.id)}"><input class="act-note" type="text" maxlength="500" placeholder="Note to Claude about this step (optional)" aria-label="Note to Claude about step ${escapeHtml(s.id)}"><span class="sent-chip chip warn" hidden>Sent · waiting for Claude</span></div>');
  if (s.history.isNotEmpty) {
    b.writeln('<p class="sd-hist">${s.history.map((h) => '${escapeHtml(h.at)} ${escapeHtml(h.event)}').join(' · ')}</p>');
  }
  b.writeln('</article>');
  return b.toString();
}

// ---------------------------------------------------------------------------
// Shared pieces

String _stat(String big, String label) =>
    '<div class="stat"><span class="stat-n">${escapeHtml(big)}</span><span class="stat-l">${escapeHtml(label)}</span></div>';

String _sectionHead(String title, String sub) =>
    '<div class="section-head"><h2>${escapeHtml(title)}</h2><p>${escapeHtml(sub)}</p></div>';

String _stateLabel(StepState s) {
  switch (s) {
    case StepState.done:
      return 'done';
    case StepState.blocked:
      return 'blocked';
    case StepState.ready:
      return 'ready to start';
    case StepState.active:
      return 'in progress';
    case StepState.codeComplete:
      return 'code complete, waiting on you';
    case StepState.flippable:
      return 'nothing left in the way';
    case StepState.waiting:
      return 'waiting';
  }
}

String _stateClass(StepState s) {
  switch (s) {
    case StepState.done:
      return 'good';
    case StepState.ready:
    case StepState.active:
      return 'accent';
    case StepState.codeComplete:
    case StepState.flippable:
      return 'warn';
    case StepState.blocked:
    case StepState.waiting:
      return 'muted';
  }
}

String _itemCard(Item i, Map<String, NeedKind> needs, Graph g, {bool flip = false}) {
  final b = StringBuffer();
  b.writeln('<article class="card${flip ? ' flip' : ''}" id="item-${escapeHtml(i.id)}">');
  b.writeln('<div class="card-head">');
  b.writeln('<div class="chips">');
  for (final n in i.needs) {
    b.writeln('<span class="chip need">${escapeHtml(needs[n]?.label ?? n)}</span>');
  }
  if (i.deadline != null) b.writeln('<span class="chip critical">by ${escapeHtml(i.deadline!)}</span>');
  for (final s in i.blocks) {
    final v = g.plan.step(s);
    if (v == null) continue;
    final cls = flip ? 'warn' : 'muted';
    b.writeln('<a class="chip $cls" href="#step-${escapeHtml(v.id)}" data-step="${escapeHtml(v.id)}">${flip ? 'flips' : 'gates'} ${escapeHtml(v.number != null ? 'Step ${v.number}' : v.id)}</a>');
  }
  b.writeln('</div>');
  b.writeln('<h3>${inlineMd(i.title)}</h3>');
  b.writeln('</div>');

  if (i.question != null) {
    final q = i.question!;
    b.writeln('<div class="question">');
    b.writeln('<p class="ask">${inlineMd(q.ask)}</p>');
    if (q.options.isNotEmpty) {
      final opts = [...q.options]..sort((a, c) => (c.recommended ? 1 : 0) - (a.recommended ? 1 : 0));
      b.writeln('<ol class="options">');
      for (final o in opts) {
        b.writeln('<li${o.recommended ? ' class="rec"' : ''} data-opt="${escapeHtml(o.label)}" tabindex="0" role="button"><span class="opt-label">${inlineMd(o.label)}</span>${o.recommended ? '<span class="chip accent">recommended</span>' : ''}${o.why != null ? '<span class="opt-why">${inlineMd(o.why!)}</span>' : ''}</li>');
      }
      b.writeln('</ol>');
    }
    if (q.answer != null) b.writeln('<p class="answer">Answered: ${inlineMd(q.answer!)}</p>');
    b.writeln('</div>');
  }

  if (i.runbook.isNotEmpty) {
    b.writeln('<ol class="runbook">');
    for (final r in i.runbook) {
      b.writeln('<li><span class="do">${inlineMd(r.doText)}</span>');
      if (r.expect != null) b.writeln('<span class="expect"><b>Expect</b> ${inlineMd(r.expect!)}</span>');
      if (r.ifFails != null) b.writeln('<span class="if-fails"><b>If not</b> ${inlineMd(r.ifFails!)}</span>');
      if (r.verify != null) b.writeln('<span class="verify"><b>Verify</b> <code>${escapeHtml(r.verify!)}</code></span>');
      b.writeln('</li>');
    }
    b.writeln('</ol>');
  }

  if (i.body.trim().isNotEmpty) {
    final short = i.body.trim().length < 420 && !i.body.contains('\n\n');
    if (short) {
      b.writeln('<div class="body">${mdToHtml(i.body)}</div>');
    } else {
      b.writeln('<details class="more"><summary>The whole entry</summary><div class="body">${mdToHtml(i.body)}</div></details>');
    }
  }

  if (i.isOpen) {
    b.writeln('<div class="act" data-item="${escapeHtml(i.id)}">');
    b.writeln('<label class="tick"><input type="checkbox" data-act="done"> Done</label>');
    b.writeln('<label class="tick"><input type="checkbox" data-act="drop"> Not doing</label>');
    b.writeln('<input class="act-note" type="text" maxlength="500" placeholder="Note to Claude (optional)" aria-label="Note to Claude about ${escapeHtml(i.id)}">');
    b.writeln('<span class="sent-chip chip warn" hidden>Sent · waiting for Claude</span>');
    b.writeln('</div>');
  }
  b.writeln('<div class="card-foot"><code class="id">${escapeHtml(i.id)}</code>');
  if (i.added != null) b.writeln('<span class="when">added ${escapeHtml(i.added!)}</span>');
  if (i.step != null) b.writeln('<span class="when">from ${escapeHtml(i.step!)}</span>');
  b.writeln('</div>');
  b.writeln('</article>');
  return b.toString();
}

String _fontLink(Map<String, String> fonts) {
  final fams = <String>{};
  for (final f in fonts.values) {
    fams.add(f);
  }
  final q = fams.map((f) => 'family=${Uri.encodeQueryComponent(f).replaceAll('%20', '+')}:wght@400;500;600;700').join('&');
  return '<link rel="preconnect" href="https://fonts.googleapis.com"><link rel="stylesheet" href="https://fonts.googleapis.com/css2?$q&display=swap">';
}

String _tokens(Map<String, String> c) => [
      for (final e in c.entries) '  --${e.key.replaceAll('_', '-')}: ${e.value};',
    ].join('\n');

String _css(Map<String, String> light, Map<String, String> dark, Map<String, String> fonts) {
  final display = fonts['display']!;
  final body = fonts['body']!;
  final mono = fonts['mono']!;
  return '''
:root {
${_tokens(light)}
  --display: "$display", "Helvetica Neue", Arial, sans-serif;
  --body: "$body", "Helvetica Neue", Arial, sans-serif;
  --mono: "$mono", ui-monospace, SFMono-Regular, Menlo, monospace;
  --radius: 14px;
  --shadow: 0 1px 2px rgba(0,0,0,.04), 0 10px 30px -18px rgba(0,0,0,.25);
}
@media (prefers-color-scheme: dark) {
  :root:not([data-theme="light"]) {
${_tokens(dark)}
    --shadow: 0 1px 2px rgba(0,0,0,.5), 0 10px 30px -18px rgba(0,0,0,.8);
  }
}
:root[data-theme="dark"] {
${_tokens(dark)}
  --shadow: 0 1px 2px rgba(0,0,0,.5), 0 10px 30px -18px rgba(0,0,0,.8);
}
* { box-sizing: border-box; }
body { margin: 0; background: var(--bg); color: var(--ink); font-family: var(--body); font-size: 16px; line-height: 1.5; -webkit-font-smoothing: antialiased; }
a { color: var(--accent); }
code { font-family: var(--mono); font-size: .86em; background: var(--line); padding: .08em .35em; border-radius: 6px; }
pre { background: var(--surface); border: 1px solid var(--line); border-radius: 10px; padding: 12px 14px; overflow-x: auto; }
pre code { background: none; padding: 0; font-size: .82em; }
.board { max-width: 1180px; margin: 0 auto; padding: 36px 20px 80px; display: flex; flex-direction: column; gap: 22px; }
.head { display: flex; flex-direction: column; gap: 12px; }
.eyebrow { margin: 0; font-family: var(--mono); font-size: 12px; letter-spacing: .06em; text-transform: uppercase; color: var(--muted); }
h1 { margin: 0; font-family: var(--display); font-weight: 700; font-size: clamp(32px, 5vw, 48px); line-height: 1; letter-spacing: -.02em; text-wrap: balance; }
h2 { margin: 0; font-family: var(--display); font-weight: 700; font-size: 24px; line-height: 1.1; letter-spacing: -.01em; text-wrap: balance; }
h3 { margin: 0; font-family: var(--body); font-weight: 600; font-size: 17px; line-height: 1.3; text-wrap: balance; }
.strip { display: grid; grid-template-columns: repeat(auto-fit, minmax(150px, 1fr)); gap: 10px; margin-top: 4px; }
.stat { background: var(--surface); border: 1px solid var(--line); border-radius: var(--radius); padding: 12px 16px; display: flex; flex-direction: column; gap: 2px; }
.stat-n { font-family: var(--display); font-size: 26px; font-weight: 700; letter-spacing: -.02em; font-variant-numeric: tabular-nums; }
.stat-l { font-size: 13px; color: var(--muted); }
.next { margin: 0; color: var(--ink2); }
.next a { color: inherit; text-decoration: none; border-bottom: 1px solid var(--accent); }
.tabs { display: flex; gap: 4px; border-bottom: 1px solid var(--line); }
.tab { appearance: none; background: none; border: 0; border-bottom: 2px solid transparent; margin-bottom: -1px; padding: 10px 14px; font: inherit; font-weight: 600; color: var(--muted); cursor: pointer; }
.tab[aria-selected="true"] { color: var(--ink); border-bottom-color: var(--accent); }
.tab-count { display: inline-block; margin-left: 6px; font-family: var(--mono); font-size: 12px; font-weight: 500; color: var(--muted); }
.pane { display: flex; flex-direction: column; gap: 20px; }
.pane[hidden] { display: none; }
.empty { color: var(--muted); }
.section-head { display: flex; flex-direction: column; gap: 4px; margin-top: 8px; }
.section-head p { margin: 0; color: var(--muted); max-width: 62ch; }
.cards { display: flex; flex-direction: column; gap: 12px; }
.card { background: var(--surface); border: 1px solid var(--line); border-radius: var(--radius); padding: 16px 18px 12px; box-shadow: var(--shadow); display: flex; flex-direction: column; gap: 10px; }
.card.flip { border-color: var(--warn); }
.card:target { outline: 2px solid var(--accent); outline-offset: 2px; }
.card-head { display: flex; flex-direction: column; gap: 8px; }
.chips { display: flex; flex-wrap: wrap; gap: 6px; }
.chip { display: inline-block; font-size: 12px; font-weight: 600; letter-spacing: .01em; padding: 2px 9px; border-radius: 999px; background: var(--line); color: var(--ink2); white-space: nowrap; text-decoration: none; }
.chip.need { background: var(--accent-soft); color: var(--accent); }
.chip.accent { background: var(--accent-soft); color: var(--accent); }
.chip.warn { background: var(--warn-soft); color: var(--warn); }
.chip.good { background: var(--good-soft); color: var(--good); }
.chip.critical { background: var(--critical-soft); color: var(--critical); }
.chip.muted { background: var(--line); color: var(--muted); }
.question { background: var(--bg); border-radius: 10px; padding: 12px 14px; display: flex; flex-direction: column; gap: 8px; }
.ask { margin: 0; font-weight: 500; }
.options { margin: 0; padding-left: 0; list-style: none; display: flex; flex-direction: column; gap: 6px; }
.options li { display: flex; flex-wrap: wrap; align-items: baseline; gap: 6px 10px; padding: 8px 10px; border: 1px solid var(--line); border-radius: 8px; background: var(--surface); }
.options li.rec { border-color: var(--accent); }
.opt-label { font-weight: 600; }
.opt-why { flex-basis: 100%; font-size: 14px; color: var(--ink2); }
.answer { margin: 0; color: var(--good); font-weight: 500; }
.runbook { margin: 0; padding-left: 22px; display: flex; flex-direction: column; gap: 8px; }
.runbook li { display: flex; flex-direction: column; gap: 2px; }
.runbook .expect, .runbook .if-fails, .runbook .verify { font-size: 14px; color: var(--ink2); }
.runbook b { font-weight: 600; color: var(--muted); font-size: 12px; letter-spacing: .04em; text-transform: uppercase; margin-right: 4px; }
.body { font-size: 15px; color: var(--ink2); max-width: 68ch; }
.body p { margin: 0 0 .7em; }
.body p:last-child { margin-bottom: 0; }
.body ul, .body ol { margin: .3em 0 .7em; padding-left: 22px; }
.body li.todo::marker { content: "☐  "; }
.body li.done::marker { content: "☑  "; }
.body h3, .body h4, .body h5 { margin: .8em 0 .3em; font-size: 15px; }
.body blockquote { margin: .4em 0; padding: 2px 12px; border-left: 3px solid var(--line); color: var(--muted); }
details.more > summary { cursor: pointer; font-size: 14px; color: var(--accent); font-weight: 500; }
details.more[open] > summary { margin-bottom: 8px; }
.card-foot { display: flex; flex-wrap: wrap; gap: 12px; align-items: center; border-top: 1px solid var(--line); padding-top: 8px; font-size: 12px; color: var(--muted); }
.card-foot .id { background: none; padding: 0; color: var(--muted); font-size: 12px; }
.sitting { border: 1px solid var(--line); border-radius: var(--radius); background: var(--surface); }
.sitting > summary { cursor: pointer; list-style: none; display: grid; grid-template-columns: auto auto 1fr; align-items: baseline; gap: 4px 12px; padding: 14px 18px; }
.sitting > summary::-webkit-details-marker { display: none; }
.sitting > summary::before { content: "▸"; color: var(--muted); grid-row: 1 / span 2; align-self: start; margin-right: -4px; }
.sitting[open] > summary::before { content: "▾"; }
.sitting-title { font-family: var(--display); font-weight: 700; font-size: 20px; letter-spacing: -.01em; }
.count { font-family: var(--mono); font-size: 13px; color: var(--muted); }
.sitting-desc { grid-column: 2 / span 2; font-size: 14px; color: var(--muted); }
.sitting > .cards { padding: 0 12px 12px; }
.sitting > .cards .card { box-shadow: none; background: var(--bg); }
.graph-bar { display: flex; flex-wrap: wrap; align-items: center; justify-content: space-between; gap: 10px 18px; }
.legend { display: flex; flex-wrap: wrap; gap: 6px 14px; font-size: 13px; color: var(--ink2); }
.lg { display: inline-flex; align-items: center; gap: 6px; }
.dot { width: 12px; height: 12px; border-radius: 50%; border: 2px solid var(--muted); background: var(--surface); display: inline-block; }
.dot.st-done { background: var(--line); border-color: var(--line); }
.dot.st-ready { background: var(--accent); border-color: var(--accent); }
.dot.st-active { background: var(--surface); border-color: var(--accent); }
.dot.st-codeComplete { background: var(--warn); border-color: var(--warn); }
.dot.st-blocked { background: var(--surface); border-color: var(--muted); }
.toggle { display: inline-flex; align-items: center; gap: 8px; font-size: 14px; color: var(--ink2); cursor: pointer; user-select: none; }
.toggle input { accent-color: var(--accent); width: 16px; height: 16px; }
.graph-wrap { display: grid; grid-template-columns: minmax(0, 1fr) 400px; gap: 16px; align-items: start; }
.graph-scroll { overflow: auto; background: var(--surface); border: 1px solid var(--line); border-radius: var(--radius); max-height: 72vh; }
.graph-scroll[hidden] { display: none; }
.graph { display: block; font-family: var(--body); }
.edge { fill: none; stroke: var(--line); stroke-width: 1.5; transition: stroke .15s, stroke-width .15s, opacity .15s; }
.graph.has-sel .edge { opacity: .3; }
.graph.has-sel .edge.lit { opacity: 1; stroke: var(--accent); stroke-width: 2.5; }
.node { cursor: pointer; outline: none; }
.node .body { fill: var(--surface); stroke: var(--muted); stroke-width: 2; }
.node.st-done .body { fill: var(--line); stroke: var(--line); }
.node.st-ready .body { fill: var(--accent); stroke: var(--accent); }
.node.st-active .body { fill: var(--surface); stroke: var(--accent); stroke-width: 3; }
.node.st-codeComplete .body { fill: var(--warn); stroke: var(--warn); }
.node.st-flippable .body { fill: var(--good); stroke: var(--good); }
.node.st-blocked .body { fill: var(--surface); stroke: var(--muted); stroke-dasharray: 3 3; }
.node .num { font-family: var(--mono); font-size: 12px; font-weight: 700; text-anchor: middle; fill: var(--ink); pointer-events: none; }
.node.st-ready .num, .node.st-codeComplete .num, .node.st-flippable .num { fill: #fff; }
.node.st-done .num { fill: var(--ink2); }
.node .lbl { font-size: 11px; text-anchor: middle; fill: var(--muted); pointer-events: none; }
.node.st-done .lbl { opacity: .7; }
.node .badge { fill: var(--critical); stroke: var(--surface); stroke-width: 2; }
.node .badge-n { font-family: var(--mono); font-size: 10px; font-weight: 700; fill: #fff; text-anchor: middle; pointer-events: none; }
.node.sel .body, .node:focus-visible .body { stroke: var(--ink); stroke-width: 3; }
.graph.has-sel .node:not(.sel):not(.near) { opacity: .4; }
.detail { position: sticky; top: 12px; background: var(--surface); border: 1px solid var(--line); border-radius: var(--radius); padding: 18px; max-height: 72vh; overflow: auto; display: flex; flex-direction: column; gap: 10px; }
.detail-empty { margin: 0; color: var(--muted); font-size: 14px; }
.step-detail { display: flex; flex-direction: column; gap: 10px; }
.step-detail[hidden] { display: none; }
.sd-head { display: flex; align-items: center; gap: 10px; }
.step-detail h2 { font-size: 22px; }
.sd-id { margin: -4px 0 0; }
.sd-id code { background: none; padding: 0; color: var(--muted); font-size: 12px; }
.sd-h { margin: 6px 0 0; font-family: var(--mono); font-size: 11px; font-weight: 600; letter-spacing: .06em; text-transform: uppercase; color: var(--muted); }
.sd-list { margin: 0; padding-left: 18px; font-size: 14px; display: flex; flex-direction: column; gap: 4px; }
.sd-list li.closed { color: var(--muted); }
.sd-list li.dropped { color: var(--muted); text-decoration: line-through; }
.why { color: var(--muted); }
.sd-none { margin: 0; color: var(--muted); font-size: 14px; }
.sd-gates { margin: 0; display: flex; flex-wrap: wrap; gap: 6px; }
.sd-spec .body { font-size: 14px; }
.sd-spec .body h3 { font-family: var(--mono); font-size: 11px; letter-spacing: .06em; text-transform: uppercase; color: var(--muted); }
.sd-hist { margin: 4px 0 0; font-family: var(--mono); font-size: 11px; color: var(--muted); }
.detail .card { box-shadow: none; background: var(--bg); padding: 12px 14px 10px; }
.foot { font-size: 13px; color: var(--muted); border-top: 1px solid var(--line); padding-top: 16px; }
.act { display: flex; flex-wrap: wrap; align-items: center; gap: 8px 14px; padding-top: 4px; }
.act .tick { display: inline-flex; align-items: center; gap: 6px; font-size: 14px; cursor: pointer; user-select: none; }
.act .tick input { accent-color: var(--accent); width: 16px; height: 16px; margin: 0; }
.act-note { flex: 1 1 220px; min-width: 0; font: inherit; font-size: 14px; padding: 6px 10px; border: 1px solid var(--line); border-radius: 8px; background: var(--surface); color: var(--ink); }
.act-note:focus { border-color: var(--accent); outline: none; }
.card.drafted { border-color: var(--accent); }
.card.sent { opacity: .7; }
.card.sent .act .tick, .card.sent .act-note { display: none; }
.options li[data-opt] { cursor: pointer; }
.options li.chosen { background: var(--accent-soft); border-color: var(--accent); }
.options li.chosen .opt-label::after { content: " ✓"; color: var(--accent); }
.sendbar { position: sticky; bottom: 12px; z-index: 5; display: flex; flex-wrap: wrap; align-items: center; gap: 10px; padding: 10px 14px; background: var(--ink); color: var(--bg); border-radius: 999px; box-shadow: var(--shadow); }
.sendbar[hidden] { display: none; }
.sendbar-n { flex: 1; font-weight: 600; font-size: 14px; }
.sendbar-msg { background: var(--surface); color: var(--ink); border: 1px solid var(--line); border-radius: 14px; }
.btn { appearance: none; font: inherit; font-size: 14px; font-weight: 600; padding: 7px 14px; border-radius: 999px; border: 1px solid var(--line); background: var(--surface); color: var(--ink); cursor: pointer; }
.btn.primary { background: var(--accent); border-color: var(--accent); color: #fff; }
.btn[disabled] { opacity: .5; cursor: default; }
:focus-visible { outline: 2px solid var(--accent); outline-offset: 2px; }
@media (max-width: 900px) { .graph-wrap { grid-template-columns: 1fr; } .graph-scroll { max-height: 52vh; } .detail { position: static; max-height: none; } }
@media (max-width: 560px) { .board { padding: 28px 14px 60px; } .card { padding: 14px 14px 10px; } }
''';
}

const _script = r'''
<script>
(function () {
  var store = { get: function (k) { try { return localStorage.getItem(k); } catch (e) { return null; } },
                set: function (k, v) { try { localStorage.setItem(k, v); } catch (e) {} } };

  // Tabs.
  var tabs = document.querySelectorAll('.tab');
  function showTab(name) {
    for (var i = 0; i < tabs.length; i++) tabs[i].setAttribute('aria-selected', tabs[i].getAttribute('data-tab') === name ? 'true' : 'false');
    var panes = document.querySelectorAll('.pane');
    for (var j = 0; j < panes.length; j++) panes[j].hidden = panes[j].getAttribute('data-pane') !== name;
    store.set('kit-board-tab', name);
  }
  for (var t = 0; t < tabs.length; t++) tabs[t].addEventListener('click', function (ev) { showTab(ev.currentTarget.getAttribute('data-tab')); });

  // Graph selection: light the selected bubble's lines, dim the rest, open its panel.
  var selected = null;
  function select(id, scroll) {
    selected = id;
    var svgs = document.querySelectorAll('svg.graph');
    for (var s = 0; s < svgs.length; s++) {
      var svg = svgs[s];
      var near = {};
      var edges = svg.querySelectorAll('.edge');
      for (var e = 0; e < edges.length; e++) {
        var ed = edges[e];
        var lit = !!id && (ed.getAttribute('data-from') === id || ed.getAttribute('data-to') === id);
        ed.classList.toggle('lit', lit);
        if (lit) { near[ed.getAttribute('data-from')] = true; near[ed.getAttribute('data-to')] = true; }
      }
      var nodes = svg.querySelectorAll('.node');
      for (var n = 0; n < nodes.length; n++) {
        var nid = nodes[n].getAttribute('data-step');
        nodes[n].classList.toggle('sel', nid === id);
        nodes[n].classList.toggle('near', !!near[nid]);
      }
      svg.classList.toggle('has-sel', !!id);
      if (scroll && id) {
        var target = svg.querySelector('.node[data-step="' + id + '"]');
        if (target && !svg.parentNode.hidden && target.scrollIntoView) target.scrollIntoView({ block: 'nearest', inline: 'center' });
      }
    }
    var panels = document.querySelectorAll('.step-detail');
    for (var p = 0; p < panels.length; p++) panels[p].hidden = panels[p].getAttribute('data-step') !== id;
    document.getElementById('detail-empty').hidden = !!id;
    if (id) store.set('kit-board-step', id);
  }
  document.addEventListener('click', function (ev) {
    var node = ev.target.closest ? ev.target.closest('.node') : null;
    if (node) { select(node.getAttribute('data-step'), false); return; }
    var link = ev.target.closest ? ev.target.closest('a[data-step]') : null;
    if (link) {
      ev.preventDefault();
      showTab('steps');
      select(link.getAttribute('data-step'), true);
      var d = document.getElementById('detail'); if (d && d.scrollTo) d.scrollTo(0, 0);
    }
  });
  document.addEventListener('keydown', function (ev) {
    if ((ev.key === 'Enter' || ev.key === ' ') && ev.target.classList && ev.target.classList.contains('node')) {
      ev.preventDefault();
      select(ev.target.getAttribute('data-step'), false);
    }
  });

  // Only what's left.
  var only = document.getElementById('only-left');
  function applyOnly() {
    var on = only.checked;
    document.getElementById('graph-all').hidden = on;
    document.getElementById('graph-left').hidden = !on;
    store.set('kit-board-only-left', on ? '1' : '0');
    if (selected) select(selected, true);
  }
  only.addEventListener('change', applyOnly);

  // Sittings remember whether they were open, per viewer.
  var openMap = {};
  try { openMap = JSON.parse(store.get('kit-board-open') || '{}') || {}; } catch (e) { openMap = {}; }
  var sittings = document.querySelectorAll('details.sitting');
  for (var i = 0; i < sittings.length; i++) {
    var d = sittings[i];
    var sid = d.getAttribute('data-sitting');
    if (openMap[sid] === true) d.open = true;
    if (i === 0 && openMap[sid] === undefined) d.open = true;
    d.addEventListener('toggle', function (ev) {
      var el = ev.target;
      openMap[el.getAttribute('data-sitting')] = el.open;
      store.set('kit-board-open', JSON.stringify(openMap));
    });
  }

  // Restore: a hash wins, then what this viewer had before.
  var hash = location.hash || '';
  if (hash.indexOf('#step-') === 0) { showTab('steps'); select(hash.substring(6), true); }
  else if (hash.indexOf('#item-') === 0) { showTab('work'); }
  else {
    showTab(store.get('kit-board-tab') || 'steps');
    var prev = store.get('kit-board-step');
    if (prev && document.querySelector('.node[data-step="' + prev + '"]')) select(prev, true);
  }
  if (store.get('kit-board-only-left') === '1') { only.checked = true; applyOnly(); }

  // ---- Ticks, answers and notes: a draft in this browser until "Send to Claude".
  var DKEY = 'kit-draft';
  var draft = { items: {}, steps: {} };
  try { draft = JSON.parse(store.get(DKEY) || '') || draft; } catch (e) {}
  if (!draft.items) draft.items = {};
  if (!draft.steps) draft.steps = {};

  var outbox = null;
  var ob = document.getElementById('kit-outbox');
  if (ob) { try { outbox = JSON.parse(ob.textContent); } catch (e) { outbox = null; } }
  var sentItems = {}, sentSteps = {};
  if (outbox && outbox.entries) {
    for (var q = 0; q < outbox.entries.length; q++) {
      var en = outbox.entries[q];
      if (en.kind === 'item') sentItems[en.id] = true; else if (en.kind === 'step') sentSteps[en.id] = true;
    }
  }

  function itemDraft(id) { return draft.items[id] || (draft.items[id] = { action: null, answer: null, note: '' }); }
  function pruneDraft() {
    for (var k in draft.items) { var d = draft.items[k]; if (!d.action && !d.answer && !(d.note && d.note.trim())) delete draft.items[k]; }
    for (var k2 in draft.steps) { if (!(draft.steps[k2] && draft.steps[k2].trim())) delete draft.steps[k2]; }
  }
  function saveDraft() { pruneDraft(); store.set(DKEY, JSON.stringify(draft)); paintBar(); }
  function draftCount() { pruneDraft(); return Object.keys(draft.items).length + Object.keys(draft.steps).length; }

  var bar = document.getElementById('sendbar');
  var barN = document.getElementById('sendbar-n');
  var sendBtn = document.getElementById('send-btn');
  var msg = document.getElementById('sendmsg');
  var msgT = document.getElementById('sendmsg-t');
  function say(text) { msgT.textContent = text; msg.hidden = false; }
  document.getElementById('sendmsg-x').addEventListener('click', function () { msg.hidden = true; });
  function paintBar() {
    var n = draftCount();
    bar.hidden = n === 0;
    barN.textContent = n === 1 ? '1 change waiting' : n + ' changes waiting';
  }

  // Paint every control from the draft and the outbox.
  var acts = document.querySelectorAll('.act[data-item]');
  for (var a = 0; a < acts.length; a++) {
    (function (act) {
      var id = act.getAttribute('data-item');
      var card = act.closest('.card');
      var done = act.querySelector('input[data-act="done"]');
      var drop = act.querySelector('input[data-act="drop"]');
      var note = act.querySelector('.act-note');
      var chip = act.querySelector('.sent-chip');
      if (sentItems[id]) { card.classList.add('sent'); chip.hidden = false; return; }
      var d = draft.items[id];
      if (d) {
        done.checked = d.action === 'done';
        drop.checked = d.action === 'drop';
        note.value = d.note || '';
        if (d.answer) { var li = card.querySelector('.options li[data-opt="' + d.answer.replace(/"/g, '\\"') + '"]'); if (li) li.classList.add('chosen'); }
        card.classList.add('drafted');
      }
      done.addEventListener('change', function () { var x = itemDraft(id); x.action = done.checked ? 'done' : null; if (done.checked) drop.checked = false; card.classList.toggle('drafted', !!(x.action || x.answer || x.note)); saveDraft(); });
      drop.addEventListener('change', function () { var x = itemDraft(id); x.action = drop.checked ? 'drop' : null; if (drop.checked) done.checked = false; card.classList.toggle('drafted', !!(x.action || x.answer || x.note)); saveDraft(); });
      note.addEventListener('input', function () { var x = itemDraft(id); x.note = note.value; card.classList.toggle('drafted', !!(x.action || x.answer || x.note.trim())); saveDraft(); });
      var opts = card.querySelectorAll('.options li[data-opt]');
      for (var o = 0; o < opts.length; o++) {
        opts[o].addEventListener('click', function (ev) {
          var li = ev.currentTarget; var label = li.getAttribute('data-opt');
          var x = itemDraft(id);
          var was = li.classList.contains('chosen');
          for (var z = 0; z < opts.length; z++) opts[z].classList.remove('chosen');
          if (!was) { li.classList.add('chosen'); x.answer = label; } else { x.answer = null; }
          card.classList.toggle('drafted', !!(x.action || x.answer || (x.note && x.note.trim())));
          saveDraft();
        });
        opts[o].addEventListener('keydown', function (ev) { if (ev.key === 'Enter' || ev.key === ' ') { ev.preventDefault(); ev.currentTarget.click(); } });
      }
    })(acts[a]);
  }
  var sacts = document.querySelectorAll('.act[data-step]');
  for (var sa = 0; sa < sacts.length; sa++) {
    (function (act) {
      var id = act.getAttribute('data-step');
      var note = act.querySelector('.act-note');
      var chip = act.querySelector('.sent-chip');
      if (sentSteps[id]) { chip.hidden = false; note.disabled = true; note.placeholder = 'Sent — waiting for Claude'; return; }
      if (draft.steps[id]) note.value = draft.steps[id];
      note.addEventListener('input', function () { draft.steps[id] = note.value; saveDraft(); });
    })(sacts[sa]);
  }
  paintBar();

  document.getElementById('send-clear').addEventListener('click', function () {
    draft = { items: {}, steps: {} };
    store.set(DKEY, JSON.stringify(draft));
    var boxes = document.querySelectorAll('.act input[type="checkbox"]'); for (var i2 = 0; i2 < boxes.length; i2++) boxes[i2].checked = false;
    var notes = document.querySelectorAll('.act-note'); for (var i3 = 0; i3 < notes.length; i3++) if (!notes[i3].disabled) notes[i3].value = '';
    var ch = document.querySelectorAll('.options li.chosen'); for (var i4 = 0; i4 < ch.length; i4++) ch[i4].classList.remove('chosen');
    var dr = document.querySelectorAll('.card.drafted'); for (var i5 = 0; i5 < dr.length; i5++) dr[i5].classList.remove('drafted');
    paintBar();
  });

  function batch() {
    pruneDraft();
    var entries = (outbox && outbox.entries) ? outbox.entries.slice() : [];
    for (var k in draft.items) { var d = draft.items[k]; entries.push({ kind: 'item', id: k, action: d.action || null, answer: d.answer || null, note: (d.note || '').trim() || null }); }
    for (var k2 in draft.steps) { entries.push({ kind: 'step', id: k2, note: draft.steps[k2].trim() }); }
    return { sentAt: new Date().toISOString(), entries: entries };
  }
  function b64decode(str) {
    var bin = atob(str.replace(/\s+/g, ''));
    var bytes = new Uint8Array(bin.length);
    for (var i = 0; i < bin.length; i++) bytes[i] = bin.charCodeAt(i);
    return new TextDecoder().decode(bytes);
  }
  function b64encode(str) {
    var bytes = new TextEncoder().encode(str);
    var bin = '';
    for (var i = 0; i < bytes.length; i += 8192) bin += String.fromCharCode.apply(null, bytes.subarray(i, i + 8192));
    return btoa(bin);
  }
  function pageWith(batchObj) {
    var srcEl = document.getElementById('kit-src');
    if (!srcEl) return null;
    var src = b64decode(srcEl.textContent);
    // JSON inside a script block: the only sequence that could end it is
    // "</script", and JSON.stringify never emits "<" unescaped here because
    // we escape it ourselves.
    var json = JSON.stringify(batchObj).replace(/</g, '\\u003c');
    var tag = '<script type="application/json" id="kit-outbox">' + json + '</' + 'script>';
    var at = src.lastIndexOf('</main>');
    if (at < 0) return null;
    var frag = src.substring(0, at) + tag + '\n' + src.substring(at);
    return '<!doctype html>\n<html lang="en">\n<head>\n<meta charset="utf-8">\n</head>\n<body>\n' + frag + '<script type="text/plain" id="kit-src">' + b64encode(src) + '</' + 'script>\n</body>\n</html>\n';
  }

  sendBtn.addEventListener('click', function () {
    if (draftCount() === 0) return;
    sendBtn.disabled = true; sendBtn.textContent = 'Sending…';
    var b = batch();
    var html = pageWith(b);
    if (!html) { say('This page cannot rebuild itself — tell Claude what you ticked.'); sendBtn.disabled = false; sendBtn.textContent = 'Send to Claude'; return; }
    var cap = (window.claude && window.claude.use) ? window.claude.use('artifact') : Promise.resolve(null);
    cap.then(function (artifact) {
      if (!artifact) { say('Sending is not available in this view. Your ticks are kept here — open the page on claude.ai to send, or tell Claude directly.'); sendBtn.disabled = false; sendBtn.textContent = 'Send to Claude'; return; }
      return artifact.publish(html).then(function () {
        draft = { items: {}, steps: {} };
        store.set(DKEY, JSON.stringify(draft));
        // The view reloads to the new version; nothing more to do here.
      }, function (err) {
        var code = err && err.code;
        if (code === 'conflict') { say('Claude published a newer version first. Your ticks are kept — after the reload, press Send again.'); }
        else if (code === 'not_writer' || code === 'not_granted' || code === 'not_declared') { say('This view cannot write the page. Your ticks are kept here; tell Claude directly.'); }
        else if (code === 'rate_limited') { say('Too many sends in a row. Wait a minute and press Send once.'); }
        else { say('Send failed (' + (code || 'unknown') + '). Your ticks are kept; try once more in a moment.'); }
        sendBtn.disabled = false; sendBtn.textContent = 'Send to Claude';
      });
    });
  });
})();
</script>
''';
