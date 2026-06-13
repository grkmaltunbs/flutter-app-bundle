// EXPERIMENTAL — manual solver playground. Debug-only scaffolding (gated by
// kDebugMode in the router + home page); safe to delete with its route + home
// button once no longer needed.
//
// Pick a mode + indicator, hand-build a 21–22 (or 14–15) tile rack, then run
// the real DpSolverEngine and dump the full SolveResult. No DI: instantiates
// the const engine and runs it off the UI isolate, exactly like SolveRack.
//
// ignore_for_file: avoid_catches_without_on_clauses

import 'dart:async';
import 'dart:isolate';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:okey_acar_mi/core/game/game_mode.dart';
import 'package:okey_acar_mi/core/game/game_tile.dart';
import 'package:okey_acar_mi/core/game/indicator.dart';
import 'package:okey_acar_mi/core/game/tile_color.dart';
import 'package:okey_acar_mi/features/solver/domain/engine/solver_engine.dart';
import 'package:okey_acar_mi/features/solver/domain/entities/reasoning_step.dart';
import 'package:okey_acar_mi/features/solver/domain/entities/solve_request.dart';
import 'package:okey_acar_mi/features/solver/domain/entities/solve_result.dart';
import 'package:okey_acar_mi/features/solver/domain/entities/solve_verdict.dart';
import 'package:okey_acar_mi/features/solver/domain/entities/solved_meld.dart';
import 'package:okey_acar_mi/features/solver/domain/entities/solved_pair.dart';
import 'package:okey_acar_mi/features/solver/domain/entities/solved_spot.dart';

/// Runs the solve off the UI isolate. MUST be top-level: defining the
/// `Isolate.run` closure inside a State method makes it share that method's
/// context, which transitively captures `this` (the widget tree) and throws
/// "object is unsendable". Here the only captured local is the sendable
/// [request].
Future<SolveResult> _solveOffIsolate(SolveRequest request) =>
    Isolate.run(() => const DpSolverEngine().solve(request));

class SolverLabPage extends StatefulWidget {
  const SolverLabPage({super.key});

  @override
  State<SolverLabPage> createState() => _SolverLabPageState();
}

class _SolverLabPageState extends State<SolverLabPage> {
  GameMode _mode = GameMode.oneZeroOne;

  // Indicator (a real numbered tile, never joker).
  TileColor _indicatorColor = TileColor.red;
  int _indicatorNumber = 1;

  // Staging controls for the next tile to add.
  TileColor _pickColor = TileColor.red;
  int _pickNumber = 1;

  final List<GameTile> _rack = [];
  final Random _rng = Random();

  String? _output;
  SolveResult? _result;
  bool _busy = false;

  static const List<TileColor> _numberedColors = [
    TileColor.red,
    TileColor.black,
    TileColor.yellow,
    TileColor.blue,
  ];

  void _addNumbered() {
    if (_rack.length >= _mode.maxTiles) return;
    setState(() {
      _rack.add(GameTile(color: _pickColor, number: _pickNumber));
      _sortRack();
    });
  }

  void _addJoker() {
    if (_rack.length >= _mode.maxTiles) return;
    setState(() {
      _rack.add(const GameTile(color: TileColor.joker));
      _sortRack();
    });
  }

  /// Keeps the rack ordered by number ascending (color as a tiebreak), with
  /// jokers pushed to the end.
  void _sortRack() => _rack.sort(_tileOrder);

  int _tileOrder(GameTile a, GameTile b) {
    final an = a.isJoker ? 99 : a.number!;
    final bn = b.isJoker ? 99 : b.number!;
    if (an != bn) return an.compareTo(bn);
    return a.color.index.compareTo(b.color.index);
  }

  void _removeAt(int i) => setState(() => _rack.removeAt(i));

