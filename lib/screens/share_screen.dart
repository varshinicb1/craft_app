import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/file_item.dart';
import '../theme/app_theme.dart';
import '../services/sharing_service.dart';

class ShareScreen extends StatefulWidget {
  const ShareScreen({super.key});

  @override
  State<ShareScreen> createState() => _ShareScreenState();
}

class _ShareScreenState extends State<ShareScreen> {
  FileItem? _shareFile;
  bool _isGeneratingQR = false;
  String _qrData = '';
  List<Map<String, String>> _nearbyDevices = [];
  bool _isScanning = false;
  String _transferStatus = '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 60,
            pinned: true,
            leading: const SizedBox(),
            title: Row(
              children: [
                Icon(Icons.share_rounded, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text('Share', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
              ],
            ),
            actions: [
              if (_shareFile != null)
                IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => setState(() => _shareFile = null)),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildShareHeader(theme),
                  const SizedBox(height: 24),
                  if (_shareFile != null) ...[
                    _buildShareMethods(theme),
                    const SizedBox(height: 24),
                    _buildQRCodeSection(theme),
                    const SizedBox(height: 24),
                    _buildNearbySection(theme),
                  ],
                  if (_transferStatus.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _buildTransferStatus(theme),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShareHeader(ThemeData theme) {
    final color = _shareFile != null
        ? AppTheme.getFileColor(_shareFile!.extension)
        : theme.colorScheme.primary;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: _pickFile,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  _shareFile != null ? Icons.check_circle_rounded : Icons.file_upload_rounded,
                  color: color,
                  size: 36,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _shareFile?.name ?? 'Select File to Share',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _shareFile != null
                          ? '${_shareFile!.formattedSize}  ·  .${_shareFile!.extension}'
                          : 'Tap to choose a file',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: theme.colorScheme.onSurface.withValues(alpha: 0.3)),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(duration: 400.ms).slideX(begin: 0.1);
  }

  Widget _buildShareMethods(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Share Methods', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 16),
        _buildShareMethodCard(
          theme,
          icon: Icons.ios_share_rounded,
          title: 'System Share',
          subtitle: 'Share via installed apps',
          color: theme.colorScheme.primary,
          onTap: _systemShare,
        ),
        const SizedBox(height: 12),
        _buildShareMethodCard(
          theme,
          icon: Icons.qr_code_2_rounded,
          title: 'QR Code',
          subtitle: 'Generate shareable QR code',
          color: Colors.deepPurple,
          onTap: _generateQR,
        ),
        const SizedBox(height: 12),
        _buildShareMethodCard(
          theme,
          icon: Icons.wifi_tethering_rounded,
          title: 'Nearby Share',
          subtitle: 'Transfer via local network',
          color: Colors.teal,
          onTap: _scanNearby,
        ),
        const SizedBox(height: 12),
        _buildShareMethodCard(
          theme,
          icon: Icons.copy_rounded,
          title: 'Copy to Clipboard',
          subtitle: 'Copy file path for sharing',
          color: Colors.orange,
          onTap: _copyToClipboard,
        ),
      ],
    );
  }

  Widget _buildShareMethodCard(
    ThemeData theme, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        title: Text(title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle, style: theme.textTheme.bodySmall),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
      ),
    );
  }

  Widget _buildQRCodeSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('QR Code', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 16),
        if (_qrData.isNotEmpty)
          Center(
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 20),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  QrImageView(
                    data: _qrData,
                    version: QrVersions.auto,
                    size: 200,
                    backgroundColor: Colors.white,
                    eyeStyle: const QrEyeStyle(
                      eyeShape: QrEyeShape.square,
                      color: Color(0xFF6C63FF),
                    ),
                    dataModuleStyle: const QrDataModuleStyle(
                      dataModuleShape: QrDataModuleShape.square,
                      color: Color(0xFF1A1A2E),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('Scan to receive file', style: theme.textTheme.bodyMedium),
                ],
              ),
            ),
          )
        else if (_isGeneratingQR)
          const Center(child: CircularProgressIndicator())
        else
          Center(
            child: Text('Tap "QR Code" above to generate', style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            )),
          ),
      ],
    );
  }

  Widget _buildNearbySection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Nearby Devices', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        if (_isScanning)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(),
            ),
          )
        else if (_nearbyDevices.isEmpty)
          Center(
            child: Text('No devices found nearby', style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            )),
          )
        else
          ...(_nearbyDevices.map((device) => Card(
            child: ListTile(
              leading: const CircleAvatar(child: Icon(Icons.devices_rounded)),
              title: Text(device['name'] ?? 'Unknown'),
              subtitle: Text('${device['ip'] ?? '?'}:${device['port'] ?? '?'}'),
              trailing: FilledButton.tonal(
                onPressed: () => _sendToDevice(device),
                child: const Text('Send'),
              ),
            ),
          ))),
      ],
    );
  }

  Widget _buildTransferStatus(ThemeData theme) {
    final isError = _transferStatus.contains('Error') || _transferStatus.contains('Failed');
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: (isError ? Colors.red : Colors.green).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: (isError ? Colors.red : Colors.green).withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(isError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
               color: isError ? Colors.red : Colors.green),
          const SizedBox(width: 12),
          Expanded(child: Text(_transferStatus, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.pickFiles(type: FileType.any);
    if (result != null && result.files.isNotEmpty && result.files.first.path != null) {
      setState(() {
        _shareFile = FileItem.fromFile(File(result.files.first.path!));
        _qrData = '';
        _transferStatus = '';
      });
    }
  }

  Future<void> _systemShare() async {
    if (_shareFile == null) return;
    try {
      await Share.shareXFiles(
        [XFile(_shareFile!.path)],
        subject: _shareFile!.name,
      );
    } catch (e) {
      setState(() => _transferStatus = 'Error sharing: $e');
    }
  }

  Future<void> _generateQR() async {
    if (_shareFile == null) return;
    setState(() => _isGeneratingQR = true);

    try {
      final service = SharingService();
      final data = await service.generateShareData(_shareFile!);
      setState(() => _qrData = data);
    } catch (e) {
      setState(() => _transferStatus = 'Error generating QR: $e');
    }
    setState(() => _isGeneratingQR = false);
  }

  Future<void> _scanNearby() async {
    if (_shareFile == null) return;
    setState(() {
      _isScanning = true;
      _transferStatus = '';
    });

    try {
      final service = SharingService();
      final devices = await service.discoverNearbyDevices();
      setState(() => _nearbyDevices = devices);
    } catch (e) {
      setState(() => _transferStatus = 'Error scanning: $e');
    }
    setState(() => _isScanning = false);
  }

  Future<void> _sendToDevice(Map<String, String> device) async {
    if (_shareFile == null) return;
    final deviceName = device['name'] ?? 'Unknown';
    setState(() => _transferStatus = 'Starting server for $deviceName...');

    try {
      final service = SharingService();
      await service.startServer(_shareFile!.path);
      setState(() => _transferStatus = 'Server ready. Device can download now.');
    } catch (e) {
      setState(() => _transferStatus = 'Error sending: $e');
    }
  }

  Future<void> _copyToClipboard() async {
    if (_shareFile == null) return;
    try {
      final service = SharingService();
      await service.copyToClipboard(_shareFile!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('File path copied to clipboard')),
        );
      }
    } catch (e) {
      setState(() => _transferStatus = 'Error copying: $e');
    }
  }
}
