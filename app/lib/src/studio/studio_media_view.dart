import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart' hide Step, StepState;
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import 'package:video_player/video_player.dart';

import '../blobs.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'studio_media.dart';

// The media the autopilot shows: a gallery and a strip on the Mac (files on
// disk), the same gallery on the phone (the relay's copies), and one viewer
// for both — pictures zoom, videos play in the app.

String _when(DateTime at) {
  final l = at.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final d = today.difference(DateTime(l.year, l.month, l.day)).inDays;
  return '${d == 0 ? 'today' : (d == 1 ? 'yesterday' : '${two(l.month)}-${two(l.day)}')} ${two(l.hour)}:${two(l.minute)}';
}

/// A picture or a video, full screen: pinch/wheel to zoom a picture; a
/// video plays with its controls. [file] is on disk; for the phone the
/// caller fetches it first.
class MediaViewer extends StatelessWidget {
  const MediaViewer({super.key, required this.file, required this.isVideo, this.caption, this.title});
  final File file;
  final bool isVideo;
  final String? caption;
  final String? title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(title ?? p.basename(file.path), maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [if (Platform.isMacOS) IconButton(tooltip: 'Open in its app', icon: const Icon(Icons.open_in_new), onPressed: () => OpenFilex.open(file.path))],
      ),
      body: Column(children: [
        Expanded(child: isVideo ? VideoView(file: file) : InteractiveViewer(maxScale: 8, child: Center(child: Image.file(file)))),
        if (caption != null && caption!.isNotEmpty)
          Container(
            width: double.infinity,
            color: Colors.black,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: SafeArea(top: false, child: Text(caption!, style: const TextStyle(color: Colors.white70, fontSize: 13))),
          ),
      ]),
    );
  }
}

/// A video from a file, playing in the app: tap to pause, a scrubber below.
class VideoView extends StatefulWidget {
  const VideoView({super.key, required this.file});
  final File file;
  @override
  State<VideoView> createState() => _VideoViewState();
}

class _VideoViewState extends State<VideoView> {
  late final VideoPlayerController _c = VideoPlayerController.file(widget.file);
  String? _error;

  @override
  void initState() {
    super.initState();
    _c.initialize().then((_) {
      if (!mounted) return;
      setState(() {});
      _c
        ..setLooping(true)
        ..play();
    }).catchError((Object e) {
      if (mounted) setState(() => _error = '$e');
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) return Center(child: Text('The video does not play here: $_error', style: const TextStyle(color: Colors.white70)));
    if (!_c.value.isInitialized) return const Center(child: CircularProgressIndicator());
    return Column(children: [
      Expanded(
        child: GestureDetector(
          onTap: () => setState(() => _c.value.isPlaying ? _c.pause() : _c.play()),
          child: Center(child: AspectRatio(aspectRatio: _c.value.aspectRatio, child: VideoPlayer(_c))),
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(children: [
          IconButton(
            color: Colors.white,
            icon: ValueListenableBuilder(valueListenable: _c, builder: (_, v, _) => Icon(v.isPlaying ? Icons.pause : Icons.play_arrow)),
            onPressed: () => setState(() => _c.value.isPlaying ? _c.pause() : _c.play()),
          ),
          Expanded(child: VideoProgressIndicator(_c, allowScrubbing: true, colors: const VideoProgressColors(playedColor: Color(0xFF58D7FF)))),
        ]),
      ),
    ]);
  }
}

/// One tile: the picture (or a film frame), its source and time.
class _Tile extends StatelessWidget {
  const _Tile({required this.image, required this.isVideo, required this.label, required this.onTap, this.state, this.stateColor, this.onState});
  final Widget image;
  final bool isVideo;
  final String label;
  final VoidCallback onTap;

  /// Where it stands with the phone (Mac only), and what a tap on that does.
  final String? state;
  final Color? stateColor;
  final VoidCallback? onState;
  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        AspectRatio(
          aspectRatio: 3 / 2,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Stack(fit: StackFit.expand, children: [
              ColoredBox(color: t.ground, child: image),
              if (isVideo) const Center(child: CircleAvatar(backgroundColor: Colors.black54, child: Icon(Icons.play_arrow, color: Colors.white))),
              if (state != null) Positioned(right: 6, top: 6, child: GestureDetector(onTap: onState, child: Pill(state!, color: stateColor ?? t.muted, filled: true))),
            ]),
          ),
        ),
        const SizedBox(height: 4),
        Text(label, maxLines: 2, overflow: TextOverflow.ellipsis, style: t.mono(10.5, color: t.ink2)),
      ]),
    );
  }
}

Widget _grid(BuildContext context, List<Widget> tiles) => LayoutBuilder(builder: (context, c) {
      final cols = (c.maxWidth / 220).floor().clamp(2, 6);
      return GridView.count(
        padding: const EdgeInsets.all(16),
        crossAxisCount: cols,
        mainAxisSpacing: 14,
        crossAxisSpacing: 12,
        childAspectRatio: 1.15,
        children: tiles,
      );
    });

