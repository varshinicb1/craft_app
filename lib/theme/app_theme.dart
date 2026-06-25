import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  AppTheme._();

  @visibleForTesting
  static bool useGoogleFonts = true;

  // Dark Chocolate Palette
  static const Color _bg = Color(0xFF120A07);
  static const Color _surface = Color(0xFF1E120D);
  static const Color _surfaceVariant = Color(0xFF2A1810);
  static const Color _card = Color(0xFF332115);
  static const Color _cardElevated = Color(0xFF3D2A1C);
  static const Color _primary = Color(0xFFD4A574);
  static const Color _primaryContainer = Color(0xFF4A2C1A);
  static const Color _secondary = Color(0xFFC9A96E);
  static const Color _secondaryContainer = Color(0xFF3D2E18);
  static const Color _error = Color(0xFFCF6679);
  static const Color _errorContainer = Color(0xFF3E1A22);
  static const Color _onSurface = Color(0xFFE8D5C0);
  static const Color _onSurfaceDim = Color(0xFFA08870);
  static const Color _outline = Color(0xFF4A3525);
  static const Color _outlineVariant = Color(0xFF3A2518);
  static const Color _gold = Color(0xFFD4AF37);
  static const Color _cream = Color(0xFFF5E6D3);

  static ThemeData get darkTheme {
    const colorScheme = ColorScheme.dark(
      primary: _primary,
      secondary: _secondary,
      surface: _surface,
      error: _error,
      onPrimary: Color(0xFF1A0A00),
      onSecondary: Color(0xFF1A0A00),
      onSurface: _onSurface,
      onError: Color(0xFF1A0A00),
      primaryContainer: _primaryContainer,
      secondaryContainer: _secondaryContainer,
      errorContainer: _errorContainer,
      outline: _outline,
      outlineVariant: _outlineVariant,
      surfaceContainerHighest: _card,
      surfaceTint: _primary,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: _bg,
      textTheme: _buildTextTheme(),
      appBarTheme: const AppBarTheme(
        elevation: 0,
        centerTitle: true,
        backgroundColor: _bg,
        foregroundColor: _onSurface,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          color: _onSurface,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: _card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: _outline.withAlpha(60)),
        ),
        clipBehavior: Clip.antiAlias,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _surfaceVariant,
        hintStyle: TextStyle(color: _onSurfaceDim.withAlpha(120)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: _outline.withAlpha(80)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: _primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: _error.withAlpha(150)),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        prefixIconColor: _onSurfaceDim,
        suffixIconColor: _onSurfaceDim,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: _primary,
          foregroundColor: const Color(0xFF1A0A00),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: _primary,
          foregroundColor: const Color(0xFF1A0A00),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        elevation: 0,
        backgroundColor: _primary,
        foregroundColor: const Color(0xFF1A0A00),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      dividerTheme: DividerThemeData(
        space: 1,
        thickness: 1,
        color: _outline.withAlpha(80),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: _cardElevated,
        contentTextStyle: const TextStyle(color: _onSurface),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: _outline.withAlpha(60)),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: _surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: _surfaceVariant,
        selectedColor: _primaryContainer,
        labelStyle: const TextStyle(color: _onSurface),
        side: BorderSide(color: _outline.withAlpha(80)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: _cardElevated,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: _outline.withAlpha(60)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: _cardElevated,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return _primary;
          return _onSurfaceDim;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return _primaryContainer;
          return _outline;
        }),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: _primary,
        linearTrackColor: _primary.withAlpha(30),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: _surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: _primary.withAlpha(30),
      ),
      extensions: const [
        AppColors(
          bg: _bg,
          surface: _surface,
          surfaceVariant: _surfaceVariant,
          card: _card,
          cardElevated: _cardElevated,
          primary: _primary,
          primaryContainer: _primaryContainer,
          secondary: _secondary,
          gold: _gold,
          cream: _cream,
          onSurfaceDim: _onSurfaceDim,
          outline: _outline,
          outlineVariant: _outlineVariant,
        ),
      ],
    );
  }

  static TextTheme _buildTextTheme() {
    const baseColor = _onSurface;
    const base = TextTheme(
      displayLarge: TextStyle(fontSize: 36, fontWeight: FontWeight.w700, color: _cream, letterSpacing: -1, height: 1.1),
      displayMedium: TextStyle(fontSize: 30, fontWeight: FontWeight.w700, color: _cream, letterSpacing: -0.5, height: 1.15),
      displaySmall: TextStyle(fontSize: 26, fontWeight: FontWeight.w600, color: baseColor, height: 1.2),
      headlineLarge: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: baseColor, height: 1.25),
      headlineMedium: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: baseColor, height: 1.3),
      headlineSmall: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: baseColor, height: 1.3),
      titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: baseColor, height: 1.3),
      titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: baseColor, height: 1.4),
      titleSmall: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: baseColor, height: 1.4),
      bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w400, color: baseColor, height: 1.5),
      bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: baseColor, height: 1.5),
      bodySmall: TextStyle(fontSize: 12, fontWeight: FontWeight.w400, color: _onSurfaceDim, height: 1.5),
      labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: baseColor, letterSpacing: 0.5, height: 1.3),
      labelMedium: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: baseColor, letterSpacing: 0.3, height: 1.3),
      labelSmall: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: _onSurfaceDim, letterSpacing: 0.2, height: 1.3),
    );
    if (useGoogleFonts) {
      try {
        return GoogleFonts.interTextTheme(base);
      } catch (_) {}
    }
    return base;
  }

  static Color get primary => _primary;
  static Color get background => _bg;
  static Color get surface => _surface;
  static Color get card => _card;
  static Color get gold => _gold;
  static Color get cream => _cream;
  static Color get onSurfaceDim => _onSurfaceDim;

  static const List<Color> gradientColors = [
    Color(0xFFD4A574),
    Color(0xFFC9A96E),
    Color(0xFFD4AF37),
    Color(0xFF8B6F47),
    Color(0xFFD4A574),
  ];

  static const Map<String, Color> fileTypeColors = {
    'pdf': Color(0xFFE57373),
    'doc': Color(0xFF64B5F6),
    'docx': Color(0xFF64B5F6),
    'xls': Color(0xFF81C784),
    'xlsx': Color(0xFF81C784),
    'ppt': Color(0xFFFF8A65),
    'pptx': Color(0xFFFF8A65),
    'txt': Color(0xFFA0A0A0),
    'csv': Color(0xFF81C784),
    'json': Color(0xFFFFD54F),
    'xml': Color(0xFFFF8A65),
    'html': Color(0xFFE57373),
    'css': Color(0xFF64B5F6),
    'js': Color(0xFFFFD54F),
    'dart': Color(0xFF64B5F6),
    'py': Color(0xFF90A4AE),
    'java': Color(0xFFE57373),
    'cpp': Color(0xFF64B5F6),
    'h': Color(0xFF64B5F6),
    'swift': Color(0xFFFF7043),
    'kt': Color(0xFFCE93D8),
    'go': Color(0xFF4DD0E1),
    'rs': Color(0xFFDEA584),
    'yaml': Color(0xFFD4A574),
    'md': Color(0xFF64B5F6),
    'zip': Color(0xFFFFB74D),
    'rar': Color(0xFFFFB74D),
    '7z': Color(0xFFFFB74D),
    'tar': Color(0xFFFFB74D),
    'gz': Color(0xFFFFB74D),
    'png': Color(0xFFCE93D8),
    'jpg': Color(0xFFCE93D8),
    'jpeg': Color(0xFFCE93D8),
    'gif': Color(0xFFCE93D8),
    'svg': Color(0xFFCE93D8),
    'webp': Color(0xFFCE93D8),
    'ico': Color(0xFFCE93D8),
    'mp4': Color(0xFFE57373),
    'avi': Color(0xFFE57373),
    'mkv': Color(0xFFE57373),
    'mov': Color(0xFFE57373),
    'wmv': Color(0xFFE57373),
    'flv': Color(0xFFE57373),
    'mp3': Color(0xFF64B5F6),
    'wav': Color(0xFF64B5F6),
    'flac': Color(0xFF64B5F6),
    'aac': Color(0xFF64B5F6),
    'ogg': Color(0xFF64B5F6),
    'wma': Color(0xFF64B5F6),
    'exe': Color(0xFF90A4AE),
    'apk': Color(0xFF81C784),
    'dmg': Color(0xFF90A4AE),
    'iso': Color(0xFF90A4AE),
    'ttf': Color(0xFFD4A574),
    'otf': Color(0xFFD4A574),
    'woff': Color(0xFFD4A574),
    'woff2': Color(0xFFD4A574),
  };

  static Color getFileColor(String ext) {
    final key = ext.toLowerCase().replaceAll('.', '');
    return fileTypeColors[key] ?? _onSurfaceDim;
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

class AppColors extends ThemeExtension<AppColors> {
  final Color bg;
  final Color surface;
  final Color surfaceVariant;
  final Color card;
  final Color cardElevated;
  final Color primary;
  final Color primaryContainer;
  final Color secondary;
  final Color gold;
  final Color cream;
  final Color onSurfaceDim;
  final Color outline;
  final Color outlineVariant;

  const AppColors({
    required this.bg,
    required this.surface,
    required this.surfaceVariant,
    required this.card,
    required this.cardElevated,
    required this.primary,
    required this.primaryContainer,
    required this.secondary,
    required this.gold,
    required this.cream,
    required this.onSurfaceDim,
    required this.outline,
    required this.outlineVariant,
  });

  @override
  ThemeExtension<AppColors> copyWith({
    Color? bg,
    Color? surface,
    Color? surfaceVariant,
    Color? card,
    Color? cardElevated,
    Color? primary,
    Color? primaryContainer,
    Color? secondary,
    Color? gold,
    Color? cream,
    Color? onSurfaceDim,
    Color? outline,
    Color? outlineVariant,
  }) {
    return AppColors(
      bg: bg ?? this.bg,
      surface: surface ?? this.surface,
      surfaceVariant: surfaceVariant ?? this.surfaceVariant,
      card: card ?? this.card,
      cardElevated: cardElevated ?? this.cardElevated,
      primary: primary ?? this.primary,
      primaryContainer: primaryContainer ?? this.primaryContainer,
      secondary: secondary ?? this.secondary,
      gold: gold ?? this.gold,
      cream: cream ?? this.cream,
      onSurfaceDim: onSurfaceDim ?? this.onSurfaceDim,
      outline: outline ?? this.outline,
      outlineVariant: outlineVariant ?? this.outlineVariant,
    );
  }

  @override
  ThemeExtension<AppColors> lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      bg: Color.lerp(bg, other.bg, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceVariant: Color.lerp(surfaceVariant, other.surfaceVariant, t)!,
      card: Color.lerp(card, other.card, t)!,
      cardElevated: Color.lerp(cardElevated, other.cardElevated, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      primaryContainer: Color.lerp(primaryContainer, other.primaryContainer, t)!,
      secondary: Color.lerp(secondary, other.secondary, t)!,
      gold: Color.lerp(gold, other.gold, t)!,
      cream: Color.lerp(cream, other.cream, t)!,
      onSurfaceDim: Color.lerp(onSurfaceDim, other.onSurfaceDim, t)!,
      outline: Color.lerp(outline, other.outline, t)!,
      outlineVariant: Color.lerp(outlineVariant, other.outlineVariant, t)!,
    );
  }
}
