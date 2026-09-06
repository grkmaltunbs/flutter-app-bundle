import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart' hide Step, StepState;
import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:flutter_kit/kit.dart';
import 'package:url_launcher/url_launcher.dart';

import '../attachment_picker.dart';
import '../attachments.dart';
import '../blobs.dart';
import '../deck_commands.dart';
import '../draft.dart';
import '../host/bridge_session.dart';
import '../host/host_actions.dart';
import '../relay.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/git_card.dart';
import '../widgets/run_card.dart';
import '../widgets/tool_sheet.dart';
import 'ask_card.dart';
import 'file_view.dart';
import 'log_sheet.dart';
import 'mirror_sheet.dart';
import 'remote_asks.dart';

/// The conversation with this project's session: what was said, what ran,
/// and, as its last row, what Claude is asking. One view, two
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
    this.modeChoice = 'default',
    this.switchPending = false,
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
    this.onChromeHidden,
    this.foldOnScroll,
    this.onInterrupt,
    this.loadFile,
    this.git,
    this.onGit,
    this.contextUsed = 0,
    this.contextWindow = 0,
    this.pool,
    this.compacting = false,
    this.onCompact,
    this.lastSeenId,
    this.seenScope,
    this.markUnread = false,
    this.onSeen,
    this.autopilot,
    this.onAutopilot,
    this.run,
    this.onRun,
    this.runLog,
    this.mirrorHooks,
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

  /// `--chrome`: the Mac's browser. A change restarts the session.
  final bool chrome;

  /// What `init` said about the browser while running: `connected`, `failed`…
  final String? chromeStatus;

  /// The dials: one of [modelChoices], one of [effortChoices], one of
  /// [modeChoices]. The mode and the model switch in place;
  /// [switchPending] says a dial moved mid-turn and the switch waits for
  /// the turn to end.
  final String modelChoice;
  final String effort;
  final String modeChoice;
  final bool switchPending;

  /// Ends the running turn and keeps the session — INTERRUPT on the title
  /// row while a turn runs. Null: no such brake here.
  final VoidCallback? onInterrupt;

  /// The instruments on the facts row: the context the model last read
  /// against its window (no arc while the window is 0 — no session yet),
  /// and the pool with its windows. [onCompact] sends `/compact`; the
  /// COMPACT pill offers it past 80 %, and reads COMPACTING while
  /// [compacting].
  final int contextUsed;
  final int contextWindow;
  final RateLimitEvent? pool;
  final bool compacting;
  final VoidCallback? onCompact;
  double get contextFraction => contextWindow == 0 ? 0 : contextUsed / contextWindow;

  /// Since you last looked, on a phone: [lastSeenId] is what the device
  /// remembered — `<session id>:<row id>` — and [seenScope] the session
  /// the rows belong to now; a different session means every row is new.
  /// With [markUnread] on, the first look at a transcript draws the line
  /// above the first row not yet shown and lands the list on it. [onSeen]
  /// is told the newest row shown with the app in front, when the app
  /// leaves or the Deck closes. All null on the Mac: nothing is drawn.
  final String? lastSeenId;
  final String? seenScope;
  final bool markUnread;
  final void Function(String seen)? onSeen;

  /// Autopilot — the loop as the host reports it, and the toggle: on with
  /// a budget and night shift (from the sheet), or off. [onAutopilot]
  /// returns the one line to toast; null where the surface has no loop.
  final AutopilotState? autopilot;
  final Future<String?> Function({required bool on, int? budget, bool? nightShift})? onAutopilot;

  /// The run bay — the app under test as the host reports it, the `run`
  /// command (start · reload · restart · stop · devices · reload_on_edit,
  /// returning the one line to toast), and the log of a run by its id.
  /// Null where the surface has no bay.
  final RunState? run;
  final Future<String> Function(String action, {String? device, bool? on})? onRun;
  final Stream<List<String>> Function(String runId)? runLog;

  /// The mirror: the run's device on this screen, and taps back. Null:
  /// no sheet here.
  final MirrorHooks? mirrorHooks;

  /// A file on the Mac, for the tap on a path — the Mac's disk, or the
  /// relay. Null: paths are not taps.
  final Future<FileRead> Function(String path)? loadFile;

  /// The Git card in the fold, and Revert file on a diff: what the host
  /// last read, and the command that runs one of commit · push · revert.
  final GitStatus? git;
  final Future<String> Function(String op, {String? message, String? path})? onGit;

  /// An option changed while a turn ran; it applies when the turn ends.
  final bool restartPending;

  /// On a phone, a drag upward (reading down) folds the chrome — the
  /// header to one row, the now line away — and says so to the screen,
  /// which folds its tab strip; a drag downward brings it all back. Null:
  /// fold on Android and iOS, never on a desktop.
  final bool? foldOnScroll;
  final void Function(bool hidden)? onChromeHidden;

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
  final void Function({String? mode, bool? chrome, String? model, String? effort})? onOptions;

  /// Sends a push to every registered phone, to see one arrive; returns
  /// the one-line result to toast. Null where the surface cannot.
  final Future<String?> Function()? onTestPush;

  @override
  State<DeckView> createState() => _DeckViewState();
}

class _DeckViewState extends State<DeckView> with WidgetsBindingObserver {
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

  /// The main list: the user's own conversation — rows a subagent
  /// produced stay under its chip.
  List<DeckMessage> get _rows => [for (final m in widget.messages) if (m.parentToolUseId == null) m];

