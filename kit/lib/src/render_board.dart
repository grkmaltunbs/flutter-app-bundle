/// The board: one page that answers "what is waiting on me, and what would
/// it unblock". Generated from the plan, never hand-curated — which is what
/// stopped the last one from going stale the day after it was written.
///
/// Sections, in reading order:
///  1. a summary strip;
///  2. items that would flip a step *today* (the last open box on a step
///     whose code is finished);
///  3. decisions — items carrying a question, recommended option first;
///  4. sittings — every other open item, grouped by what it needs;
///  5. items Claude could not classify, called out as a review task;
///  6. the steps left, with what each one waits on.
///
/// Every item is anchored by its id, so a one-word comment on the published
/// page is unambiguous once you see what it is attached to.
library;

import 'graph.dart';
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

String renderBoardHtml(Plan plan, {required String today}) {
  final m = plan.manifest;
  final g = Graph(plan);
  final needs = m.needs;
  final light = {..._defaultLight, ...?m.boardColors['light']};
  final dark = {..._defaultDark, ...?m.boardColors['dark']};
  final fonts = {..._defaultFonts, ...m.boardFonts};
  final title = m.boardTitle ?? '${m.projectName} Board';

  final views = g.views();
  final done = views.where((v) => v.state == StepState.done).length;
  final left = views.where((v) => v.state != StepState.done).toList();
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

  // 1. Header + summary.
  b.writeln('<header class="head">');
  b.writeln('<p class="eyebrow">${escapeHtml(m.projectName)} · generated ${escapeHtml(today)}</p>');
  b.writeln('<h1>What\'s waiting<br>on you</h1>');
  b.writeln('<div class="strip">');
  b.writeln(_stat('${open.length}', 'open item${open.length == 1 ? '' : 's'}'));
  b.writeln(_stat('${flipToday.length}', 'would flip a step today'));
  b.writeln(_stat('$done / ${views.length}', 'steps done'));
  b.writeln(_stat('${codeComplete.length}', 'code complete, waiting on you'));
  b.writeln('</div>');
  if (next != null) {
    b.writeln('<p class="next">Next for Claude: <strong>${escapeHtml(next.step.title)}</strong> <code>${escapeHtml(next.step.id)}</code> — ${_stateLabel(next.state)}.</p>');
  } else {
    b.writeln('<p class="next">Nothing is startable for Claude — every pending step is blocked.</p>');
  }
  b.writeln('</header>');

  // 2. Flip today.
  if (flipToday.isNotEmpty) {
    b.writeln(_sectionHead('Would flip a step today', 'The last open box on a step whose code is finished. Close one of these and the step is done.'));
    b.writeln('<div class="cards">');
    for (final i in flipToday) {
      b.writeln(_itemCard(i, needs, g, flip: true));
    }
    b.writeln('</div>');
  }

  // 3. Decisions.
  if (decisions.isNotEmpty) {
    b.writeln(_sectionHead('Decisions that come back to Claude', 'Answer in a comment on the card, or tell Claude in the terminal. The recommended option is first.'));
    b.writeln('<div class="cards">');
    for (final i in decisions) {
      b.writeln(_itemCard(i, needs, g));
    }
    b.writeln('</div>');
  }

  // 4. Sittings.
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

  // 5. Unsorted.
  if (unsorted.isNotEmpty) {
    b.writeln(_sectionHead('${unsorted.length} Claude could not sort', 'It could not tell what these need from you. A one-word comment — console, device, read, look, decision, store, money, secret — files it.'));
    b.writeln('<div class="cards">');
    for (final i in unsorted) {
      b.writeln(_itemCard(i, needs, g));
    }
    b.writeln('</div>');
  }

  // 6. Steps left.
  b.writeln(_sectionHead('${left.length} step${left.length == 1 ? '' : 's'} left', 'In work order. What each one waits on is computed, not remembered.'));
  b.writeln('<ol class="steps">');
  for (final v in left) {
    b.writeln(_stepRow(v, g));
  }
  b.writeln('</ol>');
  if (done > 0) {
    b.writeln('<details class="done-steps"><summary>$done step${done == 1 ? '' : 's'} done</summary><ul>');
    for (final v in views.where((v) => v.state == StepState.done)) {
      b.writeln('<li><code>${escapeHtml(v.step.number ?? '')}</code> ${escapeHtml(v.step.title)}</li>');
    }
    b.writeln('</ul></details>');
  }

  b.writeln('<footer class="foot">Generated by <code>kit render board</code> from <code>plan/</code>. Comments on this page reach Claude; the id under each card is the address.</footer>');
  b.writeln('</main>');
  b.writeln(_script());
  return b.toString();
}

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
    b.writeln('<span class="chip $cls">${flip ? 'flips' : 'gates'} ${escapeHtml(v.number != null ? 'Step ${v.number}' : v.id)}</span>');
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
        b.writeln('<li${o.recommended ? ' class="rec"' : ''}><span class="opt-label">${inlineMd(o.label)}</span>${o.recommended ? '<span class="chip accent">recommended</span>' : ''}${o.why != null ? '<span class="opt-why">${inlineMd(o.why!)}</span>' : ''}</li>');
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

  b.writeln('<div class="card-foot"><code class="id">${escapeHtml(i.id)}</code>');
  if (i.added != null) b.writeln('<span class="when">added ${escapeHtml(i.added!)}</span>');
  if (i.step != null) b.writeln('<span class="when">from ${escapeHtml(i.step!)}</span>');
  b.writeln('</div>');
  b.writeln('</article>');
  return b.toString();
}

