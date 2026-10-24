import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart' as mobile;
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as desktop;

import 'app.dart';
import 'core/app_controller.dart';
import 'features/history/repository.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
    ),
  );
  runApp(const Bootstrap());
}

Future<AppController> openApplication() async {
  final base = await getApplicationSupportDirectory();
  if (Platform.isWindows || Platform.isLinux) desktop.sqfliteFfiInit();
  final factory = Platform.isWindows || Platform.isLinux
      ? desktop.databaseFactoryFfi
      : mobile.databaseFactory;
  final repository = HistoryRepository(
    Directory(p.join(base.path, 'Glyphica')),
    factory,
  );
  await repository.open();
  final app = AppController(repository);
  await app.initialize();
  return app;
}

class Bootstrap extends StatefulWidget {
  const Bootstrap({super.key});
  @override
  State<Bootstrap> createState() => _BootstrapState();
}

class _BootstrapState extends State<Bootstrap> {
  late Future<AppController> ready = openApplication();
  @override
  Widget build(BuildContext context) => FutureBuilder<AppController>(
    future: ready,
    builder: (context, snapshot) {
      if (snapshot.hasData) {
        return ProviderScope(
          overrides: [appProvider.overrideWith((ref) => snapshot.data!)],
          child: const GlyphicaApp(),
        );
      }
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: snapshot.hasError
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.storage_outlined, size: 36),
                        const SizedBox(height: 16),
                        const Text(
                          'Your studio could not be opened.',
                          style: TextStyle(fontSize: 22),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Check available device storage and try again. Existing data has not been cleared.\n\n${snapshot.error}',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 18),
                        FilledButton(
                          onPressed: () =>
                              setState(() => ready = openApplication()),
                          child: const Text('Try again'),
                        ),
                      ],
                    )
                  : const CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
      );
    },
  );
}
