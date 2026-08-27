/// `kit` — the plan CLI behind flutter-kit v2.
///
/// Exit codes: 0 ok · 1 refused / validation errors · 2 usage.
library;

import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:flutter_kit/kit.dart';
import 'package:path/path.dart' as p;

const _usage = '''
kit — the plan engine behind flutter-kit

  kit validate                         check plan/ for errors and warnings
  kit status                           every step, its state, what it waits on
  kit next [--step]                    what Claude works next, and what you can do now
  kit show <step-id|item-id>           one step or item as markdown
  kit blocks <step-id>                 everything between a step and done
  kit gate <step-id> <gate> <passed|failed|pending> [--note ...]
  kit step start <step-id>
  kit step done <step-id> [--force] [--note ...]
  kit done <item-id> [--note ...]      close a human item; prints what it unblocked
  kit drop <item-id> [--note ...]      close an item as "not doing"
  kit reopen <item-id>
  kit item new --id <id> --title <t> [--needs a,b] [--blocks s1,s2] [--from <step>]
                                       [--deadline YYYY-MM-DD] [--body <md> | --body-file <path>]
  kit inbox <batch.json> [--dry-run]     apply a batch of ticks/answers/notes sent from the board
  kit render plan|board [--out <path>|-]
  kit import --plan-md <PROJECT_PLAN.md> [--journal <file>] --out <plan dir>
             --name <project> [--release-step <id>] [--active <id,id>] [--firebase <project>]
  kit init --name <project> [--out <plan dir>]

Global: --plan <dir> (default ./plan) · --project <dir> (default cwd) · --today YYYY-MM-DD
''';

late String _today;

void main(List<String> argv) {
  final parser = ArgParser(allowTrailingOptions: true)
    ..addOption('plan')
    ..addOption('project')
    ..addOption('today')
    ..addOption('note')
    ..addOption('out')
    ..addOption('id')
    ..addOption('title')
    ..addOption('needs')
    ..addOption('blocks')
    ..addOption('from')
    ..addOption('deadline')
    ..addOption('body')
    ..addOption('body-file')
    ..addOption('plan-md')
    ..addOption('journal')
    ..addOption('name')
    ..addOption('release-step')
    ..addOption('active')
    ..addOption('firebase')
    ..addFlag('step', negatable: false, help: 'next: print only the next step id')
    ..addFlag('dry-run', negatable: false)
    ..addFlag('force', negatable: false)
    ..addFlag('help', abbr: 'h', negatable: false);

  ArgResults args;
  try {
    args = parser.parse(argv);
  } on FormatException catch (e) {
    stderr.writeln(e.message);
    stderr.write(_usage);
    exit(2);
  }
  if (args['help'] as bool || args.rest.isEmpty) {
    stdout.write(_usage);
    exit(args.rest.isEmpty ? 2 : 0);
  }

  final project = p.normalize(p.absolute((args['project'] as String?) ?? Directory.current.path));
  final planDir = p.normalize(p.join(project, (args['plan'] as String?) ?? 'plan'));
  _today = (args['today'] as String?) ?? _isoToday();
  final rest = args.rest;
  final cmd = rest.first;

  try {
    switch (cmd) {
      case 'validate':
        exit(_validate(PlanStore(planDir)));
      case 'status':
        stdout.write(renderStatus(PlanStore(planDir).load()));
      case 'next':
        final plan = PlanStore(planDir).load();
        if (args['step'] as bool) {
          final n = Graph(plan).nextStep();
          stdout.writeln(n?.step.id ?? '');
        } else {
          stdout.write(renderNext(plan));
        }
      case 'show':
        _show(PlanStore(planDir).load(), _arg(rest, 1, 'show needs an id'));
      case 'blocks':
        stdout.write(renderBlocks(PlanStore(planDir).load(), _arg(rest, 1, 'blocks needs a step id')));
      case 'gate':
        _gate(PlanStore(planDir), _arg(rest, 1, 'gate needs a step id'), _arg(rest, 2, 'gate needs a gate name'),
            _arg(rest, 3, 'gate needs passed|failed|pending'), args['note'] as String?);
      case 'step':
        _stepCmd(PlanStore(planDir), rest, args);
      case 'done':
        _closeItem(PlanStore(planDir), _arg(rest, 1, 'done needs an item id'), ItemStatus.done, args['note'] as String?);
      case 'drop':
        _closeItem(PlanStore(planDir), _arg(rest, 1, 'drop needs an item id'), ItemStatus.dropped, args['note'] as String?);
      case 'reopen':
        _reopen(PlanStore(planDir), _arg(rest, 1, 'reopen needs an item id'));
      case 'item':
        _itemCmd(PlanStore(planDir), rest, args);
      case 'inbox':
        exit(_inbox(PlanStore(planDir), _abs(project, _arg(rest, 1, 'inbox needs a batch file')), dryRun: args['dry-run'] as bool));
      case 'render':
        _render(PlanStore(planDir), project, _arg(rest, 1, 'render needs plan|board'), args['out'] as String?);
      case 'import':
        _import(project, args);
      case 'init':
        _init(project, args);
      default:
        stderr.writeln('Unknown command "$cmd"');
        stderr.write(_usage);
        exit(2);
    }
  } on _Usage catch (e) {
    stderr.writeln(e.message);
    exit(2);
  } on _Refused catch (e) {
    stderr.writeln(e.message);
    exit(1);
  } on StateError catch (e) {
    stderr.writeln(e.message);
    exit(1);
  } on FormatException catch (e) {
    stderr.writeln(e.message);
    exit(1);
  } on ArgumentError catch (e) {
    stderr.writeln(e.message);
    exit(1);
  }
}

