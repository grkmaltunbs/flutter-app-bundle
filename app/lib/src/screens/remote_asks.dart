import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart' hide Step, StepState;
import 'package:flutter_kit/kit.dart';

import '../relay.dart';
import 'ask_card.dart';

/// The phone's side of an ask: the oldest unanswered one, as a card; the
/// answer goes to the host as a command. The card drops the moment it is
/// answered here, and again when the host stamps it — whichever comes
/// first, so an ask the Mac settled disappears too.
class RemoteAskPanel extends StatefulWidget {
  const RemoteAskPanel({super.key, required this.db, required this.slug, this.from = 'phone'});
  final FirebaseFirestore db;
  final String slug;
  final String from;

  @override
  State<RemoteAskPanel> createState() => _RemoteAskPanelState();
}

class _RemoteAskPanelState extends State<RemoteAskPanel> {
  final _answered = <String>{};

  Future<void> _answer(Ask ask, AskAnswer a, {bool remember = false}) async {
    setState(() => _answered.add(ask.requestId));
    try {
      await CommandSender(widget.db, widget.slug).answer(ask, a, remember: remember, from: widget.from);
    } on Object catch (e) {
      if (!mounted) return;
      setState(() => _answered.remove(ask.requestId));
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not send the answer: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: widget.db.collection('projects').doc(widget.slug).collection('asks').where('answeredAt', isNull: true).snapshots(),
      builder: (context, snap) {
        final docs = (snap.data?.docs ?? const []).where((d) => !_answered.contains(d.id)).toList()
          ..sort((a, b) => (a.data()['at'] ?? '').toString().compareTo((b.data()['at'] ?? '').toString()));
        if (docs.isEmpty) return const SizedBox.shrink();
        final ask = Ask.fromMap({for (final e in docs.first.data().entries) e.key: e.value as Object?});
        return AskCard(
          key: ValueKey(ask.requestId),
          ask: ask,
          here: widget.from,
          onAnswer: (a, {remember = false}) => _answer(ask, a, remember: remember),
        );
      },
    );
  }
}
