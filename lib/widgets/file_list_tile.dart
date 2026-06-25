import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../models/file_item.dart';

class FileListTile extends StatelessWidget {
  final FileItem file;
  final bool isSelectionMode;

  const FileListTile({super.key, required this.file, this.isSelectionMode = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ac = theme.extension<AppColors>()!;
    final color = AppTheme.getFileColor(file.extension);
    final icon = AppTheme.getFileIcon(file.extension);
    final provider = context.watch<AppProvider>();
    final isSelected = provider.selectedIds.contains(file.id);

    final tile = Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      decoration: BoxDecoration(
        color: ac.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isSelected ? ac.primary.withAlpha(100) : ac.outline.withAlpha(60)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: isSelectionMode
              ? () => context.read<AppProvider>().toggleSelection(file.id!)
              : () => context.read<AppProvider>().setSelectedFile(file),
          onLongPress: () => context.read<AppProvider>().toggleSelection(file.id!),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                if (isSelectionMode)
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Icon(
                      isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                      color: isSelected ? ac.primary : ac.onSurfaceDim.withAlpha(100),
                      size: 22,
                    ),
                  ),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isSelected ? color : color.withAlpha(25),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: isSelected ? const Color(0xFF1A0A00) : color, size: 22),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        file.name,
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w500, color: ac.cream),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            file.formattedSize,
                            style: theme.textTheme.bodySmall?.copyWith(color: ac.onSurfaceDim),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: color.withAlpha(20),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '.${file.extension}',
                              style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w500),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            file.formattedDate,
                            style: theme.textTheme.bodySmall?.copyWith(color: ac.onSurfaceDim.withAlpha(150)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (file.isFavorite)
                  const Padding(
                    padding: EdgeInsets.only(left: 8),
                    child: Icon(Icons.favorite, size: 16, color: Color(0xFFE57373)),
                  ),
                const SizedBox(width: 4),
                if (!isSelectionMode)
                  Icon(Icons.chevron_right_rounded, color: ac.onSurfaceDim.withAlpha(100)),
              ],
            ),
          ),
        ),
      ),
    );

    if (isSelectionMode) return tile;

    return Slidable(
      key: ValueKey(file.id),
      endActionPane: ActionPane(
        motion: const BehindMotion(),
        extentRatio: 0.3,
        children: [
          SlidableAction(
            onPressed: (_) => context.read<AppProvider>().toggleFavorite(file.id!),
            backgroundColor: const Color(0xFFE57373),
            foregroundColor: const Color(0xFF1A0A00),
            icon: file.isFavorite ? Icons.favorite : Icons.favorite_border,
            label: file.isFavorite ? 'Unfavorite' : 'Favorite',
            borderRadius: BorderRadius.circular(12),
          ),
          SlidableAction(
            onPressed: (_) => _confirmDelete(context),
            backgroundColor: const Color(0xFFCF6679),
            foregroundColor: const Color(0xFF1A0A00),
            icon: Icons.delete_rounded,
            label: 'Delete',
            borderRadius: BorderRadius.circular(12),
          ),
        ],
      ),
      child: tile,
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(ctx).extension<AppColors>()!.cardElevated,
        title: const Text('Delete File'),
        content: Text('Remove "${file.name}" from the library?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              context.read<AppProvider>().deleteFile(file.id!);
              Navigator.pop(ctx);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