String _stepRow(StepView v, Graph g) {
  final b = StringBuffer();
  final s = v.step;
  b.writeln('<li class="step" id="step-${escapeHtml(s.id)}">');
  b.writeln('<div class="step-head"><code class="num">${escapeHtml(s.number ?? '')}</code><h3>${escapeHtml(s.title)}</h3><span class="chip ${_stateClass(v.state)}">${_stateLabel(v.state)}</span></div>');
  final waits = <String>[];
  if (v.missingDeps.isNotEmpty) {
    final parts = <String>[];
    for (final d in v.missingDeps) {
      final dv = d.rank >= 0 ? g.view(d) : null;
      final why = dv == null
          ? 'not in the plan'
          : dv.state == StepState.codeComplete
              ? 'waiting on you: ${dv.openBlockers.map((i) => i.id).join(', ')}'
              : _stateLabel(dv.state);
      parts.add('<code>${escapeHtml(d.number != null ? 'Step ${d.number}' : d.id)}</code> <span class="why">(${escapeHtml(why)})</span>');
    }
    waits.add('<span class="wait-k">after</span> ${parts.join(', ')}');
  }
  if (v.pendingGates.isNotEmpty && s.status == StepStatus.active) {
    waits.add('<span class="wait-k">gates</span> ${v.pendingGates.map((x) => escapeHtml(x.name)).join(', ')}');
  }
  if (v.openBlockers.isNotEmpty) {
    waits.add('<span class="wait-k">you</span> ${v.openBlockers.map((i) => '<a href="#item-${escapeHtml(i.id)}">${escapeHtml(i.title)}</a>').join(' · ')}');
  }
  if (waits.isNotEmpty) b.writeln('<p class="waits">${waits.join('<br>')}</p>');
  b.writeln('</li>');
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
.board { max-width: 880px; margin: 0 auto; padding: 40px 20px 80px; display: flex; flex-direction: column; gap: 28px; }
.head { display: flex; flex-direction: column; gap: 14px; }
.eyebrow { margin: 0; font-family: var(--mono); font-size: 12px; letter-spacing: .06em; text-transform: uppercase; color: var(--muted); }
h1 { margin: 0; font-family: var(--display); font-weight: 700; font-size: clamp(38px, 7vw, 64px); line-height: .98; letter-spacing: -.02em; text-wrap: balance; }
h2 { margin: 0; font-family: var(--display); font-weight: 700; font-size: 26px; line-height: 1.1; letter-spacing: -.01em; text-wrap: balance; }
h3 { margin: 0; font-family: var(--body); font-weight: 600; font-size: 17px; line-height: 1.3; text-wrap: balance; }
.strip { display: grid; grid-template-columns: repeat(auto-fit, minmax(150px, 1fr)); gap: 10px; margin-top: 6px; }
.stat { background: var(--surface); border: 1px solid var(--line); border-radius: var(--radius); padding: 14px 16px; display: flex; flex-direction: column; gap: 2px; }
.stat-n { font-family: var(--display); font-size: 28px; font-weight: 700; letter-spacing: -.02em; font-variant-numeric: tabular-nums; }
.stat-l { font-size: 13px; color: var(--muted); }
.next { margin: 0; color: var(--ink2); }
.section-head { display: flex; flex-direction: column; gap: 4px; margin-top: 8px; }
.section-head p { margin: 0; color: var(--muted); max-width: 62ch; }
.cards { display: flex; flex-direction: column; gap: 12px; }
.card { background: var(--surface); border: 1px solid var(--line); border-radius: var(--radius); padding: 16px 18px 12px; box-shadow: var(--shadow); display: flex; flex-direction: column; gap: 10px; }
.card.flip { border-color: var(--warn); }
.card:target { outline: 2px solid var(--accent); outline-offset: 2px; }
.card-head { display: flex; flex-direction: column; gap: 8px; }
.chips { display: flex; flex-wrap: wrap; gap: 6px; }
.chip { display: inline-block; font-size: 12px; font-weight: 600; letter-spacing: .01em; padding: 2px 9px; border-radius: 999px; background: var(--line); color: var(--ink2); white-space: nowrap; }
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
.steps { list-style: none; margin: 0; padding: 0; display: flex; flex-direction: column; gap: 8px; }
.step { background: var(--surface); border: 1px solid var(--line); border-radius: 12px; padding: 12px 16px; display: flex; flex-direction: column; gap: 6px; }
.step-head { display: flex; flex-wrap: wrap; align-items: center; gap: 8px 12px; }
.step-head h3 { flex: 1 1 240px; }
.num { min-width: 2.6em; text-align: center; }
.waits { margin: 0; font-size: 14px; color: var(--ink2); line-height: 1.6; }
.wait-k { display: inline-block; min-width: 3.2em; font-family: var(--mono); font-size: 11px; letter-spacing: .06em; text-transform: uppercase; color: var(--muted); }
.why { color: var(--muted); }
.done-steps { color: var(--muted); font-size: 14px; }
.done-steps summary { cursor: pointer; }
.done-steps ul { columns: 2; column-gap: 24px; padding-left: 18px; }
.foot { font-size: 13px; color: var(--muted); border-top: 1px solid var(--line); padding-top: 16px; }
:focus-visible { outline: 2px solid var(--accent); outline-offset: 2px; }
@media (prefers-reduced-motion: no-preference) { details > summary { transition: color .15s; } }
@media (max-width: 560px) { .board { padding: 28px 14px 60px; } .card { padding: 14px 14px 10px; } .done-steps ul { columns: 1; } }
''';
}

String _script() => '''
<script>
(function () {
  // Remember which sittings are open, per viewer. Best-effort only.
  var key = 'kit-board-open';
  var open = {};
  try { open = JSON.parse(localStorage.getItem(key) || '{}') || {}; } catch (e) { open = {}; }
  var all = document.querySelectorAll('details.sitting');
  for (var i = 0; i < all.length; i++) {
    var d = all[i];
    var id = d.getAttribute('data-sitting');
    if (open[id] === true) d.open = true;
    if (i === 0 && open[id] === undefined) d.open = true;
    d.addEventListener('toggle', function (ev) {
      var el = ev.target;
      open[el.getAttribute('data-sitting')] = el.open;
      try { localStorage.setItem(key, JSON.stringify(open)); } catch (e) {}
    });
  }
})();
</script>
''';
