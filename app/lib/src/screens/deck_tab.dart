import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart' hide Step, StepState;
import 'package:flutter_kit/kit.dart';
import 'package:url_launcher/url_launcher.dart';

import '../attachment_picker.dart';
import '../attachments.dart';
import '../blobs.dart';
import '../deck_commands.dart';
import '../host/bridge_session.dart';
import '../relay.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'ask_card.dart';
import 'remote_asks.dart';

/// The conversation with this project's session: what was said, what ran,
/// and — pinned above the composer — what Claude is asking. One view, two
/// sources: the host reads its own [BridgeSession]; the phone reads the
/// mirror and sends commands. Neither owns the process from here.
class DeckView extends StatefulWidget {
  const DeckView({
    super.key,
    required this.state,
    required this.facts,
    required this.messages,
    required this.running,
    required this.canResume,
    required this.onStart,
    required this.onResume,
    required this.onStop,
    required this.onSend,
    this.pick,
    this.title,
    this.nowSlot,
    this.error,
    this.askSlot,
    this.turnOpen = false,
    this.resumeLabel = 'RESUME',
    this.here = 'Mac',
    this.skipPermissions = false,
    this.chrome = false,
    this.chromeStatus,
    this.modelChoice = 'default',
    this.effort = 'default',
    this.restartPending = false,
    this.onOptions,
    this.onTestPush,
    this.uploadProgress = const {},
    this.hostLine,
    this.hostWarn = false,
    this.hostGone = false,
    this.queued = const {},
    this.onWithdraw,
  });

  final BridgeState state;
  final List<String> facts;
  final List<DeckMessage> messages;
  final bool running;
  final bool canResume;
  final String? error;

  /// The project's name, the deck's masthead.
  final String? title;

  /// The "now" strip — what the session is doing this second, with the
  /// active step's gates. Built by whoever knows the plan.
  final Widget? nowSlot;

  /// The pending ask, rendered by whoever knows it: the host's card or the
  /// phone's panel.
  final Widget? askSlot;
  final bool turnOpen;
  final String resumeLabel;
  final String here;
  final VoidCallback onStart;
  final VoidCallback onResume;
  final VoidCallback onStop;

  /// Sends what was typed with the files picked for it. Awaited: the send
  /// button waits (a phone uploads first) and the composer clears after.
  final Future<void> Function(String text, List<PendingAttachment> files) onSend;

  /// Opens the file picker — injectable, so a test can hand the composer a
  /// file without a dialog.
  final Future<List<PendingAttachment>> Function()? pick;

  /// The options the next Start runs with: no Allow / Deny cards; the
  /// Mac's browser. Fixed while a session runs.
  final bool skipPermissions;
  final bool chrome;

  /// What `init` said about the browser while running: `connected`, `failed`…
  final String? chromeStatus;

  /// The dials: one of [modelChoices], one of [effortChoices].
  final String modelChoice;
  final String effort;

  /// An option changed while a turn ran; it applies when the turn ends.
  final bool restartPending;

  /// How far a file of an echo has gone up — `'<message id>/<name>'` → 0…1;
  /// the chip shows it in place of the size until the file is there.
  final Map<String, double> uploadProgress;

  /// The Mac's line under the facts on a phone — "Mac · 12 s ago", or
  /// amber "Mac unreachable since 4 min"; null on the Mac itself.
  final String? hostLine;
  final bool hostWarn;

  /// The Mac is unreachable or stopped: a session the relay still calls
  /// live is shown as LOST until the Mac reports it again.
  final bool hostGone;

  /// Echo ids whose command waits on a Mac that is gone.
  final Set<String> queued;
  final void Function(String echoId)? onWithdraw;

  /// Changes an option — the host writes its record, the phone sends a
  /// command. Null where the surface cannot.
  final void Function({bool? skipPermissions, bool? chrome, String? model, String? effort})? onOptions;

  /// Sends a push to every registered phone, to see one arrive; returns
  /// the one-line result to toast. Null where the surface cannot.
  final Future<String?> Function()? onTestPush;

  @override
  State<DeckView> createState() => _DeckViewState();
}

