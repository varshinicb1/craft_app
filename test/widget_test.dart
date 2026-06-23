import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:craft_app/theme/app_theme.dart';
import 'package:craft_app/models/file_item.dart';
import 'package:craft_app/database/app_database.dart';
import 'package:craft_app/services/isolate_service.dart';
import 'package:craft_app/widgets/bottom_nav.dart';
import 'package:craft_app/widgets/model_viewer_3d.dart';

void main() {
  setUpAll(() {
    AppTheme.useGoogleFonts = false;
    databaseFactory = databaseFactoryFfi;
    AppDatabase.testDirectory = Directory.systemTemp.createTempSync('craft_db_test_').path;
  });

  // ─── THEME TESTS ────────────────────────────────────────────────

  test('App theme creates successfully', () {
    final theme = AppTheme.lightTheme;
    expect(theme.useMaterial3, true);
    expect(theme.brightness, Brightness.light);
    final darkTheme = AppTheme.darkTheme;
    expect(darkTheme.brightness, Brightness.dark);
  });

  test('AppTheme returns correct file colors', () {
    expect(AppTheme.getFileColor('pdf'), isNotNull);
    expect(AppTheme.getFileColor('jpg'), isNotNull);
    expect(AppTheme.getFileColor('mp4'), isNotNull);
    expect(AppTheme.getFileColor('unknown_xyz'), Colors.grey);
  });

  test('AppTheme returns correct file icons', () {
    expect(AppTheme.getFileIcon('pdf'), Icons.description);
    expect(AppTheme.getFileIcon('png'), Icons.image);
    expect(AppTheme.getFileIcon('mp4'), Icons.videocam);
    expect(AppTheme.getFileIcon('zip'), Icons.folder_zip);
  });

  // ─── FILE ITEM TESTS ────────────────────────────────────────────

  test('FileItem creation works', () {
    final file = FileItem(name: 'test.txt', path: '/tmp/test.txt', extension: 'txt');
    expect(file.name, 'test.txt');
    expect(file.isText, true);
    expect(file.formattedSize, '0 B');
  });

  test('FileItem.fromMap and toMap roundtrip', () {
    final original = FileItem(
      name: 'doc.pdf', path: '/tmp/doc.pdf', extension: 'pdf',
      size: 1024, isFavorite: true, tags: 'work,important',
    );
    final map = original.toMap();
    final restored = FileItem.fromMap(map);
    expect(restored.name, original.name);
    expect(restored.path, original.path);
    expect(restored.isFavorite, original.isFavorite);
    expect(restored.tags, original.tags);
  });

  test('File extension categorization', () {
    expect(FileItem(name: 'a.png', path: '/a.png', extension: 'png').isImage, true);
    expect(FileItem(name: 'b.mp4', path: '/b.mp4', extension: 'mp4').isVideo, true);
    expect(FileItem(name: 'c.mp3', path: '/c.mp3', extension: 'mp3').isAudio, true);
    expect(FileItem(name: 'd.pdf', path: '/d.pdf', extension: 'pdf').isDocument, true);
    expect(FileItem(name: 'e.zip', path: '/e.zip', extension: 'zip').isArchive, true);
    expect(FileItem(name: 'f.dart', path: '/f.dart', extension: 'dart').isCode, true);
    expect(FileItem(name: 'g.obj', path: '/g.obj', extension: 'obj').isModel, true);
    expect(FileItem(name: 'h.txt', path: '/h.txt', extension: 'txt').isText, true);
  });

  test('FileItem formatted size works', () {
    expect(FileItem(name: 'a', path: '/a', extension: 'txt', size: 500).formattedSize, '500 B');
    expect(FileItem(name: 'b', path: '/b', extension: 'txt', size: 2048).formattedSize, '2.0 KB');
    expect(FileItem(name: 'c', path: '/c', extension: 'txt', size: 1048576).formattedSize, '1.0 MB');
    expect(FileItem(name: 'd', path: '/d', extension: 'txt', size: 1073741824).formattedSize, '1.0 GB');
  });

  test('FileItem formatted date returns non-empty string', () {
    final file = FileItem(name: 'a', path: '/a', extension: 'txt');
    expect(file.formattedDate, isNotEmpty);
  });

  // ─── OBJ PARSER TESTS ──────────────────────────────────────────

  test('OBJ parser parses vertices and faces', () {
    final objData = '''
v 0.0 0.0 0.0
v 1.0 0.0 0.0
v 0.0 1.0 0.0
f 1 2 3
''';
    final model = ObjModel.parse(objData);
    expect(model.vertices.length, 3);
    expect(model.faces.length, 1);
    expect(model.faces[0], [0, 1, 2]);
  });

  test('OBJ parser handles empty data', () {
    final model = ObjModel.parse('');
    expect(model.vertices.length, 0);
    expect(model.faces.length, 0);
  });

  test('OBJ parser handles normals', () {
    final objData = 'v 0 0 0\nv 1 0 0\nv 0 1 0\nvn 0 0 1\nf 1//1 2//1 3//1\n';
    final model = ObjModel.parse(objData);
    expect(model.vertices.length, 3);
    expect(model.normals.length, 1);
    expect(model.faces.length, 1);
  });

  // ─── STL PARSER TESTS ──────────────────────────────────────────

  test('STL parser handles empty bytes', () {
    final model = StlModel.parse(Uint8List(0));
    expect(model.vertices.length, 0);
    expect(model.faces.length, 0);
  });

  test('STL parser handles minimal binary STL', () {
    // 80 byte header + 4 byte count + 1 triangle * 50 bytes = 134 bytes
    final buffer = Uint8List(134);
    buffer[83] = 1;
    final model = StlModel.parse(buffer);
    expect(model.vertices.length, 3);
    expect(model.faces.length, 1);
  });

  // ─── ISOLATE SERVICE TESTS ─────────────────────────────────────

  test('IsolateService singleton works', () {
    final instance = IsolateService.instance;
    expect(IsolateService.instance, same(instance));
  });

  test('IsolateService text read/write roundtrip', () async {
    final dir = Directory.systemTemp.createTempSync('craft_test_');
    final filePath = '${dir.path}${Platform.pathSeparator}test_roundtrip.txt';
    final content = 'Hello CRAFT!';
    await IsolateService.instance.writeTextFile(filePath, content);
    final read = await IsolateService.instance.readTextFile(filePath);
    expect(read, content);
    dir.deleteSync(recursive: true);
  });

  test('IsolateService file bytes read/write', () async {
    final dir = Directory.systemTemp.createTempSync('craft_test_');
    final filePath = '${dir.path}${Platform.pathSeparator}bytes.bin';
    final bytes = Uint8List.fromList([1, 2, 3, 255, 128, 64]);
    await IsolateService.instance.writeFileBytes(filePath, bytes);
    final read = await IsolateService.instance.readFileBytes(filePath);
    expect(read, bytes);
    dir.deleteSync(recursive: true);
  });

  test('IsolateService copy and delete file', () async {
    final dir = Directory.systemTemp.createTempSync('craft_test_');
    final src = '${dir.path}${Platform.pathSeparator}src.txt';
    final dst = '${dir.path}${Platform.pathSeparator}dst.txt';
    await IsolateService.instance.writeTextFile(src, 'copy test');
    final size = await IsolateService.instance.copyFile(src, dst);
    expect(size, 'copy test'.length);
    expect(File(dst).existsSync(), true);
    await IsolateService.instance.deleteFile(src);
    expect(File(src).existsSync(), false);
    dir.deleteSync(recursive: true);
  });

  test('IsolateService list directory', () async {
    final dir = Directory.systemTemp.createTempSync('craft_test_');
    File('${dir.path}${Platform.pathSeparator}a.txt').createSync();
    File('${dir.path}${Platform.pathSeparator}b.txt').createSync();
    final entries = await IsolateService.instance.listDirectory(dir.path);
    expect(entries.length, 2);
    dir.deleteSync(recursive: true);
  });

  test('IsolateService file hash is consistent', () async {
    final dir = Directory.systemTemp.createTempSync('craft_test_');
    final filePath = '${dir.path}${Platform.pathSeparator}hash.txt';
    await IsolateService.instance.writeTextFile(filePath, 'hash me');
    final hash1 = await IsolateService.instance.getFileHash(filePath);
    final hash2 = await IsolateService.instance.getFileHash(filePath);
    expect(hash1, hash2);
    expect(hash1, isNotEmpty);
    dir.deleteSync(recursive: true);
  });

  test('IsolateService text conversion to html escapes HTML', () async {
    final dir = Directory.systemTemp.createTempSync('craft_test_');
    final src = '${dir.path}${Platform.pathSeparator}test.txt';
    await IsolateService.instance.writeTextFile(src, '<hello> & "world"');
    await IsolateService.instance.convertFile(
      sourcePath: src, targetFormat: 'html',
      onProgress: (_) {},
    );
    final htmlPath = '${dir.path}${Platform.pathSeparator}test.html';
    final html = await IsolateService.instance.readTextFile(htmlPath);
    expect(html, contains('&lt;hello&gt;'));
    expect(html, contains('&amp;'));
    dir.deleteSync(recursive: true);
  });

  test('IsolateService image conversion fails on non-image', () async {
    final dir = Directory.systemTemp.createTempSync('craft_test_');
    final src = '${dir.path}${Platform.pathSeparator}not_image.txt';
    await IsolateService.instance.writeTextFile(src, 'not an image');
    try {
      await IsolateService.instance.convertImage(
        sourcePath: src, targetFormat: 'png',
        onProgress: (_) {},
      );
      fail('Should have thrown');
    } catch (_) {}
    dir.deleteSync(recursive: true);
  });

  // ─── DATABASE TESTS ────────────────────────────────────────────

  test('Database singleton works', () {
    expect(AppDatabase.instance, isNotNull);
  });

  test('Database insert and retrieve file', () async {
    final file = FileItem(name: 'db_test.txt', path: '/tmp/db_test.txt', extension: 'txt', size: 100);
    final id = await AppDatabase.instance.insertFile(file);
    expect(id, greaterThan(0));

    final files = await AppDatabase.instance.getAllFiles();
    expect(files.any((f) => f.id == id), true);

    await AppDatabase.instance.deleteFile(id);
    final after = await AppDatabase.instance.getAllFiles();
    expect(after.any((f) => f.id == id), false);
  });

  test('Database toggle favorite', () async {
    final file = FileItem(name: 'fav_test.txt', path: '/tmp/fav_test.txt', extension: 'txt');
    final id = await AppDatabase.instance.insertFile(file);
    expect(id, greaterThan(0));

    await AppDatabase.instance.toggleFavorite(id);
    final favs = await AppDatabase.instance.getAllFiles(favorites: true);
    expect(favs.any((f) => f.id == id), true);

    await AppDatabase.instance.toggleFavorite(id);
    final favs2 = await AppDatabase.instance.getAllFiles(favorites: true);
    expect(favs2.any((f) => f.id == id), false);

    await AppDatabase.instance.deleteFile(id);
  });

  test('Database settings work', () async {
    await AppDatabase.instance.setSetting('theme_mode', 'dark');
    final val = await AppDatabase.instance.getSetting('theme_mode');
    expect(val, 'dark');
  });

  // ─── BOTTOM NAV TESTS ──────────────────────────────────────────

  testWidgets('BottomNav renders 5 tabs', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        bottomNavigationBar: CraftBottomNav(
          currentIndex: 0,
          onTap: (_) {},
        ),
      ),
    ));
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Viewer'), findsOneWidget);
    expect(find.text('Convert'), findsOneWidget);
    expect(find.text('Editor'), findsOneWidget);
    expect(find.text('Share'), findsOneWidget);
  });
}
