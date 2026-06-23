import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/file_item.dart';
import '../database/app_database.dart';

class AppProvider extends ChangeNotifier {
  AppProvider() {
    _loadSettings();
  }

  ThemeMode _themeMode = ThemeMode.system;
  ThemeMode get themeMode => _themeMode;

  List<FileItem> _files = [];
  List<FileItem> get files => _files;

  List<FileItem> _recentFiles = [];
  List<FileItem> get recentFiles => _recentFiles;

  List<FileItem> _favoriteFiles = [];
  List<FileItem> get favoriteFiles => _favoriteFiles;

  FileItem? _selectedFile;
  FileItem? get selectedFile => _selectedFile;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String _searchQuery = '';
  String get searchQuery => _searchQuery;

  String _currentCategory = 'all';
  String get currentCategory => _currentCategory;

  int _fileCount = 0;
  int get fileCount => _fileCount;

  int _totalSize = 0;
  int get totalSize => _totalSize;

  Map<String, int> _categoryCounts = {};
  Map<String, int> get categoryCounts => _categoryCounts;

  String _sortField = 'name';
  String get sortField => _sortField;
  bool _sortAscending = true;
  bool get sortAscending => _sortAscending;

  Set<int> _selectedIds = {};
  Set<int> get selectedIds => _selectedIds;
  bool get isSelectionMode => _selectedIds.isNotEmpty;

  // Additional state for tools
  final bool _isProcessing = false;
  bool get isProcessing => _isProcessing;

  String _statusMessage = '';
  String get statusMessage => _statusMessage;

  double _progressValue = 0.0;
  double get progressValue => _progressValue;

  void _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final themeStr = prefs.getString('theme_mode') ?? 'system';
    _themeMode = _parseThemeMode(themeStr);
    notifyListeners();
  }

  ThemeMode _parseThemeMode(String mode) {
    switch (mode) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  void setSortField(String field) {
    if (_sortField == field) {
      _sortAscending = !_sortAscending;
    } else {
      _sortField = field;
      _sortAscending = true;
    }
    _sortFiles();
    notifyListeners();
  }

  void _sortFiles() {
    _files.sort((a, b) {
      int cmp;
      switch (_sortField) {
        case 'date':
          cmp = a.modifiedAt.compareTo(b.modifiedAt);
          break;
        case 'size':
          cmp = a.size.compareTo(b.size);
          break;
        default:
          cmp = a.name.toLowerCase().compareTo(b.name.toLowerCase());
      }
      return _sortAscending ? cmp : -cmp;
    });
  }

  void toggleSelection(int id) {
    if (_selectedIds.contains(id)) {
      _selectedIds.remove(id);
    } else {
      _selectedIds.add(id);
    }
    notifyListeners();
  }

  void selectAll() {
    _selectedIds = _files.map((f) => f.id!).toSet();
    notifyListeners();
  }

  void clearSelection() {
    _selectedIds = {};
    notifyListeners();
  }

  Future<void> deleteSelected() async {
    if (_selectedIds.isEmpty) return;
    await AppDatabase.instance.deleteFiles(_selectedIds.toList());
    _selectedIds = {};
    await refreshAll();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    String modeStr;
    switch (mode) {
      case ThemeMode.light:
        modeStr = 'light';
        break;
      case ThemeMode.dark:
        modeStr = 'dark';
        break;
      default:
        modeStr = 'system';
    }
    await prefs.setString('theme_mode', modeStr);
    await AppDatabase.instance.setSetting('theme_mode', modeStr);
  }

  void setSelectedFile(FileItem? file) {
    _selectedFile = file;
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setCategory(String category) {
    _currentCategory = category;
    notifyListeners();
  }

  void setStatus(String message, {double progress = 0.0}) {
    _statusMessage = message;
    _progressValue = progress;
    notifyListeners();
  }

  void clearStatus() {
    _statusMessage = '';
    _progressValue = 0.0;
    notifyListeners();
  }

  // ---- File Loading ----

  Future<void> loadFiles({String? category, bool? favorites}) async {
    _isLoading = true;
    notifyListeners();

    try {
      _files = await AppDatabase.instance.getAllFiles(
        category: category ?? _currentCategory,
        favorites: favorites,
        searchQuery: _searchQuery.isNotEmpty ? _searchQuery : null,
      );
    } catch (e) {
      debugPrint('Error loading files: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadRecentFiles() async {
    try {
      _recentFiles = await AppDatabase.instance.getRecentFiles();
    } catch (e) {
      debugPrint('Error loading recent files: $e');
    }
    notifyListeners();
  }

  Future<void> loadFavorites() async {
    try {
      _favoriteFiles = await AppDatabase.instance.getAllFiles(favorites: true);
    } catch (e) {
      debugPrint('Error loading favorites: $e');
    }
    notifyListeners();
  }

  Future<void> loadStats() async {
    try {
      _fileCount = await AppDatabase.instance.getFileCount();
      _totalSize = await AppDatabase.instance.getTotalSize();
      _categoryCounts = await AppDatabase.instance.getCategoryCounts();
    } catch (e) {
      debugPrint('Error loading stats: $e');
    }
    notifyListeners();
  }

  // ---- File Operations ----

  Future<void> addFile(FileItem file) async {
    try {
      await AppDatabase.instance.insertFile(file);
      await loadFiles();
      await loadStats();
    } catch (e) {
      debugPrint('Error adding file: $e');
    }
  }

  Future<void> addFiles(List<FileItem> newFiles) async {
    try {
      await AppDatabase.instance.insertFiles(newFiles);
      await loadFiles();
      await loadStats();
    } catch (e) {
      debugPrint('Error adding files: $e');
    }
  }

  Future<void> deleteFile(int id) async {
    try {
      await AppDatabase.instance.deleteFile(id);
      await loadFiles();
      await loadStats();
    } catch (e) {
      debugPrint('Error deleting file: $e');
    }
  }

  Future<void> deleteFiles(List<int> ids) async {
    try {
      await AppDatabase.instance.deleteFiles(ids);
      await loadFiles();
      await loadStats();
    } catch (e) {
      debugPrint('Error deleting files: $e');
    }
  }

  Future<void> toggleFavorite(int id) async {
    try {
      await AppDatabase.instance.toggleFavorite(id);
      await loadFiles();
      await loadFavorites();
    } catch (e) {
      debugPrint('Error toggling favorite: $e');
    }
  }

  Future<void> refreshAll() async {
    await Future.wait([
      loadFiles(),
      loadRecentFiles(),
      loadFavorites(),
      loadStats(),
    ]);
  }
}
