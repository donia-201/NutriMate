import 'package:flutter/material.dart';

class BottomNavBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const BottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: 8,
        horizontal: 12,
      ),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(
          top: BorderSide(
            color: c.outline,
            width: 0.8,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavItem(
            0,
            Icons.home_outlined,
            Icons.home,
            "Home",
            c,
          ),
          _buildNavItem(
            1,
            Icons.search_outlined,
            Icons.search,
            "Search",
            c,
          ),
          _buildNavItem(
            2,
            Icons.auto_awesome_outlined,
            Icons.auto_awesome,
            "NutriAI",
            c,
            isCenter: true,
          ),
          _buildNavItem(
            3,
            Icons.calendar_today_outlined,
            Icons.calendar_today,
            "Planner",
            c,
          ),
          _buildNavItem(
            4,
            Icons.add_chart_rounded,
            Icons.bar_chart_outlined,
            "Insights",
            c,
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(
      int index,
      IconData icon,
      IconData activeIcon,
      String label,
      ColorScheme c, {
        bool isCenter = false,
      }) {
    final isSelected = currentIndex == index;

    return GestureDetector(
      onTap: () => onTap(index),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isCenter ? 14 : 8,
          vertical: 6,
        ),
        decoration: isCenter && isSelected
            ? BoxDecoration(
          color: c.primary.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
        )
            : null,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? activeIcon : icon,
              size: 22,
              color: isSelected
                  ? c.primary
                  : c.onSurfaceVariant,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected
                    ? FontWeight.w600
                    : FontWeight.w400,
                color: isSelected
                    ? c.onSurface
                    : c.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}