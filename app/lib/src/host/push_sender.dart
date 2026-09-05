import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_kit/kit.dart';
import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import 'bridge_session.dart';

/// The service-account key for `flutterappbundle`, outside the repo:
/// `~/.flutter_kit/flutterappbundle-service-account.json`. `.gitignore`
/// excludes `*service-account*.json` everywhere in any case.
String serviceAccountPath({String? home}) => p.join(kitHome(home: home), 'flutterappbundle-service-account.json');

/// Mints the bearer token FCM wants. One implementation reads the key;
/// a test hands in a fixed token.
abstract class TokenMinter {
  String get projectId;

  /// Who the token speaks as — the service account's email.
  String get who;
  Future<String> token();
}

/// OAuth from the service-account key — a signed JWT for an hour's access
/// token, cached until a minute before it expires.
class ServiceAccountMinter implements TokenMinter {
  /// Throws [FormatException] when [json] is not a service-account key.
  ServiceAccountMinter(Map<String, Object?> json, {http.Client? client, DateTime Function()? now})
      : _client = client ?? http.Client(),
        _now = now ?? DateTime.now,
        projectId = (json['project_id'] ?? '').toString() {
    if (json['type'] != 'service_account' || json['private_key'] == null || json['client_email'] == null || json['client_id'] == null) {
      throw const FormatException('not a service-account key (expected type, project_id, client_email, client_id, private_key)');
    }
    if (projectId.isEmpty) throw const FormatException('the key names no project_id');
    _creds = ServiceAccountCredentials.fromJson(json);
  }

  static const scopes = ['https://www.googleapis.com/auth/firebase.messaging'];

  final http.Client _client;
  final DateTime Function() _now;
  late final ServiceAccountCredentials _creds;
  AccessCredentials? _cached;

  @override
  final String projectId;

  @override
  String get who => _creds.email;

  @override
  Future<String> token() async {
    final c = _cached;
    if (c != null && c.accessToken.expiry.isAfter(_now().toUtc().add(const Duration(minutes: 1)))) return c.accessToken.data;
    final fresh = await obtainAccessCredentialsViaServiceAccount(_creds, scopes, _client);
    _cached = fresh;
    return fresh.accessToken.data;
  }
}

/// The FCM v1 message for one phone. An Android phone takes a **data**
/// message and draws the notification itself (`push/local_notices.dart`)
/// — that is how Allow and Deny get onto the lock screen, and how an ask
/// answered elsewhere comes off it. Any other platform takes the tray
/// notification FCM draws: what the tray shows, what a tap carries, and
/// the channel — each kind keeps one notification a project (the `tag`),
/// so the newest replaces the last.
Map<String, Object?> fcmMessage(Notice n, {required String slug, required String token, bool android = false}) {
  if (android) {
    return {
      'token': token,
      'data': androidData(n, slug: slug),
      'android': {'priority': 'high'},
    };
  }
  return {
    'token': token,
    'notification': {'title': n.title, 'body': n.body},
    'data': n.data(slug),
    'android': {
      'priority': 'high',
      'notification': {'channel_id': n.channel, 'tag': '${n.channel}-$slug', 'sound': 'default'},
    },
    'apns': {
      'headers': {'apns-priority': '10'},
      'payload': {
        'aps': {'sound': 'default', 'thread-id': slug},
      },
    },
  };
}

/// What an Android phone needs to draw the notification: what a tap
/// carries, the words, the channel, and the buttons as JSON. Every value a
/// string — FCM data takes nothing else.
Map<String, String> androidData(Notice n, {required String slug}) => {
      ...n.data(slug),
      'title': n.title,
      'body': n.body,
      'channel': n.channel,
      'tag': '${n.channel}-$slug',
      if (n.actions.isNotEmpty) 'actions': jsonEncode([for (final a in n.actions) {'id': a.id, 'label': a.label}]),
    };

