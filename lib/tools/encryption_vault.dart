import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:encrypt/encrypt.dart' as enc;


class EncryptionVault extends StatefulWidget {
  const EncryptionVault({super.key});
  @override
  State<EncryptionVault> createState() => _EncryptionVaultState();
}

class _EncryptionVaultState extends State<EncryptionVault> {
  File? _selectedFile;
  final _passwordCtrl = TextEditingController();
  bool _obscurePassword = true;
  bool _processing = false;
  String? _statusMessage;
  bool _statusIsError = false;

  @override
  void dispose() {
    _passwordCtrl.dispose();
    super.dispose();
  }

  String _generateSalt() {
    final rand = Random.secure();
    final bytes = List<int>.generate(16, (_) => rand.nextInt(256));
    return base64.encode(bytes);
  }

  enc.Key _deriveKey(String password, String salt) {
    final keyMaterial = password + salt;
    final bytes = utf8.encode(keyMaterial);
    final padded = <int>[];
    for (var i = 0; i < 32; i++) {
      padded.add(bytes[i % bytes.length]);
    }
    return enc.Key(Uint8List.fromList(padded));
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.pickFiles(type: FileType.any);
    if (result == null || result.files.isEmpty || result.files.first.path == null) return;
    setState(() {
      _selectedFile = File(result.files.first.path!);
      _statusMessage = null;
    });
  }

  Future<void> _encryptFile() async {
    if (_selectedFile == null || _passwordCtrl.text.isEmpty) return;
    setState(() { _processing = true; _statusMessage = null; _statusIsError = false; });

    try {
      final bytes = await _selectedFile!.readAsBytes();
      final salt = _generateSalt();
      final key = _deriveKey(_passwordCtrl.text, salt);
      final iv = enc.IV.fromSecureRandom(16);
      final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));

      final encrypted = encrypter.encryptBytes(bytes, iv: iv);
      final combined = Uint8List.fromList([
        ...utf8.encode(salt),
        ...iv.bytes,
        ...encrypted.bytes,
      ]);

      final dir = p.dirname(_selectedFile!.path);
      final name = '${p.basenameWithoutExtension(_selectedFile!.path)}.craft';
      await File(p.join(dir, name)).writeAsBytes(combined);

      setState(() {
        _processing = false;
        _statusMessage = 'Encrypted → $name (AES-256-CBC)';
        _statusIsError = false;
      });
    } catch (e) {
      setState(() { _processing = false; _statusMessage = 'Encryption failed: $e'; _statusIsError = true; });
    }
  }

  Future<void> _decryptFile() async {
    if (_selectedFile == null || _passwordCtrl.text.isEmpty) return;
    setState(() { _processing = true; _statusMessage = null; _statusIsError = false; });

    try {
      final combined = await _selectedFile!.readAsBytes();
      if (combined.length < 40) throw Exception('Invalid encrypted file');

      final salt = utf8.decode(combined.sublist(0, 24).takeWhile((c) => c != 0).toList());
      final iv = enc.IV(Uint8List.fromList(combined.sublist(24, 40)));
      final encryptedBytes = combined.sublist(40);

      final key = _deriveKey(_passwordCtrl.text, salt);
      final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
      final decrypted = encrypter.decryptBytes(
        enc.Encrypted(Uint8List.fromList(encryptedBytes)),
        iv: iv,
      );

      final dir = p.dirname(_selectedFile!.path);
      final stamp = DateTime.now().millisecondsSinceEpoch;
      final name = 'decrypted_$stamp';
      await File(p.join(dir, name)).writeAsBytes(decrypted);

      setState(() {
        _processing = false;
        _statusMessage = 'Decrypted → $name (${decrypted.length} bytes)';
        _statusIsError = false;
      });
    } catch (e) {
      setState(() { _processing = false; _statusMessage = 'Decryption failed: $e'; _statusIsError = true; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const color = Colors.deepPurple;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Encryption Vault'),
        actions: [if (_processing) const Padding(padding: EdgeInsets.all(16), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))],
      ),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        _buildHeader(theme, color), const SizedBox(height: 24),
        _buildFileSelector(theme, color), const SizedBox(height: 20),
        _buildPasswordField(theme, color), const SizedBox(height: 24),
        _buildActionButtons(theme, color),
        if (_statusMessage != null) ...[const SizedBox(height: 16), _buildStatusBanner(theme, color)],
      ]),
    );
  }

  Widget _buildHeader(ThemeData theme, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(gradient: LinearGradient(colors: [color, color.withValues(alpha: 0.7)]), borderRadius: BorderRadius.circular(20)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.lock_rounded, color: Colors.white, size: 36),
        const SizedBox(height: 12),
        Text('Encryption Vault', style: theme.textTheme.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text('AES-256-CBC encrypt/decrypt any file', style: TextStyle(color: Colors.white.withValues(alpha: 0.8))),
      ]),
    );
  }

  Widget _buildFileSelector(ThemeData theme, Color color) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16), onTap: _pickFile,
        child: Padding(padding: const EdgeInsets.all(16), child: Row(children: [
          Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
            child: Icon(Icons.file_present_rounded, color: color, size: 28)),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_selectedFile?.path.split(Platform.pathSeparator).last ?? 'Select File', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
            if (_selectedFile != null) Text('${_selectedFile!.lengthSync()} bytes', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
            if (_selectedFile == null) Text('Tap to pick any file', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.5))),
          ])),
          const Icon(Icons.chevron_right_rounded, color: Colors.grey),
        ])),
      ),
    );
  }

  Widget _buildPasswordField(ThemeData theme, Color color) {
    return Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Icon(Icons.key_rounded, color: color, size: 20), const SizedBox(width: 8), Text('Password', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600))]),
      const SizedBox(height: 12),
      TextField(
        controller: _passwordCtrl,
        obscureText: _obscurePassword,
        decoration: InputDecoration(
          hintText: 'Enter encryption password',
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          suffixIcon: IconButton(icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility), onPressed: () => setState(() => _obscurePassword = !_obscurePassword)),
        ),
      ),
    ])));
  }

  Widget _buildActionButtons(ThemeData theme, Color color) {
    final canAct = _selectedFile != null && _passwordCtrl.text.isNotEmpty && !_processing;
    return Row(children: [
      Expanded(child: FilledButton.icon(
        onPressed: canAct ? _encryptFile : null,
        icon: const Icon(Icons.lock_rounded),
        label: const Text('Encrypt'),
        style: FilledButton.styleFrom(minimumSize: const Size(0, 52), backgroundColor: color),
      )),
      const SizedBox(width: 16),
      Expanded(child: OutlinedButton.icon(
        onPressed: canAct ? _decryptFile : null,
        icon: const Icon(Icons.lock_open_rounded),
        label: const Text('Decrypt'),
        style: OutlinedButton.styleFrom(minimumSize: const Size(0, 52), foregroundColor: color, side: BorderSide(color: color)),
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
        Expanded(child: Text(_statusMessage!, style: theme.textTheme.bodySmall?.copyWith(color: _statusIsError ? theme.colorScheme.error : Colors.green.shade700))),
      ]),
    );
  }
}
