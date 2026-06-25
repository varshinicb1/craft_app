import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import '../theme/app_theme.dart';

class ImageEditor extends StatefulWidget {
  const ImageEditor({super.key});
  @override
  State<ImageEditor> createState() => _ImageEditorState();
}

class _ImageEditorState extends State<ImageEditor> {
  File? _sourceFile;
  img.Image? _workingImage;
  bool _processing = false;
  String? _statusMessage;
  bool _statusIsError = false;

  Future<void> _pickImage() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'bmp', 'gif', 'tiff'],
    );
    if (result == null || result.files.isEmpty || result.files.first.path == null) return;
    final file = File(result.files.first.path!);
    final bytes = await file.readAsBytes();
    final image = img.decodeImage(bytes);
    setState(() {
      _sourceFile = file;
      _workingImage = image;
      _statusMessage = null;
    });
  }

  void _rotate(int degrees) {
    if (_workingImage == null) return;
    setState(() {
      _workingImage = img.copyRotate(_workingImage!, angle: degrees);
      _statusMessage = 'Rotated $degrees°';
      _statusIsError = false;
    });
  }

  void _flipHorizontal() {
    if (_workingImage == null) return;
    setState(() {
      _workingImage = img.flipHorizontal(_workingImage!);
      _statusMessage = 'Flipped horizontally';
      _statusIsError = false;
    });
  }

  void _flipVertical() {
    if (_workingImage == null) return;
    setState(() {
      _workingImage = img.flipVertical(_workingImage!);
      _statusMessage = 'Flipped vertically';
      _statusIsError = false;
    });
  }

  void _cropSquare() {
    if (_workingImage == null) return;
    final size = min(_workingImage!.width, _workingImage!.height);
    final x = (_workingImage!.width - size) ~/ 2;
    final y = (_workingImage!.height - size) ~/ 2;
    setState(() {
      _workingImage = img.copyCrop(_workingImage!, x: x, y: y, width: size, height: size);
      _statusMessage = 'Cropped to square (${size}x$size)';
      _statusIsError = false;
    });
  }

  void _grayscale() {
    if (_workingImage == null) return;
    setState(() {
      _workingImage = img.grayscale(_workingImage!);
      _statusMessage = 'Grayscale filter applied';
      _statusIsError = false;
    });
  }

  void _sepia() {
    if (_workingImage == null) return;
    setState(() {
      _workingImage = img.colorOffset(_workingImage!, red: 0.393, green: 0.349, blue: 0.272);
      _statusMessage = 'Sepia filter applied';
      _statusIsError = false;
    });
  }

  void _invert() {
    if (_workingImage == null) return;
    setState(() {
      _workingImage = img.invert(_workingImage!);
      _statusMessage = 'Colors inverted';
      _statusIsError = false;
    });
  }

  void _resizeHalf() {
    if (_workingImage == null) return;
    setState(() {
      _workingImage = img.copyResize(_workingImage!, width: _workingImage!.width ~/ 2);
      _statusMessage = 'Resized to 50% (${_workingImage!.width}x${_workingImage!.height})';
      _statusIsError = false;
    });
  }

  Future<void> _save() async {
    if (_workingImage == null || _sourceFile == null) return;
    setState(() { _processing = true; _statusMessage = null; _statusIsError = false; });

    try {
      final ext = p.extension(_sourceFile!.path).toLowerCase();
      List<int> output;
      if (ext == '.png') {
        output = img.encodePng(_workingImage!);
      } else {
        output = img.encodeJpg(_workingImage!, quality: 95);
      }

      final dir = p.dirname(_sourceFile!.path);
      final name = '${p.basenameWithoutExtension(_sourceFile!.path)}_edited$ext';
      await File(p.join(dir, name)).writeAsBytes(output);

      setState(() {
        _processing = false;
        _statusMessage = 'Saved as $name (${output.length} bytes)';
        _statusIsError = false;
      });
    } catch (e) {
      setState(() { _processing = false; _statusMessage = 'Save failed: $e'; _statusIsError = true; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = AppTheme.getFileColor('jpg');
    return Scaffold(
      appBar: AppBar(
        title: const Text('Image Editor'),
        actions: [_processing ? const Padding(padding: EdgeInsets.all(16), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))) : const SizedBox()],
      ),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        _buildHeader(theme, color),
        const SizedBox(height: 24),
        _buildPreview(theme, color),
        if (_workingImage != null) ...[
          const SizedBox(height: 20),
          _buildToolbar(theme, color),
          const SizedBox(height: 20),
          _buildInfo(theme),
          const SizedBox(height: 20),
          _buildSaveButton(theme, color),
        ],
        if (_statusMessage != null) ...[const SizedBox(height: 16), _buildStatusBanner(theme, color)],
        const SizedBox(height: 32),
      ]),
    );
  }

  Widget _buildHeader(ThemeData theme, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(gradient: LinearGradient(colors: [color, color.withValues(alpha: 0.7)]), borderRadius: BorderRadius.circular(20)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.edit_rounded, color: Colors.white, size: 36),
        const SizedBox(height: 12),
        Text('Image Editor', style: theme.textTheme.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text('Crop, rotate, flip, filters & resize', style: TextStyle(color: Colors.white.withValues(alpha: 0.8))),
      ]),
    );
  }

  Widget _buildPreview(ThemeData theme, Color color) {
    if (_sourceFile == null) {
      return Card(child: InkWell(
        borderRadius: BorderRadius.circular(16), onTap: _pickImage,
        child: Container(width: double.infinity, padding: const EdgeInsets.all(40), child: Column(children: [
          Icon(Icons.add_photo_alternate_rounded, size: 48, color: theme.colorScheme.onSurface.withValues(alpha: 0.3)),
          const SizedBox(height: 12),
          Text('Tap to open image', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.5))),
        ])),
      ));
    }
    return Card(child: ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Image.memory(
        img.encodeJpg(_workingImage!, quality: 90),
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => const Padding(padding: EdgeInsets.all(40), child: Icon(Icons.broken_image_rounded, size: 64)),
      ),
    ));
  }

  Widget _buildToolbar(ThemeData theme, Color color) {
    return Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Tools', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
      const SizedBox(height: 12),
      Wrap(spacing: 8, runSpacing: 8, children: [
        _toolChip(Icons.rotate_left_rounded, 'Rotate L', () => _rotate(-90), color, theme),
        _toolChip(Icons.rotate_right_rounded, 'Rotate R', () => _rotate(90), color, theme),
        _toolChip(Icons.flip_rounded, 'Flip H', _flipHorizontal, color, theme),
        _toolChip(Icons.flip_to_front_rounded, 'Flip V', _flipVertical, color, theme),
        _toolChip(Icons.crop_square_rounded, 'Crop Sq', _cropSquare, color, theme),
        _toolChip(Icons.filter_b_and_w_rounded, 'Grayscale', _grayscale, color, theme),
        _toolChip(Icons.filter_vintage_rounded, 'Sepia', _sepia, color, theme),
        _toolChip(Icons.invert_colors_rounded, 'Invert', _invert, color, theme),
        _toolChip(Icons.photo_size_select_small_rounded, 'Resize 50%', _resizeHalf, color, theme),
      ]),
    ])));
  }

  Widget _toolChip(IconData icon, String label, VoidCallback onTap, Color color, ThemeData theme) {
    return ActionChip(
      avatar: Icon(icon, size: 16, color: color),
      label: Text(label, style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface)),
      onPressed: onTap,
      side: BorderSide(color: color.withValues(alpha: 0.3)),
    );
  }

  Widget _buildInfo(ThemeData theme) {
    final w = _workingImage!.width;
    final h = _workingImage!.height;
    return Card(child: Padding(padding: const EdgeInsets.all(16), child: Row(children: [
      const Icon(Icons.info_outline_rounded, size: 20),
      const SizedBox(width: 12),
      Text('${w}x$h px', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500)),
      const Spacer(),
      Text('${(_sourceFile!.lengthSync() / 1024).toStringAsFixed(0)} KB original', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.5))),
    ])));
  }

  Widget _buildSaveButton(ThemeData theme, Color color) {
    return FilledButton.icon(
      onPressed: _processing ? null : _save,
      icon: const Icon(Icons.save_rounded),
      label: const Text('Save Edited Image'),
      style: FilledButton.styleFrom(minimumSize: const Size(double.infinity, 52), backgroundColor: color),
    );
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
        Expanded(child: Text(_statusMessage!, style: theme.textTheme.bodySmall)),
      ]),
    );
  }
}
