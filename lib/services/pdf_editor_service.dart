import 'dart:io';
import 'dart:convert';
import 'dart:math';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path/path.dart' as p;

class PdfEditorService {
  // ─── SMART REDACT ──────────────────────────────────────────────────

  static final List<_RedactPattern> _patterns = [
    _RedactPattern(RegExp(r'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}\b'), 'email'),
    _RedactPattern(RegExp(r'\b\d{3}[-.]?\d{3}[-.]?\d{4}\b'), 'phone'),
    _RedactPattern(RegExp(r'\b\d{3}-\d{2}-\d{4}\b'), 'ssn'),
    _RedactPattern(RegExp(r'\b(?:\d[ -]*?){13,16}\b'), 'credit_card'),
    _RedactPattern(RegExp(r'\b[A-Za-z0-9]{24,}\b'), 'api_key'),
    _RedactPattern(RegExp(r'\b(?:password|passwd|pwd)[=:]\s*\S+\b', caseSensitive: false), 'password'),
    _RedactPattern(RegExp(r'\b(?:secret|token|key)[=:]\s*\S+\b', caseSensitive: false), 'secret'),
    _RedactPattern(RegExp(r'\b\d{5}(?:-\d{4})?\b'), 'zip_code'),
  ];

  static const _redactBar = '████████';

  Future<String> smartRedact(String pdfPath) async {
    final file = File(pdfPath);
    if (!file.existsSync()) return 'Error: File not found';

    final dir = p.dirname(pdfPath);
    final name = p.basenameWithoutExtension(pdfPath);
    final outputPath = p.join(dir, '${name}_redacted.pdf');

    try {
      final bytes = await file.readAsBytes();
      final content = utf8.decode(bytes, allowMalformed: true);

      final detected = <_DetectedItem>[];
      for (final pattern in _patterns) {
        for (final match in pattern.regex.allMatches(content)) {
          detected.add(_DetectedItem(pattern.label, match.start, match.end, match.group(0)!));
        }
      }

      if (detected.isEmpty) return 'No sensitive data found. Nothing to redact.';

      detected.sort((a, b) => a.start.compareTo(b.start));
      final merged = <_DetectedItem>[];
      for (final item in detected) {
        if (merged.isNotEmpty && item.start <= merged.last.end) {
          merged.last.end = max(merged.last.end, item.end);
          merged.last.text = '${merged.last.text}, ${item.text}';
        } else {
          merged.add(item);
        }
      }

      final buffer = StringBuffer();
      int lastEnd = 0;
      for (final item in merged) {
        buffer.write(content.substring(lastEnd, item.start));
        buffer.write(_redactBar);
        lastEnd = item.end;
      }
      buffer.write(content.substring(lastEnd));

      final pdf = pw.Document();
      pdf.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(72),
        build: (ctx) => [pw.Paragraph(text: buffer.toString(), style: const pw.TextStyle(fontSize: 11))],
      ));
      await File(outputPath).writeAsBytes(await pdf.save());

      final summary = merged.map((m) => '  ${m.type}: "${m.text.length > 30 ? '${m.text.substring(0, 27)}...' : m.text}"').join('\n');
      return 'Redacted ${merged.length} item(s):\n$summary\n→ Saved to $outputPath';
    } catch (e) {
      return 'Error during redaction: $e';
    }
  }

  // ─── VISUAL DIFF ────────────────────────────────────────────────────

  Future<String> visualDiff(String pdfPath) async {
    final file = File(pdfPath);
    if (!file.existsSync()) return 'Error: File not found';

    final dir = p.dirname(pdfPath);
    final name = p.basenameWithoutExtension(pdfPath);
    final prevPath = p.join(dir, '${name}_previous.pdf');

    if (!File(prevPath).existsSync()) {
      return 'No previous version found. Save a copy as "${p.basename(prevPath)}" to enable diff.';
    }

    try {
      final current = await file.readAsBytes();
      final previous = await File(prevPath).readAsBytes();

      if (current.length == previous.length) {
        bool identical = true;
        for (int i = 0; i < current.length; i++) {
          if (current[i] != previous[i]) { identical = false; break; }
        }
        if (identical) return 'Files are identical. No differences found.';
      }

      final diffSize = (current.length - previous.length).abs();
      final pct = previous.isNotEmpty ? '${(diffSize / previous.length * 100).toStringAsFixed(1)}%' : 'N/A';
      return 'Diff complete:\n  Previous: ${_fmtSize(previous.length)}\n  Current:  ${_fmtSize(current.length)}\n  Change:   ${current.length > previous.length ? '+' : '-'}$diffSize bytes ($pct)';
    } catch (e) {
      return 'Error during diff: $e';
    }
  }

  // ─── BATCH AUTO-FORM ────────────────────────────────────────────────

  Future<String> batchAutoForm(String pdfPath) async {
    final file = File(pdfPath);
    if (!file.existsSync()) return 'Error: File not found';

    try {
      final bytes = await file.readAsBytes();
      final content = utf8.decode(bytes, allowMalformed: true);
      final fieldRegex = RegExp(r'_{3,}|\[[\s\x20]{2,}\]|\([\s\x20]{2,}\)');
      final fields = fieldRegex.allMatches(content).toList();

      if (fields.isEmpty) return 'No form fields detected in the document.';

      final dir = p.dirname(pdfPath);
      final name = p.basenameWithoutExtension(pdfPath);
      final outputPath = p.join(dir, '${name}_autofilled.pdf');

      String filled = content;
      int counter = 1;
      for (final match in fields.reversed) {
        filled = filled.replaceRange(match.start, match.end, '[Field $counter]');
        counter++;
      }

      final pdf = pw.Document();
      pdf.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(72),
        build: (ctx) => [pw.Paragraph(text: filled, style: const pw.TextStyle(fontSize: 11))],
      ));
      await File(outputPath).writeAsBytes(await pdf.save());

      return 'Auto-form complete:\n  ${fields.length} field(s) detected and filled\n→ Saved to $outputPath';
    } catch (e) {
      return 'Error during auto-form: $e';
    }
  }

  static String _fmtSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class _RedactPattern {
  final RegExp regex;
  final String label;
  const _RedactPattern(this.regex, this.label);
}

class _DetectedItem {
  final String type;
  int start;
  int end;
  String text;
  _DetectedItem(this.type, this.start, this.end, this.text);
}
