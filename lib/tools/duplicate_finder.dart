import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import '../services/isolate_service.dart';
import '../theme/app_theme.dart';

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
    final ac = theme.extension<AppColors>()!;
    const color = Color(0xFFFFB74D);
    return Scaffold(
      appBar: AppBar(title: const Text('Duplicate Finder'),
        actions: [if (_scanning || _deleting) const Padding(padding: EdgeInsets.all(16), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))]),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        _buildHeader(theme, ac, color), const SizedBox(height: 24),
        _buildDirSelector(theme, ac, color), const SizedBox(height: 16),
        _buildScanButton(theme, ac, color),
        if (_scanning) ...[
          const SizedBox(height: 16),
          LinearProgressIndicator(color: ac.primary),
          const SizedBox(height: 8),
          Center(child: Text('Scanned $_filesScanned files...', style: TextStyle(color: ac.onSurfaceDim))),
        ],
        if (_statusMessage != null) ...[const SizedBox(height: 16), _buildStatusBanner(theme, ac)],
        if (_groups.isNotEmpty) ...[const SizedBox(height: 24), _buildResults(theme, ac)],
        const SizedBox(height: 32),
      ]),
    );
  }

  Widget _buildHeader(ThemeData theme, AppColors ac, Color color) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [color, color.withAlpha(100)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.white.withAlpha(30), borderRadius: BorderRadius.circular(14)),
          child: const Icon(Icons.copy_all_rounded, color: Colors.white, size: 28),
        ),
        const SizedBox(height: 16),
        Text('Duplicate Finder', style: theme.textTheme.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text('Find and remove duplicate files to free up space', style: TextStyle(color: Colors.white.withAlpha(200))),
      ]),
    );
  }

  Widget _buildDirSelector(ThemeData theme, AppColors ac, Color color) {
    return Container(
      decoration: BoxDecoration(color: ac.card, borderRadius: BorderRadius.circular(18), border: Border.all(color: ac.outline.withAlpha(60))),
      child: Material(
        color: Colors.transparent,
        child: InkWell(borderRadius: BorderRadius.circular(18), onTap: _pickDirectory,
          child: Padding(padding: const EdgeInsets.all(16), child: Row(children: [
            Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: color.withAlpha(25), borderRadius: BorderRadius.circular(14)),
              child: Icon(Icons.folder_rounded, color: color, size: 26)),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Scan Directory', style: TextStyle(color: ac.cream, fontWeight: FontWeight.w600)),
              Text(_scanDir ?? 'Tap to pick a folder to scan', style: TextStyle(color: ac.onSurfaceDim, fontSize: 12), overflow: TextOverflow.ellipsis),
            ])),
            Icon(Icons.chevron_right_rounded, color: ac.onSurfaceDim.withAlpha(120)),
          ])),
        ),
      ),
    );
  }

  Widget _buildScanButton(ThemeData theme, AppColors ac, Color color) {
    return Container(
      width: double.infinity,
      height: 54,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: color.withAlpha(60), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: FilledButton.icon(
        onPressed: (_scanDir == null || _scanning) ? null : _scan,
        icon: _scanning ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.search_rounded),
        label: Text(_scanning ? 'Scanning...' : 'Scan for Duplicates'),
        style: FilledButton.styleFrom(backgroundColor: color),
      ),
    );
  }

  Widget _buildResults(ThemeData theme, AppColors ac) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Duplicate Groups (${_groups.length})', style: TextStyle(color: ac.cream, fontWeight: FontWeight.w600, fontSize: 16)),
      const SizedBox(height: 12),
      ..._groups.map((g) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(color: ac.card, borderRadius: BorderRadius.circular(18), border: Border.all(color: ac.outline.withAlpha(60))),
        child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.copy_all_rounded, size: 20, color: Color(0xFFFFB74D)),
            const SizedBox(width: 8),
            Text('${g.files.length} copies · ${_formatSize(g.size)} each', style: TextStyle(color: ac.cream, fontWeight: FontWeight.w600)),
            const Spacer(),
            Text('${_formatSize(g.size * (g.files.length - 1))} wasted', style: const TextStyle(color: Color(0xFFE57373), fontSize: 12, fontWeight: FontWeight.w500)),
          ]),
          const SizedBox(height: 12),
          ...g.files.map((f) => Padding(padding: const EdgeInsets.only(bottom: 4), child: Row(children: [
            Icon(Icons.insert_drive_file_rounded, size: 16, color: ac.onSurfaceDim.withAlpha(120)),
            const SizedBox(width: 8),
            Expanded(child: Text(p.basename(f.path), style: TextStyle(color: ac.cream), overflow: TextOverflow.ellipsis, maxLines: 1)),
          ]))),
          const SizedBox(height: 8),
          Align(alignment: Alignment.centerRight, child: TextButton.icon(
            onPressed: _deleting ? null : () => _deleteDuplicates(g, g.files.first),
            icon: const Icon(Icons.auto_delete_rounded, size: 16),
            label: const Text('Keep first, delete rest'),
            style: TextButton.styleFrom(foregroundColor: const Color(0xFFE57373)),
          )),
        ])),
      )),
    ]);
  }

  Widget _buildStatusBanner(ThemeData theme, AppColors ac) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: (_statusIsError ? const Color(0xFFCF6679) : const Color(0xFF81C784)).withAlpha(25),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: (_statusIsError ? const Color(0xFFCF6679) : const Color(0xFF81C784)).withAlpha(80)),
      ),
      child: Row(children: [
        Icon(_statusIsError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
             color: _statusIsError ? const Color(0xFFCF6679) : const Color(0xFF81C784), size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text(_statusMessage!, style: TextStyle(color: ac.cream))),
      ]),
    );
  }
}

class _DuplicateGroup {
  final int size;
  final List<File> files;
  const _DuplicateGroup({required this.size, required this.files});
}
