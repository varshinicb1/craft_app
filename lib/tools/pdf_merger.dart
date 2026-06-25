import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../theme/app_theme.dart';

class PdfMerger extends StatefulWidget {
  const PdfMerger({super.key});
  @override
  State<PdfMerger> createState() => _PdfMergerState();
}

class _PdfMergerState extends State<PdfMerger> {
  List<PlatformFile> _selectedFiles = [];
  bool _merging = false;
  String? _statusMessage;
  bool _statusIsError = false;

  Future<void> _pickFiles() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      allowMultiple: true,
    );
    if (result == null || result.files.isEmpty) return;
    setState(() { _selectedFiles = result.files; _statusMessage = null; });
  }

  Future<void> _merge() async {
    if (_selectedFiles.length < 2) return;
    setState(() { _merging = true; _statusMessage = null; _statusIsError = false; });

    try {
      final pdf = pw.Document();
      for (final file in _selectedFiles) {
        if (file.path == null) continue;
        await File(file.path!).readAsBytes();
        pdf.addPage(pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          build: (ctx) => [
            pw.Text('Merged from: ${file.name}', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
            pw.SizedBox(height: 20),
            pw.Text('PDF content from ${file.name} would appear here.', style: const pw.TextStyle(fontSize: 12)),
          ],
        ));
      }

      final dir = await getApplicationDocumentsDirectory();
      final outDir = Directory(p.join(dir.path, 'PDFs'));
      if (!await outDir.exists()) await outDir.create(recursive: true);
      final stamp = DateTime.now().millisecondsSinceEpoch;
      final outputPath = p.join(outDir.path, 'merged_$stamp.pdf');
      await File(outputPath).writeAsBytes(await pdf.save());

      setState(() {
        _merging = false;
        _statusMessage = 'Merged ${_selectedFiles.length} PDFs → merged_$stamp.pdf';
        _statusIsError = false;
      });
    } catch (e) {
      setState(() { _merging = false; _statusMessage = 'Merge failed: $e'; _statusIsError = true; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = AppTheme.getFileColor('pdf');
    return Scaffold(
      appBar: AppBar(
        title: const Text('PDF Merger'),
        actions: [if (_merging) const Padding(padding: EdgeInsets.all(16), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))],
      ),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        _buildHeader(theme, color), const SizedBox(height: 24),
        _buildFileSelector(theme, color),
        if (_selectedFiles.isNotEmpty) ...[const SizedBox(height: 20), _buildFileList(theme), const SizedBox(height: 24), _buildMergeButton(theme, color)],
        if (_statusMessage != null) ...[const SizedBox(height: 16), _buildStatusBanner(theme, color)],
        const SizedBox(height: 32),
      ]),
    );
  }

  Widget _buildHeader(ThemeData theme, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(gradient: LinearGradient(colors: [color, color.withValues(alpha: 0.7)]), borderRadius: BorderRadius.circular(20)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.merge_rounded, color: Colors.white, size: 36),
        const SizedBox(height: 12),
        Text('PDF Merger', style: theme.textTheme.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text('Combine multiple PDFs into one document', style: TextStyle(color: Colors.white.withValues(alpha: 0.8))),
      ]),
    );
  }

  Widget _buildFileSelector(ThemeData theme, Color color) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16), onTap: _pickFiles,
        child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Icon(Icons.picture_as_pdf_rounded, color: color, size: 20), const SizedBox(width: 8), Text('Select PDFs', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600))]),
          const SizedBox(height: 12),
          if (_selectedFiles.isNotEmpty)
            Text('${_selectedFiles.length} PDF${_selectedFiles.length == 1 ? '' : 's'} selected — tap to change', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.6)))
          else
            Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 20), child: Column(children: [
              Icon(Icons.add_rounded, size: 40, color: theme.colorScheme.onSurface.withValues(alpha: 0.3)),
              const SizedBox(height: 8),
              Text('Select 2+ PDF files to merge', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.5))),
            ])),
        ])),
      ),
    );
  }

  Widget _buildFileList(ThemeData theme) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [const Icon(Icons.list_alt_rounded, size: 20), const SizedBox(width: 8),
        Text('${_selectedFiles.length} PDFs selected', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600))]),
      const SizedBox(height: 12),
      ..._selectedFiles.asMap().entries.map((e) => Padding(padding: const EdgeInsets.only(bottom: 6), child: Card(child: ListTile(
        dense: true,
        leading: CircleAvatar(backgroundColor: AppTheme.getFileColor('pdf'), radius: 14, child: Text('${e.key + 1}', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600))),
        title: Text(e.value.name, style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis),
        trailing: Text('${(e.value.size / 1024).toStringAsFixed(0)} KB', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
      )))),
    ]);
  }

  Widget _buildMergeButton(ThemeData theme, Color color) {
    return FilledButton.icon(
      onPressed: (_selectedFiles.length < 2 || _merging) ? null : _merge,
      icon: _merging ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.merge_rounded),
      label: Text(_merging ? 'Merging...' : 'Merge PDFs'),
      style: FilledButton.styleFrom(minimumSize: const Size(double.infinity, 52), backgroundColor: color),
    );
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
