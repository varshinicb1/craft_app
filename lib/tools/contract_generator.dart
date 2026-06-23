import 'dart:io';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../theme/app_theme.dart';

class ContractGenerator extends StatefulWidget {
  const ContractGenerator({super.key});
  @override
  State<ContractGenerator> createState() => _ContractGeneratorState();
}

class _ContractGeneratorState extends State<ContractGenerator> {
  final _formKey = GlobalKey<FormState>();
  final _partyACtrl = TextEditingController();
  final _partyBCtrl = TextEditingController();
  final _effectiveDateCtrl = TextEditingController(text: DateTime.now().toIso8601String().split('T')[0]);
  final _termsCtrl = TextEditingController();
  String _contractType = 'Service Agreement';
  final _types = ['Service Agreement','Non-Disclosure Agreement','Freelance Contract','Employment Contract','Partnership Agreement'];
  bool _generating = false;

  @override
  void dispose() { _partyACtrl.dispose(); _partyBCtrl.dispose(); _effectiveDateCtrl.dispose(); _termsCtrl.dispose(); super.dispose(); }

  String get _boilerplate {
    switch (_contractType) {
      case 'Non-Disclosure Agreement': return 'The Receiving Party agrees to hold all Confidential Information in strict confidence…';
      case 'Freelance Contract': return 'The Freelancer agrees to provide the Services described herein…';
      case 'Employment Contract': return 'The Employee agrees to perform the duties of the position…';
      case 'Partnership Agreement': return 'The Partners agree to contribute resources and share profits…';
      default: return 'Party A agrees to provide Services to Party B under the terms set forth…';
    }
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
          pw.Header(level: 0, text: _contractType),
          pw.SizedBox(height: 16),
          pw.Paragraph(text: 'This $_contractType (the "Agreement") is entered into on ${_effectiveDateCtrl.text} by and between:'),
          pw.SizedBox(height: 8),
          pw.Paragraph(text: 'Party A: ${_partyACtrl.text.isEmpty ? "________________" : _partyACtrl.text}'),
          pw.Paragraph(text: 'Party B: ${_partyBCtrl.text.isEmpty ? "________________" : _partyBCtrl.text}'),
          pw.SizedBox(height: 24),
          pw.Header(level: 1, text: 'Terms'),
          pw.Paragraph(text: _boilerplate),
          pw.SizedBox(height: 16),
          if (_termsCtrl.text.isNotEmpty) ...[pw.Header(level: 1, text: 'Additional Terms'), pw.Paragraph(text: _termsCtrl.text)],
          pw.SizedBox(height: 24),
          pw.Header(level: 1, text: 'Standard Provisions'),
          for (final clause in ['Confidentiality', 'Term and Termination', 'Limitation of Liability', 'Governing Law', 'Dispute Resolution'])
            pw.Paragraph(text: '$clause: This shall be governed by the laws of the applicable jurisdiction.', style: const pw.TextStyle(fontSize: 9)),
          pw.SizedBox(height: 40),
          pw.Divider(),
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [pw.Text('__________________________'), pw.Text('Party A Signature', style: const pw.TextStyle(fontSize: 8))]),
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [pw.Text('__________________________'), pw.Text('Party B Signature', style: const pw.TextStyle(fontSize: 8))]),
          ]),
        ],
      ));

      final fileName = 'Contract_${_contractType.replaceAll(' ', '_')}.pdf';
      final filePath = p.join(dir.path, fileName);
      await File(filePath).writeAsBytes(await pdf.save());

      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Contract saved to Documents/$fileName')));
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'))); }
    setState(() => _generating = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context); final color = AppTheme.getFileColor('docx');
    return Scaffold(
      appBar: AppBar(title: const Text('Contract Builder'), actions: [if (_generating) const Padding(padding: EdgeInsets.all(16), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))]),
      body: Form(key: _formKey, child: ListView(padding: const EdgeInsets.all(20), children: [
        _buildHeader(theme, color), const SizedBox(height: 24),
        Text('Contract Type', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)), const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _contractType,
          items: _types.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
          onChanged: (v) => setState(() => _contractType = v!),
          decoration: const InputDecoration(prefixIcon: Icon(Icons.description_rounded)),
        ),
        const SizedBox(height: 24), TextFormField(controller: _partyACtrl, decoration: const InputDecoration(labelText: 'Party A (You)', prefixIcon: Icon(Icons.person_rounded)), validator: (v) => v?.isEmpty == true ? 'Required' : null),
        const SizedBox(height: 12), TextFormField(controller: _partyBCtrl, decoration: const InputDecoration(labelText: 'Party B', prefixIcon: Icon(Icons.business_rounded)), validator: (v) => v?.isEmpty == true ? 'Required' : null),
        const SizedBox(height: 12), TextFormField(controller: _effectiveDateCtrl, decoration: const InputDecoration(labelText: 'Date', prefixIcon: Icon(Icons.calendar_today_rounded))),
        const SizedBox(height: 24), Text('Terms & Conditions', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)), const SizedBox(height: 12),
        TextFormField(controller: _termsCtrl, decoration: const InputDecoration(labelText: 'Custom terms (optional)', alignLabelWithHint: true), maxLines: 6),
        const SizedBox(height: 32), FilledButton.icon(onPressed: _generating ? null : _generate, icon: _generating ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.gavel_rounded), label: const Text('Generate Contract PDF'), style: FilledButton.styleFrom(minimumSize: const Size(double.infinity, 52), backgroundColor: color)),
        const SizedBox(height: 32),
      ])),
    );
  }

  Widget _buildHeader(ThemeData theme, Color color) => Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(gradient: LinearGradient(colors: [color, color.withValues(alpha: 0.7)]), borderRadius: BorderRadius.circular(20)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Icon(Icons.gavel_rounded, color: Colors.white, size: 36), const SizedBox(height: 12), Text('Contract Builder', style: theme.textTheme.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w700)), const SizedBox(height: 4), Text('Generates real PDF legal contracts', style: TextStyle(color: Colors.white.withValues(alpha: 0.8)))]));
}
