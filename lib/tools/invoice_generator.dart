import 'dart:io';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';

class InvoiceGenerator extends StatefulWidget {
  const InvoiceGenerator({super.key});
  @override
  State<InvoiceGenerator> createState() => _InvoiceGeneratorState();
}

class _InvoiceGeneratorState extends State<InvoiceGenerator> {
  final _formKey = GlobalKey<FormState>();
  final _clientCtrl = TextEditingController();
  final _invoiceNumCtrl = TextEditingController(text: 'INV-${DateTime.now().year}-001');
  final _dateCtrl = TextEditingController(text: DateFormat('yyyy-MM-dd').format(DateTime.now()));
  final List<_InvoiceLineItem> _items = [];
  double _taxRate = 10.0;
  bool _generating = false;

  @override
  void dispose() {
    _clientCtrl.dispose();
    _invoiceNumCtrl.dispose();
    _dateCtrl.dispose();
    for (final item in _items) { item.description.dispose(); item.quantity.dispose(); item.rate.dispose(); }
    super.dispose();
  }

  double get _subtotal => _items.fold(0, (s, item) => s + (double.tryParse(item.quantity.text) ?? 0) * (double.tryParse(item.rate.text) ?? 0));
  double get _tax => _subtotal * _taxRate / 100;
  double get _total => _subtotal + _tax;

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
          build: (ctx) => [
            pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
              pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Text('INVOICE', style: pw.TextStyle(fontSize: 28, fontWeight: pw.FontWeight.bold, color: PdfColors.blue700)),
                pw.Text(_invoiceNumCtrl.text, style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey600)),
              ]),
              pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                pw.Text('Date: ${_dateCtrl.text}', style: const pw.TextStyle(fontSize: 10)),
                pw.Text('Due: ${_dateCtrl.text}', style: const pw.TextStyle(fontSize: 10)),
              ]),
            ]),
            pw.SizedBox(height: 32),
            pw.Header(level: 1, text: 'Bill To'),
            pw.Paragraph(text: _clientCtrl.text.isEmpty ? 'Client Name' : _clientCtrl.text),
            pw.SizedBox(height: 24),
            pw.TableHelper.fromTextArray(
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.blue700),
              cellStyle: const pw.TextStyle(fontSize: 9),
              rowDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5))),
              headers: ['#', 'Description', 'Qty', 'Rate', 'Amount'],
              data: List.generate(_items.length, (i) {
                final item = _items[i];
                final qty = double.tryParse(item.quantity.text) ?? 0;
                final rate = double.tryParse(item.rate.text) ?? 0;
                return [ (i + 1).toString(), item.description.text, qty.toStringAsFixed(0), '\$${rate.toStringAsFixed(2)}', '\$${(qty * rate).toStringAsFixed(2)}' ];
              }),
            ),
            pw.SizedBox(height: 16),
            pw.Row(mainAxisAlignment: pw.MainAxisAlignment.end, children: [
              pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                pw.Text('Subtotal:  \$${_subtotal.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 10)),
                pw.Text('Tax ($_taxRate%):  \$${_tax.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 10)),
                pw.Divider(),
                pw.Text('Total:  \$${_total.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.blue700)),
              ]),
            ]),
            pw.SizedBox(height: 40),
            pw.Divider(),
            pw.Paragraph(text: 'Thank you for your business!', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey500)),
          ],
        ),
      );

      final fileName = 'Invoice_${_invoiceNumCtrl.text}.pdf';
      final filePath = p.join(dir.path, fileName);
      await File(filePath).writeAsBytes(await pdf.save());

      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Invoice saved to Documents/$fileName')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
    setState(() => _generating = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = AppTheme.getFileColor('xls');

    return Scaffold(
      appBar: AppBar(title: const Text('Invoice Generator'),
        actions: [if (_generating) const Padding(padding: EdgeInsets.all(16), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))],
      ),
      body: Form(key: _formKey, child: ListView(padding: const EdgeInsets.all(20), children: [
        _buildHeader(theme, color),
        const SizedBox(height: 24),
        TextFormField(controller: _clientCtrl, decoration: const InputDecoration(labelText: 'Client Name', prefixIcon: Icon(Icons.business_rounded)), validator: (v) => v?.isEmpty == true ? 'Required' : null),
        const SizedBox(height: 12), TextFormField(controller: _invoiceNumCtrl, decoration: const InputDecoration(labelText: 'Invoice Number', prefixIcon: Icon(Icons.tag_rounded))),
        const SizedBox(height: 12), TextFormField(controller: _dateCtrl, decoration: const InputDecoration(labelText: 'Date', prefixIcon: Icon(Icons.calendar_today_rounded))),
        const SizedBox(height: 24),
        Row(children: [Text('Line Items', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)), const Spacer(), TextButton.icon(icon: const Icon(Icons.add_rounded, size: 18), label: const Text('Add Item'), onPressed: () => setState(() => _items.add(_InvoiceLineItem())))]),
        ..._items.asMap().entries.map((e) => _buildLineItem(theme, e.key)),
        const SizedBox(height: 16), _buildTotals(theme),
        const SizedBox(height: 16), Row(children: [Text('Tax Rate: ', style: theme.textTheme.bodyMedium), SizedBox(width: 80, child: TextField(keyboardType: TextInputType.number, decoration: const InputDecoration(suffixText: '%', isDense: true), controller: TextEditingController(text: _taxRate.toString()), onChanged: (v) => setState(() => _taxRate = double.tryParse(v) ?? 0)))]),
        const SizedBox(height: 32),
        FilledButton.icon(onPressed: _generating ? null : _generate, icon: _generating ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.receipt_long_rounded), label: const Text('Generate Invoice PDF'), style: FilledButton.styleFrom(minimumSize: const Size(double.infinity, 52), backgroundColor: color)),
        const SizedBox(height: 32),
      ])),
    );
  }

  Widget _buildHeader(ThemeData theme, Color color) => Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(gradient: LinearGradient(colors: [color, color.withValues(alpha: 0.7)]), borderRadius: BorderRadius.circular(20)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const Icon(Icons.receipt_long_rounded, color: Colors.white, size: 36), const SizedBox(height: 12),
    Text('Invoice Generator', style: theme.textTheme.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
    const SizedBox(height: 4), Text('Generates real PDF invoices with line items', style: TextStyle(color: Colors.white.withValues(alpha: 0.8))),
  ]));

  Widget _buildLineItem(ThemeData theme, int index) {
    final item = _items[index];
    return Card(margin: const EdgeInsets.only(bottom: 12), child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Text('Item ${index + 1}', style: theme.textTheme.titleSmall), const Spacer(), IconButton(icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red), onPressed: () => setState(() => _items.removeAt(index)))]),
      TextField(controller: item.description, decoration: const InputDecoration(labelText: 'Description', isDense: true)),
      const SizedBox(height: 8), Row(children: [Expanded(child: TextField(controller: item.quantity, decoration: const InputDecoration(labelText: 'Qty', isDense: true), keyboardType: TextInputType.number)), const SizedBox(width: 12), Expanded(child: TextField(controller: item.rate, decoration: const InputDecoration(labelText: 'Rate', isDense: true, prefixText: '\$ '), keyboardType: TextInputType.number))]),
    ])));
  }

  Widget _buildTotals(ThemeData theme) => Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: theme.cardColor, borderRadius: BorderRadius.circular(12), border: Border.all(color: theme.dividerColor)), child: Column(children: [
    _totalRow('Subtotal', '\$${_subtotal.toStringAsFixed(2)}', theme),
    const SizedBox(height: 4), _totalRow('Tax ($_taxRate%)', '\$${_tax.toStringAsFixed(2)}', theme),
    const Divider(height: 20), _totalRow('Total', '\$${_total.toStringAsFixed(2)}', theme, bold: true),
  ]));

  Widget _totalRow(String label, String value, ThemeData theme, {bool bold = false}) => Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
    Text(label, style: bold ? theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600) : theme.textTheme.bodyMedium),
    Text(value, style: bold ? theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700, color: theme.colorScheme.primary) : theme.textTheme.bodyMedium),
  ]);
}

class _InvoiceLineItem { final description = TextEditingController(); final quantity = TextEditingController(text: '1'); final rate = TextEditingController(); }
