import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_kit/kit.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../firebase_options.dart';
import '../relay.dart';

/// One channel the phone draws on — the same four `MainActivity` creates,
/// so a push and a locally drawn notification land in the same place and
/// one switch in the phone's settings silences both.
class NoticeChannel {
  const NoticeChannel(this.id, this.name, this.description, {required this.high});
  final String id;
  final String name;
  final String description;

  /// Heads-up and sound — a person is waiting on the other end.
  final bool high;

  static const asks = NoticeChannel('asks', 'Claude needs you', 'A command to allow, a question to answer, a website to sign in to', high: true);
  static const problems = NoticeChannel('problems', 'Problems', 'The session stopped or a turn ended in an error', high: true);
  static const done = NoticeChannel('done', 'Turn ended', 'Claude finished what you sent, while you were away', high: false);
  static const steps = NoticeChannel('steps', 'Steps', 'A step of the plan flipped to done', high: false);

  static NoticeChannel of(String id) => switch (id) {
        'problems' => problems,
        'done' => done,
        'steps' => steps,
        _ => asks,
      };
}

/// A push as the phone draws it: the words, the channel, the buttons, and
/// the id under which the next of its kind replaces it. Pure — built from
/// the data map the Mac sends (`androidData` in the host's push sender).
class LocalNotice {
  const LocalNotice({required this.id, required this.channel, required this.title, required this.body, required this.actions, required this.data});
  final int id;
  final NoticeChannel channel;
  final String title;
  final String body;
  final List<NoticeAction> actions;
  final Map<String, String> data;

  String get slug => data['slug'] ?? '';
  String get kind => data['kind'] ?? '';
  String? get requestId => data['requestId'];
  bool get isAsk => channel.id == NoticeChannel.asks.id;

  /// What a tap or a button hands back: the data, as JSON.
  String get payload => jsonEncode(data);

  static Map<String, String> _strings(Map<String, Object?> m) => {
        for (final e in m.entries)
          if (e.value != null) e.key: e.value.toString(),
      };

  /// Null for a message that is not a notification — a withdrawal, or one
  /// with no project to open.
  static LocalNotice? from(Map<String, Object?> raw) {
    final data = _strings(raw);
    if ((data['slug'] ?? '').isEmpty || data['kind'] == 'withdraw') return null;
    final channel = NoticeChannel.of(data['channel'] ?? NoticeChannel.asks.id);
    final actions = <NoticeAction>[];
    final a = data['actions'];
    if (a != null && a.isNotEmpty) {
      try {
        for (final x in jsonDecode(a) as List) {
          if (x is Map && x['id'] != null && x['label'] != null) actions.add(NoticeAction(x['id'].toString(), x['label'].toString()));
        }
      } on Object {
        // No buttons beats no notification.
        actions.clear();
      }
    }
    return LocalNotice(id: noticeId(data), channel: channel, title: data['title'] ?? '', body: data['body'] ?? '', actions: actions, data: data);
  }

  /// A withdrawal's target — the id of the ask's notification — or null
  /// when the message is not one.
  static int? withdrawnId(Map<String, Object?> raw) {
    final data = _strings(raw);
    if (data['kind'] != 'withdraw') return null;
    final rid = data['requestId'] ?? '';
    return rid.isEmpty ? null : idFor(rid);
  }

  /// An ask is its own notification, by request id, so a withdrawal takes
  /// down exactly the ask it names; anything else is one per channel and
  /// project, the newest replacing the last — the tag FCM used.
  static int noticeId(Map<String, String> data) {
    final rid = data['requestId'] ?? '';
    final channel = data['channel'] ?? NoticeChannel.asks.id;
    return idFor(channel == NoticeChannel.asks.id && rid.isNotEmpty ? rid : '$channel-${data['slug']}');
  }

  /// A stable, positive 31-bit id from a string (FNV-1a) — the same in the
  /// isolate that drew the notification and the one that takes it down.
  static int idFor(String s) {
    var h = 0x811c9dc5;
    for (final c in s.codeUnits) {
      h ^= c;
      h = (h * 0x01000193) & 0xffffffff;
    }
    return h & 0x7fffffff;
  }
}

/// The phone's notifications, drawn here from the Mac's data messages —
/// with Allow and Deny on an ask, answered from the lock screen by
/// [kitNotificationAction] without opening the app.
class LocalNotices {
  static final FlutterLocalNotificationsPlugin plugin = FlutterLocalNotificationsPlugin();
  static bool _ready = false;

  /// Once per isolate. [onTap] runs on the main isolate when a
  /// notification's body is tapped with the app up.
  static Future<void> init({void Function(Map<String, Object?> data)? onTap}) async {
    if (_ready) return;
    _ready = true;
    await plugin.initialize(
      settings: const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')),
      onDidReceiveNotificationResponse: (r) {
        final data = dataOf(r.payload);
        if (data != null && onTap != null) onTap(data);
      },
      onDidReceiveBackgroundNotificationResponse: kitNotificationAction,
    );
  }

  /// The notification the app was opened from, if it was — so a cold start
  /// from a tap lands on the project.
  static Future<Map<String, Object?>?> launchData() async {
    final d = await plugin.getNotificationAppLaunchDetails();
    if (d == null || !d.didNotificationLaunchApp) return null;
    return dataOf(d.notificationResponse?.payload);
  }

