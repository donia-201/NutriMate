import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../data/models/meal_model.dart';
import '../widgets/bottom_nav.dart';

class CookingDetailsPage extends StatelessWidget {
  final MealModel meal;

  const CookingDetailsPage({super.key, required this.meal});

  List<String> get _steps {
    final text = (meal.strInstructions ?? '').trim();
    if (text.isEmpty) return const [];
    final lines = text
        .split(RegExp(r'\r?\n+'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    if (lines.length > 1) return lines;
    return text
        .split(RegExp(r'(?<=[.!?])\s+'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final steps = _steps;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Let's get cooking"),
            Text(
              meal.strMeal,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTheme.small.copyWith(color: colors.onSurfaceVariant),
            ),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Ingredients', style: AppTheme.titleBold.copyWith(color: colors.onSurface)),
              Text('1 serving', style: AppTheme.small.copyWith(color: colors.onSurfaceVariant)),
            ],
          ),
          const SizedBox(height: 12),
          if (meal.ingredients.isEmpty)
            _emptyCard(colors, 'Ingredient details are not available for this recipe.')
          else
            ...meal.ingredients.map(
              (ingredient) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: Theme.of(context).scaffoldBackgroundColor,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.restaurant, size: 18, color: colors.onSurfaceVariant),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(ingredient.name, style: AppTheme.label.copyWith(color: colors.onSurface)),
                    ),
                    Text(ingredient.measure, style: AppTheme.body.copyWith(color: colors.onSurfaceVariant)),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 16),
          Text('Instructions', style: AppTheme.titleBold.copyWith(color: colors.onSurface)),
          const SizedBox(height: 12),
          if (steps.isEmpty)
            _emptyCard(colors, 'Cooking instructions are not available for this recipe.')
          else
            ...List.generate(steps.length, (index) {
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Theme(
                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    tilePadding: const EdgeInsets.symmetric(horizontal: 16),
                    childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    title: Text(
                      '${index + 1}  ${_stepTitle(steps[index])}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.label.copyWith(color: colors.onSurface),
                    ),
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          steps[index],
                          style: AppTheme.body.copyWith(height: 1.5, color: colors.onSurfaceVariant),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          const SizedBox(height: 8),
          Text(
            'Expandable quantities · steps shown individually',
            style: AppTheme.small.copyWith(color: colors.onSurfaceVariant),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavBar(
        currentIndex: 0,
        onTap: (_) { Navigator.maybePop(context); },
      ),
    );
  }

  String _stepTitle(String step) {
    final cleaned = step.replaceAll(RegExp(r'^\d+[.)]?\s*'), '').trim();
    final words = cleaned.split(RegExp(r'\s+'));
    return words.take(5).join(' ');
  }

  Widget _emptyCard(ColorScheme colors, String message) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: colors.surface, borderRadius: BorderRadius.circular(20)),
        child: Text(message, style: AppTheme.body.copyWith(color: colors.onSurfaceVariant)),
      );
}
