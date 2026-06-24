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
      duration: 300.ms,
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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => const _ToolPickerSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Consumer<AppProvider>(
        builder: (context, provider, _) {
          return RefreshIndicator(
            onRefresh: () => provider.refreshAll(),
            child: CustomScrollView(
              slivers: [
                _buildAppBar(theme, provider),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    child: _buildSearchBar(theme),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _buildStatsRow(theme, provider),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    child: _buildCategoryChips(theme, provider),
                  ),
                ),
                if (provider.isLoading)
                  SliverFillRemaining(
                    child: _buildShimmerList(),
                  )
                else ...[
                  if (provider.recentFiles.isNotEmpty) ...[
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                        child: _buildSectionHeader(theme, 'Recent Files', Icons.history_rounded),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: SizedBox(
                        height: 100,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          itemCount: provider.recentFiles.length.clamp(0, 8),
                          separatorBuilder: (_, __) => const SizedBox(width: 12),
                          itemBuilder: (ctx, i) => _buildRecentFileCard(theme, provider.recentFiles[i]),
                        ),
                      ),
                    ),
                  ],
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                      child: _buildSectionHeader(theme, 'All Files', Icons.folder_rounded),
                    ),
                  ),
                  if (provider.isSelectionMode)
                    SliverToBoxAdapter(child: _buildBatchActionBar(theme, provider)),
                  if (provider.files.isEmpty)
                    SliverFillRemaining(
                      child: _buildEmptyState(theme),
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
            FloatingActionButton.small(
              heroTag: 'tools',
              onPressed: _showToolPicker,
              backgroundColor: theme.colorScheme.secondary,
              child: const Icon(Icons.auto_fix_high_rounded),
            ),
            const SizedBox(width: 12),
            FloatingActionButton(
              heroTag: 'pick',
              onPressed: _pickFiles,
              backgroundColor: theme.colorScheme.primary,
              child: const Icon(Icons.add_rounded),
            ),
          ],
        ),
      ).animate().shakeX(duration: 200.ms).then().slideX(),
    );
  }

  Widget _buildAppBar(ThemeData theme, AppProvider provider) {
    return SliverAppBar(
      expandedHeight: 80,
      floating: false,
      pinned: true,
      flexibleSpace: FlexibleSpaceBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [theme.colorScheme.primary, theme.colorScheme.secondary],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.build_circle_rounded, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 12),
            const Text(
              'CRAFT',
              style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 2),
            ),
          ],
        ),
      ),
      actions: [
        IconButton(
          icon: Icon(
            provider.themeMode == ThemeMode.dark
                ? Icons.light_mode_rounded
                : Icons.dark_mode_rounded,
          ),
          onPressed: () {
            final newMode = provider.themeMode == ThemeMode.dark
                ? ThemeMode.light
                : ThemeMode.dark;
            provider.setThemeMode(newMode);
          },
        ),
        IconButton(
          icon: const Icon(Icons.settings_rounded),
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
          tooltip: 'Settings',
        ),
        PopupMenuButton<String>(
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

  Widget _buildSearchBar(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor),
      ),
      child: TextField(
        onChanged: (v) => context.read<AppProvider>().setSearchQuery(v),
        style: theme.textTheme.bodyLarge,
        decoration: InputDecoration(
          hintText: 'Search files...',
          prefixIcon: const Icon(Icons.search_rounded),
          suffixIcon: context.watch<AppProvider>().searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded),
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

  Widget _buildStatsRow(ThemeData theme, AppProvider provider) {
    final stats = [
      _StatData(Icons.insert_drive_file_rounded, '${provider.fileCount}', 'Files', theme.colorScheme.primary),
      _StatData(Icons.storage_rounded, _formatBytes(provider.totalSize), 'Storage', theme.colorScheme.secondary),
      _StatData(Icons.favorite_rounded, '${provider.favoriteFiles.length}', 'Favorites', Colors.redAccent),
    ];

    return Row(
      children: stats.map((s) => Expanded(
        child: _buildStatCard(theme, s),
      )).toList(),
    );
  }

  Widget _buildStatCard(ThemeData theme, _StatData stat) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        child: Column(
          children: [
            Icon(stat.icon, color: stat.color, size: 28),
            const SizedBox(height: 8),
            Text(stat.value, style: theme.textTheme.titleLarge?.copyWith(color: stat.color, fontWeight: FontWeight.w700)),
            Text(stat.label, style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryChips(ThemeData theme, AppProvider provider) {
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
            child: FilterChip(
              label: Text(c.$3),
              avatar: Icon(c.$2, size: 18),
              selected: isSelected,
              onSelected: (_) {
                provider.setCategory(c.$1);
                provider.loadFiles(category: c.$1 == 'all' ? null : c.$1);
              },
              selectedColor: theme.colorScheme.primary.withValues(alpha: 0.15),
              checkmarkColor: theme.colorScheme.primary,
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSectionHeader(ThemeData theme, String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildRecentFileCard(ThemeData theme, FileItem file) {
    final color = AppTheme.getFileColor(file.extension);
    return GestureDetector(
      onTap: () => context.read<AppProvider>().setSelectedFile(file),
      child: Container(
        width: 80,
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.dividerColor),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(AppTheme.getFileIcon(file.extension), color: color, size: 24),
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                file.name.length > 10 ? '${file.name.substring(0, 8)}...' : file.name,
                style: theme.textTheme.bodySmall,
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

  Widget _buildBatchActionBar(ThemeData theme, AppProvider provider) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Text('${provider.selectedIds.length} selected', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.select_all_rounded),
            onPressed: () => provider.selectAll(),
            tooltip: 'Select All',
          ),
          IconButton(
            icon: const Icon(Icons.delete_rounded, color: Colors.redAccent),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Delete Selected'),
                  content: Text('Delete ${provider.selectedIds.length} file(s)?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                    ElevatedButton(onPressed: () => Navigator.pop(ctx, true), style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent), child: const Text('Delete')),
                  ],
                ),
              );
              if (confirm == true) await provider.deleteSelected();
            },
            tooltip: 'Delete Selected',
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: () => provider.clearSelection(),
            tooltip: 'Cancel',
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.cloud_upload_rounded, size: 64, color: theme.colorScheme.primary.withValues(alpha: 0.5)),
          ),
          const SizedBox(height: 24),
          Text('No Files Yet', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text('Tap + to import your first file', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
        ],
      ),
    );
  }

  Widget _buildShimmerList() {
    return Shimmer.fromColors(
      baseColor: Colors.grey.withValues(alpha: 0.2),
      highlightColor: Colors.grey.withValues(alpha: 0.1),
      child: ListView.builder(
        itemCount: 8,
        itemBuilder: (_, __) => ListTile(
          leading: Container(width: 48, height: 48, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12))),
          title: Container(height: 14, width: 150, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4))),
          subtitle: Container(height: 12, width: 80, margin: const EdgeInsets.only(top: 4), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4))),
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
    final tools = [
      _ToolData('Resume Builder', Icons.description_rounded, AppTheme.getFileColor('pdf'), const ResumeGenerator(), 'Create professional resumes'),
      _ToolData('Invoice Generator', Icons.receipt_long_rounded, AppTheme.getFileColor('xls'), const InvoiceGenerator(), 'Generate invoices'),
      _ToolData('PRD Writer', Icons.assignment_rounded, AppTheme.getFileColor('doc'), const PrdGenerator(), 'Product requirement docs'),
      _ToolData('Contract Builder', Icons.gavel_rounded, AppTheme.getFileColor('docx'), const ContractGenerator(), 'Legal contract templates'),
      _ToolData('Archive Extractor', Icons.folder_zip_rounded, AppTheme.getFileColor('zip'), const ArchiveExtractor(), 'Extract ZIP archives'),
      _ToolData('Archive Creator', Icons.archive_rounded, AppTheme.getFileColor('zip'), const ArchiveCreator(), 'Create ZIP archives'),
      _ToolData('Image Compressor', Icons.compress_rounded, AppTheme.getFileColor('jpg'), const ImageCompressor(), 'Compress & resize images'),
    ];

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.85,
      expand: false,
      builder: (ctx, scrollController) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.dividerColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text('Professional Tools', style: theme.textTheme.headlineSmall),
              const SizedBox(height: 4),
              Text('All tools work fully offline', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.separated(
                  controller: scrollController,
                  itemCount: tools.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (_, i) {
                    final tool = tools[i];
                    return Card(
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        leading: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: tool.color.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(tool.icon, color: tool.color, size: 28),
                        ),
                        title: Text(tool.name, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                        subtitle: Text(tool.description, style: theme.textTheme.bodySmall),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(context, MaterialPageRoute(builder: (_) => tool.screen));
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
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