  /// Replaces the rack with 21 tiles drawn from a real Okey bag (2 of every
  /// numbered tile + 2 false jokers, dealt without replacement) — so no
  /// identity ever exceeds its legal supply of 2.
  void _randomFill() {
    final bag = <GameTile>[
      for (final c in _numberedColors)
        for (var n = 1; n <= 13; n++) ...[
          GameTile(color: c, number: n),
          GameTile(color: c, number: n),
        ],
      const GameTile(color: TileColor.joker),
      const GameTile(color: TileColor.joker),
    ]..shuffle(_rng);
    setState(() {
      _rack
        ..clear()
        ..addAll(bag.take(21))
        ..sort(_tileOrder);
      _output = null;
      _result = null;
    });
  }

  void _clear() => setState(() {
    _rack.clear();
    _output = null;
    _result = null;
  });

  Future<void> _solve() async {
    setState(() {
      _busy = true;
      _output = 'Solving…';
    });
    try {
      final request = SolveRequest(
        tiles: List<GameTile>.unmodifiable(_rack),
        indicator: Indicator(color: _indicatorColor, number: _indicatorNumber),
        mode: _mode,
      );
      final sw = Stopwatch()..start();
      final result = await _solveOffIsolate(request);
      sw.stop();
      setState(() {
        _output = _dump(result, request, sw.elapsedMicroseconds);
        _result = result;
        _busy = false;
      });
    } catch (e, st) {
      setState(() {
        _output = 'ERROR: $e\n\n$st';
        _result = null;
        _busy = false;
      });
    }
  }

  // ---- Rendering of the SolveResult -------------------------------------

  String _dump(SolveResult r, SolveRequest req, int micros) {
    final ind = req.indicator;
    final indicatorStr = ind == null
        ? '(none)'
        : _tileStr(ind.color, ind.number);
    final okeyStr = ind == null
        ? '(none)'
        : _tileStr(ind.color, ind.okeyNumber);
    final buf = StringBuffer()
      ..writeln('=== SOLVE (${(micros / 1000).toStringAsFixed(2)} ms) ===')
      ..writeln('mode: ${req.mode.name}   rack: ${req.tiles.length} tiles')
      ..writeln('indicator: $indicatorStr')
      ..writeln('okey (wild target): $okeyStr')
      ..writeln()
      ..writeln('VERDICT: ${_verdictStr(r.verdict)}')
      ..writeln('totalScore: ${r.totalScore}')
      ..writeln();

    if (r.melds.isNotEmpty) {
      buf.writeln('--- MELDS (${r.melds.length}) ---');
      for (final (i, m) in r.melds.indexed) {
        buf.writeln(
          '  [$i] ${m.kind.name}  +${m.points}  '
          '${m.spots.map(_spotStr).join(' ')}',
        );
      }
      buf.writeln();
    }

    if (r.pairs.isNotEmpty) {
      buf.writeln('--- PAIRS (${r.pairs.length}) ---');
      for (final (i, p) in r.pairs.indexed) {
        buf.writeln(
          '  [$i] ${_tileStr(p.identity.color, p.identity.number)}  '
          '${_spotStr(p.first)} + ${_spotStr(p.second)}',
        );
      }
      buf.writeln();
    }

    if (r.leftovers.isNotEmpty) {
      buf
        ..writeln('--- LEFTOVERS (${r.leftovers.length}) ---')
        ..writeln('  ${r.leftovers.map(_spotStr).join('  ')}')
        ..writeln();
    }

    if (r.discardSuggested != null) {
      buf
        ..writeln(
          'discard: '
          '${_tileStr(r.discardSuggested!.color, r.discardSuggested!.number)}'
          ' @rack${r.discardRackIndex}',
        )
        ..writeln();
    }

    buf.writeln('--- REASONING (${r.reasoning.length}) ---');
    for (final step in r.reasoning) {
      buf.writeln('  ${_reasonStr(step)}');
    }
    return buf.toString();
  }

