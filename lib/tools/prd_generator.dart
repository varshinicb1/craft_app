import 'dart:io';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../theme/app_theme.dart';

class PrdGenerator extends StatefulWidget {
  const PrdGenerator({super.key});
  @override
  State<PrdGenerator> createState() => _PrdGeneratorState();
}

class _PrdGeneratorState extends State<PrdGenerator> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _authorCtrl = TextEditingController();
  final _objectiveCtrl = TextEditingController();
  final _scopeCtrl = TextEditingController();
  final List<_PrdRequirement> _requirements = [];
  final List<_PrdFeature> _features = [];
  bool _generating = false;

  @override
  void dispose() {
    _titleCtrl.dispose(); _authorCtrl.dispose(); _objectiveCtrl.dispose(); _scopeCtrl.dispose();
    for (final r in _requirements) { r.description.dispose(); }
    for (final f in _features) { f.name.dispose(); f.description.dispose(); }
    super.dispose();
  }

  Future<void> _generate() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _generating = true);

    try {
      final dir = await getApplicationDocumentsDirectory();
      final pdf = pw.Document();

      pdf.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(72),
        build: (ctx) => [
          pw.Header(level: 0, text: _titleCtrl.text.isEmpty ? 'Product Requirements Document' : _titleCtrl.text),
          pw.Paragraph(text: 'Author: ${_authorCtrl.text.isEmpty ? 'N/A' : _authorCtrl.text}'),
          pw.Paragraph(text: 'Date: ${DateTime.now().toIso8601String().split('T')[0]}'),
          pw.SizedBox(height: 16),
          if (_objectiveCtrl.text.isNotEmpty) ...[pw.Header(level: 1, text: 'Objective'), pw.Paragraph(text: _objectiveCtrl.text)],
          if (_scopeCtrl.text.isNotEmpty) ...[pw.Header(level: 1, text: 'Scope & Constraints'), pw.Paragraph(text: _scopeCtrl.text)],
          pw.SizedBox(height: 16),
          pw.Header(level: 1, text: 'Requirements (${_requirements.length})'),
          for (final req in _requirements)
            pw.Container(margin: const pw.EdgeInsets.only(bottom: 8), child: pw.Row(children: [
              pw.Container(width: 60, padding: const pw.EdgeInsets.all(4), decoration: pw.BoxDecoration(color: req.priority == 'High' ? PdfColors.red100 : req.priority == 'Medium' ? PdfColors.orange100 : PdfColors.grey100), child: pw.Text(req.priority, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))),
              pw.SizedBox(width: 8),
              pw.Expanded(child: pw.Text(req.description.text.isEmpty ? '(empty)' : req.description.text, style: const pw.TextStyle(fontSize: 9))),
            ])),
          pw.SizedBox(height: 16),
          pw.Header(level: 1, text: 'Features (${_features.length})'),
          for (final feat in _features)
            pw.Container(margin: const pw.EdgeInsets.only(bottom: 8), child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text('[${feat.category}] ${feat.name.text.isEmpty ? '(unnamed)' : feat.name.text}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
              pw.Text(feat.description.text.isEmpty ? '' : feat.description.text, style: const pw.TextStyle(fontSize: 9)),
            ])),
        ],
      ));

      final fileName = 'PRD_${_titleCtrl.text.replaceAll(' ', '_')}.pdf';
      final filePath = p.join(dir.path, fileName);
      await File(filePath).writeAsBytes(await pdf.save());

      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('PRD saved to Documents/$fileName')));
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'))); }
    setState(() => _generating = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context); final color = AppTheme.getFileColor('doc');
    return Scaffold(
      appBar: AppBar(title: const Text('PRD Writer'), actions: [if (_generating) const Padding(padding: EdgeInsets.all(16), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))]),
      body: Form(key: _formKey, child: ListView(padding: const EdgeInsets.all(20), children: [
        _buildHeader(theme, color), const SizedBox(height: 24),
        TextFormField(controller: _titleCtrl, decoration: const InputDecoration(labelText: 'Product Title', prefixIcon: Icon(Icons.title_rounded)), validator: (v) => v?.isEmpty == true ? 'Required' : null),
        const SizedBox(height: 12), TextFormField(controller: _authorCtrl, decoration: const InputDecoration(labelText: 'Author', prefixIcon: Icon(Icons.person_rounded))),
        const SizedBox(height: 12), TextFormField(controller: _objectiveCtrl, decoration: const InputDecoration(labelText: 'Product Objective', alignLabelWithHint: true), maxLines: 3),
        const SizedBox(height: 12), TextFormField(controller: _scopeCtrl, decoration: const InputDecoration(labelText: 'Scope & Constraints', alignLabelWithHint: true), maxLines: 3),
        const SizedBox(height: 24), Row(children: [Text('Requirements', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)), const Spacer(), TextButton.icon(icon: const Icon(Icons.add_rounded, size: 18), label: const Text('Add'), onPressed: () => setState(() => _requirements.add(_PrdRequirement())))]),
        ..._requirements.asMap().entries.map((e) => _buildRequirementCard(theme, e.key)),
        const SizedBox(height: 24), Row(children: [Text('Features', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)), const Spacer(), TextButton.icon(icon: const Icon(Icons.add_rounded, size: 18), label: const Text('Add'), onPressed: () => setState(() => _features.add(_PrdFeature())))]),
        ..._features.asMap().entries.map((e) => _buildFeatureCard(theme, e.key)),
        const SizedBox(height: 32), FilledButton.icon(onPressed: _generating ? null : _generate, icon: _generating ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.assignment_rounded), label: const Text('Generate PRD PDF'), style: FilledButton.styleFrom(minimumSize: const Size(double.infinity, 52), backgroundColor: color)),
        const SizedBox(height: 32),
      ])),
    );
  }

  Widget _buildHeader(ThemeData theme, Color color) => Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(gradient: LinearGradient(colors: [color, color.withValues(alpha: 0.7)]), borderRadius: BorderRadius.circular(20)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Icon(Icons.assignment_rounded, color: Colors.white, size: 36), const SizedBox(height: 12), Text('PRD Writer', style: theme.textTheme.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w700)), const SizedBox(height: 4), Text('Generates real PDF product requirement docs', style: TextStyle(color: Colors.white.withValues(alpha: 0.8)))]));

  Widget _buildRequirementCard(ThemeData theme, int index) { final req = _requirements[index]; return Card(margin: const EdgeInsets.only(bottom: 12), child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(children: [Text('REQ-${index + 1}', style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary)), const Spacer(), DropdownButton<String>(value: req.priority, underline: const SizedBox(), items: ['High','Medium','Low'].map((p) => DropdownMenuItem(value: p, child: Text(p, style: const TextStyle(fontSize: 12)))).toList(), onChanged: (v) => setState(() => req.priority = v!)), const SizedBox(width: 8), IconButton(icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red), onPressed: () => setState(() => _requirements.removeAt(index)))]),
    TextField(controller: req.description, decoration: const InputDecoration(labelText: 'Description', isDense: true), maxLines: 2),
  ]))); }

  Widget _buildFeatureCard(ThemeData theme, int index) { final feature = _features[index]; return Card(margin: const EdgeInsets.only(bottom: 12), child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(children: [Text('FTR-${index + 1}', style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.secondary)), const Spacer(), DropdownButton<String>(value: feature.category, underline: const SizedBox(), items: ['UI','API','Core','Data','Security'].map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 12)))).toList(), onChanged: (v) => setState(() => feature.category = v!)), const SizedBox(width: 8), IconButton(icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red), onPressed: () => setState(() => _features.removeAt(index)))]),
    TextField(controller: feature.name, decoration: const InputDecoration(labelText: 'Feature Name', isDense: true)),
    const SizedBox(height: 8), TextField(controller: feature.description, decoration: const InputDecoration(labelText: 'Description', isDense: true), maxLines: 2),
  ]))); }
}

class _PrdRequirement { String priority = 'Medium'; final description = TextEditingController(); }
class _PrdFeature { String category = 'Core'; final name = TextEditingController(); final description = TextEditingController(); }
