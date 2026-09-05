import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import '../relay.dart';
import '../screens/project_screen.dart';
import '../plan_source.dart';
import 'local_notices.dart';
import 'push_registrar.dart';

/// The phone's one registrar — the home screen shows its status.
class Pushes {
  static final PushRegistrar registrar = PushRegistrar(FirebaseFirestore.instance);
}

/// Phone only, under the sign-in gate: registers the phone, draws the
/// Mac's data messages as notifications (with Allow / Deny on an ask —
/// `local_notices.dart`), and turns a notification into the project it is
/// about — a tap while the app is closed or in the background opens that
/// project; one that arrives while the app is open shows a bar with OPEN,
/// since a foreground app shows nothing in the tray.
class PushListener extends StatefulWidget {
  const PushListener({super.key, required this.child, this.messaging = true});
  final Widget child;

  /// Off in a widget test: no Firebase Messaging there.
  final bool messaging;

  @override
  State<PushListener> createState() => _PushListenerState();
}

class _PushListenerState extends State<PushListener> {
  final _subs = <StreamSubscription<RemoteMessage>>[];

  @override
  void initState() {
    super.initState();
    if (!widget.messaging) return;
    unawaited(Pushes.registrar.register());
    // Notifications this app drew: a tap with the app up, or the one the
    // app was cold-started from.
    unawaited(LocalNotices.init(onTap: _open));
    LocalNotices.launchData().then((d) {
      if (d != null) _open(d);
    });
    // Notifications FCM drew (a platform without the local path).
    FirebaseMessaging.instance.getInitialMessage().then((m) {
      if (m != null) _open(m.data);
    });
    _subs.add(FirebaseMessaging.onMessageOpenedApp.listen((m) => _open(m.data)));
    _subs.add(FirebaseMessaging.onMessage.listen(_arrived));
  }

  void _arrived(RemoteMessage m) {
    final data = m.data;
    // An ask answered elsewhere: a notification drawn before the app came
    // up comes down; the card drops through the relay on its own.
    if (LocalNotice.withdrawnId(data) != null) {
      unawaited(LocalNotices.handle(data));
      return;
    }
    // A turn that ended, a step that flipped: on the screen already.
    final kind = PushTap.from(data)?.kind;
    if (kind == 'done' || kind == 'step') return;
    final text = snackText(m);
    if (text.isEmpty || !mounted) return;
    // One bar at a time, and the same words once: a push that reaches this
    // phone by several tokens, or an ask repeated, must not queue a bar
    // per copy and sit over the composer for a minute.
    final now = DateTime.now();
    if (text == _lastSnack && _lastSnackAt != null && now.difference(_lastSnackAt!) < const Duration(seconds: 20)) return;
    _lastSnack = text;
    _lastSnackAt = now;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Text(text, maxLines: 3, overflow: TextOverflow.ellipsis),
        duration: const Duration(seconds: 4),
        action: PushTap.from(data) == null ? null : SnackBarAction(label: 'OPEN', onPressed: () => _open(data)),
      ));
  }

  String? _lastSnack;
  DateTime? _lastSnackAt;

  /// The bar's line: the tray notification's words, or the data message's.
  static String snackText(RemoteMessage m) {
    final n = m.notification;
    final title = n?.title ?? m.data['title']?.toString();
    final body = n?.body ?? m.data['body']?.toString();
    return [if (title != null && title.isNotEmpty) title, if (body != null && body.isNotEmpty) body].join(' — ');
  }

  Future<void> _open(Map<String, Object?> data) async {
    final tap = PushTap.from(data);
    if (tap == null) return;
    final d = await FirebaseFirestore.instance.collection('projects').doc(tap.slug).get();
    if (!mounted || !d.exists) return;
    final s = ProjectSummary.fromDoc(d);
    final nav = Navigator.of(context);
    // Back to the list, then into the project: no second copy of a
    // project screen that is already open.
    nav.popUntil((r) => r.isFirst);
    final source = RemotePlanSource(FirebaseFirestore.instance, s.slug)..start();
    nav.push(MaterialPageRoute<void>(builder: (_) => ProjectScreen.remote(source: source, slug: s.slug)));
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