  // --- since you last looked ------------------------------------------

  /// The row the line sits above, once placed for this look; [_seenId]
  /// the newest row shown with the app in front ('' when the remembered
  /// row belongs to another session — everything here is new); and
  /// [_seenIndex] how far down the list has been built, so a row is
  /// seen once, when it first shows.
  String? _markerId;
  bool _markerPlaced = false;
  String? _seenId;
  int _seenIndex = -1;
  bool _inFront = true;
  final _markerKey = GlobalKey();

  /// The row the look at hand measures from: the remembered row on the
  /// first look, the newest row shown when the app comes back. Frozen
  /// while the line is placed, since rows shown meanwhile move [_seenId].
  /// After a resume the rows may still be on their way, so the placing
  /// stays armed a moment ([_armedUntil]) when nothing is beyond it yet.
  String? _markBase;
  DateTime? _armedUntil;

  void _takeLastSeen() {
    final raw = widget.lastSeenId;
    final scope = widget.seenScope;
    if (raw == null) {
      _seenId = null;
    } else if (scope != null && raw.startsWith('$scope:')) {
      _seenId = raw.substring(scope.length + 1);
    } else {
      _seenId = '';
    }
    _markBase = _seenId;
  }

  /// Draws the line above the first row not yet shown and lands there —
  /// once per look, when the rows and the remembered row are both known.
  void _maybePlaceMarker() {
    if (_markerPlaced || !widget.markUnread) return;
    final rows = _rows;
    if (rows.isEmpty) return;
    final seen = _markBase;
    if (seen == null) {
      _markerPlaced = true; // a first look: nothing is unread
      return;
    }
    final idx = rows.indexWhere((m) => m.id == seen);
    final first = idx < 0 ? 0 : idx + 1;
    if (first >= rows.length) {
      final until = _armedUntil;
      if (until != null && DateTime.now().isBefore(until)) return;
      _markerPlaced = true;
      return;
    }
    _markerPlaced = true;
    _armedUntil = null;
    _markerId = rows[first].id;
    _landOn(first, rows.length);
  }