class _Usage implements Exception {
  _Usage(this.message);
  final String message;
}

class _Refused implements Exception {
  _Refused(this.message);
  final String message;
}

String _arg(List<String> rest, int i, String msg) {
  if (rest.length <= i) throw _Usage(msg);
  return rest[i];
}

int _validate(PlanStore store) {
  final plan = store.load();
  final problems = validate(plan);
  for (final pr in problems) {
    stdout.writeln(pr);
  }
  final errors = problems.where((x) => x.isError).length;
  final warnings = problems.length - errors;
  stdout.writeln('${plan.steps.length} steps, ${plan.items.length} items — $errors error(s), $warnings warning(s)');
  return errors == 0 ? 0 : 1;
}

void _show(Plan plan, String id) {
  final s = plan.step(id);
  if (s != null) {
    stdout.write(renderStep(plan, s));
    return;
  }
  final i = plan.item(id);
  if (i != null) {
    stdout.write(renderItem(plan, i));
    return;
  }
  throw _Refused('No step or item with id "$id"');
}

void _gate(PlanStore store, String stepId, String gate, String status, String? note) {
  final plan = store.load();
  final s = plan.step(stepId);
  if (s == null) throw _Refused('No step "$stepId"');
  final st = GateStatus.values.asNameMap()[status];
  if (st == null) throw _Usage('gate status must be passed|failed|pending');
  final file = store.stepPath(stepId);
  store.patch(file, ['gates', gate, 'status'], st.name);
  store.patch(file, ['gates', gate, 'at'], _today);
  if (note != null) store.patch(file, ['gates', gate, 'note'], note);
  store.appendTo(file, ['history'], {'at': _today, 'event': 'gate $gate ${st.name}', if (note != null) 'note': note});
  final v = Graph(store.load()).view(store.load().step(stepId)!);
  stdout.writeln('$stepId: gate $gate → ${st.name}. State now: ${v.state.name}.');
  if (v.state == StepState.flippable) stdout.writeln('Nothing else stands in the way — `kit step done $stepId`.');
  if (v.state == StepState.codeComplete) {
    stdout.writeln('Code complete. Waiting on: ${v.openBlockers.map((i) => i.id).join(', ')}.');
  }
}

