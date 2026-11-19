import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../data/dataresource/meal_api_services.dart';
import '../../data/models/meal.model.dart';
import 'add_to_planner_sheet.dart';

class MealDetailsPage extends StatefulWidget {
  final MealModel meal;
  const MealDetailsPage({super.key, required this.meal});

  @override
  State<MealDetailsPage> createState() => _MealDetailsPageState();
}

class _MealDetailsPageState extends State<MealDetailsPage> {
  final _api = MealApiService();
  late Future<MealModel> _details;

  @override
  void initState() {
    super.initState();
    _details = _loadDetails();
  }

  Future<MealModel> _loadDetails() async {
    if (widget.meal.detailsLoaded) return widget.meal;
    final details = await _api.getMealById(widget.meal.idMeal);
    return details ?? widget.meal;
  }

  @override
  void dispose() {
    _api.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Meal Details')),
    body: FutureBuilder<MealModel>(
      future: _details,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Could not load this recipe.'));
        }
        final meal = snapshot.data ?? widget.meal;
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Hero(
              tag: 'meal-${meal.idMeal}',
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppTheme.cardRadius),
                child: Image.network(
                  meal.strMealThumb,
                  height: 240,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              meal.strMeal,
              style: AppTheme.titleBold.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${meal.strCategory ?? 'Meal'} • ${meal.strArea ?? 'International'}',
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => showAddToPlannerSheet(context, meal),
                icon: const Icon(Icons.event_note_outlined),
                label: const Text('Add to Planner'),
              ),
            ),
            if (meal.strInstructions != null) ...[
              const SizedBox(height: 24),
              Text('Instructions', style: AppTheme.label),
              const SizedBox(height: 8),
              Text(meal.strInstructions!),
            ],
          ],
        );
      },
    ),
  );
}