  /// Lands the viewport on the marker: a jump to where the row should be
  /// by count, then the row itself once it is built.
  void _landOn(int index, int count) {
    _pinned = false;
    void settle(int tries) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_scroll.hasClients) return;
        final ctx = _markerKey.currentContext;
        if (ctx != null) {
          Scrollable.ensureVisible(ctx, alignment: 0);
          return;
        }
        final pos = _scroll.position;
        _scroll.jumpTo((pos.maxScrollExtent * index / count).clamp(0.0, pos.maxScrollExtent));
        if (tries > 1) settle(tries - 1);
      });
    }

    settle(6);
  }

  String? _flushedSeen;

  void _flushSeen() {
    final id = _seenId;
    final scope = widget.seenScope;
    if (id == null || id.isEmpty || scope == null) return;
    final seen = '$scope:$id';
    if (seen == _flushedSeen) return;
    _flushedSeen = seen;
    widget.onSeen?.call(seen);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _inFront = true;
        // A new look: the line moves to the first row that arrived while
        // the app was away, if any — or arrives in the next moments.
        _markerPlaced = false;
        _markerId = null;
        _markBase = _seenId;
        _armedUntil = DateTime.now().add(const Duration(seconds: 5));
        setState(_maybePlaceMarker);
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        _inFront = false;
        _flushSeen();
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        break;
    }
  }

  /// One row of the main list; seen when built with the app in front.
  Widget _row(List<DeckMessage> rows, int i) {
    final m = rows[i];
    if (_inFront && i > _seenIndex) {
      _seenIndex = i;
      _seenId = m.id;
    }
    final row = _Row(
      message: m,
      progress: widget.uploadProgress,
      queued: widget.queued.contains(m.id),
      onWithdraw: widget.onWithdraw == null ? null : () => widget.onWithdraw!(m.id),
      onTap: _rowTap(m),
    );
    if (_markerId != m.id) return row;
    return Column(key: _markerKey, crossAxisAlignment: CrossAxisAlignment.stretch, children: [const _SinceLine(), row]);
  }

  /// The session controls under the title — Start/Stop, the pills, the
  /// dials — fold away so the transcript gets the screen. Open while idle
  /// (Start is there), folded while a session runs; a tap on the chevron
  /// or the title overrides until the session state changes again.
  bool? _openChoice;
  bool get _headerOpen => _openChoice ?? !widget.running;

  /// The chrome folded by a drag upward — see [DeckView.foldOnScroll].
  bool _chromeHidden = false;
  bool get _folds => widget.foldOnScroll ?? (Platform.isAndroid || Platform.isIOS);

  void _setChromeHidden(bool hidden) {
    if (!_folds || hidden == _chromeHidden) return;
    setState(() => _chromeHidden = hidden);
    widget.onChromeHidden?.call(hidden);
    // The viewport changes height under the list; stay on the newest row.
    if (_pinned) _snapToEnd(12);
  }

  /// Files can be dropped on a desktop window; a phone has the paperclip.
  static final bool _dropSupported = Platform.isMacOS || Platform.isWindows || Platform.isLinux;

  static const _chips = ['/step', '/qa', '/next', '/plan-status'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _takeLastSeen();
    _maybePlaceMarker();
  }

  @override
  void didUpdateWidget(DeckView old) {
    super.didUpdateWidget(old);
    if (old.running != widget.running) _openChoice = null;
    if (old.lastSeenId != widget.lastSeenId || old.seenScope != widget.seenScope) {
      if (!_markerPlaced) _takeLastSeen();
    }
    // Another transcript under the same view: what was built is moot.
    final oldFirst = old.messages.isEmpty ? null : old.messages.first.id;
    final first = widget.messages.isEmpty ? null : widget.messages.first.id;
    if (oldFirst != first || widget.messages.length <= _seenIndex) _seenIndex = -1;
    _maybePlaceMarker();
    _follow();
  }

  @override
  void dispose() {
    _flushSeen();
    WidgetsBinding.instance.removeObserver(this);
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
    if (n is UserScrollNotification) {
      // Finger up (reading down): fold the chrome; finger down: unfold.
      if (n.direction == ScrollDirection.reverse) _setChromeHidden(true);
      if (n.direction == ScrollDirection.forward) _setChromeHidden(false);
      return false;
    }
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

  /// Every tool row opens: an `Agent` row as its crew member, any other
  /// as the whole input and result — with the diff, the file behind a
  /// path, and Revert where the host can.
  VoidCallback? _rowTap(DeckMessage m) {
    if (m.role != DeckRole.tool) return null;
    if (m.isAgent) {
      return () => showCrewSheet(context, CrewMember(row: m, rows: [for (final r in widget.messages) if (r.parentToolUseId != null && r.parentToolUseId == m.toolUseId) r]), rowTap: _rowTap);
    }
    final path = m.path;
    return () => showToolSheet(
          context,
          m,
          onOpen: path != null && widget.loadFile != null ? () => _openFile(path) : null,
          onRevert: path != null && widget.onGit != null ? () => _revert(path) : null,
        );
  }

  Future<void> _revert(String path) async {
    final line = await widget.onGit!('revert', path: path);
    _toast(line);
  }

  /// The file view; Ask about this comes back as `path:line` and lands
  /// in the composer as the scope of the next message.
  Future<void> _openFile(String path) async {
    final load = widget.loadFile;
    if (load == null) return;
    final about = await Navigator.of(context).push<String>(MaterialPageRoute(
      builder: (_) => FileViewScreen(path: path, load: () => load(path), onRevert: widget.onGit == null ? null : () => widget.onGit!('revert', path: path)),
    ));
    if (!mounted || about == null) return;
    _input.text = '$about ';
    _input.selection = TextSelection.collapsed(offset: _input.text.length);
    _focus.requestFocus();
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
    final rows = _rows;
    final crew = crewOf(w.messages);
    final body = LayoutBuilder(
      builder: (context, box) {
        // The header, like the bottom, scrolls inside its own share at the
        // largest text sizes rather than pushing the transcript out. Open
        // by choice — Start, the pills, three dials and the Git card — it
        // may take more of the screen than folded, at the text sizes where
        // the composer's own share leaves room.
        final roomy = _headerOpen && !_chromeHidden && MediaQuery.textScalerOf(context).scale(1) <= 1.3;
        final chrome = Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: box.maxHeight * (roomy ? 0.62 : 0.48)),
              child: SingleChildScrollView(
                child: _Header(
                  view: w,
                  open: _headerOpen && !_chromeHidden,
                  compact: _chromeHidden,
                  onToggle: () => setState(() => _openChoice = !_headerOpen),
                  onExpand: () => _setChromeHidden(false),
                  onAttach: (f) => _addFiles([f]),
                ),
              ),
            ),
            // The crew of the turn: on the row even when the chrome is
            // folded — it is what is running now.
            if (crew.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                child: CrewStrip(crew: crew, onTap: (c) => showCrewSheet(context, c, rowTap: _rowTap)),
              ),
            if (w.nowSlot != null && !_chromeHidden) Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 4), child: w.nowSlot!),
          ],
        );
        return Column(
        children: [
          _folds ? AnimatedSize(duration: const Duration(milliseconds: 180), curve: Curves.easeOut, alignment: Alignment.topCenter, child: chrome) : chrome,
          Expanded(
            child: rows.isEmpty
                ? Column(
                    children: [
                      Expanded(child: EmptyNote(w.running ? 'Session ready. Ask, or give an order.' : 'Start a session to talk to Claude Code in this folder.')),
                      if (w.askSlot != null) Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: w.askSlot!),
                    ],
                  )
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
                            itemCount: rows.length + (w.askSlot == null ? 0 : 1),
                            itemBuilder: (context, i) => i == rows.length
                                // The ask is the last row: the conversation
                                // and what it asks are one scroll. When the
                                // card grows in — a phone's panel fills on
                                // its own — a pinned viewport follows it.
                                ? NotificationListener<SizeChangedLayoutNotification>(
                                    onNotification: (_) {
                                      if (_pinned) _snapToEnd();
                                      return true;
                                    },
                                    child: SizeChangedLayoutNotifier(child: w.askSlot!),
                                  )
                                : _row(rows, i),
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
          // The composer keeps the bottom; at the largest text sizes it
          // scrolls inside its own share and the transcript keeps the
          // rest, instead of a Column overflowing.
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: box.maxHeight * 0.5),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
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
      );
      },
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
  const DeckTab({super.key, required this.bridge, this.title, this.nowSlot, this.pick, this.testPush, this.onChromeHidden, this.files, this.git, this.onGit, this.autopilot, this.onAutopilot, this.run, this.onRun, this.runLog, this.mirrorHooks});
  final BridgeSession bridge;

  /// The host's loop, and its toggle — see [DeckView.autopilot].
  final AutopilotState? autopilot;
  final Future<String?> Function({required bool on, int? budget, bool? nightShift})? onAutopilot;

  /// The host's run bay — see [DeckView.run].
  final RunState? run;
  final Future<String> Function(String action, {String? device, bool? on})? onRun;
  final Stream<List<String>> Function(String runId)? runLog;
  final MirrorHooks? mirrorHooks;

  /// The host's own hands, for the taps: files inside the project, git.
  final HostFiles? files;
  final GitStatus? git;
  final Future<String> Function(String op, {String? message, String? path})? onGit;

  /// See [DeckView.onChromeHidden].
  final void Function(bool hidden)? onChromeHidden;

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
          onChromeHidden: onChromeHidden,
          facts: [
            if (b.sessionId != null) 'session ${shortId(b.sessionId!)}',
            if (b.transcript.model != null) b.transcript.model!,
            if (b.cliVersion != null) 'claude ${b.cliVersion}${b.cliVersion == bridgeProvenOn ? '' : ' (proven on $bridgeProvenOn)'}',
            if (b.running && b.transcript.permissionMode != null) '${modeLabel(b.transcript.permissionMode!)} mode',
          ],
          error: b.error,
          messages: b.transcript.messages,
          running: b.running,
          canResume: resumable != null,
          resumeLabel: resumable == null ? 'RESUME' : 'RESUME ${shortId(resumable).toUpperCase()}',
          turnOpen: b.transcript.turnOpen,
          contextUsed: b.transcript.contextUsed,
          contextWindow: b.running ? b.transcript.contextWindow : 0,
          pool: b.transcript.pool,
          compacting: b.transcript.compacting,
          onCompact: b.compact,
          modeChoice: b.modeChoice,
          switchPending: b.modePending || b.modelPending,
          chrome: b.chrome,
          chromeStatus: b.chromeStatus,
          modelChoice: b.modelChoice ?? 'default',
          effort: b.effort ?? 'default',
          restartPending: b.restartPending,
          onOptions: ({mode, chrome, model, effort}) => b.setOptions(mode: mode, chrome: chrome, model: model, effort: effort),
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
          onInterrupt: () => b.interrupt(),
          onWithdraw: (id) => b.withdrawQueued(id),
          loadFile: files == null ? null : (path) async => files!.read(path),
          git: git,
          onGit: onGit,
          autopilot: autopilot,
          onAutopilot: onAutopilot,
          run: run,
          onRun: onRun,
          runLog: runLog,
          mirrorHooks: mirrorHooks,
          onSend: (text, files) async => b.send(text, files: files),
          pick: pick,
        );
      },
    );
  }
}