/// The silent message that takes an ask's notification down on every phone
/// once it was answered somewhere — the Mac, a phone, a button on another
/// phone — or withdrawn by the host. Nothing is shown; the phone cancels.
Map<String, Object?> withdrawMessage({required String slug, required String requestId, required String token}) => {
      'token': token,
      'data': {'slug': slug, 'kind': 'withdraw', 'requestId': requestId},
      'android': {'priority': 'high'},
      'apns': {
        'headers': {'apns-priority': '5', 'apns-push-type': 'background'},
        'payload': {
          'aps': {'content-available': 1},
        },
      },
    };

/// The Android channels `MainActivity` creates, as [Notice.channel] names
/// them — each one the user can silence without the others.
const askChannel = 'asks';
const problemChannel = 'problems';
const doneChannel = 'done';
const stepChannel = 'steps';

/// Sends pushes from this Mac: reads the key when there is one, keeps the
/// list of registered phones live, and sends every [Notice] to each of
/// them. Never throws at the caller — what went wrong is [lastError] and
/// [status], for the Session tab.
class PushSender extends ChangeNotifier {
  PushSender({required this.db, this.home, http.Client? client, TokenMinter? minter, DateTime Function()? now})
      : _client = client ?? http.Client(),
        _now = now ?? DateTime.now {
    _minter = minter;
  }

  final FirebaseFirestore db;

  /// Overrides `~/.flutter_kit` — tests keep their key in a temp folder.
  final String? home;
  final http.Client _client;
  final DateTime Function() _now;
  TokenMinter? _minter;
  String? _keyError;
  DateTime? _keyChecked;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _devices;
  Timer? _keyTimer;

  /// The registered phones: token → the fields the phone wrote.
  Map<String, Map<String, Object?>> devices = const {};

  int sent = 0;
  DateTime? lastSentAt;
  String? lastError;

  String get keyPath => serviceAccountPath(home: home);

  /// A key is loaded — pushes can go.
  bool get ready => _minter != null;

  /// Where the key is read from; null when a minter was handed in.
  String get who => _minter?.who ?? '';

  /// Starts watching the phones. Idempotent.
  void start() {
    _devices ??= db.collection('devices').snapshots().listen((q) {
      devices = {for (final d in q.docs) d.id: {for (final e in d.data().entries) e.key: e.value as Object?}};
      notifyListeners();
    }, onError: (Object e) {
      lastError = 'could not read devices: $e';
      notifyListeners();
    });
    _loadKey();
    // A key dropped in while the app runs shows on the Session tab within
    // half a minute, not only after the next push.
    _keyTimer ??= Timer.periodic(const Duration(seconds: 30), (_) {
      if (ready) {
        _keyTimer?.cancel();
        _keyTimer = null;
      } else {
        _loadKey();
      }
    });
  }

  /// One line for the Session tab.
  String get status {
    if (!ready) return _keyError ?? 'No service-account key at $keyPath — the phone gets no pushes. Firebase console → Project settings → Service accounts → Generate new private key, then move the file there.';
    final phones = devices.isEmpty ? 'no phone registered yet — open the app on the phone and allow notifications' : '${devices.length} phone${devices.length == 1 ? '' : 's'} registered';
    final last = lastSentAt == null ? '' : ' · last sent ${_hm(lastSentAt!)}';
    final err = lastError == null ? '' : ' · last error: $lastError';
    return 'Pushes go as $who · $phones$last$err';
  }

  /// Reads the key when it has not been read yet, or is missing and might
  /// have appeared — dropping the file in works without a restart.
  void _loadKey() {
    if (_minter != null) return;
    final t = _now();
    if (_keyChecked != null && t.difference(_keyChecked!) < const Duration(seconds: 10)) return;
    _keyChecked = t;
    final f = File(keyPath);
    if (!f.existsSync()) {
      _keyError = null;
      return;
    }
    try {
      final json = jsonDecode(f.readAsStringSync());
      if (json is! Map) throw const FormatException('not a JSON object');
      _minter = ServiceAccountMinter({for (final e in json.entries) e.key.toString(): e.value}, client: _client, now: _now);
      _keyError = null;
      notifyListeners();
    } on Object catch (e) {
      _keyError = 'The key at $keyPath could not be read: $e';
      notifyListeners();
    }
  }

