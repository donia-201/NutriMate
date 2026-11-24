import 'package:flutter/material.dart';


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
          backgroundColor: Theme.of(context).colorScheme.surface,
          selectedColor:
              Theme.of(context).colorScheme.primary.withValues(alpha: 0.18),
          side: BorderSide(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.outline,
          ),
          labelStyle: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
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