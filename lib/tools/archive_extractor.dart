import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:archive/archive.dart';
import '../theme/app_theme.dart';

class ArchiveExtractor extends StatefulWidget {
  const ArchiveExtractor({super.key});
  @override
  State<ArchiveExtractor> createState() => _ArchiveExtractorState();
}

class _ArchiveExtractorState extends State<ArchiveExtractor> {
  PlatformFile? _selectedArchive;
  Directory? _outputDir;
  bool _extracting = false;
  List<_ExtractedFile>? _extractedFiles;
  String? _statusMessage;
  bool _statusIsError = false;

  String get _archiveExtension {
    if (_selectedArchive == null) return '';
    return p.extension(_selectedArchive!.name).toLowerCase().replaceAll('.', '');
  }

  Future<void> _pickArchive() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zip', 'rar', '7z'],
      withReadStream: false,
    );
    if (result == null || result.files.isEmpty) return;
    setState(() {
      _selectedArchive = result.files.first;
      _extractedFiles = null;
      _statusMessage = null;
    });
    if (_outputDir == null) {
      final docs = await getApplicationDocumentsDirectory();
      setState(() => _outputDir = Directory(p.join(docs.path, 'Extracted')));
    }
  }

  Future<void> _pickOutputDir() async {
    final result = await FilePicker.getDirectoryPath();
    if (result == null) return;
    setState(() => _outputDir = Directory(result));
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  Future<void> _extract() async {
    if (_selectedArchive == null || _outputDir == null) return;
    final ext = _archiveExtension;
    if (ext != 'zip') {
      setState(() {
        _statusMessage = '$ext extraction is not yet supported (archive package limitations). Only ZIP is supported.';
        _statusIsError = true;
      });
      return;
    }
    setState(() {
      _extracting = true;
      _extractedFiles = null;
      _statusMessage = null;
      _statusIsError = false;
    });

    try {
      if (_selectedArchive!.path == null) {
        throw Exception('Archive file path is not available.');
      }
      final file = File(_selectedArchive!.path!);
      final bytes = await file.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);
      final outDir = _outputDir!;
      if (!await outDir.exists()) await outDir.create(recursive: true);

      final extracted = <_ExtractedFile>[];
      var total = 0;

      for (final entry in archive) {
        if (entry.isFile) {
          final entryPath = p.join(outDir.path, entry.name);
          final parent = Directory(p.dirname(entryPath));
          if (!await parent.exists()) await parent.create(recursive: true);
          await File(entryPath).writeAsBytes(entry.content as List<int>);
          extracted.add(_ExtractedFile(name: entry.name, size: entry.size));
          total++;
        }
      }

      setState(() {
        _extractedFiles = extracted;
        _extracting = false;
        _statusMessage = 'Successfully extracted $total ${total == 1 ? 'file' : 'files'} to ${outDir.path}';
        _statusIsError = false;
      });
    } catch (e) {
      setState(() {
        _extracting = false;
        _statusMessage = 'Extraction failed: $e';
        _statusIsError = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = AppTheme.getFileColor('zip');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Archive Extractor'),
        actions: [
          if (_extracting)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildHeader(theme, color),
          const SizedBox(height: 24),
          _buildArchiveSelector(theme, color),
          const SizedBox(height: 16),
          _buildOutputSelector(theme),
          const SizedBox(height: 24),
          _buildExtractButton(theme),
          if (_extracting) ...[
            const SizedBox(height: 24),
            const Center(child: LinearProgressIndicator()),
            const SizedBox(height: 8),
            Center(child: Text('Extracting...', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.primary))),
          ],
          if (_statusMessage != null) ...[
            const SizedBox(height: 16),
            _buildStatusBanner(theme, color),
          ],
          if (_extractedFiles != null && _extractedFiles!.isNotEmpty) ...[
            const SizedBox(height: 24),
            _buildExtractedFilesList(theme),
          ],
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, color.withValues(alpha: 0.7)],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.folder_zip_rounded, color: Colors.white, size: 36),
          const SizedBox(height: 12),
          Text(
            'Archive Extractor',
            style: theme.textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Extract ZIP, RAR & 7z archives',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.8)),
          ),
        ],
      ),
    );
  }

  Widget _buildArchiveSelector(ThemeData theme, Color color) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: _pickArchive,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.upload_file_rounded, color: color, size: 20),
                  const SizedBox(width: 8),
                  Text('Select Archive', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(height: 12),
              if (_selectedArchive != null) ...[
                Row(
                  children: [
                    Icon(AppTheme.getFileIcon(_archiveExtension), size: 32, color: color),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _selectedArchive!.name,
                            style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _formatSize(_selectedArchive!.size),
                            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                          ),
                        ],
                      ),
                    ),
                    if (_archiveExtension == 'zip')
                      Chip(
                        label: const Text('ZIP', style: TextStyle(fontSize: 10)),
                        backgroundColor: color.withValues(alpha: 0.15),
                        padding: EdgeInsets.zero,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      )
                    else
                      Chip(
                        label: Text(_archiveExtension.toUpperCase(), style: const TextStyle(fontSize: 10)),
                        backgroundColor: Colors.orange.withValues(alpha: 0.15),
                        padding: EdgeInsets.zero,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      ),
                  ],
                ),
              ] else ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Column(
                    children: [
                      Icon(Icons.file_open_rounded, size: 40, color: theme.colorScheme.onSurface.withValues(alpha: 0.3)),
                      const SizedBox(height: 8),
                      Text('Tap to select a .zip, .rar or .7z file', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.5))),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOutputSelector(ThemeData theme) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: _pickOutputDir,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.folder_rounded, size: 20, color: Colors.blue),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Output Directory', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(
                      _outputDir?.path ?? 'Documents/Extracted (default)',
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.edit_rounded, size: 18, color: Colors.blue),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExtractButton(ThemeData theme) {
    final canExtract = _selectedArchive != null && _outputDir != null && !_extracting;
    return FilledButton.icon(
      onPressed: canExtract ? _extract : null,
      icon: _extracting
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            )
          : const Icon(Icons.unarchive_rounded),
      label: Text(_extracting ? 'Extracting...' : 'Extract Archive'),
      style: FilledButton.styleFrom(
        minimumSize: const Size(double.infinity, 52),
        backgroundColor: AppTheme.getFileColor('zip'),
      ),
    );
  }

  Widget _buildStatusBanner(ThemeData theme, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _statusIsError
            ? theme.colorScheme.error.withValues(alpha: 0.1)
            : color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _statusIsError
              ? theme.colorScheme.error.withValues(alpha: 0.3)
              : color.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            _statusIsError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
            color: _statusIsError ? theme.colorScheme.error : color,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _statusMessage!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: _statusIsError ? theme.colorScheme.error : color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExtractedFilesList(ThemeData theme) {
    final sorted = List<_ExtractedFile>.from(_extractedFiles!)
      ..sort((a, b) => a.name.compareTo(b.name));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.list_alt_rounded, size: 20, color: Colors.green),
            const SizedBox(width: 8),
            Text(
              'Extracted Files (${sorted.length})',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...sorted.map((f) => Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Card(
            child: ListTile(
              dense: true,
              leading: Icon(
                AppTheme.getFileIcon(p.extension(f.name)),
                color: AppTheme.getFileColor(p.extension(f.name)),
                size: 24,
              ),
              title: Text(
                f.name,
                style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500),
                overflow: TextOverflow.ellipsis,
              ),
              trailing: Text(
                _formatSize(f.size),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ),
          ),
        )),
      ],
    );
  }
}

class _ExtractedFile {
  final String name;
  final int size;
  const _ExtractedFile({required this.name, required this.size});
}