class _DeckViewState extends State<DeckView> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _focus = FocusNode();
  final List<PendingAttachment> _files = [];
  int _seen = 0;
  bool _busy = false;

  /// True while the viewport sits on the newest row. Growth follows the
  /// transcript only then — reading above while Claude writes stays put.
  bool _pinned = true;

  /// Rows arrived below while the user was reading above.
  bool _unseen = false;

  /// A drag from the Finder is over the Deck.
  bool _dragOver = false;

  /// The session controls under the title — Start/Stop, the pills, the
  /// dials — fold away so the transcript gets the screen. Open while idle
  /// (Start is there), folded while a session runs; a tap on the chevron
  /// or the title overrides until the session state changes again.
  bool? _openChoice;
  bool get _headerOpen => _openChoice ?? !widget.running;

  /// Files can be dropped on a desktop window; a phone has the paperclip.
  static final bool _dropSupported = Platform.isMacOS || Platform.isWindows || Platform.isLinux;

  static const _chips = ['/step', '/qa', '/next', '/plan-status'];

  @override
  void didUpdateWidget(DeckView old) {
    super.didUpdateWidget(old);
    if (old.running != widget.running) _openChoice = null;
    _follow();
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    _focus.dispose();
    super.dispose();
  }

  /// Keeps the newest row in view while the transcript grows — unless the
  /// user scrolled up to read, in which case the list stays where they
  /// left it and a chip offers the way down.
  void _follow() {
    final n = widget.messages.length;
    final grew = n != _seen;
    _seen = n;
    if (!grew && !widget.turnOpen) return;
    if (!_pinned) {
      if (grew) _unseen = true;
      return;
    }
    _snapToEnd();
  }

  /// Lands on the newest row after this frame — and looks again after the
  /// next, because a list's end is an estimate until its last rows are
  /// laid out, and a jump to an estimate leaves the viewport short of the
  /// end or hanging past it.
  void _snapToEnd([int tries = 3]) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients || !_pinned) return;
      final pos = _scroll.position;
      if (pos.pixels != pos.maxScrollExtent) _scroll.jumpTo(pos.maxScrollExtent);
      if (tries > 1) _snapToEnd(tries - 1);
    });
  }

  /// The list moved: pinned when the newest row is (nearly) in view.
  bool _onScroll(ScrollNotification n) {
    if (n.depth != 0) return false;
    if (n is! ScrollUpdateNotification && n is! ScrollEndNotification && n is! OverscrollNotification) return false;
    final m = n.metrics;
    final pinned = m.pixels >= m.maxScrollExtent - 48;
    if (pinned != _pinned || (pinned && _unseen)) {
      setState(() {
        _pinned = pinned;
        if (pinned) _unseen = false;
      });
    }
    return false;
  }

  void _jumpToLatest() {
    setState(() {
      _pinned = true;
      _unseen = false;
    });
    if (!_scroll.hasClients) return;
    final bottom = _scroll.position.maxScrollExtent;
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      _scroll.jumpTo(bottom);
      _snapToEnd();
    } else {
      _scroll.animateTo(bottom, duration: const Duration(milliseconds: 240), curve: Curves.easeOut).then((_) => _snapToEnd());
    }
  }

  /// The command palette; [highlight] leads when a chip was long-pressed.
  void _palette(String? highlight) {
    showDeckCommandsSheet(context, highlight: highlight, onPick: (c) {
      _input.text = '$c ';
      _input.selection = TextSelection.collapsed(offset: _input.text.length);
      _focus.requestFocus();
    });
  }

  void _toast(String text) => ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(text)));

  Future<void> _attach() async {
    final List<PendingAttachment> picked;
    try {
      picked = await (widget.pick ?? pickAttachments)();
    } on Object catch (e) {
      _toast('Could not open that: $e');
      return;
    }
    if (!mounted) return;
    _addFiles(picked);
  }

  /// Files dropped on the window — the Mac's way, beside the paperclip.
  Future<void> _dropped(DropDoneDetails d) async {
    setState(() => _dragOver = false);
    if (!widget.running) {
      _toast('Start the session first, then drop it again.');
      return;
    }
    final files = d.files.where((f) => f is! DropItemDirectory).toList();
    if (files.length < d.files.length) _toast('A folder does not travel — drop files.');
    if (files.isEmpty) return;
    final List<PendingAttachment> got;
    try {
      got = await attachmentsFrom(files);
    } on Object catch (e) {
      _toast('Could not read that: $e');
      return;
    }
    if (!mounted) return;
    _addFiles(got);
  }

  /// Into the composer, minus anything past the limit.
  void _addFiles(List<PendingAttachment> picked) {
    if (picked.isEmpty) return;
    final kept = <PendingAttachment>[];
    for (final f in picked) {
      if (f.size > maxAttachmentBytes) {
        _toast('${f.name} is ${formatBytes(f.size)} — the limit is ${formatBytes(maxAttachmentBytes)}.');
        continue;
      }
      kept.add(f);
    }
    setState(() => _files.addAll(kept));
    _focus.requestFocus();
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (_busy || (text.isEmpty && _files.isEmpty)) return;
    final files = List<PendingAttachment>.of(_files);
    setState(() {
      _busy = true;
      // A send is a reason to look at the newest row again.
      _pinned = true;
      _unseen = false;
    });
    try {
      await widget.onSend(text, files);
      if (!mounted) return;
      setState(() {
        _input.clear();
        _files.clear();
      });
    } on SendFailed {
      // The deck's error line says why; the words and the files stay put.
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final w = widget;
    final canType = w.running && !_busy;
    final body = LayoutBuilder(
      builder: (context, box) => Column(
        children: [
          // The header, like the bottom, scrolls inside its own share at the
          // largest text sizes rather than pushing the transcript out.
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: box.maxHeight * 0.48),
            child: SingleChildScrollView(child: _Header(view: w, open: _headerOpen, onToggle: () => setState(() => _openChoice = !_headerOpen))),
          ),
          if (w.nowSlot != null) Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 4), child: w.nowSlot!),
          Expanded(
            child: w.messages.isEmpty
                ? EmptyNote(w.running ? 'Session ready. Ask, or give an order.' : 'Start a session to talk to Claude Code in this folder.')
                : Stack(
                    children: [
                      // One selection over the whole conversation — drag on
                      // the Mac, long-press on the phone, copy — across
                      // bubbles, replies and tool rows alike.
                      SelectionArea(
                        child: NotificationListener<ScrollNotification>(
                          onNotification: _onScroll,
                          child: ListView.builder(
                            controller: _scroll,
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                            itemCount: w.messages.length,
                            itemBuilder: (context, i) => _Row(
                              message: w.messages[i],
                              progress: w.uploadProgress,
                              queued: w.queued.contains(w.messages[i].id),
                              onWithdraw: w.onWithdraw == null ? null : () => w.onWithdraw!(w.messages[i].id),
                            ),
                          ),
                        ),
                      ),
                      if (_unseen)
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 10,
                          child: Center(child: _JumpChip(onTap: _jumpToLatest)),
                        ),
                    ],
                  ),
          ),
          // The ask and the composer share the bottom; at the largest
          // text sizes a question card grows past the screen, so the
          // bottom scrolls inside its own share and the transcript keeps
          // the rest, instead of a Column overflowing.
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: box.maxHeight * 0.5),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (w.askSlot != null) w.askSlot!,
                  SafeArea(
                    top: false,
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                      decoration: BoxDecoration(color: t.bg, border: Border(top: BorderSide(color: t.line))),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_files.isNotEmpty) ...[
                            _PendingFiles(files: _files, enabled: !_busy, onRemove: (f) => setState(() => _files.remove(f))),
                            const SizedBox(height: 8),
                          ],
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(right: 6),
                                  child: _Chip(label: '/', enabled: true, onTap: () => _palette(null)),
                                ),
                                for (final c in _chips)
                                  Padding(
                                    padding: const EdgeInsets.only(right: 6),
                                    child: _Chip(
                                      label: c,
                                      enabled: w.running,
                                      onTap: () {
                                        _input.text = c;
                                        _focus.requestFocus();
                                      },
                                      onLongPress: () => _palette(c),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              SizedBox(
                                width: 44,
                                height: 48,
                                child: IconButton(
                                  tooltip: 'Attach a file',
                                  style: IconButton.styleFrom(
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    side: BorderSide(color: canType ? t.line : t.line.withValues(alpha: 0.4)),
                                    foregroundColor: t.ink2,
                                  ),
                                  onPressed: canType ? _attach : null,
                                  icon: const Icon(Icons.attach_file, size: 20),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  controller: _input,
                                  focusNode: _focus,
                                  enabled: w.running,
                                  minLines: 1,
                                  maxLines: 3,
                                  textInputAction: TextInputAction.send,
                                  onSubmitted: (_) => _send(),
                                  style: TextStyle(fontSize: 15, color: t.ink),
                                  decoration: InputDecoration(
                                    hintText: !w.running
                                        ? 'Not running'
                                        : _files.isEmpty
                                            ? 'Ask, or give an order…'
                                            : 'Say what to do with it — or just send',
                                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: t.accent.withValues(alpha: w.running ? 0.28 : 0.0))),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              SizedBox(
                                width: 48,
                                height: 48,
                                child: FilledButton(
                                  style: FilledButton.styleFrom(padding: EdgeInsets.zero, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                                  onPressed: canType ? _send : null,
                                  child: _busy
                                      ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: t.onAccent))
                                      : const Icon(Icons.arrow_forward, size: 20),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
    if (!_dropSupported) return body;
    return DropTarget(
      onDragEntered: (_) => setState(() => _dragOver = true),
      onDragExited: (_) => setState(() => _dragOver = false),
      onDragDone: _dropped,
      child: Stack(
        fit: StackFit.expand,
        children: [
          body,
          if (_dragOver) Positioned.fill(child: IgnorePointer(child: _DropVeil(running: w.running))),
        ],
      ),
    );
  }
}

/// What the window says while a file hangs over it.
class _DropVeil extends StatelessWidget {
  const _DropVeil({required this.running});
  final bool running;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final color = running ? t.accent : t.warn;
    return Container(
      margin: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: t.bg.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color, width: 1.5),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.attach_file, size: 30, color: color),
            const SizedBox(height: 10),
            Text(running ? 'DROP TO ATTACH' : 'START A SESSION FIRST', style: t.display(16, weight: FontWeight.w600, ls: 3, color: color)),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.enabled, required this.onTap, this.onLongPress});
  final String label;
  final bool enabled;
  final VoidCallback onTap;

  /// The preview — what this command does, without running it.
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: enabled ? onTap : null,
      onLongPress: onLongPress,
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), border: Border.all(color: enabled ? t.line : t.line.withValues(alpha: 0.4))),
        child: Text(label, style: t.mono(13, color: enabled ? t.ink2 : t.muted)),
      ),
    );
  }
}