/// The Mac's gallery: everything gathered, newest first, by source.
class MediaGallery extends StatefulWidget {
  const MediaGallery({super.key, required this.media});
  final StudioMedia media;
  @override
  State<MediaGallery> createState() => _MediaGalleryState();
}

class _MediaGalleryState extends State<MediaGallery> {
  String? _source;
  bool _over = false;

  void _added(int n) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(n == 0 ? 'Only pictures and videos go into the gallery.' : '$n added — uploading for the phone.')));
  }

  Future<void> _pick() async {
    final files = await openFiles(acceptedTypeGroups: const [
      XTypeGroup(label: 'Pictures and videos', extensions: ['png', 'jpg', 'jpeg', 'gif', 'webp', 'mp4', 'mov', 'webm', 'm4v']),
    ]);
    if (files.isEmpty) return;
    _added(widget.media.addFiles(files.map((f) => f.path)));
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final gallery = _gallery(context, t);
    if (!Platform.isMacOS && !Platform.isWindows && !Platform.isLinux) return gallery;
    // Drop pictures or videos on the gallery to add them (and send them to the phone).
    return DropTarget(
      onDragEntered: (_) => setState(() => _over = true),
      onDragExited: (_) => setState(() => _over = false),
      onDragDone: (d) {
        setState(() => _over = false);
        _added(widget.media.addFiles(d.files.map((f) => f.path)));
      },
      child: Stack(fit: StackFit.expand, children: [
        gallery,
        if (_over)
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                margin: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: t.bg.withValues(alpha: 0.85), borderRadius: BorderRadius.circular(14), border: Border.all(color: t.accent, width: 2)),
                alignment: Alignment.center,
                child: Text('DROP TO ADD — IT GOES TO THE PHONE TOO', style: t.display(18, color: t.accent)),
              ),
            ),
          ),
      ]),
    );
  }

  Widget _gallery(BuildContext context, KitTokens t) {
    return ListenableBuilder(
      listenable: widget.media,
      builder: (context, _) {
        final all = widget.media.newestFirst;
        final shown = [for (final m in all) if (_source == null || m.source == _source) m];
        return Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Wrap(spacing: 8, runSpacing: 8, children: [
              for (final (label, s) in [('ALL', null), ('ORCHESTRATOR', 'orchestrator'), ('STEP DESK', 'desk'), ('REVIEW FOLDER', 'review'), ('ADDED BY YOU', 'you')])
                ChoiceChip(label: Text('$label · ${s == null ? all.length : all.where((m) => m.source == s).length}'), selected: _source == s, onSelected: (_) => setState(() => _source = s), selectedColor: t.accentSoft),
              if (Platform.isMacOS) ActionChip(avatar: const Icon(Icons.add_photo_alternate_outlined, size: 18), label: const Text('ADD'), onPressed: _pick),
            ]),
          ),
          Expanded(
            child: shown.isEmpty
                ? const EmptyNote('Nothing yet. Pictures and videos the orchestrator or the step desk shows, and new ones in the reviewer\'s review/ folder, gather here — and on the phone. Drop files here or press ADD to add your own.')
                : _grid(context, [for (final m in shown) localTile(context, m, media: widget.media)]),
          ),
        ]);
      },
    );
  }
}

Widget localTile(BuildContext context, MediaItem m, {StudioMedia? media}) => _Tile(
      image: m.isVideo ? const SizedBox.shrink() : Image.file(File(m.path), fit: BoxFit.cover, cacheWidth: 440, errorBuilder: (_, _, _) => const Icon(Icons.broken_image_outlined)),
      isVideo: m.isVideo,
      state: media?.publisher == null ? null : (m.phoneState == 'ON THE PHONE' ? 'ON THE PHONE ✓' : m.phoneState),
      stateColor: switch (m.phoneState) { 'ON THE PHONE' => context.tokens.good, 'UPLOADING' => context.tokens.accent, 'UPLOAD FAILED' || 'NOT SENT' => context.tokens.critical, _ => context.tokens.warn },
      // A failed upload: the reason, and RETRY.
      onState: m.error == null && m.phoneState != 'NOT SENT'
          ? null
          : () => showDialog<void>(
                context: context,
                builder: (d) => AlertDialog(
                  title: const Text('Not on the phone'),
                  content: Text(m.error ?? 'It was not sent yet.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(d), child: const Text('CLOSE')),
                    if (media != null)
                      FilledButton(
                        onPressed: () {
                          Navigator.pop(d);
                          media.retry(m);
                        },
                        child: const Text('RETRY'),
                      ),
                  ],
                ),
              ),
      label: [m.source.toUpperCase(), if (m.step != null) m.step!, _when(m.at), if (m.caption != null) m.caption!].join(' · '),
      onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => MediaViewer(file: File(m.path), isVideo: m.isVideo, caption: m.caption))),
    );