/// The phone's Deck: the mirror in, commands out.
class RemoteDeckTab extends StatefulWidget {
  const RemoteDeckTab({super.key, required this.db, required this.slug, this.from = 'phone', this.title, this.nowSlot, this.pick, this.blobs, this.onChromeHidden});
  final FirebaseFirestore db;

  /// See [DeckView.onChromeHidden].
  final void Function(bool hidden)? onChromeHidden;
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

  /// Where this phone last looked, read once; the Deck draws its line
  /// only once this is known.
  String? _lastSeen;
  bool _seenLoaded = false;

  @override
  void initState() {
    super.initState();
    LastSeen.load(widget.slug).then((v) {
      if (!mounted) return;
      setState(() {
        _lastSeen = v;
        _seenLoaded = true;
      });
    }, onError: (Object _) {
      if (mounted) setState(() => _seenLoaded = true);
    });
  }

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
        onChromeHidden: widget.onChromeHidden,
        lastSeenId: _lastSeen,
        seenScope: d.sessionId,
        markUnread: _seenLoaded && (d.sessionId != null || d.view.isEmpty),
        onSeen: (seen) => LastSeen.save(widget.slug, seen),
        facts: [
          if (d.sessionId != null) 'session ${shortId(d.sessionId!)}',
          if (d.model != null) d.model!,
          if (d.cliVersion != null) 'claude ${d.cliVersion}',
          if (d.running && d.permissionMode != null) '${modeLabel(d.permissionMode!)} mode',
          if (d.machine != null) d.machine!,
        ],
        error: d.error,
        messages: d.view,
        running: d.running,
        canResume: d.canResume,
        turnOpen: d.turnOpen,
        contextUsed: d.contextUsed,
        contextWindow: d.running ? d.contextWindow : 0,
        pool: d.pool,
        compacting: d.compacting,
        onCompact: d.compact,
        here: widget.from,
        modeChoice: d.modeChoice,
        switchPending: d.switchPending,
        chrome: d.chrome,
        chromeStatus: d.chromeStatus,
        modelChoice: d.modelChoice,
        effort: d.effort,
        restartPending: d.restartPending,
        onOptions: ({mode, chrome, model, effort}) => d.setOptions(mode: mode, chrome: chrome, model: model, effort: effort),
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
        onInterrupt: d.interrupt,
        loadFile: d.readFile,
        git: d.git,
        onGit: d.gitOp,
        run: d.run,
        onRun: d.runCommand,
        runLog: d.runLog,
        mirrorHooks: d.mirrorHooks,
        autopilot: d.autopilot,
        onAutopilot: ({required on, budget, nightShift}) async {
          await d.setAutopilot(on: on, budget: budget, nightShift: nightShift);
          return on ? 'autopilot on — the Mac starts stepping' : 'autopilot off';
        },
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
  const _Header({required this.view, required this.open, required this.onToggle, this.compact = false, this.onExpand, this.onAttach});
  final DeckView view;

