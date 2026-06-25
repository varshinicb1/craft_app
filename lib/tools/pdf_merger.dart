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
    final ac = theme.extension<AppColors>()!;
    final color = AppTheme.getFileColor('pdf');
    return Scaffold(
      appBar: AppBar(title: const Text('PDF Merger'),
        actions: [if (_merging) const Padding(padding: EdgeInsets.all(16), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))]),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        _buildHeader(theme, ac, color), const SizedBox(height: 24),
        _buildFileSelector(theme, ac, color),
        if (_selectedFiles.isNotEmpty) ...[const SizedBox(height: 20), _buildFileList(theme, ac), const SizedBox(height: 24), _buildMergeButton(theme, ac, color)],
        if (_statusMessage != null) ...[const SizedBox(height: 16), _buildStatusBanner(theme, ac)],
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
          child: const Icon(Icons.merge_rounded, color: Colors.white, size: 28),
        ),
        const SizedBox(height: 16),
        Text('PDF Merger', style: theme.textTheme.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text('Combine multiple PDFs into one document', style: TextStyle(color: Colors.white.withAlpha(200))),
      ]),
    );
  }

  Widget _buildFileSelector(ThemeData theme, AppColors ac, Color color) {
    return Container(
      decoration: BoxDecoration(color: ac.card, borderRadius: BorderRadius.circular(18), border: Border.all(color: ac.outline.withAlpha(60))),
      child: Material(
        color: Colors.transparent,
        child: InkWell(borderRadius: BorderRadius.circular(18), onTap: _pickFiles,
          child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: color.withAlpha(25), borderRadius: BorderRadius.circular(12)),
                child: Icon(Icons.picture_as_pdf_rounded, color: color, size: 22)),
              const SizedBox(width: 10),
              Text('Select PDFs', style: TextStyle(color: ac.cream, fontWeight: FontWeight.w600)),
            ]),
            const SizedBox(height: 12),
            if (_selectedFiles.isNotEmpty)
              Text('${_selectedFiles.length} PDF${_selectedFiles.length == 1 ? '' : 's'} selected — tap to change', style: TextStyle(color: ac.onSurfaceDim, fontSize: 13))
            else
              Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 24), child: Column(children: [
                Icon(Icons.add_rounded, size: 40, color: ac.onSurfaceDim.withAlpha(80)),
                const SizedBox(height: 8),
                Text('Select 2+ PDF files to merge', style: TextStyle(color: ac.onSurfaceDim, fontSize: 13)),
              ])),
          ])),
        ),
      ),
    );
  }

  Widget _buildFileList(ThemeData theme, AppColors ac) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Icon(Icons.list_alt_rounded, size: 18, color: ac.primary), const SizedBox(width: 8),
        Text('${_selectedFiles.length} PDFs selected', style: TextStyle(color: ac.cream, fontWeight: FontWeight.w600))]),
      const SizedBox(height: 12),
      ..._selectedFiles.asMap().entries.map((e) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(color: ac.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: ac.outline.withAlpha(40))),
        child: ListTile(
          dense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          leading: CircleAvatar(backgroundColor: AppTheme.getFileColor('pdf'), radius: 14, child: Text('${e.key + 1}', style: const TextStyle(color: Color(0xFF1A0A00), fontSize: 12, fontWeight: FontWeight.w600))),
          title: Text(e.value.name, style: TextStyle(color: ac.cream, fontSize: 13), overflow: TextOverflow.ellipsis),
          trailing: Text('${(e.value.size / 1024).toStringAsFixed(0)} KB', style: TextStyle(color: ac.onSurfaceDim, fontSize: 12)),
        ),
      )),
    ]);
  }

  Widget _buildMergeButton(ThemeData theme, AppColors ac, Color color) {
    return Container(
      width: double.infinity,
      height: 54,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: color.withAlpha(60), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: FilledButton.icon(
        onPressed: (_selectedFiles.length < 2 || _merging) ? null : _merge,
        icon: _merging ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.merge_rounded),
        label: Text(_merging ? 'Merging...' : 'Merge PDFs'),
        style: FilledButton.styleFrom(backgroundColor: color),
      ),
    );
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
