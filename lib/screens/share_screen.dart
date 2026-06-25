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
    final ac = theme.extension<AppColors>()!;

    return Scaffold(
      backgroundColor: ac.bg,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 60,
            pinned: true,
            backgroundColor: ac.bg,
            surfaceTintColor: Colors.transparent,
            leading: const SizedBox(),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: ac.primaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.share_rounded, color: ac.primary, size: 18),
                ),
                const SizedBox(width: 10),
                Text('Share', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600, color: ac.cream)),
              ],
            ),
            actions: [
              if (_shareFile != null)
                IconButton(icon: Icon(Icons.close_rounded, color: ac.onSurfaceDim), onPressed: () => setState(() => _shareFile = null)),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildShareHeader(theme, ac),
                  const SizedBox(height: 24),
                  if (_shareFile != null) ...[
                    _buildShareMethods(theme, ac),
                    const SizedBox(height: 24),
                    _buildQRCodeSection(theme, ac),
                    const SizedBox(height: 24),
                    _buildNearbySection(theme, ac),
                  ],
                  if (_transferStatus.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _buildTransferStatus(theme, ac),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShareHeader(ThemeData theme, AppColors ac) {
    final color = _shareFile != null
        ? AppTheme.getFileColor(_shareFile!.extension)
        : ac.primary;

    return Container(
      decoration: BoxDecoration(
        color: ac.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: ac.outline.withAlpha(60)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: _pickFile,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: color.withAlpha(25),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    _shareFile != null ? Icons.check_circle_rounded : Icons.file_upload_rounded,
                    color: color,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _shareFile?.name ?? 'Select File to Share',
                        style: TextStyle(color: ac.cream, fontWeight: FontWeight.w600, fontSize: 15),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _shareFile != null
                            ? '${_shareFile!.formattedSize}  ·  .${_shareFile!.extension}'
                            : 'Tap to choose a file',
                        style: TextStyle(color: ac.onSurfaceDim, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: ac.onSurfaceDim.withAlpha(120)),
              ],
            ),
          ),
        ),
      ),
    ).animate().fadeIn(duration: 400.ms).slideX(begin: 0.1);
  }

  Widget _buildShareMethods(ThemeData theme, AppColors ac) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Share Methods', style: TextStyle(color: ac.cream, fontWeight: FontWeight.w600, fontSize: 16)),
        const SizedBox(height: 16),
        _buildShareMethodCard(
          theme, ac,
          icon: Icons.ios_share_rounded,
          title: 'System Share',
          subtitle: 'Share via installed apps',
          color: ac.primary,
          onTap: _systemShare,
        ),
        const SizedBox(height: 10),
        _buildShareMethodCard(
          theme, ac,
          icon: Icons.qr_code_2_rounded,
          title: 'QR Code',
          subtitle: 'Generate shareable QR code',
          color: const Color(0xFFCE93D8),
          onTap: _generateQR,
        ),
        const SizedBox(height: 10),
        _buildShareMethodCard(
          theme, ac,
          icon: Icons.wifi_tethering_rounded,
          title: 'Nearby Share',
          subtitle: 'Transfer via local network',
          color: ac.gold,
          onTap: _scanNearby,
        ),
        const SizedBox(height: 10),
        _buildShareMethodCard(
          theme, ac,
          icon: Icons.copy_rounded,
          title: 'Copy to Clipboard',
          subtitle: 'Copy file path for sharing',
          color: const Color(0xFFFFB74D),
          onTap: _copyToClipboard,
        ),
      ],
    );
  }

  Widget _buildShareMethodCard(
    ThemeData theme,
    AppColors ac, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: ac.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ac.outline.withAlpha(60)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withAlpha(25),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: TextStyle(color: ac.cream, fontWeight: FontWeight.w600, fontSize: 14)),
                      const SizedBox(height: 2),
                      Text(subtitle, style: TextStyle(color: ac.onSurfaceDim, fontSize: 12)),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: ac.onSurfaceDim.withAlpha(120)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQRCodeSection(ThemeData theme, AppColors ac) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('QR Code', style: TextStyle(color: ac.cream, fontWeight: FontWeight.w600, fontSize: 16)),
        const SizedBox(height: 16),
        if (_qrData.isNotEmpty)
          Center(
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
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
                      color: Color(0xFFD4A574),
                    ),
                    dataModuleStyle: const QrDataModuleStyle(
                      dataModuleShape: QrDataModuleShape.square,
                      color: Color(0xFF1E120D),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('Scan to receive file', style: TextStyle(color: ac.cream)),
                ],
              ),
            ),
          )
        else if (_isGeneratingQR)
          Center(child: CircularProgressIndicator(color: ac.primary))
        else
          Center(
            child: Text('Tap "QR Code" above to generate', style: TextStyle(color: ac.onSurfaceDim)),
          ),
      ],
    );
  }

  Widget _buildNearbySection(ThemeData theme, AppColors ac) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Nearby Devices', style: TextStyle(color: ac.cream, fontWeight: FontWeight.w600, fontSize: 16)),
        const SizedBox(height: 12),
        if (_isScanning)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: CircularProgressIndicator(color: ac.primary),
            ),
          )
        else if (_nearbyDevices.isEmpty)
          Center(
            child: Text('No devices found nearby', style: TextStyle(color: ac.onSurfaceDim)),
          )
        else
          ...(_nearbyDevices.map((device) => Container(
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: ac.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: ac.outline.withAlpha(60)),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.all(12),
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: ac.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.devices_rounded, color: ac.primary),
              ),
              title: Text(device['name'] ?? 'Unknown', style: TextStyle(color: ac.cream)),
              subtitle: Text('${device['ip'] ?? '?'}:${device['port'] ?? '?'}', style: TextStyle(color: ac.onSurfaceDim)),
              trailing: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: ac.primary.withAlpha(80)),
                ),
                child: TextButton(
                  onPressed: () => _sendToDevice(device),
                  child: Text('Send', style: TextStyle(color: ac.primary)),
                ),
              ),
            ),
          ))),
      ],
    );
  }

  Widget _buildTransferStatus(ThemeData theme, AppColors ac) {
    final isError = _transferStatus.contains('Error') || _transferStatus.contains('Failed');
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: (isError ? const Color(0xFFCF6679) : const Color(0xFF81C784)).withAlpha(20),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: (isError ? const Color(0xFFCF6679) : const Color(0xFF81C784)).withAlpha(60)),
      ),
      child: Row(
        children: [
          Icon(isError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
               color: isError ? const Color(0xFFCF6679) : const Color(0xFF81C784)),
          const SizedBox(width: 12),
          Expanded(child: Text(_transferStatus, style: TextStyle(color: ac.cream))),
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
