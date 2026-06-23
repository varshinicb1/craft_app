import 'package:flutter/services.dart';

/// Bridge to Android PdfBox-native PDF operations via MethodChannel.
class PdfNativeService {
  PdfNativeService._();
  static final PdfNativeService instance = PdfNativeService._();

  static const _channel = MethodChannel('com.craftapp/pdf_native');

  // ─── PDF Management ─────────────────────────────────────────────────

  /// Merge multiple PDFs into one.
  Future<String> mergePdfs({
    required List<String> paths,
    required String outputPath,
  }) async {
    return await _channel.invokeMethod('mergePdfs', {
      'paths': paths,
      'outputPath': outputPath,
    });
  }

  /// Split PDF by page ranges. Without ranges, split every page.
  Future<List<String>> splitPdf({
    required String path,
    required String outputDir,
    List<List<int>>? ranges,
  }) async {
    final result = await _channel.invokeMethod('splitPdf', {
      'path': path,
      'outputDir': outputDir,
      if (ranges != null) 'ranges': ranges,
    });
    return List<String>.from(result as List);
  }

  /// Compress PDF by reducing image DPI (quality: 1-100).
  Future<String> compressPdf({
    required String path,
    int quality = 75,
  }) async {
    return await _channel.invokeMethod('compressPdf', {
      'path': path,
      'quality': quality,
    });
  }

  /// Encrypt PDF with password (AES-256).
  Future<String> encryptPdf({
    required String path,
    required String password,
  }) async {
    return await _channel.invokeMethod('encryptPdf', {
      'path': path,
      'password': password,
    });
  }

  /// Decrypt PDF with password.
  Future<String> decryptPdf({
    required String path,
    required String password,
  }) async {
    return await _channel.invokeMethod('decryptPdf', {
      'path': path,
      'password': password,
    });
  }

  /// Extract all text from PDF.
  Future<String> extractText(String path) async {
    return await _channel.invokeMethod('extractText', {'path': path});
  }

  /// Render PDF pages to image files.
  Future<List<String>> pdfToImages({
    required String path,
    required String outputDir,
    String format = 'png',
    int dpi = 150,
  }) async {
    final result = await _channel.invokeMethod('pdfToImages', {
      'path': path,
      'outputDir': outputDir,
      'format': format,
      'dpi': dpi,
    });
    return List<String>.from(result as List);
  }

  /// Create a PDF from a list of image files.
  Future<String> imagesToPdf({
    required List<String> imagePaths,
    required String outputPath,
  }) async {
    return await _channel.invokeMethod('imagesToPdf', {
      'imagePaths': imagePaths,
      'outputPath': outputPath,
    });
  }

  /// Rotate pages (rotation: 90, 180, 270). null = all pages.
  Future<String> rotatePages({
    required String path,
    int rotation = 90,
    List<int>? pages,
  }) async {
    return await _channel.invokeMethod('rotatePages', {
      'path': path,
      'rotation': rotation,
      if (pages != null) 'pages': pages,
    });
  }

  /// Delete specific pages from PDF.
  Future<String> deletePages({
    required String path,
    required List<int> pages,
  }) async {
    return await _channel.invokeMethod('deletePages', {
      'path': path,
      'pages': pages,
    });
  }

  /// Reorder pages in PDF (list of page numbers, 1-based).
  Future<String> reorderPages({
    required String path,
    required List<int> newOrder,
  }) async {
    return await _channel.invokeMethod('reorderPages', {
      'path': path,
      'newOrder': newOrder,
    });
  }

  /// Extract specific pages into a new PDF.
  Future<String> extractPages({
    required String path,
    required List<int> pages,
  }) async {
    return await _channel.invokeMethod('extractPages', {
      'path': path,
      'pages': pages,
    });
  }

  /// Add text watermark to every page.
  Future<String> addWatermark({
    required String path,
    required String text,
    double opacity = 0.3,
  }) async {
    return await _channel.invokeMethod('addWatermark', {
      'path': path,
      'text': text,
      'opacity': opacity,
    });
  }

  /// Flatten PDF (make form fields permanent).
  Future<String> flattenPdf(String path) async {
    return await _channel.invokeMethod('flattenPdf', {'path': path});
  }

  /// Get page count.
  Future<int> getPageCount(String path) async {
    return (await _channel.invokeMethod('getPageCount', {'path': path})) as int;
  }

  /// Get PDF metadata.
  Future<Map<String, dynamic>> getPdfInfo(String path) async {
    final result = await _channel.invokeMethod('getPdfInfo', {'path': path});
    return Map<String, dynamic>.from(result as Map);
  }

  /// Encrypt any file with AES-256 (Android Keystore).
  Future<String> encryptFile(String path) async {
    return await _channel.invokeMethod('encryptFile', {'path': path});
  }

  /// Decrypt a .enc file back to original.
  Future<String> decryptFile(String path) async {
    return await _channel.invokeMethod('decryptFile', {'path': path});
  }
}
