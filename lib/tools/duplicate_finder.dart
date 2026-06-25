import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import '../services/isolate_service.dart';

class DuplicateFinder extends StatefulWidget {
  const DuplicateFinder({super.key});
  @override
  State<DuplicateFinder> createState() => _DuplicateFinderState();
}

class _DuplicateFinderState extends State<DuplicateFinder> {
  String? _scanDir;
  bool _scanning = false;
  bool _deleting = false;
  List<_DuplicateGroup> _groups = [];
  String? _statusMessage;
  bool _statusIsError = false;
  int _filesScanned = 0;

  Future<void> _pickDirectory() async {
    final result = await FilePicker.getDirectoryPath();
    if (result == null) return;
    setState(() { _scanDir = result; _groups = []; _statusMessage = null; _filesScanned = 0; });
  }

  Future<void> _scan() async {
    if (_scanDir == null) return;
    setState(() { _scanning = true; _groups = []; _statusMessage = null; _statusIsError = false; _filesScanned = 0; });

    try {
      final dir = Directory(_scanDir!);
      if (!await dir.exists()) throw Exception('Directory not found');

      final allFiles = await dir.list(recursive: true).where((e) => e is File).cast<File>().toList();
      final sizeMap = <int, List<File>>{};

      for (final file in allFiles) {
        try {
          final size = await file.length();
          sizeMap.putIfAbsent(size, () => []).add(file);
        } catch (_) {}
        _filesScanned++;
      }

      final groups = <_DuplicateGroup>[];
      for (final entry in sizeMap.entries) {
        if (entry.value.length < 2) continue;
        final hashMap = <String, List<File>>{};
        for (final file in entry.value) {
          try {
            final hash = await IsolateService.instance.getFileHash(file.path);
            hashMap.putIfAbsent(hash, () => []).add(file);
          } catch (_) {}
        }
        for (final hEntry in hashMap.entries) {
          if (hEntry.value.length > 1) {
            groups.add(_DuplicateGroup(size: entry.key, files: hEntry.value));
          }
        }
      }

      groups.sort((a, b) => b.files.length.compareTo(a.files.length));

      setState(() {
        _groups = groups;
        _scanning = false;
        if (groups.isEmpty) {
          _statusMessage = 'No duplicates found in $_filesScanned files';
          _statusIsError = false;
        } else {
          final totalWasted = groups.fold<int>(0, (s, g) => s + g.size * (g.files.length - 1));
          _statusMessage = 'Found ${groups.length} duplicate group${groups.length == 1 ? '' : 's'} (${_formatSize(totalWasted)} wasted)';
          _statusIsError = false;
        }
      });
    } catch (e) {
      setState(() { _scanning = false; _statusMessage = 'Scan failed: $e'; _statusIsError = true; });
    }
  }

