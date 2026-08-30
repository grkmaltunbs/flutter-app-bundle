import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_selector/file_selector.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart' hide Step, StepState;
import 'package:path/path.dart' as p;

import '../app.dart';
import '../host/host_projects.dart';
import '../host/project_registry.dart';
import '../plan_source.dart';
import '../relay.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'project_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _registry = ProjectRegistry();

  @override
  void initState() {
    super.initState();
    if (isHost) _registry.load();
  }

  @override
  void dispose() {
    _registry.dispose();
    super.dispose();
  }

  Future<void> _openFolder() async {
    final dir = await getDirectoryPath();
    if (dir == null || !mounted) return;
    if (!ProjectRegistry.hasPlan(dir)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No plan/kit.yaml in ${p.basename(dir)} — run `kit init` or `kit import` there first.')));
      return;
    }
    await _registry.add(dir);
    if (mounted) _openHost(dir);
  }

  void _openHost(String dir) {
    final host = HostProjects.get(dir);
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => ProjectScreen.host(host)));
  }

  void _openRemote(ProjectSummary s) {
    final source = RemotePlanSource(FirebaseFirestore.instance, s.slug)..start();
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => ProjectScreen.remote(source: source, slug: s.slug)));
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Projects'),
        actions: [
          IconButton(tooltip: 'Sign out', icon: const Icon(Icons.logout), onPressed: () => FirebaseAuth.instance.signOut()),
        ],
      ),
      floatingActionButton: isHost ? FloatingActionButton.extended(onPressed: _openFolder, icon: const Icon(Icons.folder_open), label: const Text('Open folder')) : null,
      body: isHost
          ? ListenableBuilder(
              listenable: _registry,
              builder: (context, _) {
                if (_registry.dirs.isEmpty) return const EmptyNote('Open a project folder that has a plan/ directory.');
                return ListView.separated(
                  itemCount: _registry.dirs.length,
                  separatorBuilder: (_, _) => Divider(height: 1, color: t.line),
                  itemBuilder: (context, i) {
                    final dir = _registry.dirs[i];
                    final open = HostProjects.open[dir];
                    return ListTile(
                      leading: Icon(Icons.folder, color: open != null ? t.accent : t.muted),
                      title: Text(p.basename(dir)),
                      subtitle: Text(dir, maxLines: 1, overflow: TextOverflow.ellipsis),
                      trailing: open == null
                          ? IconButton(icon: const Icon(Icons.close), tooltip: 'Forget', onPressed: () => _registry.remove(dir))
                          : ListenableBuilder(listenable: open.session, builder: (_, _) => Pill(open.session.state.name, color: open.session.running ? t.good : t.muted)),
                      onTap: () => _openHost(dir),
                    );
                  },
                );
              },
            )
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance.collection('projects').snapshots(),
              builder: (context, snap) {
                if (snap.hasError) return EmptyNote('Could not read the relay: ${snap.error}');
                if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                final projects = snap.data!.docs.map(ProjectSummary.fromDoc).toList()..sort((a, b) => (b.updatedAt ?? DateTime(0)).compareTo(a.updatedAt ?? DateTime(0)));
                if (projects.isEmpty) return const EmptyNote('Nothing published yet. Open a project in the Mac app first.');
                return ListView.separated(
                  itemCount: projects.length,
                  separatorBuilder: (_, _) => Divider(height: 1, color: t.line),
                  itemBuilder: (context, i) {
                    final s = projects[i];
                    final open = (s.counts['open'] as num?)?.toInt();
                    final asking = s.pendingAsks > 0;
                    return ListTile(
                      leading: Icon(asking ? Icons.notifications_active : Icons.auto_awesome_motion, color: asking ? t.warn : (s.live ? t.good : t.muted)),
                      title: Text(s.name),
                      subtitle: Text([s.machine, if (open != null) '$open waiting on you', if (asking) 'Claude is asking' else if (s.live) 'Claude session live'].join(' · ')),
                      trailing: asking ? Pill('needs you', color: t.warn, filled: true) : const Icon(Icons.chevron_right),
                      onTap: () => _openRemote(s),
                    );
                  },
                );
              },
            ),
    );
  }
}