  /// A frame from the mirror, for the composer.
  final void Function(PendingAttachment f)? onAttach;

  /// Whether the controls under the title row show.
  final bool open;
  final VoidCallback onToggle;

  /// Folded by a drag on a phone: one row — the status, the title, Stop
  /// and the way back, [onExpand].
  final bool compact;
  final VoidCallback? onExpand;

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
    if (compact) {
      final auto = w.autopilot;
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 6, 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
          children: [
            StatusGlyph(color: color, mode: glyph),
            const SizedBox(width: 8),
            Expanded(
              child: InkWell(
                onTap: onExpand,
                child: Text('${w.title == null ? '' : '${w.title!.toUpperCase()} · '}$label', maxLines: 1, overflow: TextOverflow.ellipsis, style: t.display(13, weight: FontWeight.w600, ls: 2.0, color: color)),
              ),
            ),
            // The instruments stay on the row, small and unlabelled; the
            // COMPACT offer waits in the sheet a tap opens.
            if (w.contextWindow > 0) ...[const SizedBox(width: 6), Flexible(child: _Gauges(view: w, size: 22, labels: false, pill: false))],
            if (w.turnOpen && w.onInterrupt != null)
              Flexible(child: _InterruptButton(onTap: w.onInterrupt!))
            else if (w.running)
              IconButton(
                tooltip: 'Stop',
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                icon: Icon(Icons.stop, color: t.ink2),
                onPressed: w.onStop,
              ),
            IconButton(
              tooltip: 'Show the header',
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              icon: Icon(Icons.expand_more, color: t.ink2),
              onPressed: onExpand,
            ),
          ],
            ),
            // Folded, the loop's line stays: the wait for the pool is
            // what the person came to look at.
            if (auto != null && auto.on) Padding(padding: const EdgeInsets.only(right: 10, bottom: 2), child: Align(alignment: Alignment.centerLeft, child: _AutopilotLine(state: auto, needsYou: w.state == BridgeState.waiting))),
            if (w.run case final r? when r.up) Padding(padding: const EdgeInsets.only(right: 10, bottom: 2), child: Align(alignment: Alignment.centerLeft, child: _RunLine(view: w, run: r))),
          ],
        ),
      );
    }
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
                  child: w.title == null
                      ? const SizedBox(height: 36)
                      : Text(w.title!.toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis, style: t.display(22, ls: 3.2)),
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
              // A turn running: INTERRUPT is the brake on the row; Stop
              // waits in the fold. Folded otherwise: Stop stays one tap away.
              if (w.turnOpen && w.onInterrupt != null)
                Flexible(child: _InterruptButton(onTap: w.onInterrupt!))
              else if (!open && w.running)
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
          // The facts row: the instruments first — the context arc, the
          // pool arc, COMPACT when it is offered — then the facts. Its own
          // row, the full width: beside the pill and INTERRUPT the title's
          // share is a third of the screen, and arcs need their size.
          if (w.facts.isNotEmpty || w.contextWindow > 0)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: InkWell(
                onTap: onToggle,
                child: Row(
                  children: [
                    if (w.contextWindow > 0) ...[
                      Flexible(child: _Gauges(view: w, size: 30, labels: true, pill: true)),
                      const SizedBox(width: 10),
                    ],
                    Expanded(child: Text(w.facts.join(' · ').toUpperCase(), maxLines: open ? 2 : 1, overflow: TextOverflow.ellipsis, style: t.readout(11))),
                  ],
                ),
              ),
            ),
          // The Mac's line on its own row: at the folded width beside the
          // pill, "unreachable since" would lose its since.
          if (w.hostLine case final line?)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(line.toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis, style: t.readout(11, color: w.hostWarn ? t.warn : t.muted)),
            ),
          // The pool refused: nothing runs until a window resets.
          if (poolLine(w.pool) case final line?)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(line.toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis, style: t.readout(11, color: t.warn)),
            ),
          // The loop: which step, how far into the budget, or the wait.
          if (w.autopilot case final a? when a.on) Padding(padding: const EdgeInsets.only(top: 4), child: _AutopilotLine(state: a, needsYou: w.state == BridgeState.waiting)),
          // The app under test: where it runs and for how long; amber once it threw. A tap opens the log.
          if (w.run case final r? when r.up) Padding(padding: const EdgeInsets.only(top: 4), child: _RunLine(view: w, run: r)),
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
          if (w.onAutopilot != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: _AutopilotControl(view: w),
            ),
          if (w.onOptions != null) ...[
            const SizedBox(height: 4),
            _Dial(label: 'MODEL', choices: modelChoices, value: w.modelChoice, enabled: true, onChanged: (v) => w.onOptions!(model: v)),
            _Dial(label: 'EFFORT', choices: effortChoices, value: w.effort, enabled: true, onChanged: (v) => w.onOptions!(effort: v)),
            _Dial(label: 'MODE', choices: modeChoices, value: w.modeChoice, enabled: true, labelOf: modeLabel, warnOn: 'bypassPermissions', onChanged: (v) => w.onOptions!(mode: v)),
            if (w.onGit != null) Padding(padding: const EdgeInsets.only(top: 8), child: GitCard(git: w.git, onOp: w.onGit!)),
            if (w.onRun != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: RunCard(
                  run: w.run ?? const RunState(),
                  onAction: w.onRun!,
                  onLog: w.runLog == null || w.run?.runId == null ? null : () => openRunLog(context, w),
                  onMirror: w.mirrorHooks == null ? null : () => showMirrorSheet(context, w.mirrorHooks!, title: 'Mirror · ${w.run?.deviceName ?? ''}', onAttach: onAttach),
                ),
              ),
            if (w.running)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  w.restartPending
                      ? 'Applies when this turn ends — the session restarts on the same conversation.'
                      : w.switchPending
                          ? 'The change applies when this turn ends.'
                          : 'Model and mode switch in place; Chrome and effort restart the session on the same conversation.',
                  style: t.mono(11, color: w.restartPending || w.switchPending ? t.warn : t.muted),
                ),
              ),
          ],
        ];
}

