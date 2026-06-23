import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:meta/meta.dart';

class AppTheme {
  AppTheme._();

  /// Set to false in tests to skip Google Fonts loading.
  @visibleForTesting
  static bool useGoogleFonts = true;

  static const Color _primaryLight = Color(0xFF6C63FF);
  static const Color _primaryDark = Color(0xFF7C73FF);
  static const Color _secondaryLight = Color(0xFF00D9A6);
  static const Color _secondaryDark = Color(0xFF00E6B0);
  static const Color _surfaceLight = Color(0xFFF8F9FE);
  static const Color _surfaceDark = Color(0xFF1A1A2E);
  static const Color _errorLight = Color(0xFFE53935);
  static const Color _errorDark = Color(0xFFEF5350);

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: const ColorScheme.light(
        primary: _primaryLight,
        secondary: _secondaryLight,
        surface: _surfaceLight,
        error: _errorLight,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: Color(0xFF1A1A2E),
      ),
      textTheme: _buildTextTheme(Brightness.light),
      appBarTheme: const AppBarTheme(
        elevation: 0,
        centerTitle: true,
        scrolledUnderElevation: 1,
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        clipBehavior: Clip.antiAlias,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _surfaceLight,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _primaryLight, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        elevation: 4,
        shape: CircleBorder(),
      ),
      dividerTheme: DividerThemeData(
        space: 1,
        thickness: 1,
        color: Colors.grey.withValues(alpha: 0.2),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: _primaryDark,
        secondary: _secondaryDark,
        surface: _surfaceDark,
        error: _errorDark,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: Color(0xFFE8E8F0),
      ),
      textTheme: _buildTextTheme(Brightness.dark),
      appBarTheme: const AppBarTheme(
        elevation: 0,
        centerTitle: true,
        scrolledUnderElevation: 1,
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        clipBehavior: Clip.antiAlias,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _surfaceDark,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _primaryDark, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        elevation: 4,
        shape: CircleBorder(),
      ),
      dividerTheme: DividerThemeData(
        space: 1,
        thickness: 1,
        color: Colors.white.withValues(alpha: 0.1),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  static TextTheme _buildTextTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final baseColor = isDark ? const Color(0xFFE8E8F0) : const Color(0xFF1A1A2E);
    final base = TextTheme(
      displayLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.w700, color: baseColor, letterSpacing: -1),
      displayMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: baseColor, letterSpacing: -0.5),
      displaySmall: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: baseColor),
      headlineLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: baseColor),
      headlineMedium: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: baseColor),
      headlineSmall: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: baseColor),
      titleLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: baseColor),
      titleMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: baseColor),
      titleSmall: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: baseColor),
      bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w400, color: baseColor),
      bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: baseColor),
      bodySmall: TextStyle(fontSize: 12, fontWeight: FontWeight.w400, color: baseColor),
      labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: baseColor),
      labelMedium: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: baseColor),
      labelSmall: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: baseColor),
    );
    if (useGoogleFonts) {
      try {
        return GoogleFonts.interTextTheme(base);
      } catch (_) {}
    }
    return base;
  }

  static const List<Color> gradientColors = [
    Color(0xFF6C63FF),
    Color(0xFF00D9A6),
    Color(0xFFFF6B6B),
    Color(0xFFFFD93D),
    Color(0xFF6C63FF),
  ];

  static const Map<String, Color> fileTypeColors = {
    'pdf': Color(0xFFFF5252),
    'doc': Color(0xFF448AFF),
    'docx': Color(0xFF448AFF),
    'xls': Color(0xFF4CAF50),
    'xlsx': Color(0xFF4CAF50),
    'ppt': Color(0xFFFF7043),
    'pptx': Color(0xFFFF7043),
    'txt': Color(0xFF78909C),
    'csv': Color(0xFF66BB6A),
    'json': Color(0xFFFFCA28),
    'xml': Color(0xFFFF7043),
    'html': Color(0xFFE53935),
    'css': Color(0xFF42A5F5),
    'js': Color(0xFFFFCA28),
    'dart': Color(0xFF0175C2),
    'py': Color(0xFF37474F),
    'java': Color(0xFFB71C1C),
    'cpp': Color(0xFF00549D),
    'h': Color(0xFF00549D),
    'swift': Color(0xFFFF3E00),
    'kt': Color(0xFF7F52FF),
    'go': Color(0xFF00ADD8),
    'rs': Color(0xFFDEA584),
    'yaml': Color(0xFF6C63FF),
    'md': Color(0xFF42A5F5),
    'zip': Color(0xFFFFB74D),
    'rar': Color(0xFFFFB74D),
    '7z': Color(0xFFFFB74D),
    'tar': Color(0xFFFFB74D),
    'gz': Color(0xFFFFB74D),
    'png': Color(0xFFAB47BC),
    'jpg': Color(0xFFAB47BC),
    'jpeg': Color(0xFFAB47BC),
    'gif': Color(0xFFAB47BC),
    'svg': Color(0xFFAB47BC),
    'webp': Color(0xFFAB47BC),
    'ico': Color(0xFFAB47BC),
    'mp4': Color(0xFFE53935),
    'avi': Color(0xFFE53935),
    'mkv': Color(0xFFE53935),
    'mov': Color(0xFFE53935),
    'wmv': Color(0xFFE53935),
    'flv': Color(0xFFE53935),
    'mp3': Color(0xFF1E88E5),
    'wav': Color(0xFF1E88E5),
    'flac': Color(0xFF1E88E5),
    'aac': Color(0xFF1E88E5),
    'ogg': Color(0xFF1E88E5),
    'wma': Color(0xFF1E88E5),
    'exe': Color(0xFF546E7A),
    'apk': Color(0xFF4CAF50),
    'dmg': Color(0xFF546E7A),
    'iso': Color(0xFF546E7A),
    'ttf': Color(0xFF6C63FF),
    'otf': Color(0xFF6C63FF),
    'woff': Color(0xFF6C63FF),
    'woff2': Color(0xFF6C63FF),
  };

  static Color getFileColor(String ext) {
    final key = ext.toLowerCase().replaceAll('.', '');
    return fileTypeColors[key] ?? Colors.grey;
  }

  static IconData getFileIcon(String ext) {
    final e = ext.toLowerCase().replaceAll('.', '');
    final textTypes = {'txt', 'md', 'csv', 'log', 'ini', 'cfg', 'conf'};
    final codeTypes = {'dart', 'py', 'js', 'ts', 'java', 'cpp', 'h', 'c', 'cs', 'rb', 'go', 'rs', 'swift', 'kt', 'scala', 'php', 'pl', 'lua', 'r', 'm', 'sql'};
    final webTypes = {'html', 'css', 'scss', 'sass', 'less', 'xml', 'yaml', 'yml', 'toml', 'json'};
    final docTypes = {'pdf', 'doc', 'docx', 'ppt', 'pptx', 'xls', 'xlsx', 'odt', 'ods', 'odp'};
    final imageTypes = {'png', 'jpg', 'jpeg', 'gif', 'svg', 'webp', 'bmp', 'ico', 'tiff', 'tif', 'psd', 'ai'};
    final videoTypes = {'mp4', 'avi', 'mkv', 'mov', 'wmv', 'flv', 'webm', 'm4v', 'mpg', 'mpeg'};
    final audioTypes = {'mp3', 'wav', 'flac', 'aac', 'ogg', 'wma', 'm4a', 'opus', 'amr'};
    final archiveTypes = {'zip', 'rar', '7z', 'tar', 'gz', 'bz2', 'xz', 'z', 'iso'};
    final fontTypes = {'ttf', 'otf', 'woff', 'woff2', 'eot'};

    if (textTypes.contains(e)) return Icons.text_snippet;
    if (codeTypes.contains(e)) return Icons.code;
    if (webTypes.contains(e)) return Icons.web;
    if (docTypes.contains(e)) return Icons.description;
    if (imageTypes.contains(e)) return Icons.image;
    if (videoTypes.contains(e)) return Icons.videocam;
    if (audioTypes.contains(e)) return Icons.audiotrack;
    if (archiveTypes.contains(e)) return Icons.folder_zip;
    if (fontTypes.contains(e)) return Icons.font_download;
    return Icons.insert_drive_file;
  }
}