/// The way back down when rows arrived while the user was reading above.
class _JumpChip extends StatelessWidget {
  const _JumpChip({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Material(
      color: t.surface,
      elevation: 3,
      shadowColor: Colors.black54,
      shape: StadiumBorder(side: BorderSide(color: t.accent.withValues(alpha: 0.5))),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.arrow_downward, size: 14, color: t.accent),
              const SizedBox(width: 6),
              Text('LATEST', style: t.display(12, weight: FontWeight.w600, ls: 2, color: t.accent)),
            ],
          ),
        ),
      ),
    );
  }
}

/// The files picked for the next message, each with its way out.
class _PendingFiles extends StatelessWidget {
  const _PendingFiles({required this.files, required this.enabled, required this.onRemove});
  final List<PendingAttachment> files;
  final bool enabled;
  final void Function(PendingAttachment f) onRemove;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final f in files)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Container(
                height: 44,
                padding: const EdgeInsets.only(left: 6),
                decoration: BoxDecoration(color: t.surface, borderRadius: BorderRadius.circular(8), border: Border.all(color: t.line)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _Thumb(bytes: f.isImage ? f.bytes : null, mime: f.mime, size: 32),
                    const SizedBox(width: 8),
                    ConstrainedBox(constraints: const BoxConstraints(maxWidth: 150), child: Text(f.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.mono(12, color: t.ink))),
                    const SizedBox(width: 6),
                    Text(formatBytes(f.size), style: t.readout(10)),
                    IconButton(
                      tooltip: 'Remove',
                      visualDensity: VisualDensity.compact,
                      iconSize: 16,
                      color: t.ink2,
                      onPressed: enabled ? () => onRemove(f) : null,
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A file's face: the image itself when the bytes or the Mac's copy are
/// at hand, an icon for its kind otherwise.
class _Thumb extends StatelessWidget {
  const _Thumb({required this.mime, required this.size, this.bytes, this.path});
  final String mime;
  final double size;
  final Uint8List? bytes;
  final String? path;

  static IconData iconFor(String mime) {
    if (mime.startsWith('image/')) return Icons.image_outlined;
    if (mime == 'application/pdf') return Icons.picture_as_pdf_outlined;
    if (mime.startsWith('text/') || mime.endsWith('json') || mime.endsWith('yaml')) return Icons.description_outlined;
    return Icons.insert_drive_file_outlined;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final icon = Icon(iconFor(mime), size: size * 0.6, color: t.accent);
    Widget? image;
    if (bytes != null) {
      // Decoded small: a shrunk screenshot is still a couple of megabytes.
      image = Image.memory(bytes!, width: size, height: size, fit: BoxFit.cover, cacheWidth: 160, gaplessPlayback: true, errorBuilder: (_, _, _) => icon);
    } else if (mime.startsWith('image/') && path != null && File(path!).existsSync()) {
      image = Image.file(File(path!), width: size, height: size, fit: BoxFit.cover, cacheWidth: 160, errorBuilder: (_, _, _) => icon);
    }
    return SizedBox(
      width: size,
      height: size,
      child: image == null ? Center(child: icon) : ClipRRect(borderRadius: BorderRadius.circular(6), child: image),
    );
  }
}

/// The files a sent message carried, under its bubble. On the Mac, where
/// the copy sits, a tap opens it.
class _Attachments extends StatelessWidget {
  const _Attachments(this.files, {this.dim = false, this.progress = const {}});
  final List<DeckAttachment> files;
  final bool dim;

  /// Name → how far up it is, while it still is on its way.
  final Map<String, double> progress;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      alignment: WrapAlignment.end,
      children: [
        for (final a in files)
          Builder(builder: (context) {
            final local = a.path != null && File(a.path!).existsSync();
            return InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: local ? () => launchUrl(Uri.file(a.path!)) : null,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: dim ? t.surface.withValues(alpha: 0.6) : t.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: t.line),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _Thumb(path: a.path, mime: a.mime, size: 44),
                    const SizedBox(width: 8),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ConstrainedBox(constraints: const BoxConstraints(maxWidth: 170), child: Text(a.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.mono(12, color: t.ink))),
                        const SizedBox(height: 2),
                        if (progress[a.name] case final p? when p < 1)
                          Text('UP ${(p * 100).round()}% · ${formatBytes(a.size)}', style: t.readout(10, color: t.accent))
                        else
                          Text('${formatBytes(a.size)}${a.isImage ? ' · IMAGE' : ''}${local ? ' · OPEN' : ''}', style: t.readout(10)),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }
}

/// The host's Deck: straight off its own bridge.
class DeckTab extends StatelessWidget {
  const DeckTab({super.key, required this.bridge, this.title, this.nowSlot, this.pick, this.testPush});
  final BridgeSession bridge;

  /// The host's push sender, on request — the PUSH · TEST pill.
  final Future<String?> Function()? testPush;
  final String? title;
  final Widget? nowSlot;
  final Future<List<PendingAttachment>> Function()? pick;

  @override
  Widget build(BuildContext context) {
    final b = bridge;
    return ListenableBuilder(
      listenable: b,
      builder: (context, _) {
        final prev = b.running ? null : b.previous();
        final resumable = prev?.sessionId;
        final pending = b.transcript.pending;
        return DeckView(
          state: b.state,
          title: title,
          nowSlot: nowSlot,
          facts: [
            if (b.sessionId != null) 'session ${shortId(b.sessionId!)}',
            if (b.transcript.model != null) b.transcript.model!,
            if (b.cliVersion != null) 'claude ${b.cliVersion}${b.cliVersion == bridgeProvenOn ? '' : ' (proven on $bridgeProvenOn)'}',
            if (b.transcript.pool?.resetsAt != null) 'pool resets ${hm(b.transcript.pool!.resetsAt!)}',
          ],
          error: b.error,
          messages: b.transcript.messages,
          running: b.running,
          canResume: resumable != null,
          resumeLabel: resumable == null ? 'RESUME' : 'RESUME ${shortId(resumable).toUpperCase()}',
          turnOpen: b.transcript.turnOpen,
          skipPermissions: b.skipPermissions,
          chrome: b.chrome,
          chromeStatus: b.chromeStatus,
          modelChoice: b.modelChoice ?? 'default',
          effort: b.effort ?? 'default',
          restartPending: b.restartPending,
          onOptions: ({skipPermissions, chrome, model, effort}) => b.setOptions(skipPermissions: skipPermissions, chrome: chrome, model: model, effort: effort),
          onTestPush: testPush,
          askSlot: pending == null
              ? null
              : AskCard(
                  key: ValueKey(pending.requestId),
                  ask: pending,
                  here: 'Mac',
                  onAnswer: (a, {remember = false}) => b.answer(a, remember: remember),
                ),
          onStart: () => b.start(),
          onResume: () => b.start(resume: true),
          onStop: () => b.stop(),
          onSend: (text, files) async => b.send(text, files: files),
          pick: pick,
        );
      },
    );
  }
}

/// The phone's Deck: the mirror in, commands out.
class RemoteDeckTab extends StatefulWidget {
  const RemoteDeckTab({super.key, required this.db, required this.slug, this.from = 'phone', this.title, this.nowSlot, this.pick, this.blobs});
  final FirebaseFirestore db;
  final String slug;
  final String from;

  /// The bucket the files go into; a test hands in a memory one.
  final BlobStore? blobs;
  final String? title;
  final Widget? nowSlot;
  final Future<List<PendingAttachment>> Function()? pick;

  @override
  State<RemoteDeckTab> createState() => _RemoteDeckTabState();
}

class _RemoteDeckTabState extends State<RemoteDeckTab> {
  late final RemoteDeck _deck = RemoteDeck(widget.db, widget.slug, from: widget.from, blobs: widget.blobs)..start();

  @override
  void dispose() {
    _deck.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = _deck;
    return ListenableBuilder(
      listenable: d,
      builder: (context, _) => DeckView(
        state: d.state,
        title: widget.title,
        nowSlot: widget.nowSlot,
        facts: [
          if (d.sessionId != null) 'session ${shortId(d.sessionId!)}',
          if (d.model != null) d.model!,
          if (d.cliVersion != null) 'claude ${d.cliVersion}',
          if (d.machine != null) d.machine!,
        ],
        error: d.error,
        messages: d.view,
        running: d.running,
        canResume: d.canResume,
        turnOpen: d.turnOpen,
        here: widget.from,
        skipPermissions: d.skipPermissions,
        chrome: d.chrome,
        chromeStatus: d.chromeStatus,
        modelChoice: d.modelChoice,
        effort: d.effort,
        restartPending: d.restartPending,
        onOptions: ({skipPermissions, chrome, model, effort}) => d.setOptions(skipPermissions: skipPermissions, chrome: chrome, model: model, effort: effort),
        onTestPush: d.testPush,
        uploadProgress: d.uploadProgress,
        hostLine: d.presence.line,
        hostWarn: d.presence.warn,
        hostGone: d.presence.gone,
        queued: d.queued,
        onWithdraw: d.withdraw,
        askSlot: RemoteAskPanel(db: widget.db, slug: widget.slug, from: widget.from),
        onStart: () => d.startSession(),
        onResume: () => d.startSession(resume: true),
        onStop: d.stopSession,
        onSend: (text, files) => d.send(text, files: files),
        pick: widget.pick,
      ),
    );
  }
}

/// The first block of a uuid — or the whole of anything shorter.
String shortId(String id) => id.length > 8 ? id.substring(0, 8) : id;

String hm(DateTime at) {
  final l = at.toLocal();
  return '${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}';
}

class _Header extends StatelessWidget {
  const _Header({required this.view, required this.open, required this.onToggle});
  final DeckView view;

  /// Whether the controls under the title row show.
  final bool open;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final w = view;
    // A session the relay still calls live, on a Mac that is gone.
    final lost = w.hostGone && w.running;
    final color = lost
        ? t.warn
        : switch (w.state) {
            BridgeState.waiting => t.warn,
            BridgeState.busy || BridgeState.ready || BridgeState.starting => t.accent,
            BridgeState.failed => t.critical,
            _ => t.muted,
          };
    final label = lost
        ? 'LOST'
        : switch (w.state) {
            BridgeState.waiting => 'NEEDS YOU',
            BridgeState.busy => 'WORKING',
            BridgeState.ready => 'LIVE',
            BridgeState.starting => 'STARTING',
            BridgeState.stopped => 'STOPPED',
            BridgeState.failed => 'FAILED',
            BridgeState.idle => 'IDLE',
          };
    final glyph = lost
        ? GlyphMode.idle
        : switch (w.state) {
            BridgeState.waiting => GlyphMode.ask,
            BridgeState.busy || BridgeState.starting => GlyphMode.busy,
            BridgeState.ready => GlyphMode.live,
            _ => GlyphMode.idle,
          };
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: InkWell(
                  onTap: onToggle,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (w.title != null) ...[
                        Text(w.title!.toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis, style: t.display(22, ls: 3.2)),
                        const SizedBox(height: 4),
                      ],
                      if (w.facts.isNotEmpty)
                        Text(w.facts.join(' · ').toUpperCase(), maxLines: open ? 2 : 1, overflow: TextOverflow.ellipsis, style: t.readout(11)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Loose: at the largest text sizes the label is wider than
              // the phone; it ellipsises instead of pushing the row over.
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(999), border: Border.all(color: color.withValues(alpha: 0.38))),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      StatusGlyph(color: color, mode: glyph),
                      const SizedBox(width: 8),
                      Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.display(13, weight: FontWeight.w600, ls: 2.3, color: color))),
                    ],
                  ),
                ),
              ),
              // Folded while running: Stop stays one tap away.
              if (!open && w.running)
                IconButton(
                  tooltip: 'Stop',
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                  icon: Icon(Icons.stop, color: t.ink2),
                  onPressed: w.onStop,
                ),
              IconButton(
                tooltip: open ? 'Hide session controls' : 'Show session controls',
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                icon: Icon(open ? Icons.expand_less : Icons.expand_more, color: t.ink2),
                onPressed: onToggle,
              ),
            ],
          ),
          // The Mac's line on its own row: at the folded width beside the
          // pill, "unreachable since" would lose its since.
          if (w.hostLine case final line?)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(line.toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis, style: t.readout(11, color: w.hostWarn ? t.warn : t.muted)),
            ),
          if (w.error != null)
            Padding(padding: const EdgeInsets.only(top: 8), child: Text(w.error!, maxLines: 3, overflow: TextOverflow.ellipsis, style: t.mono(12, color: t.critical))),
          if (open) ..._controls(context, w, t),
        ],
      ),
    );
  }

  /// Everything the chevron folds: Start / Resume / Stop, the option
  /// pills, the test pill, the two dials.
  List<Widget> _controls(BuildContext context, DeckView w, KitTokens t) => [
          if (!w.running || w.canResume)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (!w.running) FilledButton.icon(onPressed: w.onStart, icon: const Icon(Icons.play_arrow, size: 18), label: const Text('START')),
                  if (!w.running && w.canResume) OutlinedButton(onPressed: w.onResume, child: Text(w.resumeLabel)),
                  if (w.running) OutlinedButton.icon(onPressed: w.onStop, icon: const Icon(Icons.stop, size: 18), label: const Text('STOP')),
                ],
              ),
            ),
          if (w.running && !w.canResume)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: OutlinedButton.icon(onPressed: w.onStop, icon: const Icon(Icons.stop, size: 18), label: const Text('STOP')),
            ),
          if (w.onOptions != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _OptionPill(
                    text: 'PERMISSIONS · ${w.skipPermissions ? 'SKIP' : 'ASK'}',
                    color: w.skipPermissions ? t.warn : t.ink2,
                    on: w.skipPermissions,
                    enabled: true,
                    onTap: () => w.onOptions!(skipPermissions: !w.skipPermissions),
                  ),
                  _OptionPill(
                    text: 'CHROME · ${w.chrome ? (w.running && w.chromeStatus != null ? w.chromeStatus!.toUpperCase() : 'ON') : 'OFF'}',
                    color: w.chrome ? (w.chromeStatus == 'failed' ? t.critical : t.accent) : t.ink2,
                    on: w.chrome,
                    enabled: true,
                    onTap: () => w.onOptions!(chrome: !w.chrome),
                  ),
                  if (w.onTestPush != null)
                    _OptionPill(
                      text: 'PUSH · TEST',
                      color: t.accent,
                      on: false,
                      enabled: true,
                      onTap: () async {
                        final r = await w.onTestPush!();
                        if (context.mounted && r != null) ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(r)));
                      },
                    ),
                ],
              ),
            ),
          if (w.onOptions != null) ...[
            const SizedBox(height: 4),
            _Dial(label: 'MODEL', choices: modelChoices, value: w.modelChoice, enabled: true, onChanged: (v) => w.onOptions!(model: v)),
            _Dial(label: 'EFFORT', choices: effortChoices, value: w.effort, enabled: true, onChanged: (v) => w.onOptions!(effort: v)),
            if (w.running)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  w.restartPending ? 'Applies when this turn ends — the session restarts on the same conversation.' : 'A change restarts the session on the same conversation.',
                  style: t.mono(11, color: w.restartPending ? t.warn : t.muted),
                ),
              ),
          ],
        ];
}

