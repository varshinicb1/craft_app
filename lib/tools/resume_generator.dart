import 'dart:io';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../theme/app_theme.dart';

class ResumeGenerator extends StatefulWidget {
  const ResumeGenerator({super.key});

  @override
  State<ResumeGenerator> createState() => _ResumeGeneratorState();
}

class _ResumeGeneratorState extends State<ResumeGenerator> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _summaryCtrl = TextEditingController();
  final List<_ExperienceEntry> _experiences = [];
  final List<_EducationEntry> _educations = [];
  final List<_SkillEntry> _skills = [];
  String _selectedTemplate = 'Modern';
  bool _generating = false;

  final _templates = ['Modern', 'Classic', 'Minimal'];

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _summaryCtrl.dispose();
    for (final e in _experiences) { e.company.dispose(); e.role.dispose(); e.startDate.dispose(); e.endDate.dispose(); }
    for (final e in _educations) { e.school.dispose(); e.degree.dispose(); e.year.dispose(); }
    for (final s in _skills) { s.name.dispose(); }
    super.dispose();
  }

  Future<void> _generate() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _generating = true);

    try {
      final dir = await getApplicationDocumentsDirectory();
      final pdf = pw.Document();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(72),
          header: (ctx) => pw.Container(
            alignment: pw.Alignment.centerRight,
            child: pw.Text(_selectedTemplate, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey400)),
          ),
          build: (ctx) => [
            pw.Header(level: 0, text: _nameCtrl.text.isEmpty ? 'Your Name' : _nameCtrl.text),
            pw.Paragraph(text: '${_emailCtrl.text}  |  ${_phoneCtrl.text}'),
            pw.SizedBox(height: 8),
            if (_summaryCtrl.text.isNotEmpty) ...[
              pw.Header(level: 1, text: 'Professional Summary'),
              pw.Paragraph(text: _summaryCtrl.text),
            ],
            if (_experiences.isNotEmpty) ...[
              pw.Header(level: 1, text: 'Experience'),
              for (final exp in _experiences)
                if (exp.company.text.isNotEmpty) ...[
                  pw.Header(level: 2, text: exp.company.text),
                  pw.Paragraph(text: '${exp.role.text}  |  ${exp.startDate.text} - ${exp.endDate.text}'),
                  pw.SizedBox(height: 4),
                ],
            ],
            if (_educations.isNotEmpty) ...[
              pw.Header(level: 1, text: 'Education'),
              for (final edu in _educations)
                if (edu.school.text.isNotEmpty) ...[
                  pw.Header(level: 2, text: edu.school.text),
                  pw.Paragraph(text: '${edu.degree.text} — ${edu.year.text}'),
                  pw.SizedBox(height: 4),
                ],
            ],
            if (_skills.isNotEmpty) ...[
              pw.Header(level: 1, text: 'Skills'),
              pw.Paragraph(text: _skills.where((s) => s.name.text.isNotEmpty).map((s) => s.name.text).join('  ·  ')),
            ],
          ],
        ),
      );

      final fileName = 'Resume_${_nameCtrl.text.replaceAll(' ', '_')}.pdf';
      final filePath = p.join(dir.path, fileName);
      await File(filePath).writeAsBytes(await pdf.save());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Resume saved to Documents/$fileName'),
          action: SnackBarAction(label: 'OK', onPressed: () {}),
        ));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
    setState(() => _generating = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = AppTheme.getFileColor('pdf');

    return Scaffold(
      appBar: AppBar(title: const Text('Resume Builder'),
        actions: [if (_generating) const Padding(padding: EdgeInsets.all(16), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _buildHeader(theme, color),
            const SizedBox(height: 24),
            Text('Personal Info', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            TextFormField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Full Name', prefixIcon: Icon(Icons.person_rounded)), validator: (v) => v?.isEmpty == true ? 'Required' : null),
            const SizedBox(height: 12),
            TextFormField(controller: _emailCtrl, decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email_rounded)), keyboardType: TextInputType.emailAddress),
            const SizedBox(height: 12),
            TextFormField(controller: _phoneCtrl, decoration: const InputDecoration(labelText: 'Phone', prefixIcon: Icon(Icons.phone_rounded)), keyboardType: TextInputType.phone),
            const SizedBox(height: 12),
            TextFormField(controller: _summaryCtrl, decoration: const InputDecoration(labelText: 'Professional Summary', alignLabelWithHint: true), maxLines: 4),
            const SizedBox(height: 24),
            Row(children: [Text('Experience', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)), const Spacer(), TextButton.icon(icon: const Icon(Icons.add_rounded, size: 18), label: const Text('Add'), onPressed: () => setState(() => _experiences.add(_ExperienceEntry())))]),
            ..._experiences.asMap().entries.map((e) => _buildExperienceCard(theme, e.key)),
            const SizedBox(height: 24),
            Row(children: [Text('Education', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)), const Spacer(), TextButton.icon(icon: const Icon(Icons.add_rounded, size: 18), label: const Text('Add'), onPressed: () => setState(() => _educations.add(_EducationEntry())))]),
            ..._educations.asMap().entries.map((e) => _buildEducationCard(theme, e.key)),
            const SizedBox(height: 24),
            Row(children: [Text('Skills', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)), const Spacer(), TextButton.icon(icon: const Icon(Icons.add_rounded, size: 18), label: const Text('Add'), onPressed: () => setState(() => _skills.add(_SkillEntry())))]),
            ..._skills.asMap().entries.map((e) => _buildSkillChip(e.key)),
            const SizedBox(height: 24),
            Text('Template', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Wrap(spacing: 8, children: _templates.map((t) => ChoiceChip(label: Text(t), selected: _selectedTemplate == t, onSelected: (_) => setState(() => _selectedTemplate = t))).toList()),
            const SizedBox(height: 32),
            FilledButton.icon(onPressed: _generating ? null : _generate, icon: _generating ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.description_rounded), label: const Text('Generate Resume PDF'), style: FilledButton.styleFrom(minimumSize: const Size(double.infinity, 52), backgroundColor: color)),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, Color color) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(gradient: LinearGradient(colors: [color, color.withValues(alpha: 0.7)]), borderRadius: BorderRadius.circular(20)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Icon(Icons.description_rounded, color: Colors.white, size: 36),
      const SizedBox(height: 12),
      Text('Resume Builder', style: theme.textTheme.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
      const SizedBox(height: 4),
      Text('Generates real PDF resumes', style: TextStyle(color: Colors.white.withValues(alpha: 0.8))),
    ]),
  );

  Widget _buildExperienceCard(ThemeData theme, int index) {
    final exp = _experiences[index];
    return Card(margin: const EdgeInsets.only(bottom: 12), child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Text('Experience ${index + 1}', style: theme.textTheme.titleSmall), const Spacer(), IconButton(icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red), onPressed: () => setState(() => _experiences.removeAt(index)))]),
      TextField(controller: exp.company, decoration: const InputDecoration(labelText: 'Company', isDense: true)),
      const SizedBox(height: 8), TextField(controller: exp.role, decoration: const InputDecoration(labelText: 'Role', isDense: true)),
      const SizedBox(height: 8), Row(children: [Expanded(child: TextField(controller: exp.startDate, decoration: const InputDecoration(labelText: 'Start', isDense: true))), const SizedBox(width: 12), Expanded(child: TextField(controller: exp.endDate, decoration: const InputDecoration(labelText: 'End', isDense: true)))]),
    ])));
  }

  Widget _buildEducationCard(ThemeData theme, int index) {
    final edu = _educations[index];
    return Card(margin: const EdgeInsets.only(bottom: 12), child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Text('Education ${index + 1}', style: theme.textTheme.titleSmall), const Spacer(), IconButton(icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red), onPressed: () => setState(() => _educations.removeAt(index)))]),
      TextField(controller: edu.school, decoration: const InputDecoration(labelText: 'Institution', isDense: true)),
      const SizedBox(height: 8), TextField(controller: edu.degree, decoration: const InputDecoration(labelText: 'Degree', isDense: true)),
      const SizedBox(height: 8), TextField(controller: edu.year, decoration: const InputDecoration(labelText: 'Year', isDense: true)),
    ])));
  }

  Widget _buildSkillChip(int index) {
    final skill = _skills[index];
    return Padding(padding: const EdgeInsets.only(bottom: 8), child: Row(children: [
      Expanded(child: TextField(controller: skill.name, decoration: InputDecoration(labelText: 'Skill ${index + 1}', isDense: true, prefixIcon: const Icon(Icons.code_rounded, size: 18), suffixIcon: IconButton(icon: const Icon(Icons.close, size: 16, color: Colors.red), onPressed: () => setState(() => _skills.removeAt(index)))))),
    ]));
  }
}

class _ExperienceEntry { final company = TextEditingController(); final role = TextEditingController(); final startDate = TextEditingController(); final endDate = TextEditingController(); }
class _EducationEntry { final school = TextEditingController(); final degree = TextEditingController(); final year = TextEditingController(); }
class _SkillEntry { final name = TextEditingController(); }
