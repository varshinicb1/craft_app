import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_theme.dart';
import '../models/file_item.dart';
import '../services/isolate_service.dart';

class ConverterScreen extends StatefulWidget {
  const ConverterScreen({super.key});

  @override
  State<ConverterScreen> createState() => _ConverterScreenState();
}

class _ConverterScreenState extends State<ConverterScreen> {
  FileItem? _sourceFile;
  String _targetFormat = 'pdf';
  bool _isConverting = false;
  String _statusMessage = '';
  double _progress = 0;

  final _formatGroups = {
    'Documents': ['pdf', 'docx', 'txt', 'html', 'md'],
    'Images': ['png', 'jpg', 'webp', 'bmp', 'svg'],
    'Data': ['csv', 'json', 'xml', 'yaml'],
    'Code': ['html', 'css', 'js', 'py', 'dart'],
  };

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
                  child: Icon(Icons.swap_horiz_rounded, color: ac.primary, size: 18),
                ),
                const SizedBox(width: 10),
                Text('Converter', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600, color: ac.cream)),
              ],
            ),
            actions: [
              if (_sourceFile != null)
                IconButton(icon: Icon(Icons.close_rounded, color: ac.onSurfaceDim), onPressed: () => setState(() => _sourceFile = null)),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSourceSelector(theme, ac),
                  const SizedBox(height: 24),
                  if (_sourceFile != null) ...[
                    _buildFormatSelector(theme, ac),
                    const SizedBox(height: 24),
                    _buildConvertButton(theme, ac),
                    if (_isConverting) ...[
                      const SizedBox(height: 24),
                      _buildProgressIndicator(theme, ac),
                    ],
                    if (_statusMessage.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _buildStatusMessage(theme, ac),
                    ],
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSourceSelector(ThemeData theme, AppColors ac) {
    final color = _sourceFile != null
        ? AppTheme.getFileColor(_sourceFile!.extension)
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
          onTap: _pickSourceFile,
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
                  child: AnimatedSwitcher(
                    duration: 300.ms,
                    child: Icon(
                      _sourceFile != null
                          ? AppTheme.getFileIcon(_sourceFile!.extension)
                          : Icons.note_add_rounded,
                      key: ValueKey(_sourceFile?.path),
                      color: color,
                      size: 32,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _sourceFile?.name ?? 'Select Source File',
                        style: TextStyle(color: ac.cream, fontWeight: FontWeight.w600, fontSize: 15),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _sourceFile != null
                            ? '${_sourceFile!.formattedSize}  ·  .${_sourceFile!.extension}'
                            : 'Tap to browse files',
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

  Widget _buildFormatSelector(ThemeData theme, AppColors ac) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Convert to', style: TextStyle(color: ac.cream, fontWeight: FontWeight.w600, fontSize: 16)),
        const SizedBox(height: 16),
        ..._formatGroups.entries.map((group) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(group.key, style: TextStyle(color: ac.onSurfaceDim, fontSize: 12, letterSpacing: 0.5)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: group.value.map((fmt) {
                    final isSelected = _targetFormat == fmt;
                    return ChoiceChip(
                      label: Text('.$fmt'),
                      selected: isSelected,
                      onSelected: (_) => setState(() => _targetFormat = fmt),
                      selectedColor: ac.primaryContainer,
                      backgroundColor: ac.surfaceVariant,
                      side: BorderSide(color: isSelected ? ac.primary.withAlpha(80) : ac.outline.withAlpha(60)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      labelStyle: TextStyle(color: isSelected ? ac.primary : ac.onSurfaceDim, fontSize: 13),
                      avatar: isSelected ? Icon(Icons.check, size: 14, color: ac.primary) : null,
                    );
                  }).toList(),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildConvertButton(ThemeData theme, AppColors ac) {
    return Container(
      width: double.infinity,
      height: 54,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: ac.primary.withAlpha(50), blurRadius: 16, offset: const Offset(0, 6)),
        ],
      ),
      child: FilledButton.icon(
        onPressed: _isConverting ? null : _startConversion,
        icon: _isConverting
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.swap_horiz_rounded),
        label: Text(_isConverting ? 'Converting...' : 'Start Conversion'),
      ),
    );
  }

  Widget _buildProgressIndicator(ThemeData theme, AppColors ac) {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: _progress,
            minHeight: 8,
            backgroundColor: ac.primary.withAlpha(20),
          ),
        ),
        const SizedBox(height: 8),
        Text('${(_progress * 100).toStringAsFixed(0)}%', style: TextStyle(color: ac.onSurfaceDim)),
      ],
    );
  }

  Widget _buildStatusMessage(ThemeData theme, AppColors ac) {
    final isError = _statusMessage.contains('Error') || _statusMessage.contains('Failed');
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
          Expanded(child: Text(_statusMessage, style: TextStyle(color: ac.cream))),
        ],
      ),
    );
  }

  Future<void> _pickSourceFile() async {
    final result = await FilePicker.pickFiles(type: FileType.any);
    if (result != null && result.files.isNotEmpty && result.files.first.path != null) {
      setState(() {
        _sourceFile = FileItem.fromFile(File(result.files.first.path!));
        _statusMessage = '';
        _progress = 0;
      });
    }
  }

  Future<void> _startConversion() async {
    if (_sourceFile == null) return;

    setState(() {
      _isConverting = true;
      _statusMessage = '';
      _progress = 0;
    });

    try {
      final isImage = ['png', 'jpg', 'jpeg', 'webp', 'bmp'].contains(_targetFormat) &&
          ['png', 'jpg', 'jpeg', 'webp', 'bmp', 'gif', 'tiff'].contains(_sourceFile!.extension);

      if (isImage) {
        await IsolateService.instance.convertImage(
          sourcePath: _sourceFile!.path,
          targetFormat: _targetFormat,
          onProgress: (p) {
            if (mounted) setState(() => _progress = p);
          },
        );
      } else {
        await IsolateService.instance.convertFile(
          sourcePath: _sourceFile!.path,
          targetFormat: _targetFormat,
          onProgress: (p) {
            if (mounted) setState(() => _progress = p);
          },
        );
      }
      if (mounted) {
        setState(() {
          _statusMessage = 'Conversion completed successfully!';
          _isConverting = false;
          _progress = 1.0;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _statusMessage = 'Error: ${e.toString()}';
          _isConverting = false;
        });
      }
    }
  }
}
