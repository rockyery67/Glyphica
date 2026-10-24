import 'dart:convert';
import 'dart:io';

import 'package:glyphica/features/conversion/engine.dart';
import 'package:glyphica/features/conversion/models.dart';

/// Developer-only: exports real engine output for the visual contact sheets.
void main() {
  final engine = ArtEngine();
  final fixtures = Directory('test/fixtures')
      .listSync()
      .whereType<File>()
      .where((f) => RegExp(r'\.(png|jpg|webp)$').hasMatch(f.path));
  final manifest = <Map<String, dynamic>>[];
  for (final file in fixtures) {
    final name = file.uri.pathSegments.last.split('.').first;
    final bytes = file.readAsBytesSync();
    for (final look in QualityLook.values) {
      final s = const ArtSettings(width: 100).withLook(look);
      final out = engine.convert(bytes, s);
      final path = 'docs/quality/$name-${look.name}.txt';
      File(path).writeAsBytesSync(utf8.encode(out.text));
      manifest.add({
        'name': name,
        'look': look.name,
        'source': file.path,
        'text': path,
        'columns': out.columns,
        'rows': out.rows,
        'characters': out.characterCount,
      });
    }
    for (final mode in [ArtMode.blocks, ArtMode.braille]) {
      final out = engine.convert(
        bytes,
        ArtSettings(width: 100, mode: mode, dither: true),
      );
      final path = 'docs/quality/$name-${mode.name}.txt';
      File(path).writeAsBytesSync(utf8.encode(out.text));
      manifest.add({
        'name': name,
        'look': mode.name,
        'source': file.path,
        'text': path,
        'columns': out.columns,
        'rows': out.rows,
        'characters': out.characterCount,
      });
    }
  }
  File('docs/quality/manifest.json')
      .writeAsStringSync(const JsonEncoder.withIndent('  ').convert(manifest));
  stdout.writeln(
    'Rendered ${manifest.length} real conversions for inspection.',
  );
}
