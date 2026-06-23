import 'dart:io';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;

class FileItem {
  final int? id;
  final String name;
  final String path;
  final String extension;
  final String category;
  final int size;
  final DateTime createdAt;
  final DateTime modifiedAt;
  final bool isFavorite;
  final String? tags;
  final String? notes;

  FileItem({
    this.id,
    required this.name,
    required this.path,
    required this.extension,
    this.category = 'unknown',
    this.size = 0,
    DateTime? createdAt,
    DateTime? modifiedAt,
    this.isFavorite = false,
    this.tags,
    this.notes,
  })  : createdAt = createdAt ?? DateTime.now(),
        modifiedAt = modifiedAt ?? DateTime.now();

  String get formattedSize {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    if (size < 1024 * 1024 * 1024) {
      return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(size / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  String get formattedDate => DateFormat('MMM dd, yyyy').format(modifiedAt);

  String get formattedDateTime =>
      DateFormat('MMM dd, yyyy HH:mm').format(modifiedAt);

  bool get isImage => ['png', 'jpg', 'jpeg', 'gif', 'webp', 'bmp', 'ico', 'svg']
      .contains(extension);

  bool get isVideo =>
      ['mp4', 'avi', 'mkv', 'mov', 'wmv', 'flv', 'webm'].contains(extension);

  bool get isAudio =>
      ['mp3', 'wav', 'flac', 'aac', 'ogg', 'wma', 'm4a'].contains(extension);

  bool get isDocument =>
      ['pdf', 'doc', 'docx', 'ppt', 'pptx', 'xls', 'xlsx', 'odt', 'ods', 'odp']
          .contains(extension);

  bool get isCode => [
        'dart',
        'py',
        'js',
        'ts',
        'java',
        'cpp',
        'h',
        'c',
        'cs',
        'rb',
        'go',
        'rs',
        'swift',
        'kt'
      ].contains(extension);

  bool get isArchive =>
      ['zip', 'rar', '7z', 'tar', 'gz', 'bz2', 'xz'].contains(extension);

  bool get isText =>
      ['txt', 'md', 'csv', 'log', 'ini', 'cfg', 'yaml', 'yml', 'json', 'xml',
       'html', 'css', 'scss', 'sql']
          .contains(extension);

  bool get isModel => ['obj', 'stl', 'glb', 'gltf', 'fbx', 'dae', '3ds']
      .contains(extension);

  FileItem copyWith({
    int? id,
    String? name,
    String? path,
    String? extension,
    String? category,
    int? size,
    DateTime? createdAt,
    DateTime? modifiedAt,
    bool? isFavorite,
    String? tags,
    String? notes,
  }) {
    return FileItem(
      id: id ?? this.id,
      name: name ?? this.name,
      path: path ?? this.path,
      extension: extension ?? this.extension,
      category: category ?? this.category,
      size: size ?? this.size,
      createdAt: createdAt ?? this.createdAt,
      modifiedAt: modifiedAt ?? this.modifiedAt,
      isFavorite: isFavorite ?? this.isFavorite,
      tags: tags ?? this.tags,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'path': path,
      'extension': extension,
      'category': category,
      'size': size,
      'created_at': createdAt.toIso8601String(),
      'modified_at': modifiedAt.toIso8601String(),
      'is_favorite': isFavorite ? 1 : 0,
      'tags': tags,
      'notes': notes,
    };
  }

  factory FileItem.fromMap(Map<String, dynamic> map) {
    return FileItem(
      id: map['id'] as int?,
      name: map['name'] as String,
      path: map['path'] as String,
      extension: map['extension'] as String? ?? p.extension(map['path']).replaceAll('.', ''),
      category: map['category'] as String? ?? '',
      size: map['size'] as int? ?? 0,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : DateTime.now(),
      modifiedAt: map['modified_at'] != null
          ? DateTime.parse(map['modified_at'] as String)
          : DateTime.now(),
      isFavorite: (map['is_favorite'] as int? ?? 0) == 1,
      tags: map['tags'] as String?,
      notes: map['notes'] as String?,
    );
  }

  factory FileItem.fromFile(File file) {
    final entityPath = file.path;
    final ext = p.extension(entityPath).replaceAll('.', '');
    final stat = file.statSync();
    return FileItem(
      name: p.basename(entityPath),
      path: entityPath,
      extension: ext,
      category: _categorize(ext),
      size: stat.size,
      modifiedAt: stat.modified,
    );
  }

  static String _categorize(String ext) {
    final e = ext.toLowerCase();
    if (['png', 'jpg', 'jpeg', 'gif', 'webp', 'bmp', 'ico', 'svg', 'tiff', 'tif', 'psd']
        .contains(e)) { return 'image'; }
    if (['mp4', 'avi', 'mkv', 'mov', 'wmv', 'flv', 'webm', 'm4v']
        .contains(e)) { return 'video'; }
    if (['mp3', 'wav', 'flac', 'aac', 'ogg', 'wma', 'm4a', 'opus']
        .contains(e)) { return 'audio'; }
    if (['pdf', 'doc', 'docx', 'ppt', 'pptx', 'xls', 'xlsx', 'odt', 'ods', 'odp']
        .contains(e)) { return 'document'; }
    if (['dart', 'py', 'js', 'ts', 'java', 'cpp', 'h', 'c', 'cs', 'rb', 'go',
         'rs', 'swift', 'kt', 'scala', 'php', 'lua', 'r', 'm', 'sql']
        .contains(e)) { return 'code'; }
    if (['txt', 'md', 'csv', 'log', 'ini', 'cfg', 'yaml', 'yml', 'json', 'xml',
         'html', 'css', 'scss', 'sass', 'less', 'toml']
        .contains(e)) { return 'text'; }
    if (['zip', 'rar', '7z', 'tar', 'gz', 'bz2', 'xz', 'z', 'iso']
        .contains(e)) { return 'archive'; }
    if (['obj', 'stl', 'glb', 'gltf', 'fbx', 'dae', '3ds', 'ply', 'off']
        .contains(e)) { return 'model'; }
    return 'other';
  }
}
