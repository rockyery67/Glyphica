import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:glyphica/features/conversion/engine.dart';
import 'package:glyphica/features/conversion/models.dart';
import 'package:glyphica/features/conversion/worker.dart';
import 'package:glyphica/features/destinations/formatting.dart';
import 'package:glyphica/features/history/creation.dart';
import 'package:glyphica/features/history/repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late Directory temp;
  late File input;
  setUp(() async {
    temp = await Directory.systemTemp.createTemp('glyphica-test-');
    final image = img.Image(width: 100, height: 80);
    for (final pixel in image) {
      pixel.setRgb(pixel.x * 2, pixel.y * 3, 120);
    }
    input = await File(p.join(temp.path, 'input.png'))
        .writeAsBytes(img.encodePng(image));
  });
  tearDown(() async {
    await temp.delete(recursive: true);
  });

  test(
    'history, source ownership, favorites, variants survive database restart',
    () async {
      final root = Directory(p.join(temp.path, 'db'));
      var repo = HistoryRepository(root, databaseFactoryFfi);
      await repo.open();
      final engine = ArtEngine(), bytes = await input.readAsBytes();
      final source = await repo.ownSource(
        input.path,
        'Portrait',
        engine.inspect(bytes),
      );
      const s = ArtSettings(mode: ArtMode.braille, width: 40);
      final out = engine.convert(bytes, s);
      final c = Creation(
        id: 'saved-id',
        name: 'First portrait',
        createdAt: DateTime(2026, 10, 22),
        source: source,
        output: out,
        settings: s,
        favorite: true,
        variants: [
          SavedVariant(
            destination: 'discord',
            text: '  ⣿  \n     ',
            settings: s,
            budget: 2000,
            codeBlock: true,
            labels: false,
          ),
        ],
      );
      await repo.put(c);
      await repo.setPreference('welcomed', 'true');
      await repo.close();
      await input.delete();
      repo = HistoryRepository(root, databaseFactoryFfi);
      await repo.open();
      final reopened = (await repo.all()).single;
      expect(reopened.output.text, out.text);
      expect(reopened.settings.mode, ArtMode.braille);
      expect(reopened.favorite, isTrue);
      expect(reopened.variants.single.text, '  ⣿  \n     ');
      expect(await File(reopened.source.path).exists(), isTrue);
      expect(await repo.preference('welcomed'), 'true');
      await repo.put(reopened.copyWith(id: 'duplicate', name: 'Copy'));
      await repo.delete('saved-id');
      expect(await File(source.path).exists(), isTrue);
      await File(source.path).delete();
      expect(
        (await repo.all()).single.output.text,
        out.text,
      ); // Lost image does not lose text.
      await repo.clear();
      expect(await repo.all(), isEmpty);
      await repo.close();
    },
  );

  test('cancelled worker cannot publish a result', () async {
    final runner = ConversionRunner();
    final future = runner.run<RenderBundle>(
      WorkRequest(input.path, const ArtSettings(width: 200)),
    );
    runner.cancel();
    expect(await future, isNull);
  });

  test(
    'latest request supersedes earlier worker and fits an independent variant',
    () async {
      final runner = ConversionRunner();
      final old = runner.run<RenderBundle>(
        WorkRequest(input.path, const ArtSettings(width: 200)),
      );
      final fresh = runner.run<RenderBundle>(
        WorkRequest(
          input.path,
          const ArtSettings(width: 40),
          kind: WorkKind.fit,
          budget: 300,
          codeBlock: true,
        ),
      );
      expect(await old, isNull);
      final result = (await fresh)!;
      expect(result.output.columns, lessThan(40));
      expect(
        MessageFormatter.wrap(result.output.text, codeBlock: true).length,
        lessThanOrEqualTo(300),
      );
      runner.cancel();
    },
  );

  test('missing source produces actionable recovery error', () async {
    final runner = ConversionRunner();
    await expectLater(
      runner.run<RenderBundle>(
        WorkRequest(p.join(temp.path, 'missing.png'), const ArtSettings()),
      ),
      throwsA(
        isA<ConversionException>().having(
          (e) => e.message,
          'message',
          contains('saved text'),
        ),
      ),
    );
    runner.cancel();
  });
}
