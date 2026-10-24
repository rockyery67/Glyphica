import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:glyphica/app.dart';
import 'package:glyphica/core/app_controller.dart';
import 'package:glyphica/core/output_service.dart';
import 'package:glyphica/features/history/repository.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'offline sample import → convert → durable reopen → clipboard → UTF-8 file',
    (tester) async {
      final root = Directory(
        p.join(
          (await getTemporaryDirectory()).path,
          'offline-journey-${DateTime.now().microsecondsSinceEpoch}',
        ),
      );
      var repo = HistoryRepository(root, databaseFactory);
      await repo.open();
      var app = AppController(repo);
      await app.initialize();
      await app.setPreference('welcomed', 'true');
      await app.setPreference('reduceMotion', 'true');
      await tester.pumpWidget(
        ProviderScope(
          overrides: [appProvider.overrideWith((ref) => app)],
          child: const GlyphicaApp(),
        ),
      );
      Future<void> waitFor(Finder finder) async {
        for (var i = 0; i < 200 && finder.evaluate().isEmpty; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(finder, findsWidgets);
      }

      final sample = find.byKey(const Key('sample-import'));
      await waitFor(sample);
      await tester.ensureVisible(sample);
      await tester.tap(sample);
      await waitFor(find.byKey(const Key('prepare-next')));
      await tester.tap(find.byKey(const Key('prepare-next')));
      await waitFor(find.byKey(const Key('generate-artwork')));
      await tester.tap(find.byKey(const Key('generate-artwork')));
      await waitFor(find.byKey(const Key('copy-original')));
      expect(app.creations.length, 1);
      final original = app.creations.single;
      expect(original.output.columns, 100);
      expect(await File(original.source.path).exists(), isTrue);
      await tester.tap(find.byKey(const Key('copy-original')));
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        (await Clipboard.getData(Clipboard.kTextPlain))!.text,
        original.output.text,
      );
      final export = File(
        p.join(root.path, OutputService.filename(original.name)),
      );
      await export.writeAsBytes(
        OutputService.encode(original.output.text),
        flush: true,
      );
      expect(utf8.decode(await export.readAsBytes()), original.output.text);
      // Recreate database connection and app state: no in-memory history survives.
      await tester.pumpWidget(const SizedBox());
      await repo.close();
      repo = HistoryRepository(root, databaseFactory);
      await repo.open();
      app = AppController(repo);
      await app.initialize();
      expect(app.creations.single.output.text, original.output.text);
      expect(app.welcomed, isTrue);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [appProvider.overrideWith((ref) => app)],
          child: const GlyphicaApp(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text(original.name),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text(original.name), findsOneWidget);
      await tester.ensureVisible(find.text(original.name));
      await tester.tap(find.text(original.name));
      await waitFor(find.byKey(const Key('copy-original')));
      expect(find.text('Saved locally'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await repo.close();
      await root.delete(recursive: true);
    },
  );
}
