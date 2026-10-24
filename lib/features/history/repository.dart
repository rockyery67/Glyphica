import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../conversion/models.dart';
import 'creation.dart';

class HistoryRepository {
  HistoryRepository(this.root, this.factory);
  final Directory root;
  final DatabaseFactory factory;
  late Database db;

  Future<void> open() async {
    await root.create(recursive: true);
    await Directory(p.join(root.path, 'sources')).create(recursive: true);
    await Directory(p.join(root.path, 'thumbnails')).create(recursive: true);
    db = await factory.openDatabase(
      p.join(root.path, 'glyphica.sqlite'),
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, version) async {
          await db.execute(
            'CREATE TABLE creations (id TEXT PRIMARY KEY, name TEXT NOT NULL, createdAt TEXT NOT NULL, source TEXT NOT NULL, thumbnail TEXT NOT NULL, sourceId TEXT NOT NULL, sourceName TEXT NOT NULL, sourceWidth INTEGER NOT NULL, sourceHeight INTEGER NOT NULL, text TEXT NOT NULL, columns INTEGER NOT NULL, rows INTEGER NOT NULL, imageWidth INTEGER NOT NULL, imageHeight INTEGER NOT NULL, characterCount INTEGER NOT NULL, settings TEXT NOT NULL, favorite INTEGER NOT NULL, variants TEXT NOT NULL)',
          );
          await db.execute(
            'CREATE INDEX creation_date ON creations(createdAt DESC)',
          );
          await db.execute(
            'CREATE TABLE preferences (key TEXT PRIMARY KEY, value TEXT NOT NULL)',
          );
        },
      ),
    );
    await _removeAbandonedImports();
  }

  Future<SourceImage> ownSource(
    String inputPath,
    String name,
    Inspection inspection,
  ) async {
    final id = const Uuid().v4();
    final sourcePath = p.join(root.path, 'sources', '$id.img');
    final thumbPath = p.join(root.path, 'thumbnails', '$id.png');
    try {
      await File(inputPath).copy(sourcePath);
      await File(thumbPath).writeAsBytes(inspection.thumbnail, flush: true);
      return SourceImage(
        id: id,
        name: name,
        path: sourcePath,
        thumbnailPath: thumbPath,
        width: inspection.width,
        height: inspection.height,
      );
    } catch (_) {
      if (await File(sourcePath).exists()) await File(sourcePath).delete();
      if (await File(thumbPath).exists()) await File(thumbPath).delete();
      rethrow;
    }
  }

  Future<void> put(Creation c) async {
    await db.insert('creations', {
      'id': c.id,
      'name': c.name,
      'createdAt': c.createdAt.toUtc().toIso8601String(),
      'source': p.basename(c.source.path),
      'thumbnail': p.basename(c.source.thumbnailPath),
      'sourceId': c.source.id,
      'sourceName': c.source.name,
      'sourceWidth': c.source.width,
      'sourceHeight': c.source.height,
      'text': c.output.text,
      'columns': c.output.columns,
      'rows': c.output.rows,
      'imageWidth': c.output.sourceWidth,
      'imageHeight': c.output.sourceHeight,
      'characterCount': c.output.characterCount,
      'settings': jsonEncode(c.settings.toJson()),
      'favorite': c.favorite ? 1 : 0,
      'variants': jsonEncode(c.variants.map((v) => v.toJson()).toList()),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Creation _read(Map<String, Object?> j) => Creation(
    id: j['id'] as String,
    name: j['name'] as String,
    createdAt: DateTime.parse(j['createdAt'] as String).toLocal(),
    source: SourceImage(
      id: j['sourceId'] as String,
      name: j['sourceName'] as String,
      path: p.join(root.path, 'sources', j['source'] as String),
      thumbnailPath: p.join(root.path, 'thumbnails', j['thumbnail'] as String),
      width: j['sourceWidth'] as int,
      height: j['sourceHeight'] as int,
    ),
    output: ArtOutput(
      text: j['text'] as String,
      columns: j['columns'] as int,
      rows: j['rows'] as int,
      sourceWidth: j['imageWidth'] as int,
      sourceHeight: j['imageHeight'] as int,
    ),
    settings: ArtSettings.fromJson(jsonDecode(j['settings'] as String)),
    favorite: j['favorite'] == 1,
    variants: (jsonDecode(j['variants'] as String) as List)
        .map((v) => SavedVariant.fromJson(v))
        .toList(),
  );

  Future<List<Creation>> all() async => (await db.query(
    'creations',
    orderBy: 'createdAt DESC',
  )).map(_read).toList();

  Future<void> delete(String id) async {
    final rows = await db.query('creations', where: 'id = ?', whereArgs: [id]);
    await db.delete('creations', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return;
    final sourceId = rows.first['sourceId'];
    final references = await db.query(
      'creations',
      columns: ['id'],
      where: 'sourceId = ?',
      whereArgs: [sourceId],
      limit: 1,
    );
    if (references.isEmpty) {
      for (final file in [
        p.join(root.path, 'sources', rows.first['source'] as String),
        p.join(root.path, 'thumbnails', rows.first['thumbnail'] as String),
      ]) {
        try {
          if (await File(file).exists()) await File(file).delete();
        } on FileSystemException {
          /* Cleanup retries on next startup. */
        }
      }
    }
  }

  Future<void> clear() async {
    for (final c in await all()) {
      await delete(c.id);
    }
  }

  Future<String?> preference(String key) async {
    final r = await db.query('preferences', where: 'key = ?', whereArgs: [key]);
    return r.isEmpty ? null : r.first['value'] as String;
  }

  Future<void> setPreference(String key, String value) => db.insert(
    'preferences',
    {'key': key, 'value': value},
    conflictAlgorithm: ConflictAlgorithm.replace,
  );

  Future<void> _removeAbandonedImports() async {
    final rows = await db.query('creations', columns: ['source', 'thumbnail']);
    final used = rows.expand((r) => [r['source'], r['thumbnail']]).toSet();
    for (final folder in ['sources', 'thumbnails']) {
      await for (final f in Directory(p.join(root.path, folder)).list()) {
        if (f is File &&
            !used.contains(p.basename(f.path)) &&
            DateTime.now().difference((await f.stat()).modified).inHours >=
                24) {
          try {
            await f.delete();
          } on FileSystemException {
            /* Text history remains available. */
          }
        }
      }
    }
  }

  Future<void> close() => db.close();
}
