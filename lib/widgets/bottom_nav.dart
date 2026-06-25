import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_theme.dart';

class CraftBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const CraftBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ac = theme.extension<AppColors>()!;

    return Container(
      decoration: BoxDecoration(
        color: ac.surface,
        border: Border(top: BorderSide(color: ac.outline.withAlpha(60))),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(_navItems.length, (index) {
              final item = _navItems[index];
              final isSelected = index == currentIndex;
              return _NavBarItem(
                icon: item.icon,
                label: item.label,
                isSelected: isSelected,
                selectedColor: ac.primary,
                onSurfaceDim: ac.onSurfaceDim,
                cream: ac.cream,
                onTap: () => onTap(index),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _NavItemData {
  final IconData icon;
  final String label;
  const _NavItemData({required this.icon, required this.label});
}

const List<_NavItemData> _navItems = [
  _NavItemData(icon: Icons.home_rounded, label: 'Home'),
  _NavItemData(icon: Icons.visibility_rounded, label: 'Viewer'),
  _NavItemData(icon: Icons.swap_horiz_rounded, label: 'Convert'),
  _NavItemData(icon: Icons.edit_note_rounded, label: 'Editor'),
  _NavItemData(icon: Icons.share_rounded, label: 'Share'),
];

class _NavBarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final Color selectedColor;
  final Color onSurfaceDim;
  final Color cream;
  final VoidCallback onTap;

  const _NavBarItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.selectedColor,
    required this.onSurfaceDim,
    required this.cream,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: 300.ms,
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? selectedColor.withAlpha(20) : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              children: [
                AnimatedSwitcher(
                  duration: 300.ms,
                  transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
                  child: Icon(
                    icon,
                    key: ValueKey(isSelected),
                    size: 24,
                    color: isSelected ? selectedColor : onSurfaceDim,
                  ),
                ),
                if (isSelected)
                  Positioned(
                    top: -2,
                    right: -2,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: selectedColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            AnimatedDefaultTextStyle(
              duration: 200.ms,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected ? selectedColor : onSurfaceDim,
                letterSpacing: 0.3,
              ),
              child: Text(label),
            ),
            if (isSelected)
              Container(
                width: 16,
                height: 2,
                margin: const EdgeInsets.only(top: 2),
                decoration: BoxDecoration(
                  color: selectedColor,
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