  /// Sends [n] to every registered phone. Returns how many took it; a
  /// phone whose token FCM no longer knows is forgotten on the spot.
  Future<int> send(Notice n, {required String slug}) => _broadcast((token) => fcmMessage(n, slug: slug, token: token, android: isAndroid(token)));

  /// Takes an ask's notification down on every phone — it was answered, or
  /// withdrawn. Not counted as a push sent.
  Future<int> withdraw(String requestId, {required String slug}) =>
      _broadcast((token) => withdrawMessage(slug: slug, requestId: requestId, token: token), count: false);

  /// The phone registered under [token] draws its own notifications.
  bool isAndroid(String token) => devices[token]?['platform'] == 'android';

  Future<int> _broadcast(Map<String, Object?> Function(String token) build, {bool count = true}) async {
    _loadKey();
    final m = _minter;
    if (m == null) return 0;
    if (devices.isEmpty) return 0;
    var ok = 0;
    String? failure;
    for (final token in devices.keys.toList()) {
      try {
        final r = await _post(m, build(token));
        if (r == null) {
          ok++;
        } else if (r.stale) {
          unawaited(db.collection('devices').doc(token).delete().catchError((Object _) {}));
          devices = {...devices}..remove(token);
        } else {
          failure = r.message;
        }
      } on Object catch (e) {
        failure = e.toString();
      }
    }
    if (ok > 0 && count) {
      sent += ok;
      lastSentAt = _now();
    }
    lastError = failure;
    notifyListeners();
    return ok;
  }

  /// Null on success; otherwise what FCM said, and whether the token is
  /// gone for good (`UNREGISTERED`, or plain 404).
  Future<_Failure?> _post(TokenMinter m, Map<String, Object?> message) async {
    final bearer = await m.token();
    final res = await _client
        .post(
          Uri.parse('https://fcm.googleapis.com/v1/projects/${m.projectId}/messages:send'),
          headers: {'Authorization': 'Bearer $bearer', 'Content-Type': 'application/json'},
          body: jsonEncode({'message': message}),
        )
        .timeout(const Duration(seconds: 20));
    if (res.statusCode >= 200 && res.statusCode < 300) return null;
    String detail = res.body;
    var stale = res.statusCode == 404;
    try {
      final j = jsonDecode(res.body);
      final err = j is Map ? j['error'] : null;
      if (err is Map) {
        detail = '${err['status'] ?? res.statusCode}: ${err['message'] ?? ''}';
        for (final d in (err['details'] as List? ?? const [])) {
          if (d is Map && d['errorCode'] == 'UNREGISTERED') stale = true;
        }
      }
    } on Object {
      // Not JSON — the body is the detail.
    }
    return _Failure('FCM ${res.statusCode} — ${detail.length > 200 ? detail.substring(0, 200) : detail}', stale: stale);
  }

  static String _hm(DateTime at) {
    final l = at.toLocal();
    return '${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _devices?.cancel();
    _keyTimer?.cancel();
    super.dispose();
  }
}

class _Failure {
  const _Failure(this.message, {required this.stale});
  final String message;
  final bool stale;
}

/// What the end of a turn is worth: the session failed (once per
/// failure), a turn ended in an error, or a turn ended well (once per
/// result — the reply the user walked away from). Pure — the host feeds
/// it the session's state on every change.
class TurnWatch {
  String? _failure;
  ResultEvent? _result;

  Notice? check({required BridgeState state, String? error, ResultEvent? lastResult, bool interrupted = false, required String project}) {
    if (state == BridgeState.failed && error != null && error.isNotEmpty) {
      if (_failure == error) return null;
      _failure = error;
      return noticeForProblem(error, project: project);
    }
    if (state != BridgeState.failed) _failure = null;
    if (lastResult != null && !identical(lastResult, _result)) {
      _result = lastResult;
      // The user cut it; they know.
      if (interrupted) return null;
      if (lastResult.isError) return noticeForProblem(lastResult.text.trim().isEmpty ? 'The turn ended in an error.' : lastResult.text, project: project);
      return noticeForDone(lastResult, project: project);
    }
    return null;
  }
}
