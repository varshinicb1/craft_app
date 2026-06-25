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
    final ac = theme.extension<AppColors>()!;
    final provider = context.watch<AppProvider>();
    final file = _viewingFile ?? provider.selectedFile;

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
                  child: Icon(Icons.visibility_rounded, color: ac.primary, size: 18),
                ),
                const SizedBox(width: 10),
                Text('Viewer', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600, color: ac.cream)),
              ],
            ),
            actions: [
              if (file != null && file.extension == 'md')
                IconButton(
                  icon: Icon(_showMarkdownRendered ? Icons.code_rounded : Icons.visibility_rounded, color: ac.onSurfaceDim),
                  onPressed: () => setState(() => _showMarkdownRendered = !_showMarkdownRendered),
                  tooltip: _showMarkdownRendered ? 'Show source' : 'Show rendered',
                ),
              Container(
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: ac.outline.withAlpha(80)),
                  color: ac.surfaceVariant,
                ),
                child: IconButton(
                  icon: Icon(Icons.folder_open_rounded, size: 20, color: ac.onSurfaceDim),
                  onPressed: _pickAndView,
                  tooltip: 'Open file',
                ),
              ),
            ],
          ),
          if (file == null)
            SliverFillRemaining(child: _buildEmptyView(theme, ac))
          else ...[
            SliverToBoxAdapter(
              child: _buildFileHeader(theme, ac, file),
            ),
            SliverFillRemaining(
              child: _isLoadingContent
                  ? Center(child: CircularProgressIndicator(color: ac.primary))
                  : _buildContentView(theme, ac, file),
            ),
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
            child: Icon(Icons.visibility_rounded, size: 64, color: ac.primary.withAlpha(100)),
          ).animate().scale(delay: 100.ms, duration: 600.ms, curve: Curves.elasticOut),
          const SizedBox(height: 24),
          Text('No File Selected', style: theme.textTheme.headlineSmall?.copyWith(color: ac.cream)),
          const SizedBox(height: 8),
          Text('Tap the folder icon to open a file', style: TextStyle(color: ac.onSurfaceDim)),
          const SizedBox(height: 24),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(color: ac.primary.withAlpha(40), blurRadius: 16, offset: const Offset(0, 6)),
              ],
            ),
            child: FilledButton.icon(
              onPressed: _pickAndView,
              icon: const Icon(Icons.folder_open_rounded),
              label: const Text('Browse Files'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFileHeader(ThemeData theme, AppColors ac, FileItem file) {
    final color = AppTheme.getFileColor(file.extension);
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
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: color.withAlpha(25),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(AppTheme.getFileIcon(file.extension), color: color, size: 30),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(file.name, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600, color: ac.cream), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(file.formattedSize, style: TextStyle(color: ac.onSurfaceDim, fontSize: 13)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: color.withAlpha(20), borderRadius: BorderRadius.circular(6)),
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

  Widget _buildContentView(ThemeData theme, AppColors ac, FileItem file) {
    if (file.isImage) {
      return _buildImageView(file);
    } else if (file.isVideo) {
      return _buildVideoView();
    } else if (file.isAudio) {
      return AudioPlayerWidget(filePath: file.path);
    } else if (file.isText && _textContent.isNotEmpty) {
      if (file.extension == 'md' && _showMarkdownRendered) {
        return _buildMarkdownView(theme, ac);
      }
      return _buildTextView(theme, ac);
    } else if (file.isModel) {
      return ModelViewer3D(filePath: file.path);
    } else if (file.extension == 'pdf' && _pdfContent.isNotEmpty) {
      return _buildTextView(theme, ac, content: _pdfContent);
    } else {
      return _buildUnsupportedView(theme, ac, file);
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
                Icon(Icons.broken_image_rounded, size: 64, color: Colors.grey.shade600),
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
    final ac = Theme.of(context).extension<AppColors>()!;
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: ac.cardElevated,
              border: Border.all(color: ac.outline.withAlpha(80)),
            ),
            child: IconButton(
              icon: Icon(
                _videoController!.value.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: ac.primary,
              ),
              iconSize: 36,
              onPressed: () {
                _videoController!.value.isPlaying
                    ? _videoController!.pause()
                    : _videoController!.play();
                setState(() {});
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextView(ThemeData theme, AppColors ac, {String? content}) {
    final text = content ?? _textContent;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: ac.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: ac.outline.withAlpha(60)),
        ),
        child: SingleChildScrollView(
          child: SelectableText(
            text,
            style: TextStyle(fontFamily: 'monospace', fontSize: 13, height: 1.5, color: ac.cream),
          ),
        ),
      ),
    );
  }

  Widget _buildMarkdownView(ThemeData theme, AppColors ac) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: ac.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: ac.outline.withAlpha(60)),
        ),
        child: Markdown(
          data: _textContent,
          selectable: true,
          styleSheet: MarkdownStyleSheet(
            h1: theme.textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.w700, color: ac.cream),
            h2: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w600, color: ac.cream),
            h3: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600, color: ac.cream),
            p: TextStyle(color: ac.cream),
            code: TextStyle(
              fontFamily: 'monospace',
              fontSize: 13,
              color: ac.primary,
              backgroundColor: ac.primaryContainer.withAlpha(150),
            ),
            codeblockDecoration: BoxDecoration(
              color: ac.surfaceVariant,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: ac.outline.withAlpha(60)),
            ),
            blockquoteDecoration: BoxDecoration(
              border: Border(left: BorderSide(color: ac.primary, width: 4)),
              color: ac.primary.withAlpha(10),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUnsupportedView(ThemeData theme, AppColors ac, FileItem file) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.preview_rounded, size: 80, color: ac.onSurfaceDim.withAlpha(80)),
          const SizedBox(height: 16),
          Text('Preview not available', style: theme.textTheme.titleMedium?.copyWith(color: ac.cream)),
          const SizedBox(height: 8),
          Text('.${file.extension} files cannot be previewed', style: TextStyle(color: ac.onSurfaceDim)),
        ],
      ),
    );
  }
}