  static Map<String, Object?>? dataOf(String? payload) {
    if (payload == null || payload.isEmpty) return null;
    try {
      final j = jsonDecode(payload);
      return j is Map ? {for (final e in j.entries) e.key.toString(): e.value as Object?} : null;
    } on FormatException {
      return null;
    }
  }

  /// A data message from the Mac: drawn, or — a withdrawal — taken down.
  static Future<void> handle(Map<String, Object?> data) async {
    final w = LocalNotice.withdrawnId(data);
    if (w != null) return plugin.cancel(id: w);
    final n = LocalNotice.from(data);
    if (n == null) return;
    return show(n);
  }

  static Future<void> show(LocalNotice n) => plugin.show(id: n.id, title: n.title, body: n.body, notificationDetails: NotificationDetails(android: androidDetails(n)), payload: n.payload);

  static AndroidNotificationDetails androidDetails(LocalNotice n) => AndroidNotificationDetails(
        n.channel.id,
        n.channel.name,
        channelDescription: n.channel.description,
        importance: n.channel.high ? Importance.high : Importance.defaultImportance,
        priority: n.channel.high ? Priority.high : Priority.defaultPriority,
        styleInformation: BigTextStyleInformation(n.body),
        category: n.isAsk ? AndroidNotificationCategory.message : null,
        // A button answers in the background and the notification stays
        // until the answer went through — then [kitNotificationAction]
        // takes it down, or says what went wrong in its place.
        actions: [for (final a in n.actions) AndroidNotificationAction(a.id, a.label, showsUserInterface: false, cancelNotification: false)],
      );
}

/// FCM's background entry: a data message while the app is in the
/// background or closed. Its own isolate — Firebase first.
@pragma('vm:entry-point')
Future<void> kitBackgroundMessage(RemoteMessage m) async {
  await _firebase();
  // Its own isolate: the plugin is set up here too, once.
  await LocalNotices.init();
  await LocalNotices.handle(m.data);
}

/// A button on a notification, in its own isolate, the app still closed:
/// the answer goes to the Mac as the `answer` command the card would send.
@pragma('vm:entry-point')
Future<void> kitNotificationAction(NotificationResponse r) async {
  final data = LocalNotices.dataOf(r.payload);
  final action = r.actionId;
  if (data == null || action == null || action.isEmpty) return;
  await _firebase();
  await LocalNotices.init();
  final outcome = await answerFromNotification(FirebaseFirestore.instance, data, action, signedIn: _signedIn);
  final n = LocalNotice.from(data);
  if (n == null) return;
  if (outcome == AnswerOutcome.answered || outcome == AnswerOutcome.stale) {
    await LocalNotices.plugin.cancel(id: n.id);
  } else {
    // The button did nothing; say so where the button was.
    await LocalNotices.show(LocalNotice(id: n.id, channel: n.channel, title: n.title, body: outcomeLine(outcome), actions: const [], data: n.data));
  }
}

Future<void> _firebase() async {
  if (Firebase.apps.isEmpty) await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

/// The relay user, restored by Firebase Auth in this isolate — up to a few
/// seconds after a cold start.
Future<bool> _signedIn() async {
  if (FirebaseAuth.instance.currentUser != null) return true;
  try {
    final u = await FirebaseAuth.instance.authStateChanges().first.timeout(const Duration(seconds: 6));
    return u != null;
  } on Object {
    return false;
  }
}

/// What became of a button press.
enum AnswerOutcome { answered, stale, unknown, signedOut, failed }

/// The line that replaces the buttons when the press did nothing.
String outcomeLine(AnswerOutcome o) => switch (o) {
      AnswerOutcome.answered => 'Answered.',
      AnswerOutcome.stale => 'Already answered elsewhere.',
      AnswerOutcome.unknown => 'That button no longer applies — open K.A.T.Y.A to answer.',
      AnswerOutcome.signedOut => 'Not signed in on this phone — open K.A.T.Y.A to answer.',
      AnswerOutcome.failed => 'Could not reach the relay — open K.A.T.Y.A to answer.',
    };

/// Answers the ask a notification is about, as the card would: reads the
/// ask from the relay (the button carries no input), maps the button to an
/// answer, and writes the `answer` command the host runs. Pure over
/// Firestore — a test runs it on a fake.
Future<AnswerOutcome> answerFromNotification(FirebaseFirestore db, Map<String, Object?> data, String actionId, {Future<bool> Function()? signedIn, String from = 'notification'}) async {
  final slug = (data['slug'] ?? '').toString();
  final rid = (data['requestId'] ?? '').toString();
  if (slug.isEmpty || rid.isEmpty) return AnswerOutcome.unknown;
  if (signedIn != null && !await signedIn()) return AnswerOutcome.signedOut;
  try {
    final d = await db.collection('projects').doc(slug).collection('asks').doc(rid).get();
    final m = d.data();
    if (m == null || m['answeredAt'] != null) return AnswerOutcome.stale;
    final ask = Ask.fromMap({for (final e in m.entries) e.key: e.value as Object?});
    final a = answerForAction(ask, actionId, here: from);
    if (a == null) return AnswerOutcome.unknown;
    await CommandSender(db, slug).answer(ask, a, from: from);
    return AnswerOutcome.answered;
  } on Object {
    return AnswerOutcome.failed;
  }
}
