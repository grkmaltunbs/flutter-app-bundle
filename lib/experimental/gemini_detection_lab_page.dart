// EXPERIMENTAL — Gemini tile-detection lab. Debug-only scaffolding (gated by
// kDebugMode in the router + home page). Pick/shoot a rack photo, send it to
// Gemini 3.1 Flash-Lite via Firebase AI Logic, and inspect the raw structured
// JSON + parsed tiles. REQUIRES the prod flavor (Firebase only initializes
// there): run with --dart-define=APP_ENV=prod. Safe to delete with its route +
// home button once detection is validated.
//
// ignore_for_file: avoid_catches_without_on_clauses

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:okey_acar_mi/core/di/injection.dart';
import 'package:okey_acar_mi/core/env/app_env.dart';
import 'package:okey_acar_mi/core/env/gemini_config.dart';
import 'package:okey_acar_mi/core/game/tile_color.dart';
import 'package:okey_acar_mi/features/detection/data/processing/gemini_rack_parser.dart';
import 'package:okey_acar_mi/features/detection/data/processing/rack_image_prep.dart';
import 'package:okey_acar_mi/features/detection/data/services/gemini_client.dart';
import 'package:okey_acar_mi/features/detection/domain/entities/detected_tile.dart';

class GeminiDetectionLabPage extends StatefulWidget {
  const GeminiDetectionLabPage({super.key});

  @override
  State<GeminiDetectionLabPage> createState() => _GeminiDetectionLabPageState();
}

class _GeminiDetectionLabPageState extends State<GeminiDetectionLabPage> {
  final ImagePicker _picker = ImagePicker();

  static const List<int> _dimensions = [768, 1024, 1536];

  String? _imagePath;
  int _maxDim = GeminiConfig.maxImageDimension;
  bool _busy = false;

  String? _rawJson;
  List<DetectedTile> _tiles = const [];
  String? _status;

  bool get _isProd => AppEnv.current == AppEnv.prod;

  Future<void> _pick(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(source: source);
      if (picked == null) return;
      setState(() {
        _imagePath = picked.path;
        _rawJson = null;
        _tiles = const [];
        _status = 'Image ready — pick a size and run Gemini.';
      });
    } catch (e) {
      setState(() => _status = 'Pick failed: $e');
    }
  }

  Future<void> _run() async {
    final path = _imagePath;
    if (path == null) return;
    if (!_isProd) {
      setState(
        () => _status =
            'Run with --dart-define=APP_ENV=prod to reach Firebase AI Logic '
            '(Firebase is not initialized in the demo flavor).',
      );
      return;
    }
    setState(() {
      _busy = true;
      _status = 'Preparing image…';
      _rawJson = null;
      _tiles = const [];
    });
    try {
      final jpeg = await prepareRackJpeg(
        path,
        maxDimension: _maxDim,
        quality: GeminiConfig.jpegQuality,
      );
      final kb = (jpeg.lengthInBytes / 1024).toStringAsFixed(1);

      setState(
        () => _status =
            'Uploaded ${kb}KB @ ${_maxDim}px — calling '
            '${GeminiConfig.modelId}…',
      );

      final client = getIt<GeminiClient>();
      final sw = Stopwatch()..start();
      final json = await client.generateRackJson(jpeg);
      sw.stop();

      final tiles = GeminiRackParser.parse(json);
      setState(() {
        _rawJson = json;
        _tiles = tiles;
        _status =
            '${tiles.length} tiles in ${sw.elapsedMilliseconds}ms '
            '· ${kb}KB @ ${_maxDim}px';
        _busy = false;
      });
    } catch (e) {
      setState(() {
        _status = 'ERROR: $e';
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Gemini Detection Lab (temp)')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!_isProd)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    '⚠ Demo flavor — run with APP_ENV=prod for real Gemini.',
                    style: TextStyle(color: Colors.orange.shade800),
                  ),
                ),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _busy ? null : () => _pick(ImageSource.camera),
                      icon: const Icon(Icons.photo_camera),
                      label: const Text('Camera'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.tonalIcon(
                      onPressed: _busy
                          ? null
                          : () => _pick(ImageSource.gallery),
                      icon: const Icon(Icons.photo_library),
                      label: const Text('Gallery'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text('Max size:'),
                  const SizedBox(width: 8),
                  DropdownButton<int>(
                    value: _maxDim,
                    onChanged: _busy
                        ? null
                        : (v) => setState(() => _maxDim = v ?? _maxDim),
                    items: [
                      for (final d in _dimensions)
                        DropdownMenuItem(value: d, child: Text('${d}px')),
                    ],
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: (_busy || _imagePath == null) ? null : _run,
                    icon: _busy
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.auto_awesome),
                    label: const Text('Run Gemini'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_imagePath != null)
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 200),
                  child: Image.file(File(_imagePath!), fit: BoxFit.contain),
                ),
              if (_status != null) ...[
                const SizedBox(height: 12),
                Text(_status!, style: const TextStyle(fontFamily: 'monospace')),
              ],
              if (_tiles.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text(
                  'PARSED TILES',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 8),
                _TileRows(tiles: _tiles),
              ],
              if (_rawJson != null) ...[
                const SizedBox(height: 16),
                const Text(
                  'RAW JSON',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 8),
                DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: SelectableText(
                      _pretty(_rawJson!),
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _pretty(String raw) {
    try {
      return const JsonEncoder.withIndent('  ').convert(jsonDecode(raw));
    } catch (_) {
      return raw;
    }
  }
}

/// Renders detected tiles grouped by rack row.
class _TileRows extends StatelessWidget {
  const _TileRows({required this.tiles});

  final List<DetectedTile> tiles;

  @override
  Widget build(BuildContext context) {
    final byRow = <int, List<DetectedTile>>{};
    for (final tile in tiles) {
      byRow.putIfAbsent(tile.position.row, () => []).add(tile);
    }
    final rows = byRow.keys.toList()..sort();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final row in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [for (final t in byRow[row]!) _TileChip(tile: t)],
            ),
          ),
      ],
    );
  }
}

class _TileChip extends StatelessWidget {
  const _TileChip({required this.tile});

  final DetectedTile tile;

  static const Map<TileColor, Color> _ink = {
    TileColor.red: Color(0xFFD23B3B),
    TileColor.black: Color(0xFF222222),
    TileColor.yellow: Color(0xFFCB9A00),
    TileColor.blue: Color(0xFF2D6BD2),
    TileColor.joker: Color(0xFF6B7280),
  };

  @override
  Widget build(BuildContext context) {
    final isJoker = tile.color == TileColor.joker;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 34,
          height: 46,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFFF6F1E7),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.black26),
          ),
          child: Text(
            isJoker ? '🃏' : '${tile.number ?? '?'}',
            style: TextStyle(
              color: _ink[tile.color],
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
              fontSize: 16,
            ),
          ),
        ),
        Text(
          tile.confidence.toStringAsFixed(2),
          style: const TextStyle(fontSize: 9, color: Colors.grey),
        ),
      ],
    );
  }
}
