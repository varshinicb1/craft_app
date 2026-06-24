import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import '../theme/app_theme.dart';

class ImageCompressor extends StatefulWidget {
  const ImageCompressor({super.key});
  @override
  State<ImageCompressor> createState() => _ImageCompressorState();
}

class _ImageCompressorState extends State<ImageCompressor> {
  File? _sourceFile;
  int _quality = 80;
  int _maxWidth = 1920;
  bool _compressing = false;
  String? _statusMessage;
  bool _statusIsError = false;
  int _originalSize = 0;
  int _compressedSize = 0;

  Future<void> _pickImage() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'webp', 'bmp', 'gif', 'tiff'],
    );
    if (result == null || result.files.isEmpty || result.files.first.path == null) return;
    final file = File(result.files.first.path!);
    setState(() {
      _sourceFile = file;
      _originalSize = file.lengthSync();
      _compressedSize = 0;
      _statusMessage = null;
    });
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Future<void> _compress() async {
    if (_sourceFile == null) return;
    setState(() {
      _compressing = true;
      _statusMessage = null;
      _statusIsError = false;
    });

    try {
      final bytes = await _sourceFile!.readAsBytes();
      final image = img.decodeImage(bytes);
      if (image == null) throw Exception('Failed to decode image. Unsupported format.');

      img.Image working = image;
      if (working.width > _maxWidth) {
        final scale = _maxWidth / working.width;
        working = img.copyResize(working, width: _maxWidth, height: (working.height * scale).round());
      }

      List<int> output;
      final ext = p.extension(_sourceFile!.path).toLowerCase();
      if (ext == '.png') {
        output = img.encodePng(working);
      } else if (ext == '.webp') {
        throw Exception('WebP encoding is not supported. Please use JPEG or PNG.');
      } else {
        output = img.encodeJpg(working, quality: _quality);
      }

      final dir = p.dirname(_sourceFile!.path);
      final nameWithoutExt = p.basenameWithoutExtension(_sourceFile!.path);
      final suffix = _quality < 100 ? '_compressed' : '_resized';
      final outputPath = p.join(dir, '$nameWithoutExt$suffix${p.extension(_sourceFile!.path)}');
      await File(outputPath).writeAsBytes(output);

      setState(() {
        _compressedSize = output.length;
        _compressing = false;
        final saved = _originalSize - output.length;
        final pct = _originalSize > 0 ? ((1 - output.length / _originalSize) * 100).toStringAsFixed(1) : '0';
        _statusMessage = 'Saved ${_formatSize(saved)} ($pct% reduction) → $outputPath';
        _statusIsError = false;
      });
    } catch (e) {
      setState(() {
        _compressing = false;
        _statusMessage = 'Compression failed: $e';
        _statusIsError = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = AppTheme.getFileColor('jpg');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Image Compressor'),
        actions: [
          if (_compressing) const Padding(
            padding: EdgeInsets.all(16),
            child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildHeader(theme, color),
          const SizedBox(height: 24),
          _buildSourceSelector(theme, color),
          const SizedBox(height: 24),
          if (_sourceFile != null) ...[
            _buildQualitySlider(theme, color),
            const SizedBox(height: 20),
            _buildResizeSlider(theme, color),
            const SizedBox(height: 24),
            _buildSizeComparison(theme),
            const SizedBox(height: 24),
            _buildCompressButton(theme),
            if (_statusMessage != null) ...[
              const SizedBox(height: 16),
              _buildStatusBanner(theme, color),
            ],
          ],
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [color, color.withValues(alpha: 0.7)]),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.compress_rounded, color: Colors.white, size: 36),
          const SizedBox(height: 12),
          Text('Image Compressor', style: theme.textTheme.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('Reduce file size with quality & resize controls', style: TextStyle(color: Colors.white.withValues(alpha: 0.8))),
        ],
      ),
    );
  }

  Widget _buildSourceSelector(ThemeData theme, Color color) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: _pickImage,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.image_rounded, color: color, size: 20),
                  const SizedBox(width: 8),
                  Text('Select Image', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(height: 12),
              if (_sourceFile != null) ...[
                Row(
                  children: [
                    Icon(Icons.image_rounded, size: 32, color: color),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p.basename(_sourceFile!.path), style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis),
                          Text(_formatSize(_originalSize), style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
                        ],
                      ),
                    ),
                  ],
                ),
              ] else ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Column(
                    children: [
                      Icon(Icons.add_photo_alternate_rounded, size: 40, color: theme.colorScheme.onSurface.withValues(alpha: 0.3)),
                      const SizedBox(height: 8),
                      Text('Tap to select a JPEG or PNG image', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.5))),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQualitySlider(ThemeData theme, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.tune_rounded, color: color, size: 20),
                const SizedBox(width: 8),
                Text('Quality: $_quality%', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 4),
            Text('Lower = smaller file. 80% is recommended.', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
            const SizedBox(height: 8),
            Slider(
              value: _quality.toDouble(),
              min: 10,
              max: 100,
              divisions: 9,
              label: '$_quality%',
              activeColor: color,
              onChanged: (v) => setState(() => _quality = v.round()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResizeSlider(ThemeData theme, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.photo_size_select_large_rounded, color: color, size: 20),
                const SizedBox(width: 8),
                Text('Max Width: ${_maxWidth}px', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 4),
            Text('Images wider than this will be resized proportionally.', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
            const SizedBox(height: 8),
            Slider(
              value: _maxWidth.toDouble(),
              min: 320,
              max: 4096,
              divisions: 11,
              label: '${_maxWidth}px',
              activeColor: color,
              onChanged: (v) => setState(() => _maxWidth = v.round()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSizeComparison(ThemeData theme) {
    if (_compressedSize == 0) return const SizedBox.shrink();
    final pct = _originalSize > 0 ? ((1 - _compressedSize / _originalSize) * 100).toStringAsFixed(1) : '0';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Text('Original', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
                      const SizedBox(height: 4),
                      Text(_formatSize(_originalSize), style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('-$pct%', style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.w700)),
                ),
                Expanded(
                  child: Column(
                    children: [
                      Text('Compressed', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
                      const SizedBox(height: 4),
                      Text(_formatSize(_compressedSize), style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600, color: Colors.green)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: _compressedSize / _originalSize,
                minHeight: 8,
                backgroundColor: Colors.red.withValues(alpha: 0.2),
                color: Colors.green,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompressButton(ThemeData theme) {
    return FilledButton.icon(
      onPressed: _compressing ? null : _compress,
      icon: _compressing
          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
          : const Icon(Icons.compress_rounded),
      label: Text(_compressing ? 'Compressing...' : 'Compress & Save'),
      style: FilledButton.styleFrom(
        minimumSize: const Size(double.infinity, 52),
        backgroundColor: AppTheme.getFileColor('jpg'),
      ),
    );
  }

  Widget _buildStatusBanner(ThemeData theme, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _statusIsError ? theme.colorScheme.error.withValues(alpha: 0.1) : color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _statusIsError ? theme.colorScheme.error.withValues(alpha: 0.3) : color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(_statusIsError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
               color: _statusIsError ? theme.colorScheme.error : color, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(_statusMessage!, style: theme.textTheme.bodySmall?.copyWith(color: _statusIsError ? theme.colorScheme.error : color))),
        ],
      ),
    );
  }
}
