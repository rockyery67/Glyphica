import 'dart:convert';
import 'dart:io';

import 'package:glyphica/features/conversion/engine.dart';
import 'package:glyphica/features/conversion/models.dart';

void main(List<String> args) {
  final expected = ArtEngine().convert(
    File(args.length > 1 ? args[1] : 'assets/samples/philosopher.png')
        .readAsBytesSync(),
    ArtSettings(
      mode: args.length > 2 ? ArtMode.values.byName(args[2]) : ArtMode.detailed,
    ),
  );
  final bytes = File(args.first).readAsBytesSync();
  if (utf8.decode(bytes) != expected.text) {
    stderr.writeln('Export differs from the original conversion.');
    exitCode = 1;
  } else {
    stdout.writeln(
      'Exact UTF-8 match: ${expected.characterCount} code points, ${expected.rows} lines, ${bytes.length} bytes.',
    );
  }
}
