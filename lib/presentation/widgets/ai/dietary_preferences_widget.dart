import 'package:flutter/material.dart';

import '../../../core/utils/app_colors.dart';

class DietaryPreferencesWidget extends StatelessWidget {
  final Set<String> selectedPreferences;
  final ValueChanged<Set<String>> onChanged;

  const DietaryPreferencesWidget({
    super.key,
    required this.selectedPreferences,
    required this.onChanged,
  });

  static const List<String> preferences = [
    'Vegan',
    'Vegetarian',
    'Gluten-Free',
    'Low-Carb',
    'Diabetic-Friendly',
    'Dairy-Free',
    'Nut-Free',
  ];

  void _togglePreference(String preference) {
    final updated = Set<String>.from(selectedPreferences);

    if (updated.contains(preference)) {
      updated.remove(preference);
    } else {
      updated.add(preference);
    }

    onChanged(updated);
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 10,
      children: preferences.map((preference) {
        final isSelected =
            selectedPreferences.contains(preference);

        return FilterChip(
          label: Text(preference),
          selected: isSelected,
          onSelected: (_) => _togglePreference(preference),
          showCheckmark: false,
          backgroundColor: AppColors.surface,
          selectedColor:
              AppColors.primaryGreen.withValues(alpha: 0.18),
          side: BorderSide(
            color: isSelected
                ? AppColors.primaryGreen
                : AppColors.divider,
          ),
          labelStyle: TextStyle(
            color: AppColors.textDark,
            fontSize: 12,
            fontWeight: isSelected
                ? FontWeight.w600
                : FontWeight.w400,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
        );
      }).toList(),
    );
  }
}