/// The orchestrator's latest pictures, as a strip under its bar; hidden
/// until there is one.
class MediaStrip extends StatelessWidget {
  const MediaStrip({super.key, required this.media, this.source = 'orchestrator'});
  final StudioMedia media;
  final String source;
  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return ListenableBuilder(
      listenable: media,
      builder: (context, _) {
        final items = media.newestFirst.where((m) => m.source == source).take(12).toList();
        if (items.isEmpty) return const SizedBox.shrink();
        return Container(
          height: 92,
          decoration: BoxDecoration(color: t.surface, border: Border(bottom: BorderSide(color: t.line))),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final m = items[i];
              return Tooltip(
                message: m.caption ?? m.name,
                child: InkWell(
                  onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => MediaViewer(file: File(m.path), isVideo: m.isVideo, caption: m.caption))),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 112,
                      child: Stack(fit: StackFit.expand, children: [
                        ColoredBox(color: t.ground, child: m.isVideo ? const SizedBox.shrink() : Image.file(File(m.path), fit: BoxFit.cover, cacheWidth: 240, errorBuilder: (_, _, _) => const Icon(Icons.broken_image_outlined))),
                        if (m.isVideo) const Center(child: Icon(Icons.play_circle_fill, color: Colors.white70, size: 30)),
                      ]),
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

/// Pictures and videos a reply names, as thumbnails under it (the step desk's thread).
class InlineMedia extends StatelessWidget {
  const InlineMedia({super.key, required this.paths});
  final List<String> paths;
  @override
  Widget build(BuildContext context) {
    if (paths.isEmpty) return const SizedBox.shrink();
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(spacing: 8, runSpacing: 8, children: [
        for (final path in paths)
          InkWell(
            onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => MediaViewer(file: File(path), isVideo: kVideoExt.contains(p.extension(path).toLowerCase())))),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 160,
                height: 106,
                child: kVideoExt.contains(p.extension(path).toLowerCase())
                    ? ColoredBox(color: t.ground, child: const Center(child: Icon(Icons.play_circle_fill, size: 34)))
                    : Image.file(File(path), fit: BoxFit.cover, cacheWidth: 320, errorBuilder: (_, _, _) => ColoredBox(color: t.ground, child: const Icon(Icons.broken_image_outlined))),
              ),
            ),
          ),
      ]),
    );
  }
}

// --- the phone ------------------------------------------------------------------------

/// The phone's gallery: the relay's copies, newest first; small pictures
/// first, the full file fetched when opened (a video to a temp file, then
/// played in the app).
class PhoneMediaScreen extends StatefulWidget {
  const PhoneMediaScreen({super.key, required this.db, required this.blobs, this.embedded = false});
  final FirebaseFirestore db;
  final BlobStore blobs;

  /// Inside the phone's Studio, as its MEDIA tab: no page of its own.
  final bool embedded;
  @override
  State<PhoneMediaScreen> createState() => _PhoneMediaScreenState();
}

class _PhoneMediaScreenState extends State<PhoneMediaScreen> {
  final Map<String, Future<Uint8List>> _thumbs = {};

  Future<void> _open(Map<String, dynamic> m) async {
    final path = m['path'] as String?;
    if (path == null) return;
    final isVideo = m['kind'] == 'video';
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    messenger.showSnackBar(SnackBar(content: Text(isVideo ? 'Fetching the video…' : 'Fetching the picture…'), duration: const Duration(seconds: 2)));
    try {
      final f = File(p.join(Directory.systemTemp.path, 'studio-${p.basename(p.dirname(path))}-${p.basename(path)}'));
      if (!f.existsSync() || f.lengthSync() == 0) await widget.blobs.download(path, f);
      nav.push(MaterialPageRoute<void>(builder: (_) => MediaViewer(file: f, isVideo: isVideo, caption: m['caption'] as String?, title: m['name'] as String?)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Could not fetch it: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final body = StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: widget.db.collection('studio').doc('main').collection('media').orderBy('at', descending: true).limit(300).snapshots(),
        builder: (context, snap) {
          if (snap.hasError) return EmptyNote('Could not read the relay: ${snap.error}');
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final docs = snap.data!.docs;
          if (docs.isEmpty) return const EmptyNote('Nothing yet. Pictures and videos the orchestrator, the step desk and the reviewer show on the Mac arrive here.');
          return _grid(context, [
            for (final d in docs)
              () {
                final m = d.data();
                final thumb = m['thumb'] as String?;
                return _Tile(
                  image: thumb == null
                      ? const SizedBox.shrink()
                      : FutureBuilder<Uint8List>(
                          future: _thumbs.putIfAbsent(thumb, () => widget.blobs.get(thumb)),
                          builder: (context, s) => s.hasData ? Image.memory(s.data!, fit: BoxFit.cover) : Center(child: Icon(Icons.image_outlined, color: t.muted)),
                        ),
                  isVideo: m['kind'] == 'video',
                  label: [(m['source'] ?? '').toString().toUpperCase(), if (m['step'] != null) m['step'], _when(DateTime.tryParse('${m['at']}') ?? DateTime.now()), if (m['caption'] != null) m['caption']].join(' · '),
                  onTap: () => _open(m),
                );
              }(),
          ]);
        },
      );
    if (widget.embedded) return body;
    return Scaffold(appBar: AppBar(title: const Text('STUDIO MEDIA')), body: body);
  }
}
