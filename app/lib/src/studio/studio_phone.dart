import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart' hide Step, StepState;

import '../blobs.dart';
import '../screens/deck_tab.dart';
import '../widgets/common.dart';
import 'studio_desk_relay.dart';
import 'studio_draft.dart';
import 'studio_media_view.dart';
import 'studio_orchestrator.dart';
import 'studio_orchestrator_relay.dart';
import 'studio_relay.dart';
import 'studio_screen.dart';

/// The phone's Studio: the Mac's, as the relay has it — [initialTab] 1 opens
/// on the orchestrator (a push about one of its asks lands there).
Future<void> openPhoneStudio(BuildContext context, {int initialTab = 0, int inboxSegment = 0}) async {
  final data = RemoteStudioData(FirebaseFirestore.instance)..start();
  final orch = RemoteOrchestrator(FirebaseFirestore.instance)..start();
  final threads = RemoteThreads(FirebaseFirestore.instance)..start();
  await Navigator.of(context).push(MaterialPageRoute<void>(
    builder: (_) => StudioScreen(
      source: data,
      remote: true,
      initialTab: initialTab,
      initialInboxSegment: inboxSegment,
      // Questions on a step, and the phone's own draft — sent through the Mac.
      threads: threads,
      draft: phoneDraft,
      sendToOrchestrator: orch.send,
      orchestratorTab: PhoneOrchestratorTab(remote: orch, data: data),
      mediaTab: PhoneMediaScreen(db: FirebaseFirestore.instance, blobs: FirebaseBlobStore(), embedded: true),
    ),
  ));
  data.dispose();
  orch.dispose();
  threads.dispose();
}

/// The phone's draft — kept on the phone across launches until sent.
final StudioDraft phoneDraft = StudioDraft()..restore();

/// The orchestrator on the phone: the same AUTOPILOT bar as on the Mac (its
/// commands, the review loop, the schedule — carried out by the Mac) over the
/// phone's own Deck on the orchestrator's session.
class PhoneOrchestratorTab extends StatelessWidget {
  const PhoneOrchestratorTab({super.key, required this.remote, required this.data});
  final RemoteOrchestrator remote;
  final RemoteStudioData data;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: remote,
      builder: (context, _) {
        if (!remote.published) return const EmptyNote('The Mac has not published the orchestrator yet. Open K.A.T.Y.A on the Mac with the orchestrator\'s folder set.');
        return Column(children: [
          AutopilotBar(send: remote.send, lanes: data.snapshot.lanes, loop: remote, schedule: remote),
          Expanded(child: RemoteDeckTab(db: FirebaseFirestore.instance, slug: kOrchestratorSlug, title: 'ORCHESTRATOR', blobs: FirebaseBlobStore(), planControls: false)),
        ]);
      },
    );
  }
}
