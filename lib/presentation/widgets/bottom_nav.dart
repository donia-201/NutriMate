 import 'package:flutter/material.dart';

import '../../core/utils/app_colors.dart';
import '../pages/ai_assistant_page.dart';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/network/dio_client.dart';
import '../../data/dataresource/ai_remote_darasource.dart';
import '../../data/repositories/ai_repository.dart';
import '../cubit/ai_chat_cubit.dart';

class BottomNavBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const BottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  void _handleNavigation(BuildContext context, int index) {
    switch (index) {
      case 0:
        // Navigator.push(
        //   context,
        //   MaterialPageRoute(builder: (_) => const HomePage()),
        // );
        onTap(index);
        break;

      case 1:
        // Navigator.push(
        //   context,
        //   MaterialPageRoute(builder: (_) => const SearchPage()),
        // );
        onTap(index);
        break;

      case 2:
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => BlocProvider(
        create: (_) {
          final dioClient = DioClient();

          final dataSource = AiRemoteDataSource(
            dioClient: dioClient,
            useMockData: true,
          );

          final repository = AiRepository(
            dataSource: dataSource,
          );

          return AiChatCubit(
            repository: repository,
          );
        },
        child: const AiAssistantPage(),
      ),
    ),
  );
  break;

      case 3:
        // Navigator.push(
        //   context,
        //   MaterialPageRoute(builder: (_) => const PlannerPage()),
        // );
        onTap(index);
        break;

      case 4:
        // Navigator.push(
        //   context,
        //   MaterialPageRoute(builder: (_) => const InsightsPage()),
        // );
        onTap(index);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: 8,
        horizontal: 12,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(
            color: AppColors.divider,
            width: 0.8,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavItem(
            context,
            0,
            Icons.home_outlined,
            Icons.home,
            'Home',
          ),
          _buildNavItem(
            context,
            1,
            Icons.search_outlined,
            Icons.search,
            'Search',
          ),
          _buildNavItem(
            context,
            2,
            Icons.auto_awesome_outlined,
            Icons.auto_awesome,
            'NutriAI',
            isCenter: true,
          ),
          _buildNavItem(
            context,
            3,
            Icons.calendar_today_outlined,
            Icons.calendar_today,
            'Planner',
          ),
          _buildNavItem(
            context,
            4,
            Icons.add_chart_rounded,
            Icons.bar_chart_outlined,
            'Insights',
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(
    BuildContext context,
    int index,
    IconData icon,
    IconData activeIcon,
    String label, {
    bool isCenter = false,
  }) {
    final isSelected = currentIndex == index;

    return GestureDetector(
      onTap: () => _handleNavigation(context, index),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isCenter ? 14 : 8,
          vertical: 6,
        ),
        decoration: isCenter && isSelected
            ? BoxDecoration(
                color: AppColors.primaryGreen.withValues(alpha: 0.15),
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
                  ? AppColors.primaryGreen
                  : AppColors.textMuted,
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
                    ? AppColors.textDark
                    : AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}