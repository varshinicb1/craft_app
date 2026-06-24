import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:archive/archive.dart';
import '../theme/app_theme.dart';

class ArchiveCreator extends StatefulWidget {
  const ArchiveCreator({super.key});
  @override
  State<ArchiveCreator> createState() => _ArchiveCreatorState();
}

class _ArchiveCreatorState extends State<ArchiveCreator> {
  List<PlatformFile> _selectedFiles = [];
  Directory? _outputDir;
  String _archiveName = 'archive.zip';
  bool _creating = false;
  String? _statusMessage;
  bool _statusIsError = false;

  Future<void> _pickFiles() async {
    final result = await FilePicker.pickFiles(
      type: FileType.any,
      allowMultiple: true,
    );
    if (result == null || result.files.isEmpty) return;
    setState(() {
      _selectedFiles = result.files;
      _statusMessage = null;
    });
    if (_outputDir == null) {
      final docs = await getApplicationDocumentsDirectory();
      setState(() => _outputDir = Directory(p.join(docs.path, 'Archives')));
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

  Future<void> _createArchive() async {
    if (_selectedFiles.isEmpty || _outputDir == null) return;
    setState(() {
      _creating = true;
      _statusMessage = null;
      _statusIsError = false;
    });

    try {
      final archive = Archive();

      for (final file in _selectedFiles) {
        if (file.path == null) continue;
        final bytes = await File(file.path!).readAsBytes();
        archive.addFile(ArchiveFile(file.name, bytes.length, bytes));
      }

      final encoded = ZipEncoder().encode(archive);
      if (encoded == null) throw Exception('Failed to encode ZIP archive');

      if (!await _outputDir!.exists()) await _outputDir!.create(recursive: true);
      final finalName = _archiveName.endsWith('.zip') ? _archiveName : '$_archiveName.zip';
      final outputPath = p.join(_outputDir!.path, finalName);
      await File(outputPath).writeAsBytes(encoded);

      setState(() {
        _creating = false;
        _statusMessage = 'Created $finalName (${_formatSize(encoded.length)}) from ${_selectedFiles.length} ${_selectedFiles.length == 1 ? 'file' : 'files'}';
        _statusIsError = false;
      });
    } catch (e) {
      setState(() {
        _creating = false;
        _statusMessage = 'Archive creation failed: $e';
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
        title: const Text('Archive Creator'),
        actions: [
          if (_creating) const Padding(
            padding: EdgeInsets.all(16),
            child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildHeader(theme, color),
          const SizedBox(height: 24),
          _buildFileSelector(theme, color),
          if (_selectedFiles.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildFileNameInput(theme),
            const SizedBox(height: 16),
            _buildOutputSelector(theme),
            const SizedBox(height: 24),
            _buildFileList(theme),
            const SizedBox(height: 24),
            _buildCreateButton(theme),
            if (_statusMessage != null) ...[
              const SizedBox(height: 16),
              _buildStatusBanner(theme, color),
            ],
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
        gradient: LinearGradient(colors: [color, color.withValues(alpha: 0.7)]),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.archive_rounded, color: Colors.white, size: 36),
          const SizedBox(height: 12),
          Text('Archive Creator', style: theme.textTheme.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('Package multiple files into a ZIP archive', style: TextStyle(color: Colors.white.withValues(alpha: 0.8))),
        ],
      ),
    );
  }

  Widget _buildFileSelector(ThemeData theme, Color color) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: _pickFiles,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.upload_file_rounded, color: color, size: 20),
                  const SizedBox(width: 8),
                  Text('Select Files', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(height: 12),
              if (_selectedFiles.isNotEmpty)
                Text('${_selectedFiles.length} ${_selectedFiles.length == 1 ? 'file' : 'files'} selected — tap to change',
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.6)))
              else
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Column(
                    children: [
                      Icon(Icons.note_add_rounded, size: 40, color: theme.colorScheme.onSurface.withValues(alpha: 0.3)),
                      const SizedBox(height: 8),
                      Text('Tap to select multiple files', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.5))),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFileNameInput(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.drive_file_rename_outline_rounded, size: 20, color: AppTheme.getFileColor('zip')),
                const SizedBox(width: 8),
                Text('Archive Name', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              decoration: InputDecoration(
                hintText: 'archive.zip',
                suffixText: '.zip',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              controller: TextEditingController(text: _archiveName.replaceAll('.zip', '')),
              onChanged: (v) => setState(() => _archiveName = v.isEmpty ? 'archive.zip' : '$v.zip'),
            ),
          ],
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
                    Text(_outputDir?.path ?? 'Documents/Archives (default)',
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                        overflow: TextOverflow.ellipsis),
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

  Widget _buildFileList(ThemeData theme) {
    final totalSize = _selectedFiles.fold<int>(0, (sum, f) => sum + f.size);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.list_alt_rounded, size: 20),
            const SizedBox(width: 8),
            Text('${_selectedFiles.length} Files · ${_formatSize(totalSize)}',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
          ],
        ),
        const SizedBox(height: 12),
        ..._selectedFiles.map((f) => Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Card(
            child: ListTile(
              dense: true,
              leading: Icon(AppTheme.getFileIcon(p.extension(f.name)), color: AppTheme.getFileColor(p.extension(f.name)), size: 24),
              title: Text(f.name, style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis),
              trailing: Text(_formatSize(f.size), style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
            ),
          ),
        )),
      ],
    );
  }

  Widget _buildCreateButton(ThemeData theme) {
    return FilledButton.icon(
      onPressed: _creating ? null : _createArchive,
      icon: _creating
          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
          : const Icon(Icons.archive_rounded),
      label: Text(_creating ? 'Creating...' : 'Create ZIP Archive'),
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
        color: _statusIsError ? theme.colorScheme.error.withValues(alpha: 0.1) : color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _statusIsError ? theme.colorScheme.error.withValues(alpha: 0.3) : color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(_statusIsError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
               color: _statusIsError ? theme.colorScheme.error : color, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(_statusMessage!, style: theme.textTheme.bodySmall?.copyWith(color: _statusIsError ? theme.colorScheme.error : color))),
        ],
      ),
    );
  }
}