void _stepCmd(PlanStore store, List<String> rest, ArgResults args) {
  final sub = _arg(rest, 1, 'step needs start|done');
  final id = _arg(rest, 2, 'step $sub needs a step id');
  final plan = store.load();
  final s = plan.step(id);
  if (s == null) throw _Refused('No step "$id"');
  final file = store.stepPath(id);
  final note = args['note'] as String?;
  switch (sub) {
    case 'start':
      final v = Graph(plan).view(s);
      if (v.state == StepState.blocked && !(args['force'] as bool)) {
        throw _Refused('$id is blocked by ${v.missingDeps.map((d) => d.id).join(', ')}. Finish those first, or --force.');
      }
      if (s.status == StepStatus.done) throw _Refused('$id is already done.');
      store.patch(file, ['status'], 'active');
      store.appendTo(file, ['history'], {'at': _today, 'event': 'started', if (note != null) 'note': note});
      stdout.writeln('$id: active.');
    case 'done':
      final v = Graph(plan).view(s);
      final force = args['force'] as bool;
      if (!force) {
        if (v.pendingGates.isNotEmpty) {
          throw _Refused('$id: gates not passed: ${v.pendingGates.map((g) => g.name).join(', ')}. Record them with `kit gate`, or --force.');
        }
        if (v.openBlockers.isNotEmpty) {
          throw _Refused('$id: ${v.openBlockers.length} human item(s) still open: ${v.openBlockers.map((i) => i.id).join(', ')}. A step is not done while its boxes are open. Close them with `kit done`, or --force.');
        }
        if (v.missingDeps.isNotEmpty) {
          throw _Refused('$id: dependencies not done: ${v.missingDeps.map((d) => d.id).join(', ')}.');
        }
      }
      store.patch(file, ['status'], 'done');
      store.appendTo(file, ['history'], {'at': _today, 'event': force ? 'done (forced)' : 'done', if (note != null) 'note': note});
      stdout.writeln('$id: done.');
      _reportUnblocked(store.load(), before: plan);
    default:
      throw _Usage('step needs start|done');
  }
}

void _closeItem(PlanStore store, String id, ItemStatus status, String? note) {
  final plan = store.load();
  final i = plan.item(id);
  if (i == null) throw _Refused('No item "$id"');
  if (!i.isOpen) throw _Refused('$id is already ${i.status.name}.');
  final file = store.itemPath(id);
  store.patch(file, ['status'], status.name);
  store.patch(file, ['done_at'], _today);
  if (note != null) store.patch(file, ['note'], note);
  stdout.writeln('$id: ${status.name}.');
  final after = store.load();
  final g = Graph(after);
  for (final v in g.stepsGatedBy(id)) {
    if (v.state == StepState.flippable) {
      stdout.writeln('  ${v.step.id} has nothing left in the way — `kit step done ${v.step.id}`.');
    } else if (v.openBlockers.isNotEmpty) {
      stdout.writeln('  ${v.step.id} still waits on: ${v.openBlockers.map((x) => x.id).join(', ')}.');
    } else if (v.state == StepState.ready) {
      stdout.writeln('  ${v.step.id} is now ready to start.');
    } else {
      stdout.writeln('  ${v.step.id}: ${v.state.name}.');
    }
  }
}

void _reopen(PlanStore store, String id) {
  final plan = store.load();
  final i = plan.item(id);
  if (i == null) throw _Refused('No item "$id"');
  final file = store.itemPath(id);
  store.patch(file, ['status'], 'open');
  store.patch(file, ['done_at'], null);
  stdout.writeln('$id: open.');
}

void _reportUnblocked(Plan after, {required Plan before}) {
  final gb = Graph(before);
  final ga = Graph(after);
  for (final s in after.steps) {
    final was = gb.view(before.step(s.id)!).state;
    final now = ga.view(s).state;
    if (was == StepState.blocked && now == StepState.ready) {
      stdout.writeln('  ${s.id} is now ready to start.');
    }
  }
}

