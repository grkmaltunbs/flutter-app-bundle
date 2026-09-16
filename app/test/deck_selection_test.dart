import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_kit/kit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kit_app/src/host/bridge_session.dart';
import 'package:kit_app/src/screens/deck_tab.dart';
import 'package:kit_app/src/theme.dart';
import 'package:kit_app/src/widgets/common.dart';

const _first = 'First paragraph to copy.';
const _second = 'Second paragraph stays selected.';
const _last = 'Another reply is selectable too.';

Widget _app(Widget child, {double scale = 1}) => MaterialApp(
  theme: kitTheme(KitTokens.light),
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: child!,
  ),
  home: Scaffold(body: child),
);

Widget _deck({bool anotherReply = false}) => DeckView(
  state: BridgeState.idle,
  title: 'Scratch',
  facts: const [],
  messages: [
    DeckMessage(id: 'first', role: DeckRole.assistant, text: '$_first\n\n$_second', at: DateTime(2026, 9, 17)),
    if (anotherReply)
      DeckMessage(id: 'next', role: DeckRole.assistant, text: _last, at: DateTime(2026, 9, 17)),
  ],
  running: false,
  canResume: false,
  onStart: () {},
  onResume: () {},
  onStop: () {},
  onSend: (_, _) async {},
);

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _surface(WidgetTester tester, Size size) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

Offset _textPoint(WidgetTester tester, String text, int offset) {
  final finder = find.text(text);
  final editable = find.descendant(of: finder, matching: find.byType(EditableText));
  if (editable.evaluate().isNotEmpty) {
    final render = tester.state<EditableTextState>(editable).renderEditable;
    return render.localToGlobal(render.getLocalRectForCaret(TextPosition(offset: offset)).centerLeft);
  }
  final render = tester.renderObject<RenderParagraph>(find.descendant(of: finder, matching: find.byType(RichText)));
  final caret = render.getOffsetForCaret(TextPosition(offset: offset), Rect.zero);
  return render.localToGlobal(caret + Offset(0, render.preferredLineHeight / 2));
}

Future<String?> _copyDrag(WidgetTester tester, String from, String to, {bool touch = false}) async {
  if (tester.binding is AutomatedTestWidgetsFlutterBinding) {
    String? clipboard;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      switch (call.method) {
        case 'Clipboard.setData': clipboard = (call.arguments as Map)['text'] as String?;
        case 'Clipboard.getData': return {'text': clipboard};
        case 'Clipboard.hasStrings': return {'value': clipboard?.isNotEmpty ?? false};
      }
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
  } else {
    final original = await Clipboard.getData(Clipboard.kTextPlain);
    addTearDown(() => Clipboard.setData(original ?? const ClipboardData(text: '')));
  }
  await Clipboard.setData(const ClipboardData(text: 'no selection copied'));
  final gesture = await tester.startGesture(
    _textPoint(tester, from, 0) + const Offset(1, 0),
    kind: touch ? PointerDeviceKind.touch : PointerDeviceKind.mouse,
  );
  addTearDown(gesture.removePointer);
  await tester.pump(touch ? const Duration(milliseconds: 600) : Duration.zero);
  await gesture.moveTo(_textPoint(tester, to, to.length));
  await tester.pump();
  await gesture.up();
  await _settle(tester);
  if (touch) {
    await tester.tap(find.text('Copy'));
  } else {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
  }
  await tester.pump();
  return (await Clipboard.getData(Clipboard.kTextPlain))?.text;
}

void main() {
  testWidgets('Deck mouse selection copies both Markdown paragraphs', (tester) async {
    await _surface(tester, const Size(1000, 800));
    await tester.pumpWidget(_app(_deck()));
    await _settle(tester);

    final copied = await _copyDrag(tester, _first, _second);
    expect(copied, contains(_first));
    expect(copied, contains(_second));
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  testWidgets('Deck mouse selection continues into another reply', (tester) async {
    await _surface(tester, const Size(1000, 800));
    await tester.pumpWidget(_app(_deck(anotherReply: true)));
    await _settle(tester);

    final copied = await _copyDrag(tester, _first, _last);
    expect(copied, contains(_first));
    expect(copied, contains(_second));
    expect(copied, contains(_last));
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  testWidgets('Deck phone long press copies across Markdown paragraphs', (tester) async {
    await _surface(tester, const Size(390, 844));
    await tester.pumpWidget(_app(_deck()));
    await _settle(tester);

    final copied = await _copyDrag(tester, _first, _second, touch: true);
    expect(copied, contains(_first));
    expect(copied, contains(_second));
    expect(tester.takeException(), isNull);
  }, variant: const TargetPlatformVariant({TargetPlatform.iOS, TargetPlatform.android}));

  testWidgets('standalone Markdown keeps selection across its paragraphs', (tester) async {
    await tester.pumpWidget(_app(const Padding(
      padding: EdgeInsets.all(40),
      child: Md('$_first\n\n$_second'),
    )));
    await _settle(tester);

    final copied = await _copyDrag(tester, _first, _second);
    expect(copied, contains(_first));
    expect(copied, contains(_second));
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  for (final size in const [Size(320, 568), Size(390, 844), Size(440, 956), Size(768, 1024)]) {
    for (final scale in [1.0, 2.0, 3.12]) {
      testWidgets('Deck Markdown at ${size.width}x${size.height}, ${scale}x has no overflow', (tester) async {
        await _surface(tester, size);
        await tester.pumpWidget(_app(_deck(), scale: scale));
        await _settle(tester);
        expect(tester.takeException(), isNull);
        await tester.dragUntilVisible(find.text(_second), find.byType(ListView), const Offset(0, -120));
        await _settle(tester);
        // At the largest scale a paragraph can be taller than the viewport;
        // its center need not be visible while its lines remain scrollable.
        expect(tester.getRect(find.text(_second)).overlaps(tester.getRect(find.byType(ListView))), isTrue);
        expect(tester.takeException(), isNull);
      }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
    }
  }
}