  String _verdictStr(SolveVerdict v) => switch (v) {
    Finishes101(:final score) => 'BİTER — finishes (score $score)',
    Opens101(:final score, :final via) =>
      'AÇAR — opens 101 (score $score via ${via.name})',
    DoesNotOpen101(:final score, :final pointsShort) =>
      'AÇMAZ — does not open (score $score, $pointsShort short)',
    OkeyOutcome(:final tilesToWin, :final via) =>
      'tilesToWin=$tilesToWin via ${via.name}',
  };

  String _spotStr(SolvedSpot s) => switch (s) {
    RackSpot(:final physical, :final playsAs, :final rackIndex) => _playStr(
      physical,
      playsAs,
      rackIndex,
      'R',
    ),
    WildSpot(:final physical, :final playsAs, :final rackIndex) => _playStr(
      physical,
      playsAs,
      rackIndex,
      'W',
    ),
    NeededSpot(:final playsAs) =>
      '[need ${_tileStr(playsAs.color, playsAs.number)}]',
  };

  String _playStr(GameTile physical, GameTile playsAs, int idx, String tag) {
    final phys = _tileStr(physical.color, physical.number);
    final as = _tileStr(playsAs.color, playsAs.number);
    final body = phys == as ? phys : '$phys→$as';
    return '$body·$tag$idx';
  }

  String _reasonStr(ReasoningStep s) => switch (s) {
    OkeyDerivedStep(:final okeyTile) =>
      'okey derived → ${_tileStr(okeyTile.color, okeyTile.number)}',
    WildsCountedStep(:final falseJokers, :final okeyCopies) =>
      'wilds: $falseJokers false-joker(s), $okeyCopies okey-copy',
    RackCountNotedStep(:final count, :final mode) =>
      'rack count $count (${mode.name})',
    CountsClampedStep(:final kind, :final dropped) =>
      'clamped ${_tileStr(kind.color, kind.number)} ×$dropped',
    MeldFormedStep(:final meld, :final runningTotal) =>
      'meld ${meld.kind.name} +${meld.points} → total $runningTotal',
    FinishCheckedStep(:final tilesUsed, :final rackCount, :final finishes) =>
      'finish check $tilesUsed/$rackCount → ${finishes ? "finishes" : "no finish"}',
    ThresholdCheckedStep(:final total, :final threshold, :final opens) =>
      'threshold $total/$threshold → ${opens ? "opens" : "short"}',
    PairsCountedStep(:final pairCount, :final opens) =>
      'pairs $pairCount → ${opens ? "opens" : "short"}',
    PathChosenStep(:final via) => 'path: ${via.name}',
    OkeyTemplateChosenStep(:final via, :final matched, :final wildsUsed) =>
      'template ${via.name}: matched $matched, wilds $wildsUsed',
    TilesNeededStep(:final needed) =>
      'needed: '
          '${needed.map((t) => _tileStr(t.color, t.number)).join(", ")}',
    DiscardSuggestedStep(:final tile, :final rackIndex) =>
      'discard ${_tileStr(tile.color, tile.number)} @$rackIndex',
    TilesToWinComputedStep(:final tilesToWin) => 'tilesToWin=$tilesToWin',
  };

  String _tileStr(TileColor c, int? n) =>
      c == TileColor.joker ? '🃏' : '${_colorTag(c)}$n';

  String _colorTag(TileColor c) => switch (c) {
    TileColor.red => 'R',
    TileColor.black => 'K',
    TileColor.yellow => 'Y',
    TileColor.blue => 'B',
    TileColor.joker => 'J',
  };

  Color _colorOf(TileColor c) => switch (c) {
    TileColor.red => const Color(0xFFD23B3B),
    TileColor.black => const Color(0xFF222222),
    TileColor.yellow => const Color(0xFFCB9A00),
    TileColor.blue => const Color(0xFF2D6BD2),
    TileColor.joker => const Color(0xFF6B7280),
  };