void _itemCmd(PlanStore store, List<String> rest, ArgResults args) {
  final sub = _arg(rest, 1, 'item needs new');
  if (sub != 'new') throw _Usage('item needs new');
  final id = args['id'] as String?;
  final title = args['title'] as String?;
  if (id == null || title == null) throw _Usage('item new needs --id and --title');
  final plan = store.load();
  if (plan.item(id) != null) throw _Refused('Item "$id" already exists.');
  final needs = _csv(args['needs'] as String?);
  final blocks = _csv(args['blocks'] as String?);
  for (final n in needs) {
    if (!plan.manifest.needs.containsKey(n)) {
      throw _Refused('Unknown need "$n". Known: ${plan.manifest.needs.keys.join(', ')}');
    }
  }
  for (final b in blocks) {
    if (plan.step(b) == null) throw _Refused('Unknown step "$b" in --blocks.');
  }
  var body = (args['body'] as String?) ?? '';
  final bodyFile = args['body-file'] as String?;
  if (bodyFile != null) body = File(bodyFile).readAsStringSync();
  final item = Item(
    id: id,
    title: title,
    needs: needs,
    blocks: blocks,
    step: args['from'] as String?,
    added: _today,
    deadline: args['deadline'] as String?,
    body: body,
  );
  store.writeItem(item);
  stdout.writeln('items/$id.yaml written.');
}

/// Applies a batch the board sent: `{sentAt, entries:[{kind:item,id,action,answer,note}|{kind:step,id,note}]}`.
int _inbox(PlanStore store, String file, {required bool dryRun}) {
  final raw = jsonDecode(File(file).readAsStringSync());
  if (raw is! Map || raw['entries'] is! List) throw _Usage('inbox: expected {"entries": [...]}');
  final sentAt = raw['sentAt']?.toString();
  final plan = store.load();
  var applied = 0;
  var skipped = 0;
  for (final e in raw['entries'] as List) {
    if (e is! Map) continue;
    final kind = e['kind']?.toString();
    final id = e['id']?.toString() ?? '';
    final note = e['note']?.toString();
    final stamp = sentAt == null ? '' : ' (sent $sentAt)';
    if (kind == 'item') {
      final i = plan.item(id);
      if (i == null) {
        stdout.writeln('skip  item $id: unknown');
        skipped++;
        continue;
      }
      final action = e['action']?.toString();
      final answer = e['answer']?.toString();
      final f = store.itemPath(id);
      final what = <String>[];
      if (!dryRun) {
        if (answer != null && answer.isNotEmpty) {
          store.patch(f, ['question', 'answer'], answer);
          what.add('answer: $answer');
        }
        if (note != null && note.isNotEmpty) {
          final existing = i.note;
          store.patch(f, ['note'], existing == null || existing.isEmpty ? '$note$stamp' : '$existing\n$note$stamp');
          what.add('note');
        }
        if (action == 'drop') {
          if (i.isOpen) {
            store.patch(f, ['status'], 'dropped');
            store.patch(f, ['done_at'], _today);
          }
          what.add('dropped');
        } else if (action == 'done' || (answer != null && answer.isNotEmpty)) {
          if (i.isOpen) {
            store.patch(f, ['status'], 'done');
            store.patch(f, ['done_at'], _today);
          }
          what.add('done');
        }
      } else {
        if (answer != null && answer.isNotEmpty) what.add('answer: $answer');
        if (note != null && note.isNotEmpty) what.add('note');
        if (action != null) what.add(action);
      }
      stdout.writeln('${dryRun ? 'would ' : ''}item  $id: ${what.isEmpty ? 'nothing to apply' : what.join(', ')}');
      applied++;
    } else if (kind == 'step') {
      final s = plan.step(id);
      if (s == null) {
        stdout.writeln('skip  step $id: unknown');
        skipped++;
        continue;
      }
      if (note != null && note.isNotEmpty) {
        if (!dryRun) {
          store.appendTo(store.stepPath(id), ['history'], {'at': _today, 'event': 'note from user', 'note': note});
        }
        stdout.writeln('${dryRun ? 'would ' : ''}step  $id: note recorded');
        applied++;
      }
    } else {
      stdout.writeln('skip  entry of kind "$kind"');
      skipped++;
    }
  }
  stdout.writeln('$applied applied, $skipped skipped${dryRun ? ' (dry run — nothing written)' : ''}.');
  if (!dryRun && applied > 0) {
    final after = store.load();
    final g = Graph(after);
    for (final v in g.views()) {
      if (v.state == StepState.flippable) stdout.writeln('  ${v.step.id} has nothing left in the way — `kit step done ${v.step.id}`.');
    }
  }
  return skipped == 0 ? 0 : 1;
}

