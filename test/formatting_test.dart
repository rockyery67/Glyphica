import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glyphica/core/output_service.dart';
import 'package:glyphica/features/destinations/formatting.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'clipboard and UTF-8 preserve all significant whitespace and Unicode',
    () async {
      const text = '  @⠀⣿\n  ░▒  \n\n  😀  \n';
      String? copied;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            if (call.method == 'Clipboard.setData') {
              copied = (call.arguments as Map)['text'];
            }
            return null;
          });
      await OutputService().copy(text);
      expect(copied, text);
      expect(utf8.decode(OutputService.encode(text)), text);
      expect(OutputService.encode(text).last, 10);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    },
  );

  test(
    'Unicode-safe complete-line splitting reconstructs the original exactly',
    () {
      final text = '${List.generate(30, (i) => '  ⣿😀$i  ').join('\n')}\n';
      final parts = MessageFormatter.split(
        text,
        budget: 65,
        codeBlock: true,
        labels: true,
      );
      expect(parts.length, greaterThan(1));
      expect(parts.every((p) => p.units <= 65), isTrue);
      expect(parts.map((p) => p.raw).join('\n'), text);
      expect(parts.every((p) => !p.formatted.runes.contains(0xfffd)), isTrue);
      expect(
        parts.first.formatted.startsWith('Part 1/${parts.length}\n```\n'),
        isTrue,
      );
      expect(parts.last.formatted.endsWith('\n```'), isTrue);
    },
  );

  test('line that cannot fit is rejected rather than truncated', () {
    expect(
      () => MessageFormatter.split('x' * 100, budget: 20),
      throwsFormatException,
    );
  });

  test('labels and wrappers stay within budgets through digit transitions', () {
    final text = List.generate(
      120,
      (i) => '  #${i.toString().padLeft(3, '0')}  ',
    ).join('\n');
    final parts = MessageFormatter.split(
      text,
      budget: 35,
      labels: true,
      codeBlock: true,
    );
    expect(parts.length, greaterThan(10));
    expect(parts.every((p) => p.units <= 35), isTrue);
    expect(parts.map((p) => p.raw).join('\n'), text);
  });

  test('code-fence collision is explained', () {
    expect(
      () => MessageFormatter.split('```', budget: 30, codeBlock: true),
      throwsFormatException,
    );
  });

  test('one-part artwork has no unnecessary part label', () {
    final p = MessageFormatter.split(
      '  #  \n     ',
      budget: 100,
      labels: true,
    ).single;
    expect(p.raw, p.formatted);
  });

  test('export filenames are meaningful and safe on Windows and mobile', () {
    expect(OutputService.filename('A portrait.txt'), 'A portrait.txt');
    expect(OutputService.filename('../a:b?'), '_a_b_.txt');
    expect(OutputService.filename('CON'), 'art-CON.txt');
    expect(OutputService.filename('  '), 'glyphica-artwork.txt');
  });
}
