import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_theme.dart';
import '../models/file_item.dart';
import '../services/pdf_editor_service.dart';
import '../services/isolate_service.dart';

class EditorScreen extends StatefulWidget {
  const EditorScreen({super.key});

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  FileItem? _editingFile;
  String _textContent = '';
  final _textController = TextEditingController();
  bool _isEditing = false;
  bool _isModified = false;
  String _editorMode = 'text';
  bool _isProcessing = false;
  String _processingStatus = '';

  final _pdfTools = ['Smart Redact', 'Visual Diff', 'Batch Auto-Form'];
  String? _selectedPdfTool;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.pickFiles(type: FileType.any);
    if (result != null && result.files.isNotEmpty && result.files.first.path != null) {
      final file = FileItem.fromFile(File(result.files.first.path!));
      setState(() {
        _editingFile = file;
        _isEditing = false;
        _isModified = false;
        _selectedPdfTool = null;
      });
      _loadFileContent(file);
    }
  }

  Future<void> _loadFileContent(FileItem file) async {
    setState(() => _isProcessing = true);
    try {
      if (file.isText || file.isCode) {
        _textContent = await IsolateService.instance.readTextFile(file.path);
        _textController.text = _textContent;
        setState(() {
          _editorMode = 'text';
          _isEditing = false;
        });
      } else if (file.extension == 'pdf') {
        setState(() => _editorMode = 'pdf');
      } else {
        setState(() => _editorMode = 'binary');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading file: $e')),
        );
      }
    }
    setState(() => _isProcessing = false);
  }

  Future<void> _saveFile() async {
    if (_editingFile == null || !_isModified) return;
    setState(() => _isProcessing = true);

    try {
      await IsolateService.instance.writeTextFile(_editingFile!.path, _textController.text);
      setState(() {
        _textContent = _textController.text;
        _isModified = false;
        _isEditing = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('File saved successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving file: $e')),
        );
      }
    }
    setState(() => _isProcessing = false);
  }

  Future<void> _runPdfTool(String tool) async {
    if (_editingFile == null) return;
    setState(() {
      _selectedPdfTool = tool;
      _isProcessing = true;
      _processingStatus = 'Running $tool...';
    });

    try {
      final editor = PdfEditorService();
      String result;

      switch (tool) {
        case 'Smart Redact':
          result = await editor.smartRedact(_editingFile!.path);
          break;
        case 'Visual Diff':
          result = await editor.visualDiff(_editingFile!.path);
          break;
        case 'Batch Auto-Form':
          result = await editor.batchAutoForm(_editingFile!.path);
          break;
        default:
          result = 'Unknown tool';
      }

      if (mounted) {
        setState(() {
          _processingStatus = 'Completed: $result';
          _isProcessing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result)),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _processingStatus = 'Error: $e';
          _isProcessing = false;
        });
      }
    }
  }

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
                  child: Icon(Icons.edit_note_rounded, color: ac.primary, size: 18),
                ),
                const SizedBox(width: 10),
                Text('Editor', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600, color: ac.cream)),
              ],
            ),
            actions: [
              if (_editingFile != null) ...[
                if (_isModified)
                  IconButton(
                    icon: Icon(Icons.save_rounded, color: ac.primary),
                    onPressed: _saveFile,
                    tooltip: 'Save',
                  ),
                IconButton(icon: Icon(Icons.close_rounded, color: ac.onSurfaceDim), onPressed: () => setState(() => _editingFile = null)),
              ],
              Container(
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: ac.outline.withAlpha(80)),
                  color: ac.surfaceVariant,
                ),
                child: IconButton(
                  icon: Icon(Icons.folder_open_rounded, size: 20, color: ac.onSurfaceDim),
                  onPressed: _pickFile,
                  tooltip: 'Open file',
                ),
              ),
            ],
          ),
          if (_editingFile == null)
            SliverFillRemaining(child: _buildEmptyView(theme, ac))
          else ...[
            SliverToBoxAdapter(
              child: _buildFileHeader(theme, ac),
            ),
            if (_isProcessing)
              SliverToBoxAdapter(
                child: _buildProcessingView(theme, ac),
              )
            else if (_editorMode == 'text')
              SliverFillRemaining(child: _buildTextEditor(theme, ac))
            else if (_editorMode == 'pdf')
              SliverFillRemaining(child: _buildPdfEditor(theme, ac))
            else
              SliverFillRemaining(child: _buildBinaryView(theme, ac)),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyView(ThemeData theme, AppColors ac) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(
              color: ac.primary.withAlpha(15),
              shape: BoxShape.circle,
              border: Border.all(color: ac.primary.withAlpha(40)),
            ),
            child: Icon(Icons.edit_note_rounded, size: 64, color: ac.primary.withAlpha(100)),
          ).animate().scale(duration: 600.ms, curve: Curves.elasticOut),
          const SizedBox(height: 24),
          Text('Open a File to Edit', style: theme.textTheme.headlineSmall?.copyWith(color: ac.cream)),
          const SizedBox(height: 8),
          Text('Supports text, code, and PDF editing', style: TextStyle(color: ac.onSurfaceDim)),
          const SizedBox(height: 24),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(color: ac.primary.withAlpha(40), blurRadius: 16, offset: const Offset(0, 6)),
              ],
            ),
            child: FilledButton.icon(
              onPressed: _pickFile,
              icon: const Icon(Icons.folder_open_rounded),
              label: const Text('Browse Files'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFileHeader(ThemeData theme, AppColors ac) {
    final color = AppTheme.getFileColor(_editingFile!.extension);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ac.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: ac.outline.withAlpha(60)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withAlpha(25),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(AppTheme.getFileIcon(_editingFile!.extension), color: color, size: 26),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_editingFile!.name, style: TextStyle(color: ac.cream, fontWeight: FontWeight.w600, fontSize: 15),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text('${_editingFile!.formattedSize}  ·  .${_editingFile!.extension}', style: TextStyle(color: ac.onSurfaceDim, fontSize: 12)),
              ],
            ),
          ),
          if (_editorMode == 'text')
            Switch(
              value: _isEditing,
              onChanged: (v) => setState(() => _isEditing = v),
            ),
        ],
      ),
    );
  }

  Widget _buildTextEditor(ThemeData theme, AppColors ac) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Container(
        decoration: BoxDecoration(
          color: ac.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: ac.outline.withAlpha(60)),
        ),
        child: _isEditing
            ? TextField(
                controller: _textController,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                style: TextStyle(fontFamily: 'monospace', fontSize: 13, height: 1.6, color: ac.cream),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.all(16),
                ),
                onChanged: (_) {
                  if (!_isModified) setState(() => _isModified = true);
                },
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: SelectableText(
                  _textContent,
                  style: TextStyle(fontFamily: 'monospace', fontSize: 13, height: 1.6, color: ac.cream),
                ),
              ),
      ),
    );
  }

  Widget _buildPdfEditor(ThemeData theme, AppColors ac) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('PDF Tools', style: TextStyle(color: ac.cream, fontWeight: FontWeight.w600, fontSize: 16)),
          const SizedBox(height: 16),
          ..._pdfTools.map((tool) {
            final isSelected = _selectedPdfTool == tool;
            final icons = {
              'Smart Redact': Icons.visibility_off_rounded,
              'Visual Diff': Icons.compare_rounded,
              'Batch Auto-Form': Icons.auto_fix_high_rounded,
            };
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: isSelected ? ac.primaryContainer.withAlpha(60) : ac.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isSelected ? ac.primary.withAlpha(80) : ac.outline.withAlpha(60)),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => _runPdfTool(tool),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: ac.primaryContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(icons[tool] ?? Icons.picture_as_pdf, color: ac.primary, size: 22),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(tool, style: TextStyle(color: ac.cream, fontWeight: FontWeight.w600, fontSize: 14)),
                              const SizedBox(height: 2),
                              Text(_getToolDescription(tool), style: TextStyle(color: ac.onSurfaceDim, fontSize: 12)),
                            ],
                          ),
                        ),
                        Icon(isSelected ? Icons.check_circle : Icons.chevron_right_rounded, color: isSelected ? ac.primary : ac.onSurfaceDim),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildBinaryView(ThemeData theme, AppColors ac) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.code_rounded, size: 80, color: ac.onSurfaceDim.withAlpha(80)),
          const SizedBox(height: 16),
          Text('Binary File', style: theme.textTheme.titleMedium?.copyWith(color: ac.cream)),
          const SizedBox(height: 8),
          Text('Editing not supported for this file type', style: TextStyle(color: ac.onSurfaceDim)),
        ],
      ),
    );
  }

  Widget _buildProcessingView(ThemeData theme, AppColors ac) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          CircularProgressIndicator(color: ac.primary),
          const SizedBox(height: 16),
          Text(_processingStatus, style: TextStyle(color: ac.cream)),
        ],
      ),
    );
  }

  String _getToolDescription(String tool) {
    switch (tool) {
      case 'Smart Redact':
        return 'Automatically detect and redact sensitive information';
      case 'Visual Diff':
        return 'Compare two PDF files side by side';
      case 'Batch Auto-Form':
        return 'Auto-detect and fill form fields in batch';
      default:
        return '';
    }
  }
}
