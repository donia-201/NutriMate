import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/network/ai_api_config.dart';
import '../../core/network/dio_client.dart';
import '../../data/dataresource/ai_remote_darasource.dart';
import '../../data/dataresource/meal_api_services.dart';
import '../../data/repositories/ai_repository.dart';
import '../cubit/ai_chat_cubit.dart';
import '../pages/ai_assistant_page.dart';

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
      case 2:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => BlocProvider(
              create: (_) {
                // AI requests use a dedicated backend client.
                // MealApiService keeps its own TheMealDB client.
                final aiDioClient = DioClient(
                  baseUrl: AiApiConfig.baseUrl.isEmpty
                      ? 'https://invalid.invalid/'
                      : AiApiConfig.baseUrl,
                );
                final mealApiService = MealApiService();

                final dataSource = AiRemoteDataSource(
                  aiDioClient: aiDioClient,
                  mealApiService: mealApiService,
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

      default:
        onTap(index);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return SafeArea(
      top: false,
      minimum: EdgeInsets.only(
        bottom: MediaQuery.viewPaddingOf(context).bottom,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          border: Border(
            top: BorderSide(color: colorScheme.outline, width: 0.8),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(context, 0, Icons.home_outlined, Icons.home, "Home"),
            _buildNavItem(
              context,
              1,
              Icons.search_outlined,
              Icons.search,
              "Search",
            ),
            _buildNavItem(
              context,
              2,
              Icons.auto_awesome_outlined,
              Icons.auto_awesome,
              "NutriAI",
              isCenter: true,
            ),
            _buildNavItem(
              context,
              3,
              Icons.calendar_today_outlined,
              Icons.calendar_today,
              "Planner",
            ),
            _buildNavItem(
              context,
              4,
              Icons.insights_outlined,
              Icons.insights,
              "Insights",
            ),

          ],
        ),
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
    final colorScheme = Theme.of(context).colorScheme;

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
          color: colorScheme.primary.withValues(alpha: 0.15),
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
                  ? colorScheme.primary
                  : colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected
                    ? colorScheme.onSurface
                    : colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}