// The mirror's pure half: the record both sides merge, the tap-to-device
// arithmetic, the frame size, the PNG header, the captions.
import 'package:flutter_kit/kit.dart';
import 'package:test/test.dart';

void main() {
  test('the record round-trips; the host never writes watching, and reads it', () {
    final at = DateTime.utc(2026, 9, 6, 0, 30);
    final m = MirrorState(seq: 3, at: at, w: 331, h: 720, dw: 1206, dh: 2622, streaming: true, lastInput: 'TAP 600, 900');
    final map = m.toMap();
    expect(map.containsKey('watching'), isFalse);
    expect(map['error'], isNull, reason: 'null, not absent — the document is merged');
    final back = MirrorState.fromMap({...map, 'watching': {'at': at.add(const Duration(seconds: 3)).toIso8601String(), 'by': 'phone'}});
    expect(back.seq, 3);
    expect(back.w, 331);
    expect(back.dw, 1206);
    expect(back.streaming, isTrue);
    expect(back.lastInput, 'TAP 600, 900');
    expect(back.watchingBy, 'phone');
    expect(back.watching(at.add(const Duration(seconds: 10))), isTrue);
    expect(back.watching(at.add(const Duration(seconds: 30))), isFalse, reason: 'a sheet on a locked phone goes quiet');
    expect(const MirrorState().watching(at), isFalse);
    expect(MirrorState.fromMap(const {}).seq, 0);
    expect(back.copyWith(error: 'x').error, 'x');
    expect(back.copyWith(error: 'x').copyWith(clearError: true).error, isNull);
    expect(back.copyWith(seq: 4).watchingAt, isNotNull, reason: 'copyWith keeps the phone\'s half');
  });

  test('a tap on the drawn frame lands on the device; the frame keeps the aspect', () {
    expect(deviceXY(0, 0, drawnW: 331, drawnH: 720, dw: 1206, dh: 2622), (0, 0));
    expect(deviceXY(331, 720, drawnW: 331, drawnH: 720, dw: 1206, dh: 2622), (1205, 2621), reason: 'clamped inside');
    expect(deviceXY(165.5, 360, drawnW: 331, drawnH: 720, dw: 1206, dh: 2622), (603, 1311));
    expect(deviceXY(100, 100, drawnW: 200, drawnH: 400, dw: 1000, dh: 2000), (500, 500));
    expect(deviceXY(10, 10, drawnW: 0, drawnH: 0, dw: 1, dh: 1), (0, 0));
    expect(fitLongEdge(1206, 2622), (331, 720));
    expect(fitLongEdge(2622, 1206), (720, 331));
    expect(fitLongEdge(1200, 2608), (331, 720));
    expect(fitLongEdge(0, 0), (0, 0));
  });

  test('the PNG header, the input command and its caption, the age', () {
    final png = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0, 0, 0, 13, 0x49, 0x48, 0x44, 0x52, 0, 0, 0x04, 0xB6, 0, 0, 0x0A, 0x3E];
    expect(pngSize(png), (1206, 2622));
    expect(pngSize([1, 2, 3]), isNull);
    expect(inputCommand('tap', x: 600, y: 900), {'type': 'input', 'action': 'tap', 'x': 600, 'y': 900});
    expect(inputLabel(inputCommand('tap', x: 600, y: 900)), 'TAP 600, 900');
    expect(inputLabel(inputCommand('swipe', x: 100, y: 900, x2: 100, y2: 300)), 'SWIPE 100,900 → 100,300');
    expect(inputLabel(inputCommand('text', text: 'hello')), 'TEXT "hello"');
    expect(inputLabel(inputCommand('key', text: 'back')), 'KEY back');
    expect(ageLabel(const Duration(milliseconds: 400)), '0.4 s');
    expect(ageLabel(const Duration(seconds: 12)), '12 s');
    expect(ageLabel(const Duration(minutes: 3)), '3 min');
    expect(framePath('scratch'), 'projects/scratch/frames/live.jpg');
    final now = DateTime.utc(2026, 9, 6, 0, 30);
    expect(mirrorLine(const MirrorState(), now: now), 'Mirror · no frame yet');
    expect(mirrorLine(MirrorState(seq: 5, at: now.subtract(const Duration(seconds: 1)), streaming: true, watchingAt: now, watchingBy: 'phone'), now: now), 'Mirror · live · frame 5 · 1.0 s ago · a sheet is open on phone');
    expect(mirrorLine(const MirrorState(error: 'capture failed'), now: now), 'Mirror · capture failed');
  });
}
