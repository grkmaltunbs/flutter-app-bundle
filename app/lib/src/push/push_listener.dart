import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import '../relay.dart';
import '../screens/project_screen.dart';
import '../plan_source.dart';
import 'push_registrar.dart';

/// The phone's one registrar — the home screen shows its status.
class Pushes {
  static final PushRegistrar registrar = PushRegistrar(FirebaseFirestore.instance);
}

/// Phone only, under the sign-in gate: registers the phone, and turns a
/// notification into the project it is about — a tap while the app is
/// closed or in the background opens that project; one that arrives
/// while the app is open shows a bar with OPEN, since Android shows no
/// tray notification for a foreground app.
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
    FirebaseMessaging.instance.getInitialMessage().then((m) {
      if (m != null) _open(m);
    });
    _subs.add(FirebaseMessaging.onMessageOpenedApp.listen(_open));
    _subs.add(FirebaseMessaging.onMessage.listen(_arrived));
  }

  void _arrived(RemoteMessage m) {
    // A turn that ended is on the screen already when the app is open.
    if (PushTap.from(m.data)?.kind == 'done') return;
    final n = m.notification;
    final text = [if (n?.title != null) n!.title!, if (n?.body != null) n!.body!].join(' — ');
    if (text.isEmpty || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(text, maxLines: 3, overflow: TextOverflow.ellipsis),
      duration: const Duration(seconds: 8),
      action: PushTap.from(m.data) == null ? null : SnackBarAction(label: 'OPEN', onPressed: () => _open(m)),
    ));
  }

  Future<void> _open(RemoteMessage m) async {
    final tap = PushTap.from(m.data);
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
