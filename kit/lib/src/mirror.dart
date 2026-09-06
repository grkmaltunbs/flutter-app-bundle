/// The mirror's pure half: the frame's record on the project document,
/// the input command, the arithmetic between a tap on the phone and a
/// point on the device, and the lines. Capture and input themselves are
/// the host's (`app/lib/src/host/mirror.dart`).
library;

/// `projects/{slug}.mirror` — what the host writes about the newest
/// frame, and what the phone writes while its sheet is open
/// (`watching`). The host never writes `watching`; the phone never
/// writes the rest; both merge.
class MirrorState {
  const MirrorState({this.seq = 0, this.at, this.w = 0, this.h = 0, this.dw = 0, this.dh = 0, this.streaming = false, this.lastInput, this.error, this.watchingAt, this.watchingBy});

  factory MirrorState.fromMap(Map<String, Object?> m) {
    final watching = m['watching'];
    final wm = watching is Map ? {for (final e in watching.entries) e.key.toString(): e.value as Object?} : const <String, Object?>{};
    return MirrorState(
      seq: (m['seq'] as num?)?.toInt() ?? 0,
      at: _time(m['at']),
      w: (m['w'] as num?)?.toInt() ?? 0,
      h: (m['h'] as num?)?.toInt() ?? 0,
      dw: (m['dw'] as num?)?.toInt() ?? 0,
      dh: (m['dh'] as num?)?.toInt() ?? 0,
      streaming: m['streaming'] == true,
      lastInput: _text(m['lastInput']),
      error: _text(m['error']),
      watchingAt: _time(wm['at']),
      watchingBy: _text(wm['by']),
    );
  }

  /// How many frames the host has put up; the phone fetches on a change.
  final int seq;
  final DateTime? at;

  /// The frame as put up (long edge 720), and the device's own pixels —
  /// a tap on the frame maps to the device by their ratio.
  final int w;
  final int h;
  final int dw;
  final int dh;

  /// The host is capturing once a second because a sheet is open.
  final bool streaming;

  /// The last input played, as the caption reads it.
  final String? lastInput;
  final String? error;

  /// The phone's heartbeat while its sheet is open.
  final DateTime? watchingAt;
  final String? watchingBy;

  /// A sheet is open somewhere: the heartbeat is younger than [stale].
  bool watching(DateTime now, {Duration stale = watchStale}) => watchingAt != null && now.difference(watchingAt!) < stale;

  /// The host's half of the document — never `watching`.
  Map<String, Object?> toMap() => {
        'seq': seq,
        'at': at?.toUtc().toIso8601String(),
        'w': w,
        'h': h,
        'dw': dw,
        'dh': dh,
        'streaming': streaming,
        'lastInput': lastInput,
        'error': error,
      };

  MirrorState copyWith({int? seq, DateTime? at, int? w, int? h, int? dw, int? dh, bool? streaming, String? lastInput, String? error, bool clearError = false}) => MirrorState(
        seq: seq ?? this.seq,
        at: at ?? this.at,
        w: w ?? this.w,
        h: h ?? this.h,
        dw: dw ?? this.dw,
        dh: dh ?? this.dh,
        streaming: streaming ?? this.streaming,
        lastInput: lastInput ?? this.lastInput,
        error: clearError ? null : error ?? this.error,
        watchingAt: watchingAt,
        watchingBy: watchingBy,
      );

  static String? _text(Object? v) {
    final s = v?.toString() ?? '';
    return s.isEmpty ? null : s;
  }

  static DateTime? _time(Object? v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    final parsed = DateTime.tryParse(v.toString());
    if (parsed != null) return parsed;
    // A Firestore timestamp read through a generic map.
    try {
      final d = (v as dynamic).toDate();
      if (d is DateTime) return d;
    } on Object {
      // Not a timestamp either.
    }
    return null;
  }
}

/// A sheet left open on a locked phone stops the stream this long after
/// its last heartbeat.
const watchStale = Duration(seconds: 15);

