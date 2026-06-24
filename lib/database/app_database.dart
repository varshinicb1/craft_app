import 'dart:isolate';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../models/file_item.dart';

class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();

  static Database? _database;

  @visibleForTesting
  static String? testDirectory;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dir = testDirectory ?? (await getApplicationDocumentsDirectory()).path;
    final dbPath = p.join(dir, 'craft_app.db');
    return await openDatabase(
      dbPath,
      version: 2,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      singleInstance: true,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE files (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        path TEXT NOT NULL UNIQUE,
        extension TEXT NOT NULL DEFAULT '',
        category TEXT NOT NULL DEFAULT 'unknown',
        size INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        modified_at TEXT NOT NULL,
        is_favorite INTEGER NOT NULL DEFAULT 0,
        tags TEXT,
        notes TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE recent_files (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        file_id INTEGER NOT NULL,
        opened_at TEXT NOT NULL,
        FOREIGN KEY (file_id) REFERENCES files(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE file_tags (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        color TEXT NOT NULL DEFAULT '#6C63FF'
      )
    ''');

    await db.execute('''
      CREATE TABLE conversions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        source_file_id INTEGER,
        target_format TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'pending',
        created_at TEXT NOT NULL,
        completed_at TEXT,
        output_path TEXT,
        FOREIGN KEY (source_file_id) REFERENCES files(id) ON DELETE SET NULL
      )
    ''');

    // Default settings
    await db.insert('settings', {'key': 'theme_mode', 'value': 'system'});
    await db.insert('settings', {'key': 'auto_save', 'value': 'true'});
    await db.insert('settings', {'key': 'recent_files_limit', 'value': '20'});
    await db.insert('settings', {'key': 'default_export_format', 'value': 'pdf'});
    await db.insert('settings', {'key': 'compression_quality', 'value': 'high'});
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS conversions (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          source_file_id INTEGER,
          target_format TEXT NOT NULL,
          status TEXT NOT NULL DEFAULT 'pending',
          created_at TEXT NOT NULL,
          completed_at TEXT,
          output_path TEXT,
          FOREIGN KEY (source_file_id) REFERENCES files(id) ON DELETE SET NULL
        )
      ''');
    }
  }

  // ---- File CRUD ----

  Future<int> insertFile(FileItem file) async {
    final db = await database;
    return await db.insert('files', file.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<int> updateFile(FileItem file) async {
    final db = await database;
    return await db.update('files', file.toMap(),
        where: 'id = ?', whereArgs: [file.id]);
  }

  Future<int> deleteFile(int id) async {
    final db = await database;
    return await db.delete('files', where: 'id = ?', whereArgs: [id]);
  }

  Future<FileItem?> getFile(int id) async {
    final db = await database;
    final maps = await db.query('files', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return FileItem.fromMap(maps.first);
  }

  Future<FileItem?> getFileByPath(String path) async {
    final db = await database;
    final maps = await db.query('files', where: 'path = ?', whereArgs: [path]);
    if (maps.isEmpty) return null;
    return FileItem.fromMap(maps.first);
  }

  Future<List<FileItem>> getAllFiles({String? category, bool? favorites, String? searchQuery}) async {
    final db = await database;
    final where = <String>[];
    final args = <dynamic>[];

    if (category != null && category != 'all') {
      where.add('category = ?');
      args.add(category);
    }
    if (favorites == true) {
      where.add('is_favorite = 1');
    }
    if (searchQuery != null && searchQuery.isNotEmpty) {
      where.add('name LIKE ?');
      args.add('%$searchQuery%');
    }

    final whereStr = where.isNotEmpty ? 'WHERE ${where.join(' AND ')}' : '';
    final maps = await db.rawQuery('SELECT * FROM files $whereStr ORDER BY modified_at DESC');
    return maps.map((m) => FileItem.fromMap(m)).toList();
  }

  Future<List<FileItem>> getRecentFiles({int limit = 10}) async {
    final db = await database;
    final maps = await db.rawQuery('''
      SELECT f.* FROM files f
      INNER JOIN recent_files r ON f.id = r.file_id
      GROUP BY f.id
      ORDER BY MAX(r.opened_at) DESC
      LIMIT ?
    ''', [limit]);
    return maps.map((m) => FileItem.fromMap(m)).toList();
  }

  Future<void> addRecentFile(int fileId) async {
    final db = await database;
    await db.insert('recent_files', {
      'file_id': fileId,
      'opened_at': DateTime.now().toIso8601String(),
    });

    // Keep only the most recent entries
    await db.rawDelete('''
      DELETE FROM recent_files WHERE id NOT IN (
        SELECT id FROM recent_files ORDER BY opened_at DESC LIMIT 50
      )
    ''');
  }

  Future<void> toggleFavorite(int id) async {
    final db = await database;
    await db.rawUpdate(
      'UPDATE files SET is_favorite = CASE WHEN is_favorite = 1 THEN 0 ELSE 1 END WHERE id = ?',
      [id],
    );
  }

  // ---- Settings ----

  Future<String?> getSetting(String key) async {
    final db = await database;
    final maps = await db.query('settings', where: 'key = ?', whereArgs: [key]);
    if (maps.isEmpty) return null;
    return maps.first['value'] as String?;
  }

  Future<void> setSetting(String key, String value) async {
    final db = await database;
    await db.insert('settings', {'key': key, 'value': value},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Map<String, String>> getAllSettings() async {
    final db = await database;
    final maps = await db.query('settings');
    return {for (var m in maps) m['key'] as String: m['value'] as String};
  }

  // ---- Statistics ----

  Future<int> getFileCount({String? category}) async {
    final db = await database;
    final where = category != null ? 'WHERE category = ?' : '';
    final args = category != null ? [category] : [];
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM files $where', args);
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<int> getTotalSize() async {
    final db = await database;
    final result = await db.rawQuery('SELECT SUM(size) as total FROM files');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<Map<String, int>> getCategoryCounts() async {
    final db = await database;
    final maps = await db.rawQuery(
      'SELECT category, COUNT(*) as count FROM files GROUP BY category',
    );
    return {for (var m in maps) m['category'] as String: m['count'] as int};
  }

  // ---- Bulk Operations ----

  Future<void> insertFiles(List<FileItem> files) async {
    final db = await database;
    final batch = db.batch();
    for (final file in files) {
      batch.insert('files', file.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<int> deleteFiles(List<int> ids) async {
    final db = await database;
    return await db.delete(
      'files',
      where: 'id IN (${ids.map((_) => '?').join(',')})',
      whereArgs: ids,
    );
  }

  Future<void> clearAllFiles() async {
    final db = await database;
    await db.delete('files');
    await db.delete('recent_files');
  }

  // ---- Tags ----

  Future<List<Map<String, dynamic>>> getAllTags() async {
    final db = await database;
    return await db.query('file_tags', orderBy: 'name ASC');
  }

  Future<int> addTag(String name, {String color = '#6C63FF'}) async {
    final db = await database;
    return await db.insert('file_tags', {'name': name, 'color': color});
  }

  Future<int> deleteTag(int id) async {
    final db = await database;
    return await db.delete('file_tags', where: 'id = ?', whereArgs: [id]);
  }

  // ---- Conversions ----

  Future<int> insertConversion(Map<String, dynamic> conversion) async {
    final db = await database;
    return await db.insert('conversions', conversion);
  }

  Future<void> updateConversionStatus(int id, String status, {String? outputPath}) async {
    final db = await database;
    final values = <String, dynamic>{
      'status': status,
      'completed_at': DateTime.now().toIso8601String(),
    };
    if (outputPath != null) values['output_path'] = outputPath;
    await db.update('conversions', values, where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Map<String, dynamic>>> getConversionHistory({int limit = 20}) async {
    final db = await database;
    return await db.rawQuery('''
      SELECT c.*, f.name as source_name
      FROM conversions c
      LEFT JOIN files f ON c.source_file_id = f.id
      ORDER BY c.created_at DESC
      LIMIT ?
    ''', [limit]);
  }

  // ---- Isolate Operations ----

  static Future<void> insertFilesInIsolate(List<Map<String, dynamic>> fileMaps) async {
    final dbPath = await _getDbPath();
    await Isolate.run(() async {
      final db = await openDatabase(dbPath);
      final batch = db.batch();
      for (final map in fileMaps) {
        batch.insert('files', map,
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await batch.commit(noResult: true);
      await db.close();
    });
  }

  static Future<String> _getDbPath() async {
    final dir = await getApplicationDocumentsDirectory();
    return p.join(dir.path, 'craft_app.db');
  }

  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }
}
