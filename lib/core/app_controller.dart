import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../features/conversion/engine.dart';
import '../features/conversion/models.dart';
import '../features/conversion/worker.dart';
import '../features/destinations/formatting.dart';
import '../features/history/creation.dart';
import '../features/history/repository.dart';

final appProvider = ChangeNotifierProvider<AppController>(
  (ref) => throw UnimplementedError('Override at startup'),
);

enum ImportKind { photos, files, camera, sample }

class AppController extends ChangeNotifier {
  AppController(this.repository);
  final HistoryRepository repository;
  List<Creation> creations = [];
  List<DestinationProfile> profiles = [];
  bool welcomed = false;
  bool reduceMotion = false;
  String theme = 'system';
  bool importing = false;
  SourceImage? draft;
  ArtSettings draftSettings = const ArtSettings();
  final importRunner = ConversionRunner();

  Future<void> initialize() async {
    creations = await repository.all();
    profiles = (jsonDecode(
      await rootBundle.loadString('assets/config/destinations.json'),
    ) as List).map((j) => DestinationProfile.fromJson(j)).toList();
    welcomed = await repository.preference('welcomed') == 'true';
    reduceMotion = await repository.preference('reduceMotion') == 'true';
    theme = await repository.preference('theme') ?? 'system';
  }

  Future<void> setPreference(String key, String value) async {
    await repository.setPreference(key, value);
    if (key == 'welcomed') welcomed = value == 'true';
    if (key == 'reduceMotion') reduceMotion = value == 'true';
    if (key == 'theme') theme = value;
    notifyListeners();
  }

  Creation? find(String id) {
    for (final c in creations) {
      if (c.id == id) return c;
    }
    return null;
  }

  Future<SourceImage?> importImage(ImportKind kind) async {
    if (importing) return null;
    importing = true;
    notifyListeners();
    File? staging;
    try {
      String? path;
      String name = 'Untitled';
      if (kind == ImportKind.sample) {
        final data = await rootBundle.load('assets/samples/philosopher.png');
        staging = File(
          p.join((await getTemporaryDirectory()).path, 'glyphica-sample.png'),
        );
        await staging.writeAsBytes(
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
          flush: true,
        );
        path = staging.path;
        name = 'Philosopher';
      } else if (kind == ImportKind.files ||
          (kind == ImportKind.photos &&
              !(Platform.isAndroid || Platform.isIOS))) {
        final file = await FilePicker.pickFile(
          type: FileType.custom,
          allowedExtensions: ['png', 'jpg', 'jpeg', 'webp'],
          dialogTitle: 'Choose an image',
        );
        if (file == null) return null;
        name = p.basenameWithoutExtension(file.name);
        path = file.path;
        if (path == null) {
          if (!{'content', 'file'}.contains(file.uri.scheme)) {
            throw const ConversionException(
              'Choose an image stored locally on this device.',
            );
          }
          final knownSize = file.lengthSync();
          if (knownSize != null && knownSize > ArtEngine.maxEncodedBytes) {
            throw const ConversionException(
              'Choose an image smaller than 24 MB.',
            );
          }
          staging = File(
            p.join(
              (await getTemporaryDirectory()).path,
              '${const Uuid().v4()}.img',
            ),
          );
          final sink = staging.openWrite();
          var size = 0;
          try {
            await for (final bytes in file.readAsByteStream()) {
              size += bytes.length;
              if (size > ArtEngine.maxEncodedBytes) {
                throw const ConversionException(
                  'Choose an image smaller than 24 MB.',
                );
              }
              sink.add(bytes);
            }
            await sink.flush();
          } finally {
            await sink.close();
          }
          path = staging.path;
        }
      } else {
        final file = await ImagePicker().pickImage(
          source: kind == ImportKind.camera
              ? ImageSource.camera
              : ImageSource.gallery,
          requestFullMetadata: false,
        );
        if (file == null) return null;
        path = file.path;
        name = p.basenameWithoutExtension(file.name);
      }
      return await adopt(path, name);
    } finally {
      if (staging != null && await staging.exists()) await staging.delete();
      importing = false;
      notifyListeners();
    }
  }

  Future<SourceImage?> adopt(String path, String name) async {
    final inspection = await importRunner.run<Inspection>(
      WorkRequest(path, const ArtSettings(), kind: WorkKind.inspect),
    );
    if (inspection == null) return null;
    final source = await repository.ownSource(path, name, inspection);
    draft = source;
    draftSettings = const ArtSettings();
    notifyListeners();
    return source;
  }

  Future<bool> recoverPicker() async {
    if (!Platform.isAndroid) return false;
    final response = await ImagePicker().retrieveLostData();
    if (response.exception != null) throw response.exception!;
    if (response.files?.isNotEmpty != true) return false;
    final file = response.files!.first;
    return await adopt(file.path, p.basenameWithoutExtension(file.name)) !=
        null;
  }

  Future<Creation> saveRender(SourceImage source, RenderBundle render) async {
    final creation = Creation(
      id: const Uuid().v4(),
      name: source.name,
      createdAt: DateTime.now(),
      source: source,
      output: render.output,
      settings: render.settings,
    );
    await put(creation);
    return creation;
  }

  Future<void> put(Creation c) async {
    await repository.put(c);
    creations = await repository.all();
    notifyListeners();
  }

  Future<void> duplicate(Creation c) => put(
    c.copyWith(
      id: const Uuid().v4(),
      name: '${c.name} copy',
      createdAt: DateTime.now(),
    ),
  );
  Future<void> delete(String id) async {
    await repository.delete(id);
    creations = await repository.all();
    notifyListeners();
  }

  Future<void> clear() async {
    await repository.clear();
    creations = [];
    notifyListeners();
  }

  void edit(Creation c) {
    draft = c.source;
    draftSettings = c.settings;
    notifyListeners();
  }

  @override
  void dispose() {
    importRunner.cancel();
    super.dispose();
  }
}