/// A dial: a slider over a short list of words, the current word beside
/// it. Moves freely while dragged and reports once, when the finger lifts
/// — so the phone sends one command, not one per notch. [labelOf] turns a
/// choice into its word when they differ; [warnOn] is the choice drawn in
/// the warning colour.
class _Dial extends StatefulWidget {
  const _Dial({required this.label, required this.choices, required this.value, required this.enabled, required this.onChanged, this.labelOf, this.warnOn});
  final String label;
  final List<String> choices;
  final String value;
  final bool enabled;
  final void Function(String) onChanged;
  final String Function(String)? labelOf;
  final String? warnOn;

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
    final color = !widget.enabled
        ? t.muted
        : word == 'default'
            ? t.ink2
            : word == widget.warnOn
                ? t.warn
                : t.accent;
    final shown = (widget.labelOf?.call(word) ?? word).toUpperCase();
    return Row(children: [
      Flexible(child: Text('${widget.label} · $shown', maxLines: 1, overflow: TextOverflow.ellipsis, style: t.mono(11.5, color: color))),
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

/// The brake on the title row: ends the turn, keeps the session.
class _InterruptButton extends StatelessWidget {
  const _InterruptButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return TextButton(
      style: TextButton.styleFrom(
        foregroundColor: t.warn,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        minimumSize: const Size(0, 36),
        visualDensity: VisualDensity.compact,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      onPressed: onTap,
      child: Text('INTERRUPT', maxLines: 1, softWrap: false, overflow: TextOverflow.ellipsis, style: t.display(12, weight: FontWeight.w600, ls: 1.8, color: t.warn)),
    );
  }
}

/// One session option, as a switch that reads: what it is · what it is set
/// to. Fixed while a session runs.
/// The run bay's log for the run on the state.
Future<void> openRunLog(BuildContext context, DeckView w) {
  final r = w.run;
  final id = r?.runId;
  if (id == null || w.runLog == null) return Future.value();
  return showLogSheet(context, lines: w.runLog!(id), title: 'Log · ${r!.deviceName ?? r.device ?? id}');
}

/// The app under test on one line under the facts — `RUNNING · IPHONE 17
/// PRO · 4 MIN`, amber with the count once it threw; a tap opens the log.
/// Redrawn once a minute for the age.
class _RunLine extends StatefulWidget {
  const _RunLine({required this.view, required this.run});
  final DeckView view;
  final RunState run;

  @override
  State<_RunLine> createState() => _RunLineState();
}

class _RunLineState extends State<_RunLine> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final r = widget.run;
    final color = r.exceptions > 0 ? t.warn : r.running ? t.good : t.accent;
    final line = runLine(r) ?? '';
    return InkWell(
      onTap: widget.view.runLog == null || r.runId == null ? null : () => openRunLog(context, widget.view),
      child: Text(line.toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis, style: t.readout(11, color: color)),
    );
  }
}

/// The loop's line under the facts: the step and the budget, or the
/// countdown to the pool's reset — ticking once a second while it waits.
class _AutopilotLine extends StatefulWidget {
  const _AutopilotLine({required this.state, this.needsYou = false});
  final AutopilotState state;
  final bool needsYou;

  @override
  State<_AutopilotLine> createState() => _AutopilotLineState();
}

class _AutopilotLineState extends State<_AutopilotLine> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _arm();
  }

  @override
  void didUpdateWidget(_AutopilotLine old) {
    super.didUpdateWidget(old);
    _arm();
  }

  void _arm() {
    final waiting = widget.state.waitingUntil != null;
    if (waiting && _tick == null) {
      _tick = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    } else if (!waiting) {
      _tick?.cancel();
      _tick = null;
    }
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final line = autopilotLine(widget.state, needsYou: widget.needsYou) ?? '';
    final color = widget.state.waitingUntil != null || widget.needsYou ? t.warn : t.accent;
    return Text(line.toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis, style: t.readout(11, color: color));
  }
}

