import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:archive/archive.dart';
import 'package:craft_app/theme/app_theme.dart';
import 'package:craft_app/models/file_item.dart';
import 'package:craft_app/database/app_database.dart';
import 'package:craft_app/services/isolate_service.dart';
import 'package:craft_app/services/pdf_editor_service.dart';
import 'package:craft_app/services/sharing_service.dart';
import 'package:craft_app/widgets/model_viewer_3d.dart';

void main() {
  setUpAll(() {
    AppTheme.useGoogleFonts = false;
    databaseFactory = databaseFactoryFfi;
    AppDatabase.testDirectory = Directory.systemTemp.createTempSync('craft_comp_test_').path;
  });

  // ═══════════════════════════════════════════════════════════════════
  // OBJ PARSER EDGE CASES
  // ═══════════════════════════════════════════════════════════════════

  group('OBJ Parser', () {
    test('parses vertices and faces', () {
      final model = ObjModel.parse('v 0.0 0.0 0.0\nv 1.0 0.0 0.0\nv 0.0 1.0 0.0\nf 1 2 3\n');
      expect(model.vertices.length, 3);
      expect(model.faces.length, 1);
      expect(model.faces[0], [0, 1, 2]);
    });

    test('handles empty data', () {
      final model = ObjModel.parse('');
      expect(model.vertices.length, 0);
      expect(model.faces.length, 0);
    });

    test('handles only whitespace', () {
      final model = ObjModel.parse('   \n  \n  ');
      expect(model.vertices.length, 0);
      expect(model.faces.length, 0);
    });

    test('handles negative coordinates', () {
      final model = ObjModel.parse('v -1.5 -2.5 -3.5\nv 0 0 0\nf 1 2\n');
      expect(model.vertices.length, 2);
      expect(model.vertices[0].x, -1.5);
      expect(model.vertices[0].y, -2.5);
      expect(model.vertices[0].z, -3.5);
    });

    test('parses normals', () {
      final model = ObjModel.parse('v 0 0 0\nv 1 0 0\nv 0 1 0\nvn 0 0 1\nf 1//1 2//1 3//1\n');
      expect(model.vertices.length, 3);
      expect(model.normals.length, 1);
      expect(model.normals[0].z, 1.0);
      expect(model.faces.length, 1);
    });

    test('ignores comment lines', () {
      final model = ObjModel.parse('# this is a comment\nv 0 0 0\n# another comment\nv 1 0 0\n');
      expect(model.vertices.length, 2);
      expect(model.faces.length, 0);
    });

    test('handles tab-separated values', () {
      final model = ObjModel.parse('v\t0\t0\t0\nv\t1\t0\t0\nf\t1\t2\n');
      expect(model.vertices.length, 2);
    });

    test('handles texture coordinate syntax (v1/vt1/vn1)', () {
      final model = ObjModel.parse('v 0 0 0\nv 1 0 0\nv 0 1 0\nf 1/1/1 2/2/1 3/3/1\n');
      expect(model.vertices.length, 3);
      expect(model.faces.length, 1);
      expect(model.faces[0], [0, 1, 2]);
    });

    test('parses quadrilateral face', () {
      final model = ObjModel.parse('v 0 0 0\nv 1 0 0\nv 1 1 0\nv 0 1 0\nf 1 2 3 4\n');
      expect(model.faces.length, 1);
      expect(model.faces[0], [0, 1, 2, 3]);
    });

    test('skips faces referencing non-existent vertices', () {
      final model = ObjModel.parse('v 0 0 0\nf 1 2 3\n');
      expect(model.vertices.length, 1);
      expect(model.faces.length, 0);
    });

    test('handles multiple normals', () {
      final model = ObjModel.parse('v 0 0 0\nv 1 0 0\nv 0 1 0\nvn 0 0 1\nvn 1 0 0\nf 1//1 2//2 3//1\n');
      expect(model.normals.length, 2);
    });

    test('normalize centers and scales', () {
      final model = ObjModel.parse('v 0 0 0\nv 2 0 0\nv 0 2 0\nf 1 2 3\n');
      model.normalize();
      // Center: (0.667, 0.667, 0). MaxDist: 1.491. Scale: 0.671.
      // v0 after normalize: (-0.447, -0.447, 0)
      expect(model.vertices[0].x, closeTo(-0.447, 0.001));
      expect(model.vertices[0].y, closeTo(-0.447, 0.001));
    });

    test('normalize with single vertex does not crash', () {
      final model = ObjModel.parse('v 5 5 5\n');
      model.normalize();
      expect(model.vertices.length, 1);
    });

    test('handles large coordinate values', () {
      final model = ObjModel.parse('v 1e10 2e10 3e10\nv 0 0 0\n');
      expect(model.vertices.length, 2);
    });

    test('handles mixed line endings', () {
      // Parser splits on \n; \r is trimmed from each line
      final model = ObjModel.parse('v 0 0 0\r\nv 1 0 0\r\nv 0 1 0\nf 1 2 3\n');
      expect(model.vertices.length, 3);
      expect(model.faces.length, 1);
    });
  });

  // ═══════════════════════════════════════════════════════════════════
  // STL PARSER EDGE CASES
  // ═══════════════════════════════════════════════════════════════════

  group('STL Parser', () {
    List<int> _buildStl(int triangleCount) {
      final buffer = <int>[];
      buffer.addAll(List.filled(80, 0));
      buffer.addAll([
        triangleCount & 0xFF,
        (triangleCount >> 8) & 0xFF,
        (triangleCount >> 16) & 0xFF,
        (triangleCount >> 24) & 0xFF,
      ]);
      for (int i = 0; i < triangleCount; i++) {
        buffer.addAll(List.filled(12, 0));
        buffer.addAll([0, 0, 0, 0x3F, 0x80, 0, 0, 0x40, 0, 0, 0, 0x40]);
        buffer.addAll([0, 0, 0, 0x3F, 0x80, 0, 0, 0, 0, 0, 0, 0x40]);
        buffer.addAll([0, 0, 0, 0x3F, 0x80, 0, 0, 0x40, 0, 0, 0, 0x40]);
        buffer.addAll([0, 0]);
      }
      return buffer;
    }

    test('handles empty bytes', () {
      final model = StlModel.parse(Uint8List(0));
      expect(model.vertices.length, 0);
      expect(model.faces.length, 0);
    });

    test('handles minimal binary STL with one triangle', () {
      final bytes = Uint8List.fromList(_buildStl(1));
      expect(bytes.length, 134);
      final model = StlModel.parse(bytes);
      expect(model.vertices.length, 3);
      expect(model.faces.length, 1);
    });

    test('handles zero triangles', () {
      final bytes = Uint8List(84);
      final model = StlModel.parse(bytes);
      expect(model.vertices.length, 0);
      expect(model.faces.length, 0);
    });

    test('handles multiple triangles', () {
      final bytes = Uint8List.fromList(_buildStl(5));
      final model = StlModel.parse(bytes);
      expect(model.vertices.length, 15);
      expect(model.faces.length, 5);
    });

    test('handles truncated data gracefully', () {
      final bytes = Uint8List(90);
      final model = StlModel.parse(bytes);
      expect(model.vertices.length, 0);
      expect(model.faces.length, 0);
    });

    test('handles header-only data no triangles', () {
      final bytes = Uint8List(84);
      final model = StlModel.parse(bytes);
      expect(model.vertices.length, 0);
      expect(model.faces.length, 0);
    });

    test('parses actual float values correctly', () {
      final buffer = Uint8List(134);
      buffer[83] = 1; // triangle count = 1 at bytes 80-83
      // STL parser: offset starts at 80, loop: offset += 12 → 92 for vertex 0
      // Normal (offset 80-91): skip (12 bytes)
      // Vertex 0 (offset 92-103): x=1.0, y=2.0, z=3.0
      _writeFloat32(buffer, 92, 1.0);
      _writeFloat32(buffer, 96, 2.0);
      _writeFloat32(buffer, 100, 3.0);
      // Vertex 1 (offset 104-115): x=4.0, y=5.0, z=6.0
      _writeFloat32(buffer, 104, 4.0);
      _writeFloat32(buffer, 108, 5.0);
      _writeFloat32(buffer, 112, 6.0);
      // Vertex 2 (offset 116-127): x=7.0, y=8.0, z=9.0
      _writeFloat32(buffer, 116, 7.0);
      _writeFloat32(buffer, 120, 8.0);
      _writeFloat32(buffer, 124, 9.0);
      final model = StlModel.parse(buffer);
      expect(model.vertices.length, 3);
      expect(model.vertices[0].x, 1.0);
      expect(model.vertices[2].z, 9.0);
    });
  });

  // ═══════════════════════════════════════════════════════════════════
  // PDF EDITOR SERVICE
  // ═══════════════════════════════════════════════════════════════════

  group('PdfEditorService', () {
    late Directory tmpDir;
    late PdfEditorService service;

    setUp(() {
      tmpDir = Directory.systemTemp.createTempSync('craft_pdf_test_');
      service = PdfEditorService();
    });

    tearDown(() {
      tmpDir.deleteSync(recursive: true);
    });

    String _writePdf(String content) {
      final path = '${tmpDir.path}${Platform.pathSeparator}test.pdf';
      File(path).writeAsBytesSync(content.codeUnits);
      return path;
    }

    test('smartRedact returns error for missing file', () async {
      final result = await service.smartRedact('${tmpDir.path}${Platform.pathSeparator}nope.pdf');
      expect(result, startsWith('Error:'));
    });

    test('smartRedact detects email', () async {
      final path = _writePdf('Contact me at john.doe@example.com for details.');
      final result = await service.smartRedact(path);
      expect(result, contains('email'));
      expect(result, contains('Redacted'));
      expect(File(path.replaceAll('.pdf', '_redacted.pdf')).existsSync(), true);
    });

    test('smartRedact detects phone numbers', () async {
      final path = _writePdf('Call 555-123-4567 today!');
      final result = await service.smartRedact(path);
      expect(result, contains('phone'));
    });

    test('smartRedact detects SSN', () async {
      final path = _writePdf('SSN: 123-45-6789');
      final result = await service.smartRedact(path);
      expect(result, contains('ssn'));
    });

    test('smartRedact detects credit card', () async {
      final path = _writePdf('Card: 4111 1111 1111 1111');
      final result = await service.smartRedact(path);
      expect(result, contains('credit_card'));
    });

    test('smartRedact detects API keys', () async {
      final path = _writePdf('sk-123456789012345678901234');
      final result = await service.smartRedact(path);
      expect(result, contains('api_key'));
    });

    test('smartRedact returns no-data message for clean text', () async {
      final path = _writePdf('This document has no sensitive information 123.');
      final result = await service.smartRedact(path);
      expect(result, contains('No sensitive data found'));
    });

    test('smartRedact merges overlapping detections', () async {
      final path = _writePdf('Email: user@domain.com Phone: 555-123-4567');
      final result = await service.smartRedact(path);
      expect(result, contains('Redacted'));
    });

    test('smartRedact detects passwords', () async {
      final path = _writePdf('password=hunter2');
      final result = await service.smartRedact(path);
      expect(result, contains('password'));
    });

    test('smartRedact detects zip codes', () async {
      final path = _writePdf('ZIP: 90210');
      final result = await service.smartRedact(path);
      expect(result, contains('zip_code'));
    });

    test('visualDiff returns error for missing file', () async {
      final result = await service.visualDiff('${tmpDir.path}${Platform.pathSeparator}nope.pdf');
      expect(result, startsWith('Error:'));
    });

    test('visualDiff returns no-previous message when no _previous.pdf exists', () async {
      final path = _writePdf('hello');
      final result = await service.visualDiff(path);
      expect(result, contains('No previous version found'));
    });

    test('visualDiff returns identical for matching files', () async {
      final path = _writePdf('hello world');
      File(path.replaceAll('.pdf', '_previous.pdf')).writeAsBytesSync('hello world'.codeUnits);
      final result = await service.visualDiff(path);
      expect(result, contains('identical'));
    });

    test('visualDiff detects size changes', () async {
      final path = _writePdf('hello world');
      File(path.replaceAll('.pdf', '_previous.pdf')).writeAsBytesSync('hi'.codeUnits);
      final result = await service.visualDiff(path);
      expect(result, contains('Diff complete'));
      expect(result, contains('bytes'));
    });

    test('batchAutoForm returns error for missing file', () async {
      final result = await service.batchAutoForm('${tmpDir.path}${Platform.pathSeparator}nope.pdf');
      expect(result, startsWith('Error:'));
    });

    test('batchAutoForm detects field placeholders', () async {
      final path = _writePdf('Name: _______  Date: [  ]');
      final result = await service.batchAutoForm(path);
      expect(result, contains('field(s)'));
      expect(result, contains('autofilled'));
      expect(File(path.replaceAll('.pdf', '_autofilled.pdf')).existsSync(), true);
    });

    test('batchAutoForm returns no-fields message', () async {
      final path = _writePdf('Just plain text without any fields.');
      final result = await service.batchAutoForm(path);
      expect(result, contains('No form fields detected'));
    });
  });

  // ═══════════════════════════════════════════════════════════════════
  // SHARING SERVICE
  // ═══════════════════════════════════════════════════════════════════

  group('SharingService', () {
    test('generateShareData and parseShareData roundtrip', () async {
      final file = FileItem(name: 'test.pdf', path: '/tmp/test.pdf', extension: 'pdf', size: 1024);
      final data = await SharingService().generateShareData(file);
      expect(data, isNotEmpty);

      final parsed = await SharingService().parseShareData(data);
      expect(parsed, isNotNull);
      expect(parsed!.name, 'test.pdf');
      expect(parsed.extension, 'pdf');
      expect(parsed.size, 1024);
    });

    test('parseShareData returns null for invalid base64', () async {
      final result = await SharingService().parseShareData('not-base64!!!');
      expect(result, isNull);
    });

    test('parseShareData returns null for malformed JSON', () async {
      final data = base64Encode(utf8.encode('not json at all'));
      final result = await SharingService().parseShareData(data);
      expect(result, isNull);
    });

    test('parseShareData returns null for missing name field', () async {
      final data = base64Encode(utf8.encode('{"foo": "bar"}'));
      final result = await SharingService().parseShareData(data);
      expect(result, isNull);
    });
  });

  // ═══════════════════════════════════════════════════════════════════
  // ARCHIVE EXTRACTOR
  // ═══════════════════════════════════════════════════════════════════

  group('Archive Package (ZipDecoder)', () {
    late Directory tmpDir;

    setUp(() {
      tmpDir = Directory.systemTemp.createTempSync('craft_archive_test_');
    });

    tearDown(() {
      if (tmpDir.existsSync()) tmpDir.deleteSync(recursive: true);
    });

    test('ZipDecoder decodes valid ZIP', () {
      final content = 'Hello World'.codeUnits;
      final zipBytes = _buildZipBytes('hello.txt', content);
      final archive = ZipDecoder().decodeBytes(zipBytes);
      expect(archive.length, 1);
      expect(archive.first.name, 'hello.txt');
      expect(archive.first.size, content.length);
    });

    test('ZipDecoder decodes multiple files', () {
      final a = ArchiveFile('a.txt', 1, [65]);
      final b = ArchiveFile('b.txt', 1, [66]);
      final archiveData = Archive()..addFile(a)..addFile(b);
      final zipBytes = ZipEncoder().encode(archiveData)!;
      final decoded = ZipDecoder().decodeBytes(zipBytes);
      expect(decoded.length, 2);
      expect(decoded.any((f) => f.name == 'a.txt'), true);
      expect(decoded.any((f) => f.name == 'b.txt'), true);
    });

    test('ZipDecoder handles empty file', () {
      final zipBytes = _buildZipBytes('empty.txt', []);
      final archive = ZipDecoder().decodeBytes(zipBytes);
      expect(archive.length, 1);
      expect(archive.first.size, 0);
    });

    test('ZipDecoder throws on invalid data', () {
      expect(() => ZipDecoder().decodeBytes([0, 1, 2, 3]), throwsException);
    });
  });

  // ═══════════════════════════════════════════════════════════════════
  // ISOLATE SERVICE EDGE CASES
  // ═══════════════════════════════════════════════════════════════════

  group('IsolateService', () {
    late Directory tmpDir;

    setUp(() {
      tmpDir = Directory.systemTemp.createTempSync('craft_iso_test_');
    });

    tearDown(() {
      tmpDir.deleteSync(recursive: true);
    });

    test('handles non-existent file on read', () async {
      try {
        await IsolateService.instance.readTextFile('${tmpDir.path}${Platform.pathSeparator}nope.txt');
        fail('Should have thrown');
      } catch (_) {}
    });

    test('handles non-existent file on delete', () async {
      try {
        await IsolateService.instance.deleteFile('${tmpDir.path}${Platform.pathSeparator}nope.txt');
        fail('Should have thrown');
      } catch (_) {}
    });

    test('converts text to markdown', () async {
      final src = '${tmpDir.path}${Platform.pathSeparator}test.txt';
      await IsolateService.instance.writeTextFile(src, '# Hello\n\nThis is **bold**');
      await IsolateService.instance.convertFile(
        sourcePath: src, targetFormat: 'md',
        onProgress: (_) {},
      );
      final md = await IsolateService.instance.readTextFile(
        '${tmpDir.path}${Platform.pathSeparator}test.md',
      );
      expect(md, isNotEmpty);
    });

    test('converts text to plain text', () async {
      final src = '${tmpDir.path}${Platform.pathSeparator}test.txt';
      await IsolateService.instance.writeTextFile(src, 'Hello World');
      await IsolateService.instance.convertFile(
        sourcePath: src, targetFormat: 'txt',
        onProgress: (_) {},
      );
      final txt = await IsolateService.instance.readTextFile(
        '${tmpDir.path}${Platform.pathSeparator}test.txt',
      );
      expect(txt, 'Hello World');
    });

    test('copyFile throws for non-existent source', () async {
      try {
        await IsolateService.instance.copyFile(
          '${tmpDir.path}${Platform.pathSeparator}nope.txt',
          '${tmpDir.path}${Platform.pathSeparator}dst.txt',
        );
        fail('Should have thrown');
      } catch (_) {}
    });

    test('listDirectory throws for non-existent path', () async {
      try {
        await IsolateService.instance.listDirectory(
          '${tmpDir.path}${Platform.pathSeparator}nope_dir',
        );
        fail('Should have thrown');
      } catch (_) {}
    });
  });

  // ═══════════════════════════════════════════════════════════════════
  // FILE ITEM EDGE CASES
  // ═══════════════════════════════════════════════════════════════════

  group('FileItem', () {
    test('unknown extensions return false for all known types', () {
      final file = FileItem(name: 'a.xyz', path: '/a.xyz', extension: 'xyz');
      expect(file.isImage, false);
      expect(file.isVideo, false);
      expect(file.isAudio, false);
      expect(file.isDocument, false);
      expect(file.isCode, false);
      expect(file.isArchive, false);
      expect(file.isText, false);
      expect(file.isModel, false);
    });

    test('no extension returns false for known types', () {
      final file = FileItem(name: 'Makefile', path: '/Makefile', extension: '');
      expect(file.isImage, false);
      expect(file.isVideo, false);
    });

    test('size formatting handles zero', () {
      expect(FileItem(name: 'a', path: '/a', extension: 'txt', size: 0).formattedSize, '0 B');
    });

    test('size formatting handles large values', () {
      expect(FileItem(name: 'a', path: '/a', extension: 'txt', size: 3 * 1024 * 1024 * 1024).formattedSize, '3.0 GB');
    });

    test('size formatting handles exact KB', () {
      expect(FileItem(name: 'a', path: '/a', extension: 'txt', size: 2048).formattedSize, '2.0 KB');
    });

    test('file type detection: model', () {
      expect(FileItem(name: 'm.stl', path: '/m.stl', extension: 'stl').isModel, true);
      expect(FileItem(name: 'm.glb', path: '/m.glb', extension: 'glb').isModel, true);
    });

    test('file type detection: document', () {
      expect(FileItem(name: 'd.pdf', path: '/d.pdf', extension: 'pdf').isDocument, true);
      expect(FileItem(name: 'd.docx', path: '/d.docx', extension: 'docx').isDocument, true);
    });

    test('file type detection: code', () {
      expect(FileItem(name: 'c.py', path: '/c.py', extension: 'py').isCode, true);
      expect(FileItem(name: 'c.js', path: '/c.js', extension: 'js').isCode, true);
    });

    test('fromMap derives extension from path when missing', () {
      final map = <String, dynamic>{'name': 'orphan.txt', 'path': '/orphan.txt', 'extension': null};
      final file = FileItem.fromMap(map);
      expect(file.name, 'orphan.txt');
      expect(file.extension, 'txt');
      expect(file.size, 0);
    });

    test('fromMap handles null favorite and tags', () {
      final map = <String, dynamic>{
        'name': 'test.txt', 'path': '/test.txt', 'extension': 'txt',
        'is_favorite': null, 'tags': null,
      };
      final file = FileItem.fromMap(map);
      expect(file.isFavorite, false);
      expect(file.tags, isNull);
    });
  });

  // ═══════════════════════════════════════════════════════════════════
  // DATABASE EDGE CASES
  // ═══════════════════════════════════════════════════════════════════

  group('AppDatabase', () {
    test('getSetting returns null for missing key', () async {
      final val = await AppDatabase.instance.getSetting('nonexistent_key_xyz');
      expect(val, isNull);
    });

    test('getAllFiles returns empty list initially', () async {
      final files = await AppDatabase.instance.getAllFiles();
      expect(files, isA<List>());
    });

    test('insertFile with tags', () async {
      final file = FileItem(name: 'tagged.txt', path: '/tmp/tagged.txt', extension: 'txt', tags: 'important,urgent');
      final id = await AppDatabase.instance.insertFile(file);
      expect(id, greaterThan(0));

      final files = await AppDatabase.instance.getAllFiles();
      final found = files.firstWhere((f) => f.id == id);
      expect(found.tags, 'important,urgent');

      await AppDatabase.instance.deleteFile(id);
    });

    test('favorite only filtering', () async {
      final f1 = FileItem(name: 'fav1.txt', path: '/tmp/fav1.txt', extension: 'txt');
      final f2 = FileItem(name: 'fav2.txt', path: '/tmp/fav2.txt', extension: 'txt');
      final id1 = await AppDatabase.instance.insertFile(f1);
      final id2 = await AppDatabase.instance.insertFile(f2);

      await AppDatabase.instance.toggleFavorite(id1);

      final favs = await AppDatabase.instance.getAllFiles(favorites: true);
      expect(favs.length, 1);
      expect(favs[0].id, id1);

      await AppDatabase.instance.deleteFile(id1);
      await AppDatabase.instance.deleteFile(id2);
    });

    test('recent files order', () async {
      final f1 = FileItem(name: 'recent1.txt', path: '/tmp/recent1.txt', extension: 'txt');
      final id1 = await AppDatabase.instance.insertFile(f1);
      await Future.delayed(const Duration(milliseconds: 10));
      final f2 = FileItem(name: 'recent2.txt', path: '/tmp/recent2.txt', extension: 'txt');
      final id2 = await AppDatabase.instance.insertFile(f2);

      final all = await AppDatabase.instance.getAllFiles();
      expect(all.length, greaterThanOrEqualTo(2));

      await AppDatabase.instance.deleteFile(id1);
      await AppDatabase.instance.deleteFile(id2);
    });

    test('updateFile does not throw', () async {
      final file = FileItem(name: 'update_test.txt', path: '/tmp/update_test.txt', extension: 'txt');
      final id = await AppDatabase.instance.insertFile(file);
      await AppDatabase.instance.updateFile(FileItem(id: id, name: 'renamed.txt', path: '/tmp/renamed.txt', extension: 'txt'));

      final files = await AppDatabase.instance.getAllFiles();
      final updated = files.firstWhere((f) => f.id == id);
      expect(updated.name, 'renamed.txt');

      await AppDatabase.instance.deleteFile(id);
    });

    test('deleteFile with non-existent id does not throw', () async {
      await AppDatabase.instance.deleteFile(9999999);
    });

    test('settings persistence', () async {
      await AppDatabase.instance.setSetting('int_val', '42');
      await AppDatabase.instance.setSetting('bool_val', 'true');
      await AppDatabase.instance.setSetting('string_val', 'hello');

      expect(await AppDatabase.instance.getSetting('int_val'), '42');
      expect(await AppDatabase.instance.getSetting('bool_val'), 'true');
      expect(await AppDatabase.instance.getSetting('string_val'), 'hello');
    });
  });

  // ═══════════════════════════════════════════════════════════════════
  // APP THEME EDGE CASES
  // ═══════════════════════════════════════════════════════════════════

  group('AppTheme', () {
    test('getFileColor handles all document types', () {
      expect(AppTheme.getFileColor('pdf'), isNot(Colors.grey));
      expect(AppTheme.getFileColor('doc'), isNot(Colors.grey));
      expect(AppTheme.getFileColor('docx'), isNot(Colors.grey));
      expect(AppTheme.getFileColor('xls'), isNot(Colors.grey));
      expect(AppTheme.getFileColor('ppt'), isNot(Colors.grey));
    });

    test('getFileColor handles all code types', () {
      expect(AppTheme.getFileColor('dart'), isNot(Colors.grey));
      expect(AppTheme.getFileColor('js'), isNot(Colors.grey));
      expect(AppTheme.getFileColor('py'), isNot(Colors.grey));
      expect(AppTheme.getFileColor('html'), isNot(Colors.grey));
      expect(AppTheme.getFileColor('css'), isNot(Colors.grey));
    });

    test('getFileColor handles all archive types', () {
      expect(AppTheme.getFileColor('zip'), isNot(Colors.grey));
      expect(AppTheme.getFileColor('rar'), isNot(Colors.grey));
      expect(AppTheme.getFileColor('tar'), isNot(Colors.grey));
      expect(AppTheme.getFileColor('gz'), isNot(Colors.grey));
    });

    test('getFileColor returns grey for unknown types', () {
      expect(AppTheme.getFileColor('obj'), Colors.grey);
      expect(AppTheme.getFileColor('xyz'), Colors.grey);
    });

    test('getFileColor is case insensitive', () {
      expect(AppTheme.getFileColor('PDF'), AppTheme.getFileColor('pdf'));
      expect(AppTheme.getFileColor('JPG'), AppTheme.getFileColor('jpg'));
    });

    test('getFileIcon handles all category types', () {
      expect(AppTheme.getFileIcon('pdf'), Icons.description);
      expect(AppTheme.getFileIcon('jpg'), Icons.image);
      expect(AppTheme.getFileIcon('mp4'), Icons.videocam);
      expect(AppTheme.getFileIcon('mp3'), Icons.audiotrack);
      expect(AppTheme.getFileIcon('zip'), Icons.folder_zip);
      expect(AppTheme.getFileIcon('dart'), Icons.code);
      expect(AppTheme.getFileIcon('txt'), Icons.text_snippet);
      expect(AppTheme.getFileIcon('ttf'), Icons.font_download);
    });

    test('getFileIcon returns insert_drive_file for unknown', () {
      expect(AppTheme.getFileIcon('xyz123'), Icons.insert_drive_file);
    });
  });
}

/// Helper: write a float32 into a byte list at the given offset (little-endian)
void _writeFloat32(List<int> buffer, int offset, double value) {
  final bytes = ByteData(4)..setFloat32(0, value, Endian.little);
  for (int i = 0; i < 4; i++) buffer[offset + i] = bytes.getUint8(i);
}

/// Helper: create ZIP bytes using the archive package's ZipEncoder
List<int> _buildZipBytes(String name, List<int> content) {
  final archive = Archive();
  archive.addFile(ArchiveFile(name, content.length, content));
  return ZipEncoder().encode(archive)!;
}


