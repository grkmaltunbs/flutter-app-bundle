import 'package:flutter_kit/kit.dart';
import 'package:test/test.dart';

void main() {
  group('mini markdown', () {
    test('inline: code protects its contents; bold, italic, strike, links', () {
      expect(inlineMd('a `**not bold**` b **bold** *it* ~~gone~~ [x](https://e.com) https://y.org/p'),
          'a <code>**not bold**</code> b <strong>bold</strong> <em>it</em> <s>gone</s> <a href="https://e.com">x</a> <a href="https://y.org/p">https://y.org/p</a>');
    });

    test('escapes html', () {
      expect(inlineMd('<b>&'), '&lt;b&gt;&amp;');
    });

    test('blocks: paragraphs, lists with checkboxes and nesting, fences, quotes, headings', () {
      final html = mdToHtml('''
Para one
continues.

- [ ] open box
- [x] done box
  with continuation
  - nested bullet

1. first
2. second

```
code <here>
```

> quoted

## H
''');
      expect(html, contains('<p>Para one continues.</p>'));
      expect(html, contains('<li class="todo">open box</li>'));
      expect(html, contains('<li class="done">done box with continuation<ul>'));
      expect(html, contains('<li>nested bullet</li>'));
      expect(html, contains('<ol>\n<li>first</li>\n<li>second</li>\n</ol>'));
      expect(html, contains('<pre><code>code &lt;here&gt;</code></pre>'));
      expect(html, contains('<blockquote><p>quoted</p>\n</blockquote>'));
      expect(html, contains('<h4>H</h4>'));
    });
  });

  group('board', () {
    Plan sample() {
      final steps = [
        Step(id: 'g2', number: 'G2', title: 'Engine', rank: 1, status: StepStatus.active, gates: {'qa': Gate('qa', status: GateStatus.passed)}),
        Step(id: 'g12', number: 'G12', title: 'Recap', rank: 2, dependsOn: const ['g2']),
        Step(id: 'ship', number: '26', title: 'Ship', rank: 3, dependsOn: const ['g12']),
        Step(id: 'old', number: '1', title: 'Old', rank: 0, status: StepStatus.done),
      ];
      final items = [
        Item(id: 'push', title: 'Receive a push on a real iPhone', needs: const ['device'], blocks: const ['g2']),
        Item(id: 'name-admin', title: 'Which account is the admin?', needs: const ['decision'], question: const Question(ask: 'Pick', options: [QuestionOption('B'), QuestionOption('A', recommended: true, why: 'w')])),
        Item(id: 'domain', title: 'Register the domain', needs: const ['console', 'money'], blocks: const ['ship'], deadline: '2026-10-30', body: 'Short body with `code`.'),
        Item(id: 'mystery', title: 'Nobody knows', needs: const []),
        Item(id: 'closed', title: 'Closed', needs: const ['console'], status: ItemStatus.done),
      ];
      return Plan(
        manifest: Manifest(projectName: 'Nahmatik', boardTitle: 'Nahmatik Kit Board', releaseStep: 'ship', boardFonts: const {'display': 'Archivo Black'}, boardColors: const {'light': {'accent': '#1E5BFF'}, 'dark': {'accent': '#93AEFF'}}),
        steps: steps,
        items: items,
      );
    }

    test('sections, anchors, chips, and the recommended option first', () {
      final html = renderBoardHtml(sample(), today: '2026-08-27');
      expect(html, startsWith('<title>Nahmatik Kit Board</title>'));
      expect(html, contains('<h2>Would flip a step today</h2>'));
      expect(html, contains('id="item-push"'));
      expect(html, contains('flips Step G2'));
      expect(html, contains('<h2>Decisions that come back to Claude</h2>'));
      final a = html.indexOf('<span class="opt-label">A</span>');
      final b = html.indexOf('<span class="opt-label">B</span>');
      expect(a, lessThan(b));
      expect(html, contains('by 2026-10-30'));
      expect(html, contains('gates Step 26'));
      expect(html, contains('<h2>1 Claude could not sort</h2>'));
      expect(html, contains('id="item-mystery"'));
      expect(html, isNot(contains('id="item-closed"')));
      expect(html, contains('<h2>3 steps left</h2>'));
      expect(html, contains('waiting on you: push'));
      expect(html, contains('1 step done'));
    });

    test('theme tokens: every colour is defined on bare :root and overridden for dark both ways', () {
      final html = renderBoardHtml(sample(), today: '2026-08-27');
      expect(html, contains('--accent: #1E5BFF;'));
      expect(html, contains(':root:not([data-theme="light"]) {'));
      expect(html, contains(':root[data-theme="dark"] {'));
      expect('--accent: #93AEFF;'.allMatches(html).length, 2);
      expect(html, contains('family=Archivo+Black'));
      expect(html, contains('body { margin: 0; background: var(--bg);'));
    });

    test('is self-contained: no external scripts, no remote images', () {
      final html = renderBoardHtml(sample(), today: '2026-08-27');
      expect(html, isNot(contains('<script src=')));
      expect(html, isNot(contains('<img')));
    });
  });

  group('text renderers', () {
    test('status clips a long depends_on and names the next step', () {
      final steps = [
        Step(id: 'a', number: '1', title: 'A', rank: 1, status: StepStatus.done),
        Step(id: 'z', number: '26', title: 'Z', rank: 2, dependsOn: [for (var i = 0; i < 12; i++) 'dependency-number-$i']),
        Step(id: 'b', number: '2', title: 'B', rank: 3, dependsOn: const ['a']),
      ];
      final out = renderStatus(Plan(manifest: Manifest(projectName: 't'), steps: steps, items: const []));
      expect(out, contains('+'));
      expect(out, contains('more'));
      expect(out, contains('Next for Claude: b (B) — ready'));
    });

    test('next lists sittings and flips', () {
      final p = Plan(
        manifest: Manifest(projectName: 't'),
        steps: [Step(id: 'g2', title: 'g2', rank: 1, status: StepStatus.active, gates: {'qa': Gate('qa', status: GateStatus.passed)})],
        items: [Item(id: 'push', title: 'Push', needs: const ['device'], blocks: const ['g2'])],
      );
      final out = renderNext(p);
      expect(out, contains('WOULD FLIP A STEP TODAY'));
      expect(out, contains('A real phone  (1)'));
      expect(out, contains('[flips g2]'));
    });
  });
}