void _render(PlanStore store, String project, String what, String? out) {
  final plan = store.load();
  String content;
  String defaultOut;
  switch (what) {
    case 'plan':
      content = renderPlanMarkdown(plan);
      defaultOut = plan.manifest.planMarkdown;
    case 'board':
      content = renderBoardHtml(plan, today: _today);
      defaultOut = plan.manifest.boardOutput;
    default:
      throw _Usage('render needs plan|board');
  }
  final target = out ?? defaultOut;
  if (target == '-') {
    stdout.write(content);
    return;
  }
  final path = p.isAbsolute(target) ? target : p.join(project, target);
  File(path)
    ..createSync(recursive: true)
    ..writeAsStringSync(content);
  stdout.writeln('wrote $path');
}

void _import(String project, ArgResults args) {
  final planMd = args['plan-md'] as String?;
  final out = args['out'] as String?;
  final name = args['name'] as String?;
  if (planMd == null || out == null || name == null) {
    throw _Usage('import needs --plan-md, --out and --name');
  }
  final outDir = p.isAbsolute(out) ? out : p.join(project, out);
  final store = PlanStore(outDir);
  final notes = <String>[];
  final items = <Item>[];
  final active = _csv(args['active'] as String?);
  final steps = importPlanMarkdown(File(_abs(project, planMd)).readAsStringSync(), activeIds: active, itemsOut: items, notes: notes);
  final byNumber = {for (final s in steps) if (s.number != null) s.number!: s.id};
  final journal = args['journal'] as String?;
  if (journal != null) {
    items.addAll(importJournalMarkdown(
      File(_abs(project, journal)).readAsStringSync(),
      numberToStepId: byNumber,
      releaseStep: args['release-step'] as String?,
      existingIds: items.map((i) => i.id).toSet(),
      doneStepIds: {for (final s in steps) if (s.status == StepStatus.done) s.id},
      notes: notes,
    ));
  }
  final manifest = Manifest(
    projectName: name,
    firebaseProject: args['firebase'] as String?,
    releaseStep: args['release-step'] as String?,
    boardTitle: '$name Launch Board',
    journal: journal == null ? null : p.basename(journal),
  );
  store.writeManifest(manifest);
  for (final s in steps) {
    store.writeStep(s);
  }
  for (final i in items) {
    store.writeItem(i);
  }
  stdout.writeln('wrote ${steps.length} steps and ${items.length} items to $outDir');
  if (notes.isNotEmpty) {
    stdout.writeln('${notes.length} thing(s) to review:');
    for (final n in notes) {
      stdout.writeln('  $n');
    }
  }
  final problems = validate(store.load());
  final errors = problems.where((x) => x.isError).toList();
  if (errors.isNotEmpty) {
    stdout.writeln('${errors.length} validation error(s):');
    for (final e in errors) {
      stdout.writeln('  $e');
    }
  }
}

void _init(String project, ArgResults args) {
  final name = args['name'] as String?;
  if (name == null) throw _Usage('init needs --name');
  final out = (args['out'] as String?) ?? 'plan';
  final store = PlanStore(_abs(project, out));
  if (store.exists) throw _Refused('${store.manifestPath} already exists.');
  store.writeManifest(Manifest(projectName: name, boardTitle: '$name Launch Board'));
  Directory(store.stepsDir).createSync(recursive: true);
  Directory(store.itemsDir).createSync(recursive: true);
  stdout.writeln('created ${store.dir}');
}

List<String> _csv(String? s) =>
    s == null || s.trim().isEmpty ? const [] : [for (final x in s.split(',')) x.trim()].where((x) => x.isNotEmpty).toList();

String _abs(String project, String path) => p.isAbsolute(path) ? path : p.join(project, path);

String _isoToday() {
  final d = DateTime.now();
  return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