/// How often an open sheet says so.
const watchPing = Duration(seconds: 5);

/// The long edge a frame is shrunk to.
const frameLongEdge = 720;

/// Where the newest frame lives in the bucket.
String framePath(String slug) => 'projects/$slug/frames/live.jpg';

/// `{type: input, action: tap|swipe|text|key, x, y, x2, y2, text}` in
/// device pixels.
Map<String, Object?> inputCommand(String action, {int? x, int? y, int? x2, int? y2, String? text}) => {
      'type': 'input',
      'action': action,
      if (x != null) 'x': x,
      if (y != null) 'y': y,
      if (x2 != null) 'x2': x2,
      if (y2 != null) 'y2': y2,
      if (text != null) 'text': text,
    };

/// A point on the frame (as drawn, [drawnW]×[drawnH]) to the device's
/// pixels ([dw]×[dh]), clamped inside.
(int, int) deviceXY(double fx, double fy, {required double drawnW, required double drawnH, required int dw, required int dh}) {
  if (drawnW <= 0 || drawnH <= 0 || dw <= 0 || dh <= 0) return (0, 0);
  final x = (fx / drawnW * dw).round().clamp(0, dw - 1);
  final y = (fy / drawnH * dh).round().clamp(0, dh - 1);
  return (x, y);
}

/// The frame's size once the long edge is [long] — what sips produces.
(int, int) fitLongEdge(int dw, int dh, {int long = frameLongEdge}) {
  if (dw <= 0 || dh <= 0) return (0, 0);
  if (dw >= dh) return (long, (dh * long / dw).round().clamp(1, long));
  return ((dw * long / dh).round().clamp(1, long), long);
}

/// A PNG's pixel size from its header; null when [bytes] is not one.
(int, int)? pngSize(List<int> bytes) {
  if (bytes.length < 24 || bytes[0] != 0x89 || bytes[1] != 0x50 || bytes[2] != 0x4E || bytes[3] != 0x47) return null;
  int be(int i) => (bytes[i] << 24) | (bytes[i + 1] << 16) | (bytes[i + 2] << 8) | bytes[i + 3];
  return (be(16), be(20));
}

/// The input as the caption reads it: `TAP 512, 900`, `SWIPE 100,900 → 100,300`, `TEXT "hello"`, `KEY back`.
String inputLabel(Map<String, Object?> cmd) {
  final a = (cmd['action'] ?? '').toString();
  switch (a) {
    case 'tap':
      return 'TAP ${cmd['x']}, ${cmd['y']}';
    case 'swipe':
      return 'SWIPE ${cmd['x']},${cmd['y']} → ${cmd['x2']},${cmd['y2']}';
    case 'text':
      return 'TEXT "${cmd['text']}"';
    case 'key':
      return 'KEY ${cmd['text']}';
    default:
      return a.toUpperCase();
  }
}

/// `0.4 s`, `12 s`, `3 min` — a frame's age.
String ageLabel(Duration d) {
  final ms = d.inMilliseconds;
  if (ms < 0) return '0 s';
  if (ms < 10000) return '${(ms / 1000).toStringAsFixed(1)} s';
  if (ms < 60000) return '${ms ~/ 1000} s';
  return '${ms ~/ 60000} min';
}

/// The Session tab's line.
String mirrorLine(MirrorState m, {DateTime? now}) {
  final t = now ?? DateTime.now();
  if (m.error != null) return 'Mirror · ${m.error}';
  if (m.seq == 0) return 'Mirror · no frame yet';
  final age = m.at == null ? '' : ' · ${ageLabel(t.difference(m.at!))} ago';
  return 'Mirror · ${m.streaming ? 'live' : 'idle'} · frame ${m.seq}$age${m.watching(t) ? ' · a sheet is open on ${m.watchingBy ?? 'a phone'}' : ''}';
}

/// What the host says when idb is missing — the session can install it.
const idbMissing = 'idb is not installed on the Mac — input on the simulator needs it: brew install idb-companion, then pipx install fb-idb (or pip3 install fb-idb)';