  // ---- UI ----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final min = _mode.minTiles;
    final max = _mode.maxTiles;
    final legal = _rack.length >= min && _rack.length <= max;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Solver Lab (temp)'),
        actions: [
          IconButton(
            onPressed: _rack.isEmpty ? null : _clear,
            icon: const Icon(Icons.delete_sweep),
            tooltip: 'Clear rack',
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _modeRow(),
              const SizedBox(height: 8),
              _indicatorRow(),
              const Divider(height: 20),
              _stagingRow(),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: _randomFill,
                  icon: const Icon(Icons.casino),
                  label: const Text('Random 21'),
                ),
              ),
              const SizedBox(height: 8),
              _rackHeader(min, max, legal),
              const SizedBox(height: 4),
              _rackChips(),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: (_busy || _rack.isEmpty) ? null : _solve,
                icon: _busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.play_arrow),
                label: Text(
                  legal
                      ? 'Run solver'
                      : 'Run solver (rack is $min–$max for ${_mode.name})',
                ),
              ),
              const SizedBox(height: 12),
              _outputText(),
              if (_result != null) ...[
                const SizedBox(height: 12),
                _visualResult(_result!),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _modeRow() {
    return Row(
      children: [
        const Text('Mode:'),
        const SizedBox(width: 8),
        SegmentedButton<GameMode>(
          segments: const [
            ButtonSegment(value: GameMode.oneZeroOne, label: Text('101')),
            ButtonSegment(value: GameMode.okey, label: Text('Okey')),
          ],
          selected: {_mode},
          onSelectionChanged: (s) => setState(() => _mode = s.first),
        ),
      ],
    );
  }

  Widget _indicatorRow() {
    return Row(
      children: [
        const Text('Indicator:'),
        const SizedBox(width: 8),
        _colorDropdown(
          _indicatorColor,
          (c) => setState(() => _indicatorColor = c),
        ),
        const SizedBox(width: 8),
        _numberDropdown(
          _indicatorNumber,
          (n) => setState(() => _indicatorNumber = n),
        ),
        const SizedBox(width: 8),
        Text(
          '→ okey ${_indicatorNumber % 13 + 1}',
          style: const TextStyle(color: Colors.grey),
        ),
      ],
    );
  }

  Widget _stagingRow() {
    return Row(
      children: [
        const Text('Add:'),
        const SizedBox(width: 8),
        _colorDropdown(_pickColor, (c) => setState(() => _pickColor = c)),
        const SizedBox(width: 8),
        _numberDropdown(_pickNumber, (n) => setState(() => _pickNumber = n)),
        const SizedBox(width: 8),
        FilledButton.tonal(
          onPressed: _rack.length >= _mode.maxTiles ? null : _addNumbered,
          child: const Text('+ tile'),
        ),
        const SizedBox(width: 8),
        OutlinedButton(
          onPressed: _rack.length >= _mode.maxTiles ? null : _addJoker,
          child: const Text('+ 🃏'),
        ),
      ],
    );
  }

  Widget _colorDropdown(TileColor value, ValueChanged<TileColor> onChanged) {
    return DropdownButton<TileColor>(
      value: value,
      onChanged: (c) => c == null ? null : onChanged(c),
      items: [
        for (final c in _numberedColors)
          DropdownMenuItem(
            value: c,
            child: Text(
              _colorTag(c),
              style: TextStyle(color: _colorOf(c), fontWeight: FontWeight.bold),
            ),
          ),
      ],
    );
  }

  Widget _numberDropdown(int value, ValueChanged<int> onChanged) {
    return DropdownButton<int>(
      value: value,
      onChanged: (n) => n == null ? null : onChanged(n),
      items: [
        for (var n = 1; n <= 13; n++)
          DropdownMenuItem(value: n, child: Text('$n')),
      ],
    );
  }

  Widget _rackHeader(int min, int max, bool legal) {
    return Text(
      'Rack: ${_rack.length} tiles  (legal $min–$max)',
      style: TextStyle(
        fontWeight: FontWeight.bold,
        color: legal ? Colors.green.shade700 : Colors.orange.shade800,
      ),
    );
  }

  Widget _rackChips() {
    if (_rack.isEmpty) {
      return const Align(
        alignment: Alignment.centerLeft,
        child: Text('(no tiles yet)', style: TextStyle(color: Colors.grey)),
      );
    }
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        for (final (i, t) in _rack.indexed) _rackTile(i, t),
      ],
    );
  }

  /// A rack tile rendered as a tile, tappable to remove (× badge affordance).
  Widget _rackTile(int index, GameTile tile) {
    return GestureDetector(
      onTap: () => _removeAt(index),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          _tileWidget(color: tile.color, number: tile.number),
          Positioned(
            right: -5,
            top: -6,
            child: Container(
              width: 17,
              height: 17,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: Colors.redAccent,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, size: 11, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _outputText() {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: SelectableText(
          _output ?? 'Build a rack and press Run solver.',
          style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
        ),
      ),
    );
  }

  // ---- Visual tile rendering of the arrangement -------------------------

  Widget _visualResult(SolveResult r) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (r.melds.isNotEmpty) ...[
          _sectionLabel('Melds'),
          for (final m in r.melds) _meldRow(m),
        ],
        if (r.pairs.isNotEmpty) ...[
          _sectionLabel('Pairs'),
          _pairsRow(r.pairs),
        ],
        if (r.leftovers.isNotEmpty) ...[
          _sectionLabel('Leftovers'),
          Opacity(
            opacity: 0.55,
            child: Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [for (final s in r.leftovers) _spotTile(s)],
            ),
          ),
        ],
      ],
    );
  }

  Widget _sectionLabel(String text) => Padding(
    padding: const EdgeInsets.only(top: 8, bottom: 6),
    child: Text(
      text.toUpperCase(),
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.bold,
        letterSpacing: 1,
        color: Colors.grey,
      ),
    ),
  );

  Widget _meldRow(SolvedMeld m) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black12,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '${m.kind.name} +${m.points}',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [for (final s in m.spots) _spotTile(s)],
            ),
          ),
        ],
      ),
    );
  }

  Widget _pairsRow(List<SolvedPair> pairs) {
    return Wrap(
      spacing: 14,
      runSpacing: 8,
      children: [
        for (final p in pairs)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _spotTile(p.first),
              const SizedBox(width: 2),
              _spotTile(p.second),
            ],
          ),
      ],
    );
  }

  Widget _spotTile(SolvedSpot s) => switch (s) {
    RackSpot(:final playsAs) => _tileWidget(
      color: playsAs.color,
      number: playsAs.number,
    ),
    WildSpot(:final playsAs) => _tileWidget(
      color: playsAs.color,
      number: playsAs.number,
      wild: true,
    ),
    NeededSpot(:final playsAs) => _tileWidget(
      color: playsAs.color,
      number: playsAs.number,
      needed: true,
    ),
  };

  Widget _tileWidget({
    required TileColor color,
    int? number,
    bool wild = false,
    bool needed = false,
  }) {
    final label = color == TileColor.joker ? '🃏' : '${number ?? '?'}';
    final tile = Container(
      width: 32,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: needed ? Colors.transparent : const Color(0xFFF6F1E7),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: needed
              ? Colors.grey
              : wild
              ? const Color(0xFF1F8A70)
              : Colors.black26,
          width: wild ? 2 : 1,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: needed ? Colors.grey : _colorOf(color),
          fontWeight: FontWeight.bold,
          fontFamily: 'monospace',
          fontSize: 16,
        ),
      ),
    );
    if (!wild && !needed) return tile;
    // Badge: W = a wild (joker/okey copy) standing in; ? = a tile still needed.
    return Stack(
      clipBehavior: Clip.none,
      children: [
        tile,
        Positioned(
          right: -3,
          top: -5,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
            decoration: BoxDecoration(
              color: wild ? const Color(0xFF1F8A70) : Colors.grey,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              wild ? 'W' : '?',
              style: const TextStyle(fontSize: 8, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}
