import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:video_player/video_player.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../models/file_item.dart';
import '../widgets/model_viewer_3d.dart';
import '../widgets/audio_player_widget.dart';
import '../services/isolate_service.dart';

class ViewerScreen extends StatefulWidget {
  const ViewerScreen({super.key});

  @override
  State<ViewerScreen> createState() => _ViewerScreenState();
}

class _ViewerScreenState extends State<ViewerScreen> {
  FileItem? _viewingFile;
  VideoPlayerController? _videoController;
  String _textContent = '';
  String _pdfContent = '';
  bool _isLoadingContent = false;
  bool _showMarkdownRendered = true;

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _pickAndView() async {
    final result = await FilePicker.pickFiles(type: FileType.any);
    if (result != null && result.files.isNotEmpty && result.files.first.path != null) {
      final file = FileItem.fromFile(File(result.files.first.path!));
      setState(() => _viewingFile = file);
      _loadContent(file);
    }
  }

  Future<void> _loadContent(FileItem file) async {
    setState(() => _isLoadingContent = true);
    _textContent = '';
    _pdfContent = '';

    if (file.isImage && file.extension != 'svg') {
      setState(() => _isLoadingContent = false);
    } else if (file.isVideo) {
      _videoController?.dispose();
      _videoController = VideoPlayerController.file(File(file.path));
      await _videoController!.initialize();
      setState(() => _isLoadingContent = false);
    } else if (file.isAudio) {
      setState(() => _isLoadingContent = false);
    } else if (file.isText) {
      try {
        _textContent = await IsolateService.instance.readTextFile(file.path);
      } catch (e) {
        _textContent = 'Error reading file: $e';
      }
      setState(() => _isLoadingContent = false);
    } else if (file.isModel) {
      setState(() => _isLoadingContent = false);
    } else if (file.extension == 'pdf') {
      try {
        _pdfContent = await IsolateService.instance.readTextFile(file.path);
      } catch (e) {
        _pdfContent = 'Error reading PDF: $e';
      }
      setState(() => _isLoadingContent = false);
    } else {
      setState(() => _isLoadingContent = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = context.watch<AppProvider>();
    final file = _viewingFile ?? provider.selectedFile;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 60,
            pinned: true,
            leading: const SizedBox(),
            title: Row(
              children: [
                Icon(Icons.visibility_rounded, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text('Viewer', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
              ],
            ),
            actions: [
              if (file != null && file.extension == 'md')
                IconButton(
                  icon: Icon(_showMarkdownRendered ? Icons.code_rounded : Icons.visibility_rounded),
                  onPressed: () => setState(() => _showMarkdownRendered = !_showMarkdownRendered),
                  tooltip: _showMarkdownRendered ? 'Show source' : 'Show rendered',
                ),
              IconButton(
                icon: const Icon(Icons.folder_open_rounded),
                onPressed: _pickAndView,
                tooltip: 'Open file',
              ),
            ],
          ),
          if (file == null)
            SliverFillRemaining(child: _buildEmptyView(theme))
          else ...[
            SliverToBoxAdapter(
              child: _buildFileHeader(theme, file),
            ),
            SliverFillRemaining(
              child: _isLoadingContent
                  ? const Center(child: CircularProgressIndicator())
                  : _buildContentView(theme, file),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyView(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.visibility_rounded, size: 64, color: theme.colorScheme.primary.withValues(alpha: 0.4)),
          ).animate().scale(delay: 100.ms, duration: 600.ms, curve: Curves.elasticOut),
          const SizedBox(height: 24),
          Text('No File Selected', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text('Tap the folder icon to open a file', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.5))),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _pickAndView,
            icon: const Icon(Icons.folder_open_rounded),
            label: const Text('Browse Files'),
          ),
        ],
      ),
    );
  }

  Widget _buildFileHeader(ThemeData theme, FileItem file) {
    final color = AppTheme.getFileColor(file.extension);
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(AppTheme.getFileIcon(file.extension), color: color, size: 32),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(file.name, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text('${file.formattedSize}  ·  ', style: theme.textTheme.bodySmall),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
                      child: Text('.${file.extension}', style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w500)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContentView(ThemeData theme, FileItem file) {
    if (file.isImage) {
      return _buildImageView(file);
    } else if (file.isVideo) {
      return _buildVideoView();
    } else if (file.isAudio) {
      return AudioPlayerWidget(filePath: file.path);
    } else if (file.isText && _textContent.isNotEmpty) {
      if (file.extension == 'md' && _showMarkdownRendered) {
        return _buildMarkdownView(theme);
      }
      return _buildTextView(theme);
    } else if (file.isModel) {
      return ModelViewer3D(filePath: file.path);
    } else if (file.extension == 'pdf' && _pdfContent.isNotEmpty) {
      return _buildTextView(theme, content: _pdfContent);
    } else {
      return _buildUnsupportedView(theme, file);
    }
  }

  Widget _buildImageView(FileItem file) {
    return InteractiveViewer(
      minScale: 0.5,
      maxScale: 5.0,
      child: Center(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.file(
            File(file.path),
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.broken_image_rounded, size: 64, color: Colors.grey.shade400),
                const SizedBox(height: 8),
                const Text('Unable to load image'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVideoView() {
    if (_videoController == null || !_videoController!.value.isInitialized) {
      return const Center(child: Text('Video not available'));
    }
    return Column(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () {
              _videoController!.value.isPlaying
                  ? _videoController!.pause()
                  : _videoController!.play();
              setState(() {});
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: VideoPlayer(_videoController!),
            ),
          ),
        ),
        _buildVideoControls(),
      ],
    );
  }

  Widget _buildVideoControls() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: Icon(_videoController!.value.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded),
            iconSize: 48,
            onPressed: () {
              _videoController!.value.isPlaying
                  ? _videoController!.pause()
                  : _videoController!.play();
              setState(() {});
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTextView(ThemeData theme, {String? content}) {
    final text = content ?? _textContent;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.dividerColor),
        ),
        child: SingleChildScrollView(
          child: SelectableText(
            text,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 13, height: 1.5),
          ),
        ),
      ),
    );
  }

  Widget _buildMarkdownView(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.dividerColor),
        ),
        child: Markdown(
          data: _textContent,
          selectable: true,
          styleSheet: MarkdownStyleSheet(
            h1: theme.textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.w700),
            h2: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w600),
            h3: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
            p: theme.textTheme.bodyMedium,
            code: TextStyle(
              fontFamily: 'monospace',
              fontSize: 13,
              color: theme.colorScheme.primary,
              backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
            ),
            codeblockDecoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            blockquoteDecoration: BoxDecoration(
              border: Border(left: BorderSide(color: theme.colorScheme.primary, width: 4)),
              color: theme.colorScheme.primary.withValues(alpha: 0.05),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUnsupportedView(ThemeData theme, FileItem file) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.preview_rounded, size: 80, color: theme.colorScheme.onSurface.withValues(alpha: 0.2)),
          const SizedBox(height: 16),
          Text('Preview not available', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text('.${file.extension} files cannot be previewed', style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}
