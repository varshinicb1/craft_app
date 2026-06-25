import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shimmer/shimmer.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../models/file_item.dart';
import '../database/app_database.dart';
import '../widgets/file_list_tile.dart';
import '../tools/resume_generator.dart';
import '../tools/invoice_generator.dart';
import '../tools/prd_generator.dart';
import '../tools/contract_generator.dart';
import '../tools/archive_extractor.dart';
import '../tools/archive_creator.dart';
import '../tools/image_compressor.dart';
import '../tools/encryption_vault.dart';
import '../tools/pdf_merger.dart';
import '../tools/duplicate_finder.dart';
import '../tools/image_editor.dart';
import '../tools/notes_app.dart';
import '../tools/unit_converter.dart';
import '../screens/settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late AnimationController _fabController;
  late Animation<double> _fabScale;

  @override
  void initState() {
    super.initState();
    _fabController = AnimationController(
      vsync: this,
      duration: 400.ms,
    );
    _fabScale = CurvedAnimation(parent: _fabController, curve: Curves.elasticOut);
    _fabController.forward();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  Future<void> _loadData() async {
    final provider = context.read<AppProvider>();
    await provider.refreshAll();
  }

  @override
  void dispose() {
    _fabController.dispose();
    super.dispose();
  }

  Future<void> _pickFiles() async {
    final result = await FilePicker.pickFiles(
      allowMultiple: true,
      type: FileType.any,
    );

    if (result != null && result.files.isNotEmpty) {
      final files = result.files
          .where((f) => f.path != null)
          .map((f) => FileItem.fromFile(File(f.path!)))
          .toList();

      if (files.isNotEmpty && mounted) {
        await context.read<AppProvider>().addFiles(files);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${files.length} file(s) imported'),
              action: SnackBarAction(label: 'OK', onPressed: () {}),
            ),
          );
        }
      }
    }
  }

  void _showToolPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const _ToolPickerSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ac = theme.extension<AppColors>()!;

    return Scaffold(
      body: Consumer<AppProvider>(
        builder: (context, provider, _) {
          return RefreshIndicator(
            onRefresh: () => provider.refreshAll(),
            child: CustomScrollView(
              slivers: [
                _buildAppBar(theme, ac, provider),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                    child: _buildSearchBar(theme, ac),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _buildStatsRow(theme, ac, provider),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    child: _buildCategoryChips(theme, ac, provider),
                  ),
                ),
                if (provider.isLoading)
                  SliverFillRemaining(
                    child: _buildShimmerList(theme),
                  )
                else ...[
                  if (provider.recentFiles.isNotEmpty) ...[
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                        child: _buildSectionHeader(theme, ac, 'Recent Files', Icons.history_rounded),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: SizedBox(
                        height: 108,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          itemCount: provider.recentFiles.length.clamp(0, 8),
                          separatorBuilder: (_, __) => const SizedBox(width: 12),
                          itemBuilder: (ctx, i) => _buildRecentFileCard(theme, ac, provider.recentFiles[i]),
                        ),
                      ),
                    ),
                  ],
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                      child: _buildSectionHeader(theme, ac, 'All Files', Icons.folder_rounded),
                    ),
                  ),
                  if (provider.isSelectionMode)
                    SliverToBoxAdapter(child: _buildBatchActionBar(theme, ac, provider)),
                  if (provider.files.isEmpty)
                    SliverFillRemaining(
                      child: _buildEmptyState(theme, ac),
                    )
                  else
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (ctx, i) => FileListTile(file: provider.files[i], isSelectionMode: provider.isSelectionMode),
                        childCount: provider.files.length,
                      ),
                    ),
                ],
                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            ),
          );
        },
      ),
      floatingActionButton: ScaleTransition(
        scale: _fabScale,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(color: ac.primary.withAlpha(60), blurRadius: 20, offset: const Offset(0, 8)),
                ],
              ),
              child: FloatingActionButton.small(
                heroTag: 'tools',
                onPressed: _showToolPicker,
                backgroundColor: ac.cardElevated,
                foregroundColor: ac.primary,
                child: const Icon(Icons.auto_fix_high_rounded),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(color: ac.primary.withAlpha(80), blurRadius: 24, offset: const Offset(0, 8)),
                ],
              ),
              child: FloatingActionButton(
                heroTag: 'pick',
                onPressed: _pickFiles,
                backgroundColor: ac.primary,
                foregroundColor: const Color(0xFF1A0A00),
                child: const Icon(Icons.add_rounded),
              ),
            ),
          ],
        ),
      ).animate().shakeX(duration: 200.ms).then().slideX(),
    );
  }

  Widget _buildAppBar(ThemeData theme, AppColors ac, AppProvider provider) {
    return SliverAppBar(
      expandedHeight: 88,
      floating: false,
      pinned: true,
      backgroundColor: ac.bg,
      surfaceTintColor: Colors.transparent,
      flexibleSpace: FlexibleSpaceBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [ac.primary, ac.gold],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(color: ac.primary.withAlpha(60), blurRadius: 12, offset: const Offset(0, 4)),
                ],
              ),
              child: const Icon(Icons.build_circle_rounded, color: Color(0xFF1A0A00), size: 22),
            ),
            const SizedBox(width: 12),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CRAFT',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 3,
                    color: ac.cream,
                    fontSize: 18,
                  ),
                ),
                Text(
                  'File Toolkit',
                  style: TextStyle(fontSize: 10, color: ac.onSurfaceDim, letterSpacing: 1),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        Container(
          margin: const EdgeInsets.only(right: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: ac.outline.withAlpha(80)),
            color: ac.surfaceVariant,
          ),
          child: IconButton(
            icon: Icon(
              provider.themeMode == ThemeMode.dark
                  ? Icons.light_mode_rounded
                  : Icons.dark_mode_rounded,
              size: 20,
            ),
            color: ac.onSurfaceDim,
            onPressed: () {
              final newMode = provider.themeMode == ThemeMode.dark
                  ? ThemeMode.light
                  : ThemeMode.dark;
              provider.setThemeMode(newMode);
            },
          ),
        ),
        Container(
          margin: const EdgeInsets.only(right: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: ac.outline.withAlpha(80)),
            color: ac.surfaceVariant,
          ),
          child: IconButton(
            icon: Icon(Icons.settings_rounded, size: 20, color: ac.onSurfaceDim),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
            tooltip: 'Settings',
          ),
        ),
        PopupMenuButton<String>(
          color: ac.cardElevated,
          surfaceTintColor: Colors.transparent,
          icon: Icon(Icons.more_vert_rounded, color: ac.onSurfaceDim),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: ac.outline.withAlpha(60)),
          ),
          onSelected: (v) async {
            if (v == 'sort_name' || v == 'sort_date' || v == 'sort_size') {
              provider.setSortField(v == 'sort_name' ? 'name' : v == 'sort_date' ? 'date' : 'size');
            } else if (v == 'clear_all') {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Clear All Files'),
                  content: const Text('This will remove all files from the database. Continue?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                    ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Clear')),
                  ],
                ),
              );
              if (confirm == true) {
                await AppDatabase.instance.clearAllFiles();
                await provider.refreshAll();
              }
            }
          },
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'sort_name', child: ListTile(leading: Icon(Icons.sort_by_alpha), title: Text('Sort by Name'), dense: true)),
            const PopupMenuItem(value: 'sort_date', child: ListTile(leading: Icon(Icons.date_range), title: Text('Sort by Date'), dense: true)),
            const PopupMenuItem(value: 'sort_size', child: ListTile(leading: Icon(Icons.storage), title: Text('Sort by Size'), dense: true)),
            const PopupMenuDivider(),
            const PopupMenuItem(value: 'clear_all', child: ListTile(leading: Icon(Icons.delete_sweep, color: Colors.red), title: Text('Clear All', style: TextStyle(color: Colors.red)), dense: true)),
          ],
        ),
      ],
    );
  }

  Widget _buildSearchBar(ThemeData theme, AppColors ac) {
    return Container(
      decoration: BoxDecoration(
        color: ac.surfaceVariant,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ac.outline.withAlpha(80)),
      ),
      child: TextField(
        onChanged: (v) => context.read<AppProvider>().setSearchQuery(v),
        style: TextStyle(color: ac.cream),
        decoration: InputDecoration(
          hintText: 'Search files...',
          prefixIcon: Icon(Icons.search_rounded, color: ac.onSurfaceDim),
          suffixIcon: context.watch<AppProvider>().searchQuery.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.clear_rounded, color: ac.onSurfaceDim),
                  onPressed: () {
                    context.read<AppProvider>().setSearchQuery('');
                  },
                )
              : null,
          border: InputBorder.none,
          filled: false,
        ),
      ),
    );
  }

  Widget _buildStatsRow(ThemeData theme, AppColors ac, AppProvider provider) {
    final stats = [
      _StatData(Icons.insert_drive_file_rounded, '${provider.fileCount}', 'Files', ac.primary),
      _StatData(Icons.storage_rounded, _formatBytes(provider.totalSize), 'Storage', ac.gold),
      _StatData(Icons.favorite_rounded, '${provider.favoriteFiles.length}', 'Favorites', const Color(0xFFE57373)),
    ];

    return Row(
      children: stats.map((s) => Expanded(
        child: _buildStatCard(theme, ac, s),
      )).toList(),
    );
  }

  Widget _buildStatCard(ThemeData theme, AppColors ac, _StatData stat) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: ac.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: ac.outline.withAlpha(60)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: stat.color.withAlpha(25),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(stat.icon, color: stat.color, size: 22),
            ),
            const SizedBox(height: 10),
            Text(stat.value, style: theme.textTheme.titleLarge?.copyWith(color: stat.color, fontWeight: FontWeight.w700, fontSize: 20)),
            const SizedBox(height: 2),
            Text(stat.label, style: theme.textTheme.bodySmall?.copyWith(color: ac.onSurfaceDim)),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryChips(ThemeData theme, AppColors ac, AppProvider provider) {
    final categories = [
      ('all', Icons.all_inclusive_rounded, 'All'),
      ('image', Icons.image_rounded, 'Images'),
      ('document', Icons.description_rounded, 'Docs'),
      ('video', Icons.videocam_rounded, 'Videos'),
      ('audio', Icons.audiotrack_rounded, 'Audio'),
      ('code', Icons.code_rounded, 'Code'),
      ('text', Icons.text_snippet_rounded, 'Text'),
      ('archive', Icons.folder_zip_rounded, 'Archives'),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: categories.map((c) {
          final isSelected = provider.currentCategory == c.$1;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(c.$2, size: 16, color: isSelected ? ac.primary : ac.onSurfaceDim),
                  const SizedBox(width: 6),
                  Text(c.$3),
                ],
              ),
              selected: isSelected,
              onSelected: (_) {
                provider.setCategory(c.$1);
                provider.loadFiles(category: c.$1 == 'all' ? null : c.$1);
              },
              selectedColor: ac.primaryContainer,
              backgroundColor: ac.surfaceVariant,
              side: BorderSide(color: isSelected ? ac.primary.withAlpha(80) : ac.outline.withAlpha(60)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              labelStyle: TextStyle(color: isSelected ? ac.primary : ac.onSurfaceDim, fontSize: 13),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSectionHeader(ThemeData theme, AppColors ac, String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: ac.primary),
        const SizedBox(width: 8),
        Text(title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600, color: ac.cream, letterSpacing: 0.5)),
      ],
    );
  }

  Widget _buildRecentFileCard(ThemeData theme, AppColors ac, FileItem file) {
    final color = AppTheme.getFileColor(file.extension);
    return GestureDetector(
      onTap: () => context.read<AppProvider>().setSelectedFile(file),
      child: Container(
        width: 84,
        decoration: BoxDecoration(
          color: ac.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: ac.outline.withAlpha(60)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withAlpha(25),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(AppTheme.getFileIcon(file.extension), color: color, size: 24),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                file.name.length > 10 ? '${file.name.substring(0, 8)}...' : file.name,
                style: theme.textTheme.bodySmall?.copyWith(color: ac.cream),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBatchActionBar(ThemeData theme, AppColors ac, AppProvider provider) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: ac.primaryContainer.withAlpha(180),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: ac.primary.withAlpha(60)),
      ),
      child: Row(
        children: [
          Icon(Icons.checklist_rounded, size: 18, color: ac.primary),
          const SizedBox(width: 8),
          Text('${provider.selectedIds.length} selected', style: TextStyle(color: ac.primary, fontWeight: FontWeight.w600, fontSize: 14)),
          const Spacer(),
          _buildBatchBtn(Icons.select_all_rounded, 'Select All', ac.primary, () => provider.selectAll()),
          _buildBatchBtn(Icons.delete_rounded, 'Delete', const Color(0xFFE57373), () async {
            final confirm = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Delete Selected'),
                content: Text('Delete ${provider.selectedIds.length} file(s)?'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                  ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
                ],
              ),
            );
            if (confirm == true) await provider.deleteSelected();
          }),
          _buildBatchBtn(Icons.close_rounded, 'Cancel', ac.onSurfaceDim, () => provider.clearSelection()),
        ],
      ),
    );
  }

  Widget _buildBatchBtn(IconData icon, String tooltip, Color color, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2),
      child: IconButton(
        icon: Icon(icon, size: 20, color: color),
        onPressed: onTap,
        tooltip: tooltip,
        splashRadius: 20,
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme, AppColors ac) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(36),
            decoration: BoxDecoration(
              color: ac.primary.withAlpha(15),
              shape: BoxShape.circle,
              border: Border.all(color: ac.primary.withAlpha(40)),
            ),
            child: Icon(Icons.cloud_upload_rounded, size: 56, color: ac.primary.withAlpha(100)),
          ).animate().scale(delay: 100.ms, duration: 800.ms, curve: Curves.elasticOut),
          const SizedBox(height: 24),
          Text('No Files Yet', style: theme.textTheme.headlineSmall?.copyWith(color: ac.cream)),
          const SizedBox(height: 8),
          Text('Tap + to import your first file', style: TextStyle(color: ac.onSurfaceDim)),
          const SizedBox(height: 28),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(color: ac.primary.withAlpha(40), blurRadius: 16, offset: const Offset(0, 6)),
              ],
            ),
            child: FilledButton.icon(
              onPressed: _pickFiles,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Import Files'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmerList(ThemeData theme) {
    return Shimmer.fromColors(
      baseColor: AppTheme.background.withAlpha(120),
      highlightColor: AppTheme.card.withAlpha(80),
      child: ListView.builder(
        itemCount: 8,
        itemBuilder: (_, __) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Container(
            height: 72,
            decoration: BoxDecoration(
              color: AppTheme.card,
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}

class _StatData {
  final IconData icon;
  final String value;
  final String label;
  final Color color;
  _StatData(this.icon, this.value, this.label, this.color);
}

class _ToolPickerSheet extends StatelessWidget {
  const _ToolPickerSheet();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ac = theme.extension<AppColors>()!;
    final tools = [
      _ToolData('Resume Builder', Icons.description_rounded, AppTheme.getFileColor('pdf'), const ResumeGenerator(), 'Create professional resumes'),
      _ToolData('Invoice Generator', Icons.receipt_long_rounded, AppTheme.getFileColor('xls'), const InvoiceGenerator(), 'Generate invoices'),
      _ToolData('PRD Writer', Icons.assignment_rounded, AppTheme.getFileColor('doc'), const PrdGenerator(), 'Product requirement docs'),
      _ToolData('Contract Builder', Icons.gavel_rounded, AppTheme.getFileColor('docx'), const ContractGenerator(), 'Legal contract templates'),
      _ToolData('Archive Extractor', Icons.folder_zip_rounded, AppTheme.getFileColor('zip'), const ArchiveExtractor(), 'Extract ZIP archives'),
      _ToolData('Archive Creator', Icons.archive_rounded, AppTheme.getFileColor('zip'), const ArchiveCreator(), 'Create ZIP archives'),
      _ToolData('Image Compressor', Icons.compress_rounded, AppTheme.getFileColor('jpg'), const ImageCompressor(), 'Compress & resize images'),
      _ToolData('Image Editor', Icons.edit_rounded, AppTheme.getFileColor('jpg'), const ImageEditor(), 'Crop, rotate, flip & filters'),
      _ToolData('Encryption Vault', Icons.lock_rounded, const Color(0xFFCE93D8), const EncryptionVault(), 'AES-256 encrypt/decrypt files'),
      _ToolData('PDF Merger', Icons.merge_rounded, AppTheme.getFileColor('pdf'), const PdfMerger(), 'Combine multiple PDFs'),
      _ToolData('Duplicate Finder', Icons.copy_all_rounded, const Color(0xFFFFB74D), const DuplicateFinder(), 'Find & remove duplicate files'),
      _ToolData('Notes', Icons.note_rounded, ac.gold, const NotesApp(), 'Write & save text notes'),
      _ToolData('Unit Converter', Icons.swap_horiz_rounded, AppTheme.getFileColor('csv'), const UnitConverter(), 'Length, weight, temp, data & more'),
    ];

    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      expand: false,
      builder: (ctx, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: ac.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 48,
                    height: 5,
                    decoration: BoxDecoration(
                      color: ac.outline.withAlpha(120),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: ac.primaryContainer,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.auto_fix_high_rounded, size: 18, color: ac.primary),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Professional Tools', style: theme.textTheme.titleLarge?.copyWith(color: ac.cream, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 2),
                        Text('All tools work fully offline', style: TextStyle(color: ac.onSurfaceDim, fontSize: 13)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: ListView.separated(
                    controller: scrollController,
                    itemCount: tools.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final tool = tools[i];
                      return Container(
                        decoration: BoxDecoration(
                          color: ac.card,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: ac.outline.withAlpha(40)),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () {
                              Navigator.pop(context);
                              Navigator.push(context, MaterialPageRoute(builder: (_) => tool.screen));
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: tool.color.withAlpha(25),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Icon(tool.icon, color: tool.color, size: 26),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(tool.name, style: TextStyle(color: ac.cream, fontWeight: FontWeight.w600, fontSize: 15)),
                                        const SizedBox(height: 2),
                                        Text(tool.description, style: TextStyle(color: ac.onSurfaceDim, fontSize: 12)),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: ac.outline.withAlpha(40),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(Icons.chevron_right_rounded, size: 18, color: ac.onSurfaceDim),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ToolData {
  final String name;
  final IconData icon;
  final Color color;
  final Widget screen;
  final String description;
  _ToolData(this.name, this.icon, this.color, this.screen, this.description);
}
