import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../providers/app_provider.dart';
import '../database/app_database.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppProvider>().loadStats();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ac = theme.extension<AppColors>()!;

    return Scaffold(
      backgroundColor: ac.bg,
      appBar: AppBar(
        title: const Text('Settings'),
        centerTitle: true,
      ),
      body: Consumer<AppProvider>(
        builder: (context, provider, _) {
          return ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              _buildAppearanceSection(theme, ac, provider),
              _buildStorageSection(theme, ac, provider),
              _buildAboutSection(theme, ac),
              _buildActionsSection(theme, ac, provider),
              const SizedBox(height: 32),
            ],
          );
        },
      ),
    );
  }

  Widget _buildAppearanceSection(ThemeData theme, AppColors ac, AppProvider provider) {
    return _buildSection(
      ac: ac,
      icon: Icons.palette_rounded,
      title: 'APPEARANCE',
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: SegmentedButton<ThemeMode>(
            segments: const [
              ButtonSegment(
                value: ThemeMode.system,
                label: Text('System'),
                icon: Icon(Icons.brightness_auto_rounded),
              ),
              ButtonSegment(
                value: ThemeMode.light,
                label: Text('Light'),
                icon: Icon(Icons.light_mode_rounded),
              ),
              ButtonSegment(
                value: ThemeMode.dark,
                label: Text('Dark'),
                icon: Icon(Icons.dark_mode_rounded),
              ),
            ],
            selected: {provider.themeMode},
            onSelectionChanged: (selected) {
              provider.setThemeMode(selected.first);
            },
            showSelectedIcon: false,
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) return ac.primaryContainer;
                return ac.surfaceVariant;
              }),
              foregroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) return ac.primary;
                return ac.onSurfaceDim;
              }),
              side: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return BorderSide(color: ac.primary.withAlpha(80));
                }
                return BorderSide(color: ac.outline.withAlpha(60));
              }),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStorageSection(ThemeData theme, AppColors ac, AppProvider provider) {
    return _buildSection(
      ac: ac,
      icon: Icons.storage_rounded,
      title: 'STORAGE',
      children: [
        _buildSettingTile(
          ac: ac,
          icon: Icons.insert_drive_file_rounded,
          iconColor: ac.primary,
          title: 'Total Files',
          trailing: Text(
            '${provider.fileCount}',
            style: TextStyle(color: ac.cream, fontWeight: FontWeight.w600),
          ),
        ),
        _buildSettingTile(
          ac: ac,
          icon: Icons.cloud_rounded,
          iconColor: ac.gold,
          title: 'Storage Used',
          trailing: Text(
            _formatBytes(provider.totalSize),
            style: TextStyle(color: ac.cream, fontWeight: FontWeight.w600),
          ),
        ),
        const Divider(height: 1),
        _buildSettingTile(
          ac: ac,
          icon: Icons.delete_sweep_rounded,
          iconColor: const Color(0xFFCF6679),
          title: 'Clear All Files',
          subtitle: 'Remove all files from the database',
          onTap: () => _confirmClearAll(provider, ac),
        ),
      ],
    );
  }

  Widget _buildAboutSection(ThemeData theme, AppColors ac) {
    return _buildSection(
      ac: ac,
      icon: Icons.info_outline_rounded,
      title: 'ABOUT',
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
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
                ),
                child: const Icon(Icons.build_circle_rounded, color: Color(0xFF1A0A00), size: 28),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'CRAFT',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2,
                      color: ac.cream,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Complete Resource and File Toolkit',
                    style: TextStyle(color: ac.onSurfaceDim, fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        _buildSettingTile(
          ac: ac,
          icon: Icons.code_rounded,
          iconColor: ac.tertiary,
          title: 'Version',
          trailing: Text('1.0.0', style: TextStyle(color: ac.cream, fontWeight: FontWeight.w600)),
        ),
        _buildSettingTile(
          ac: ac,
          icon: Icons.description_rounded,
          iconColor: ac.primary,
          title: 'Licenses',
          subtitle: 'Open source licenses',
          trailing: Icon(Icons.chevron_right_rounded, color: ac.onSurfaceDim),
          onTap: () {
            showLicensePage(
              context: context,
              applicationName: 'CRAFT',
              applicationVersion: '1.0.0',
              applicationLegalese: 'Complete Resource and File Toolkit',
            );
          },
        ),
      ],
    );
  }

  Widget _buildActionsSection(ThemeData theme, AppColors ac, AppProvider provider) {
    return _buildSection(
      ac: ac,
      icon: Icons.settings_rounded,
      title: 'ACTIONS',
      children: [
        _buildSettingTile(
          ac: ac,
          icon: Icons.file_upload_rounded,
          iconColor: const Color(0xFF81C784),
          title: 'Export Database',
          subtitle: 'Copy database to a chosen location',
          trailing: Icon(Icons.chevron_right_rounded, color: ac.onSurfaceDim),
          onTap: () => _exportDatabase(),
        ),
        const Divider(height: 1),
        _buildSettingTile(
          ac: ac,
          icon: Icons.file_download_rounded,
          iconColor: const Color(0xFFFFB74D),
          title: 'Import Database',
          subtitle: 'Replace database from a file',
          trailing: Icon(Icons.chevron_right_rounded, color: ac.onSurfaceDim),
          onTap: () => _importDatabase(provider, ac),
        ),
      ],
    );
  }

  Widget _buildSettingTile({
    required AppColors ac,
    required IconData icon,
    required Color iconColor,
    required String title,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: iconColor.withAlpha(25),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(title, style: TextStyle(color: ac.cream, fontWeight: FontWeight.w500)),
      subtitle: subtitle != null ? Text(subtitle, style: TextStyle(color: ac.onSurfaceDim)) : null,
      trailing: trailing,
      onTap: onTap,
    );
  }

  Future<void> _confirmClearAll(AppProvider provider, AppColors ac) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ac.cardElevated,
        title: const Text('Clear All Files'),
        content: const Text(
          'This will permanently remove all files from the database. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await AppDatabase.instance.clearAllFiles();
      await provider.refreshAll();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All files cleared')),
        );
      }
    }
  }

  Future<void> _exportDatabase() async {
    final dir = await FilePicker.getDirectoryPath(
      dialogTitle: 'Select export destination',
    );
    if (dir == null) return;

    final appDir = await getApplicationDocumentsDirectory();
    final sourcePath = p.join(appDir.path, 'craft_app.db');
    final sourceFile = File(sourcePath);

    if (!await sourceFile.exists()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Database file not found')),
        );
      }
      return;
    }

    final destPath = p.join(dir, 'craft_app_backup.db');
    try {
      await sourceFile.copy(destPath);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Database exported to $destPath')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    }
  }

  Future<void> _importDatabase(AppProvider provider, AppColors ac) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ac.cardElevated,
        title: const Text('Import Database'),
        content: const Text(
          'This will replace the current database with the selected file. All current data will be lost. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Import'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final result = await FilePicker.pickFiles(
      type: FileType.any,
      allowMultiple: false,
    );

    if (result == null || result.files.isEmpty) return;
    final pickedFile = result.files.first;
    if (pickedFile.path == null) return;

    try {
      await AppDatabase.instance.close();

      final appDir = await getApplicationDocumentsDirectory();
      final destPath = p.join(appDir.path, 'craft_app.db');
      final sourceFile = File(pickedFile.path!);
      await sourceFile.copy(destPath);

      await provider.refreshAll();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Database imported successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import failed: $e')),
        );
      }
    }
  }

  Widget _buildSection({
    required AppColors ac,
    required IconData icon,
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
          child: Row(
            children: [
              Icon(icon, size: 16, color: ac.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  color: ac.primary,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: ac.card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: ac.outline.withAlpha(60)),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}

extension on AppColors {
  Color get tertiary => const Color(0xFF8B6F47);
}