/// A dial: a slider over a short list of words, the current word beside
/// it. Moves freely while dragged and reports once, when the finger lifts
/// — so the phone sends one command, not one per notch.
class _Dial extends StatefulWidget {
  const _Dial({required this.label, required this.choices, required this.value, required this.enabled, required this.onChanged});
  final String label;
  final List<String> choices;
  final String value;
  final bool enabled;
  final void Function(String) onChanged;

  @override
  State<_Dial> createState() => _DialState();
}

class _DialState extends State<_Dial> {
  double? _dragging;

  int get _index {
    final i = widget.choices.indexOf(widget.value);
    return i < 0 ? 0 : i;
  }

  @override
  void didUpdateWidget(_Dial old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) _dragging = null;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final v = _dragging ?? _index.toDouble();
    final word = widget.choices[v.round().clamp(0, widget.choices.length - 1)];
    final color = widget.enabled ? (word == 'default' ? t.ink2 : t.accent) : t.muted;
    return Row(children: [
      Flexible(child: Text('${widget.label} · ${word.toUpperCase()}', maxLines: 1, overflow: TextOverflow.ellipsis, style: t.mono(11.5, color: color))),
      Expanded(
        child: SliderTheme(
          data: SliderThemeData(
            trackHeight: 2,
            activeTrackColor: color,
            inactiveTrackColor: t.line,
            thumbColor: color,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
            tickMarkShape: const RoundSliderTickMarkShape(tickMarkRadius: 1.5),
            activeTickMarkColor: color.withValues(alpha: 0.5),
            inactiveTickMarkColor: t.line,
            showValueIndicator: ShowValueIndicator.never,
          ),
          child: SizedBox(
            height: 34,
            child: Slider(
              min: 0,
              max: (widget.choices.length - 1).toDouble(),
              divisions: widget.choices.length - 1,
              value: v,
              onChanged: widget.enabled ? (x) => setState(() => _dragging = x) : null,
              onChangeEnd: widget.enabled
                  ? (x) {
                      final chosen = widget.choices[x.round().clamp(0, widget.choices.length - 1)];
                      setState(() => _dragging = null);
                      if (chosen != widget.value) widget.onChanged(chosen);
                    }
                  : null,
            ),
          ),
        ),
      ),
    ]);
  }
}