/// The AUTOPILOT pill in the fold, and why the last run stopped beside
/// it. Off: a tap opens the budget sheet. On: a tap stops it.
class _AutopilotControl extends StatelessWidget {
  const _AutopilotControl({required this.view});
  final DeckView view;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final w = view;
    final a = w.autopilot ?? const AutopilotState();
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _OptionPill(
          text: autopilotPill(a),
          color: a.on ? (a.waitingUntil != null ? t.warn : t.accent) : t.ink2,
          on: a.on,
          enabled: true,
          onTap: () async {
            if (a.on) {
              final r = await w.onAutopilot!(on: false);
              if (context.mounted && r != null) ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(r)));
            } else {
              await showAutopilotSheet(context, w);
            }
          },
        ),
        if (!a.on && a.stoppedFor != null)
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 240),
            child: Text('stopped · ${a.stoppedFor}', maxLines: 2, overflow: TextOverflow.ellipsis, style: t.mono(11, color: t.muted)),
          ),
        if (a.on && a.done > 0) Text('${a.done} step${a.done == 1 ? '' : 's'} finished', style: t.mono(11, color: t.muted)),
      ],
    );
  }
}

/// The budget sheet: how many steps, night shift, the fixed rules, and
/// START — the confirm the toggle asks for until biometrics come.
Future<void> showAutopilotSheet(BuildContext context, DeckView w) {
  final t = context.tokens;
  final a = w.autopilot ?? const AutopilotState();
  var budget = a.budget.clamp(1, 10);
  var night = a.nightShift;
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('AUTOPILOT', style: t.readout(11)),
              const SizedBox(height: 8),
              Text('The Mac keeps sending /step — the next step of the plan after each turn — and stops for you.', style: t.mono(11.5, color: t.ink2)),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(child: Text('STEPS', style: t.readout(10))),
                  Text('$budget', style: t.display(20, weight: FontWeight.w600, color: t.accent)),
                ],
              ),
              Slider(
                value: budget.toDouble(),
                min: 1,
                max: 10,
                divisions: 9,
                label: '$budget',
                onChanged: (v) => setState(() => budget = v.round()),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: night,
                onChanged: (v) => setState(() => night = v),
                title: Text('NIGHT SHIFT', style: t.readout(10)),
                subtitle: Text(night ? 'When the pool runs dry, wait for its reset and carry on.' : 'When the pool runs dry, stop and say so.', style: t.mono(11, color: t.muted)),
              ),
              const SizedBox(height: 6),
              Text('Fixed: an ask waits for you (the push carries it); a step whose gate fails twice stops the run; so does a plan that needs you, an error, Stop or INTERRUPT.', style: t.mono(11, color: t.muted)),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: () async {
                  Navigator.of(context).pop();
                  final r = await w.onAutopilot!(on: true, budget: budget, nightShift: night);
                  if (context.mounted && r != null) ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(r)));
                },
                icon: const Icon(Icons.play_arrow, size: 18),
                label: Text('START · $budget STEP${budget == 1 ? '' : 'S'}'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

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
  const _Row({required this.message, this.progress = const {}, this.queued = false, this.onWithdraw, this.onTap});
  final DeckMessage message;
  final Map<String, double> progress;

  /// A tool row with a diff or a file behind it.
  final VoidCallback? onTap;

  /// This echo's command waits on a Mac that is gone. A row the host
  /// holds behind a running turn says so itself ([DeckMessage.queued]).
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
              // The loop's own message, labelled — the record says who sent it.
              if (m.by == 'autopilot') Padding(padding: const EdgeInsets.only(bottom: 3), child: Text('AUTOPILOT', style: t.readout(10, color: t.accent))),
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
              if (queued || m.queued)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    alignment: WrapAlignment.end,
                    spacing: 8,
                    children: [
                      Text(queued ? 'QUEUED · MAC UNREACHABLE' : 'QUEUED · AFTER THIS TURN', style: t.readout(10, color: t.warn)),
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
                // The turn's cost rides on its last row: the context read, the output written.
                Flexible(child: Text('CLAUDE · ${hm(m.at)}${m.turn == null ? '' : ' · ${tokensLabel(m.turn!.context)} CTX · ${tokensLabel(m.turn!.output)} OUT'}', maxLines: 1, overflow: TextOverflow.ellipsis, style: t.readout(11))),
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
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(6),
            child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(color: t.surface, borderRadius: BorderRadius.circular(6), border: Border.all(color: onTap == null ? t.line : t.accent.withValues(alpha: 0.35))),
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
                if (m.diff != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4, left: 20),
                    child: Text('DIFF · TAP', style: t.readout(10, color: t.accent)),
                  ),
              ],
            ),
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

/// The instruments: the context arc against its window, the five-hour
/// pool's arc with the countdown to its reset under it, and the COMPACT
/// pill once the context passes 80 % (COMPACTING while it runs). A tap on
/// an arc opens the numbers.
class _Gauges extends StatelessWidget {
  const _Gauges({required this.view, required this.size, required this.labels, required this.pill});
  final DeckView view;
  final double size;
  final bool labels;

  /// Whether COMPACT rides beside the arcs when it is offered.
  final bool pill;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final w = view;
    final ctx = w.contextFraction;
    final pool = w.pool;
    final five = pool?.fiveHour;
    final poolFraction = pool?.exhausted == true ? 1.0 : (five?.utilization ?? 0.0);
    final resets = five?.resetsAt ?? pool?.resetsAt;
    final offer = pill && w.onCompact != null && w.running && (ctx >= 0.8 || w.compacting);
    // Scales down, never up: where the row is short the arcs shrink
    // together rather than push the row over.
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => showInstrumentsSheet(context, w),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GaugeArc(fraction: ctx, inner: '${(ctx * 100).round()}', label: labels ? 'ctx' : null, size: size),
          if (pool != null) ...[
            const SizedBox(width: 6),
            GaugeArc(
              fraction: poolFraction,
              inner: five?.utilization == null && !pool.exhausted ? null : '${(poolFraction * 100).round()}',
              label: labels ? (resets == null ? 'pool' : untilLabel(resets)) : null,
              size: size,
              color: pool.exhausted ? t.critical : null,
            ),
          ],
          if (offer) ...[
            const SizedBox(width: 8),
            _OptionPill(text: w.compacting ? 'COMPACTING…' : 'COMPACT', color: t.warn, on: true, enabled: !w.compacting && !w.turnOpen, onTap: w.onCompact!),
          ],
        ],
      ),
      ),
    );
  }
}

