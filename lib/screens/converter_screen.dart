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

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 60,
            pinned: true,
            leading: const SizedBox(),
            title: Row(
              children: [
                Icon(Icons.swap_horiz_rounded, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text('Converter', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
              ],
            ),
            actions: [
              if (_sourceFile != null)
                IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => setState(() => _sourceFile = null)),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSourceSelector(theme),
                  const SizedBox(height: 24),
                  if (_sourceFile != null) ...[
                    _buildFormatSelector(theme),
                    const SizedBox(height: 24),
                    _buildConvertButton(theme),
                    if (_isConverting) ...[
                      const SizedBox(height: 24),
                      _buildProgressIndicator(theme),
                    ],
                    if (_statusMessage.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _buildStatusMessage(theme),
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

  Widget _buildSourceSelector(ThemeData theme) {
    final color = _sourceFile != null
        ? AppTheme.getFileColor(_sourceFile!.extension)
        : theme.colorScheme.primary;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: _pickSourceFile,
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
                child: AnimatedSwitcher(
                  duration: 300.ms,
                  child: Icon(
                    _sourceFile != null
                        ? AppTheme.getFileIcon(_sourceFile!.extension)
                        : Icons.note_add_rounded,
                    key: ValueKey(_sourceFile?.path),
                    color: color,
                    size: 36,
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
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _sourceFile != null
                          ? '${_sourceFile!.formattedSize}  ·  .${_sourceFile!.extension}'
                          : 'Tap to browse files',
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

  Widget _buildFormatSelector(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Convert to', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        ..._formatGroups.entries.map((group) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(group.key, style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
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
                      selectedColor: theme.colorScheme.primary.withValues(alpha: 0.15),
                      avatar: isSelected ? Icon(Icons.check, size: 16, color: theme.colorScheme.primary) : null,
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

  Widget _buildConvertButton(ThemeData theme) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: FilledButton.icon(
        onPressed: _isConverting ? null : _startConversion,
        icon: _isConverting
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.swap_horiz_rounded),
        label: Text(_isConverting ? 'Converting...' : 'Start Conversion'),
        style: FilledButton.styleFrom(
          backgroundColor: theme.colorScheme.primary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
    ).animate().shimmer(duration: 1500.ms);
  }

  Widget _buildProgressIndicator(ThemeData theme) {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: _progress,
            minHeight: 8,
            backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
          ),
        ),
        const SizedBox(height: 8),
        Text('${(_progress * 100).toStringAsFixed(0)}%', style: theme.textTheme.bodySmall),
      ],
    );
  }

  Widget _buildStatusMessage(ThemeData theme) {
    final isError = _statusMessage.contains('Error') || _statusMessage.contains('Failed');
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
          Expanded(child: Text(_statusMessage, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }

  Future<void> _pickSourceFile() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.any);
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