  Future<void> _deleteDuplicates(_DuplicateGroup group, File fileToKeep) async {
    setState(() => _deleting = true);
    try {
      for (final file in group.files) {
        if (file.path != fileToKeep.path && await file.exists()) {
          await file.delete();
        }
      }
      setState(() {
        _groups.remove(group);
        _deleting = false;
        _statusMessage = 'Deleted ${group.files.length - 1} duplicate${group.files.length - 1 == 1 ? '' : 's'}';
        _statusIsError = false;
      });
    } catch (e) {
      setState(() { _deleting = false; _statusMessage = 'Delete failed: $e'; _statusIsError = true; });
    }
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const color = Colors.orange;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Duplicate Finder'),
        actions: [if (_scanning || _deleting) const Padding(padding: EdgeInsets.all(16), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))],
      ),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        _buildHeader(theme, color), const SizedBox(height: 24),
        _buildDirSelector(theme, color), const SizedBox(height: 16),
        _buildScanButton(theme, color),
        if (_scanning) ...[const SizedBox(height: 16), const LinearProgressIndicator(), const SizedBox(height: 8), Center(child: Text('Scanned $_filesScanned files...', style: theme.textTheme.bodySmall))],
        if (_statusMessage != null) ...[const SizedBox(height: 16), _buildStatusBanner(theme, color)],
        if (_groups.isNotEmpty) ...[const SizedBox(height: 24), _buildResults(theme)],
        const SizedBox(height: 32),
      ]),
    );
  }

  Widget _buildHeader(ThemeData theme, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(gradient: LinearGradient(colors: [color, color.withValues(alpha: 0.7)]), borderRadius: BorderRadius.circular(20)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.copy_all_rounded, color: Colors.white, size: 36),
        const SizedBox(height: 12),
        Text('Duplicate Finder', style: theme.textTheme.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text('Find and remove duplicate files to free up space', style: TextStyle(color: Colors.white.withValues(alpha: 0.8))),
      ]),
    );
  }

  Widget _buildDirSelector(ThemeData theme, Color color) {
    return Card(child: InkWell(
      borderRadius: BorderRadius.circular(16), onTap: _pickDirectory,
      child: Padding(padding: const EdgeInsets.all(16), child: Row(children: [
        Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
          child: const Icon(Icons.folder_rounded, color: Colors.orange, size: 28)),
        const SizedBox(width: 16),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Scan Directory', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
          Text(_scanDir ?? 'Tap to pick a folder to scan', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.5)), overflow: TextOverflow.ellipsis),
        ])),
        const Icon(Icons.chevron_right_rounded, color: Colors.grey),
      ])),
    ));
  }

  Widget _buildScanButton(ThemeData theme, Color color) {
    return FilledButton.icon(
      onPressed: (_scanDir == null || _scanning) ? null : _scan,
      icon: _scanning ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.search_rounded),
      label: Text(_scanning ? 'Scanning...' : 'Scan for Duplicates'),
      style: FilledButton.styleFrom(minimumSize: const Size(double.infinity, 52), backgroundColor: color),
    );
  }

  Widget _buildResults(ThemeData theme) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Duplicate Groups (${_groups.length})', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
      const SizedBox(height: 12),
      ..._groups.map((g) => Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.copy_all_rounded, size: 20, color: Colors.orange.shade300),
            const SizedBox(width: 8),
            Text('${g.files.length} copies · ${_formatSize(g.size)} each', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
            const Spacer(),
            Text('${_formatSize(g.size * (g.files.length - 1))} wasted', style: TextStyle(color: Colors.red.shade400, fontSize: 12, fontWeight: FontWeight.w500)),
          ]),
          const SizedBox(height: 12),
          ...g.files.map((f) => Padding(padding: const EdgeInsets.only(bottom: 4), child: Row(children: [
            Icon(Icons.insert_drive_file_rounded, size: 16, color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
            const SizedBox(width: 8),
            Expanded(child: Text(p.basename(f.path), style: theme.textTheme.bodySmall, overflow: TextOverflow.ellipsis, maxLines: 1)),
          ]))),
          const SizedBox(height: 8),
          Align(alignment: Alignment.centerRight, child: TextButton.icon(
            onPressed: _deleting ? null : () => _deleteDuplicates(g, g.files.first),
            icon: const Icon(Icons.auto_delete_rounded, size: 16),
            label: const Text('Keep first, delete rest'),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
          )),
        ])),
      )),
    ]);
  }

  Widget _buildStatusBanner(ThemeData theme, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _statusIsError ? theme.colorScheme.error.withValues(alpha: 0.1) : Colors.green.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _statusIsError ? theme.colorScheme.error.withValues(alpha: 0.3) : Colors.green.withValues(alpha: 0.3)),
      ),
      child: Row(children: [
        Icon(_statusIsError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded, color: _statusIsError ? theme.colorScheme.error : Colors.green, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text(_statusMessage!, style: theme.textTheme.bodySmall)),
      ]),
    );
  }
}

class _DuplicateGroup {
  final int size;
  final List<File> files;
  const _DuplicateGroup({required this.size, required this.files});
}