/// One session option, as a switch that reads: what it is · what it is set
/// to. Fixed while a session runs.
class _OptionPill extends StatelessWidget {
  const _OptionPill({required this.text, required this.color, required this.on, required this.enabled, required this.onTap});
  final String text;
  final Color color;
  final bool on;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final c = enabled ? color : color.withValues(alpha: 0.55);
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: enabled ? onTap : null,
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: on ? c.withValues(alpha: 0.12) : null,
          border: Border.all(color: on ? c.withValues(alpha: 0.6) : t.line),
        ),
        child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.mono(11.5, color: c)),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.message, this.progress = const {}, this.queued = false, this.onWithdraw});
  final DeckMessage message;
  final Map<String, double> progress;

  /// This echo's command waits on a Mac that is gone.
  final bool queued;
  final VoidCallback? onWithdraw;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final m = message;
    switch (m.role) {
      case DeckRole.user:
        return Padding(
          padding: const EdgeInsets.only(bottom: 12, left: 48),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (threadKey(m.about) case final key?)
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text(key.replaceFirst(':', ' · ').toUpperCase(), style: t.readout(10, color: t.accent)),
                ),
              if (m.attachments.isNotEmpty)
                Padding(
                  padding: EdgeInsets.only(bottom: m.text.isEmpty ? 0 : 6),
                  child: _Attachments(m.attachments, dim: m.streaming, progress: {for (final e in progress.entries) if (e.key.startsWith('${m.id}/')) e.key.substring(m.id.length + 1): e.value}),
                ),
              if (m.text.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: m.streaming ? t.bubble.withValues(alpha: 0.6) : t.bubble,
                    border: Border.all(color: t.line),
                    borderRadius: const BorderRadius.only(topLeft: Radius.circular(14), topRight: Radius.circular(14), bottomLeft: Radius.circular(14), bottomRight: Radius.circular(4)),
                  ),
                  child: Text(m.text, style: TextStyle(fontSize: 15, height: 1.4, color: m.streaming ? t.ink2 : t.ink)),
                ),
              if (queued)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    alignment: WrapAlignment.end,
                    spacing: 8,
                    children: [
                      Text('QUEUED · MAC UNREACHABLE', style: t.readout(10, color: t.warn)),
                      if (onWithdraw != null)
                        InkWell(
                          onTap: onWithdraw,
                          child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2), child: Text('WITHDRAW', style: t.readout(10, color: t.accent))),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        );
      case DeckRole.assistant:
        return Padding(
          padding: const EdgeInsets.only(bottom: 14, right: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(width: 14, height: 2, color: t.accent),
                const SizedBox(width: 8),
                // Loose: at the largest text sizes the caption is wider than a phone.
                Flexible(child: Text('CLAUDE · ${hm(m.at)}', maxLines: 1, overflow: TextOverflow.ellipsis, style: t.readout(11))),
              ]),
              const SizedBox(height: 6),
              if (m.text.isEmpty && m.streaming) Padding(padding: const EdgeInsets.only(top: 4), child: ThinkingDots(color: t.muted)) else Md(m.streaming ? '${m.text} ▍' : m.text, color: t.ink),
            ],
          ),
        );
      case DeckRole.tool:
        final done = m.toolResult != null;
        final color = m.isError ? t.critical : (done ? t.good : t.accent);
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(color: t.surface, borderRadius: BorderRadius.circular(6), border: Border.all(color: t.line)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Icon(m.isError ? Icons.error_outline : (done ? Icons.check : Icons.play_arrow), size: 12, color: color),
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(m.toolSummary, maxLines: 2, overflow: TextOverflow.ellipsis, style: t.mono(11.5, color: t.ink2))),
                  ],
                ),
                if (done && m.toolResult!.trim().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4, left: 20),
                    child: Text(m.toolResult!.trim(), maxLines: 3, overflow: TextOverflow.ellipsis, style: t.mono(11, color: m.isError ? t.critical : t.muted)),
                  ),
              ],
            ),
          ),
        );
      case DeckRole.note:
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text(m.text, style: TextStyle(fontSize: 12.5, fontStyle: FontStyle.italic, color: t.muted)),
        );
    }
  }
}