/// "Pool exhausted · resets in 1 h 12 m" while the pool refuses; null
/// otherwise.
String? poolLine(RateLimitEvent? pool) {
  if (pool == null || !pool.exhausted) return null;
  final at = pool.fiveHour?.resetsAt ?? pool.resetsAt;
  return at == null ? 'Pool exhausted' : 'Pool exhausted · resets in ${untilLabel(at)}';
}

/// The numbers behind the arcs, and COMPACT when the session can take it.
Future<void> showInstrumentsSheet(BuildContext context, DeckView w) {
  final t = context.tokens;
  final pct = (w.contextFraction * 100).round();
  final pool = w.pool;
  String window(PoolWindow? p) {
    if (p == null) return '—';
    final u = p.utilization == null ? '' : '${(p.utilization! * 100).round()} % used';
    final r = p.resetsAt == null ? '' : 'resets in ${untilLabel(p.resetsAt!)} (${hm(p.resetsAt!)})';
    final s = [u, r].where((x) => x.isNotEmpty).join(' · ');
    return s.isEmpty ? '—' : s;
  }

  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('INSTRUMENTS', style: t.readout(11)),
            const SizedBox(height: 12),
            _Reading('Context', '${thousands(w.contextUsed)} / ${thousands(w.contextWindow)} tokens · $pct %', warn: w.contextFraction >= 0.7),
            _Reading('Five-hour pool', pool == null ? '—' : window(pool.fiveHour ?? PoolWindow(resetsAt: pool.resetsAt))),
            _Reading('Weekly pool', window(pool?.sevenDay)),
            if (pool?.exhausted == true) const _Reading('Status', 'Exhausted — nothing runs until a window resets', warn: true),
            const SizedBox(height: 10),
            Text('The context is what the model read on its last call. COMPACT folds the conversation into a summary and the arc drops. Tokens, never dollars.', style: t.mono(11, color: t.muted)),
            if (w.onCompact != null && w.running)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: OutlinedButton(
                  onPressed: w.compacting || w.turnOpen
                      ? null
                      : () {
                          Navigator.of(context).pop();
                          w.onCompact!();
                        },
                  child: Text(w.compacting ? 'COMPACTING…' : 'COMPACT'),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

class _Reading extends StatelessWidget {
  const _Reading(this.label, this.value, {this.warn = false});
  final String label;
  final String value;
  final bool warn;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 118, child: Text(label.toUpperCase(), style: t.readout(10))),
          Expanded(child: Text(value, style: t.mono(12, color: warn ? t.warn : t.ink))),
        ],
      ),
    );
  }
}

/// A subagent, opened: what it was asked, how it is doing, its report,
/// and the rows it produced — each a tap like any tool row.
Future<void> showCrewSheet(BuildContext context, CrewMember c, {required VoidCallback? Function(DeckMessage) rowTap}) {
  final t = context.tokens;
  final clock = clockLabel(c.elapsed(DateTime.now()));
  final status = c.running
      ? 'Running · $clock · ${c.toolUses} tool use${c.toolUses == 1 ? '' : 's'}'
      : c.failed
          ? 'Failed · after $clock'
          : 'Done · in $clock · ${c.toolUses} tool use${c.toolUses == 1 ? '' : 's'}';
  final summary = c.summary?.trim() ?? '';
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: t.surface,
    builder: (sheet) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.96,
      builder: (context, ctrl) => SelectionArea(
        child: ListView(
          controller: ctrl,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            Text('${c.kind.toUpperCase()} · ${c.description}', style: t.display(15, weight: FontWeight.w600, ls: 0.4)),
            const SizedBox(height: 4),
            Text(status.toUpperCase(), style: t.readout(10, color: c.failed ? t.critical : c.running ? t.accent : t.muted)),
            const SizedBox(height: 12),
            if (summary.isNotEmpty) ...[
              const SheetHead('Report'),
              MonoBlock(summary, error: c.failed),
              const SizedBox(height: 12),
            ],
            SheetHead('Its rows · ${c.rows.length}'),
            if (c.rows.isEmpty) Text('Nothing yet.', style: t.mono(12, color: t.muted)) else for (final r in c.rows) _Row(message: r, onTap: rowTap(r)),
          ],
        ),
      ),
    ),
  );
}

/// The thin labelled line above the first row not seen since the app
/// was last in front.
class _SinceLine extends StatelessWidget {
  const _SinceLine();

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final line = Expanded(child: Container(height: 1, color: t.accent.withValues(alpha: 0.5)));
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 2),
      child: Row(
        children: [
          line,
          Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: Text('SINCE YOU LAST LOOKED', style: t.readout(10, color: t.accent))),
          line,
        ],
      ),
    );
  }
}
