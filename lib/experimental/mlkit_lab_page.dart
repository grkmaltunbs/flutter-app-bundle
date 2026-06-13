// EXPERIMENTAL — ML Kit playground for tile detection. Debug-only scaffolding
// (gated by kDebugMode in the router + home page); safe to delete with its
// route + home button once detection work lands.
//
// ignore_for_file: avoid_catches_without_on_clauses

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

class MlkitLabPage extends StatefulWidget {
  const MlkitLabPage({super.key});

  @override
  State<MlkitLabPage> createState() => _MlkitLabPageState();
}

class _MlkitLabPageState extends State<MlkitLabPage> {
  final ImagePicker _picker = ImagePicker();
  final TextRecognizer _recognizer = TextRecognizer();

  String? _imagePath;
  String _output = 'Pick an image to run ML Kit text recognition.';
  bool _busy = false;

  @override
  void dispose() {
    unawaited(_recognizer.close());
    super.dispose();
  }

  Future<void> _pickAndProcess(ImageSource source) async {
    setState(() => _busy = true);
    try {
      final picked = await _picker.pickImage(source: source);
      if (picked == null) {
        setState(() => _busy = false);
        return;
      }
      setState(() {
        _imagePath = picked.path;
        _output = 'Processing…';
      });

      final stopwatch = Stopwatch()..start();
      final result = await _recognizer.processImage(
        InputImage.fromFilePath(picked.path),
      );
      stopwatch.stop();

      setState(() {
        _output = _dump(result, stopwatch.elapsedMilliseconds);
        _busy = false;
      });
    } catch (e, st) {
      setState(() {
        _output = 'ERROR: $e\n\n$st';
        _busy = false;
      });
    }
  }

  String _dump(RecognizedText result, int elapsedMs) {
    final buf = StringBuffer()
      ..writeln('=== ML Kit Text Recognition ($elapsedMs ms) ===')
      ..writeln('Blocks: ${result.blocks.length}')
      ..writeln()
      ..writeln('--- FULL TEXT ---')
      ..writeln(result.text.isEmpty ? '(none)' : result.text)
      ..writeln()
      ..writeln('--- STRUCTURE ---');

    for (final (bi, block) in result.blocks.indexed) {
      buf
        ..writeln('BLOCK $bi  rect=${_rect(block.boundingBox)}  '
            'langs=${block.recognizedLanguages}')
        ..writeln('  text: "${block.text}"');
      for (final (li, line) in block.lines.indexed) {
        buf.writeln('  LINE $li  rect=${_rect(line.boundingBox)}  '
            'conf=${line.confidence?.toStringAsFixed(3)}  '
            'angle=${line.angle?.toStringAsFixed(1)}  "${line.text}"');
        for (final (ei, el) in line.elements.indexed) {
          buf.writeln('    EL $ei  rect=${_rect(el.boundingBox)}  '
              'conf=${el.confidence?.toStringAsFixed(3)}  '
              'angle=${el.angle?.toStringAsFixed(1)}  "${el.text}"');
        }
      }
      buf.writeln();
    }
    return buf.toString();
  }

  String _rect(Rect r) =>
      '(${r.left.toInt()},${r.top.toInt()} '
      '${r.width.toInt()}x${r.height.toInt()})';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ML Kit Lab (temp)')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _busy
                          ? null
                          : () => _pickAndProcess(ImageSource.camera),
                      icon: const Icon(Icons.photo_camera),
                      label: const Text('Camera'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.tonalIcon(
                      onPressed: _busy
                          ? null
                          : () => _pickAndProcess(ImageSource.gallery),
                      icon: const Icon(Icons.photo_library),
                      label: const Text('Gallery'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_imagePath != null)
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 180),
                  child: Image.file(File(_imagePath!), fit: BoxFit.contain),
                ),
              const SizedBox(height: 12),
              Expanded(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: _busy
                      ? const Center(child: CircularProgressIndicator())
                      : SingleChildScrollView(
                          padding: const EdgeInsets.all(8),
                          child: SelectableText(
                            _output,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 11,
                            ),
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
