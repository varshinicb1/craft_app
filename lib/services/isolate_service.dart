import 'dart:io';
import 'dart:isolate';
import 'dart:convert';
import 'dart:typed_data';
import 'package:image/image.dart' as img;

class IsolateService {
  IsolateService._();
  static final IsolateService instance = IsolateService._();

  Future<String> readTextFile(String filePath) async {
    return await Isolate.run(() {
      final file = File(filePath);
      return file.readAsStringSync();
    });
  }

  Future<void> writeTextFile(String filePath, String content) async {
    await Isolate.run(() {
      final file = File(filePath);
      file.writeAsStringSync(content);
    });
  }

  Future<Uint8List> readFileBytes(String filePath) async {
    return await Isolate.run(() {
      final file = File(filePath);
      return file.readAsBytesSync();
    });
  }

  Future<void> writeFileBytes(String filePath, Uint8List bytes) async {
    await Isolate.run(() {
      final file = File(filePath);
      file.writeAsBytesSync(bytes);
    });
  }

  Future<List<FileSystemEntity>> listDirectory(String dirPath) async {
    return await Isolate.run(() {
      final dir = Directory(dirPath);
      return dir.listSync();
    });
  }

  Future<int> copyFile(String source, String destination) async {
    return await Isolate.run(() {
      final src = File(source);
      return src.copySync(destination).lengthSync();
    });
  }

  Future<void> deleteFile(String path) async {
    await Isolate.run(() {
      final file = File(path);
      if (file.existsSync()) file.deleteSync();
    });
  }

  Future<void> convertImage({
    required String sourcePath,
    required String targetFormat,
    required Function(double) onProgress,
  }) async {
    await Isolate.run(() {
      final source = File(sourcePath);
      final bytes = source.readAsBytesSync();
      final image = img.decodeImage(bytes);
      if (image == null) throw Exception('Failed to decode image');

      List<int> output;
      switch (targetFormat) {
        case 'png':
          output = img.encodePng(image);
          break;
        case 'jpg':
        case 'jpeg':
          output = img.encodeJpg(image);
          break;
        case 'webp':
          throw Exception('WebP encoding not supported by the image package');

        case 'bmp':
          output = img.encodeBmp(image);
          break;
        default:
          throw Exception('Unsupported image format: $targetFormat');
      }

      final basename = sourcePath.split(Platform.pathSeparator).last;
      final nameWithoutExt = basename.contains('.')
          ? basename.substring(0, basename.lastIndexOf('.'))
          : basename;
      final dir = sourcePath.substring(0, sourcePath.lastIndexOf(Platform.pathSeparator));
      final outputPath = '$dir${Platform.pathSeparator}$nameWithoutExt.$targetFormat';
      File(outputPath).writeAsBytesSync(output);
    });
    onProgress(1.0);
  }

  Future<String> getFileHash(String filePath) async {
    return await Isolate.run(() {
      final file = File(filePath);
      final bytes = file.readAsBytesSync();
      final hash = bytes.fold<int>(0, (h, b) => h * 31 + b);
      return hash.toRadixString(16);
    });
  }

  Future<void> convertFile({
    required String sourcePath,
    required String targetFormat,
    required Function(double) onProgress,
  }) async {
    final source = File(sourcePath);
    final bytes = source.readAsBytesSync();
    final basename = sourcePath.split(Platform.pathSeparator).last;
    final nameWithoutExt = basename.contains('.')
        ? basename.substring(0, basename.lastIndexOf('.'))
        : basename;
    final dir = sourcePath.substring(0, sourcePath.lastIndexOf(Platform.pathSeparator));
    final outputPath = '$dir${Platform.pathSeparator}$nameWithoutExt.$targetFormat';

    final targetFile = File(outputPath);
    if (targetFormat == 'txt' || targetFormat == 'md' || targetFormat == 'html') {
      String content;
      try {
        content = utf8.decode(bytes);
      } catch (_) {
        content = 'Binary file content (${bytes.length} bytes)';
      }

      if (targetFormat == 'html') {
        final escaped = content
            .replaceAll('&', '&amp;')
            .replaceAll('<', '&lt;')
            .replaceAll('>', '&gt;')
            .replaceAll('"', '&quot;');
        content = '<!DOCTYPE html>\n<html>\n<head><meta charset="UTF-8">'
            '<title>$nameWithoutExt</title></head>\n<body>\n'
            '<pre>$escaped</pre>\n</body>\n</html>';
      } else if (targetFormat == 'md') {
        content = '# $nameWithoutExt\n\n```\n$content\n```';
      }
      targetFile.writeAsStringSync(content);
    } else {
      targetFile.writeAsBytesSync(bytes);
    }
    onProgress(1.0);
  }

  Future<void> batchProcessFiles({
    required List<String> filePaths,
    required Function(String) processor,
    required Function(double) onProgress,
  }) async {
    for (var i = 0; i < filePaths.length; i++) {
      processor(filePaths[i]);
      onProgress((i + 1) / filePaths.length);
    }
  }
}
