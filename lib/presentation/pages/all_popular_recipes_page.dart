import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../data/dataresource/meal_api_services.dart';
import '../../data/models/meal_model.dart';
import '../widgets/bottom_nav.dart';
import 'meal_details_page.dart';

class AllPopularRecipesPage extends StatefulWidget {
  final ValueChanged<int> onBottomNavTap;

  const AllPopularRecipesPage({
    super.key,
    required this.onBottomNavTap,
  });

  @override
  State<AllPopularRecipesPage> createState() => _AllPopularRecipesPageState();
}

class _AllPopularRecipesPageState extends State<AllPopularRecipesPage> {
  final MealApiService _api = MealApiService();
  late Future<List<MealModel>> _mealsFuture;

  @override
  void initState() {
    super.initState();
    _mealsFuture = _loadMeals();
  }

  Future<List<MealModel>> _loadMeals() async {
    final unique = <String, MealModel>{};
    for (final category in const ['Seafood', 'Pasta', 'Chicken', 'Vegetarian', 'Dessert']) {
      try {
        final meals = await _api.getMealsByCategory(category);
        for (final meal in meals) {
          unique.putIfAbsent(meal.idMeal, () => meal);
        }
      } catch (_) {
        // Keep recipes already fetched from the other categories.
      }
    }
    return unique.values.toList();
  }

  @override
  void dispose() {
    _api.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () => Navigator.maybePop(context),
          icon: const Icon(Icons.arrow_back),
        ),
        title: const Text('Popular Recipes'),
      ),
      body: FutureBuilder<List<MealModel>>(
        future: _mealsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Could not load recipes right now.'),
                    TextButton(
                      onPressed: () => setState(() => _mealsFuture = _loadMeals()),
                      child: const Text('Try again'),
                    ),
                  ],
                ),
              ),
            );
          }
          final meals = snapshot.data!;
          return GridView.builder(
            padding: const EdgeInsets.all(AppTheme.pagePadding),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: .78,
            ),
            itemCount: meals.length,
            itemBuilder: (context, index) {
              final meal = meals[index];
              return Material(
                color: colors.surface,
                borderRadius: BorderRadius.circular(AppTheme.cardRadius),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => MealDetailsPage(meal: meal)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Image.network(
                          meal.strMealThumb,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => const Center(
                            child: Icon(Icons.restaurant, size: 38),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(10),
                        child: Text(
                          meal.strMeal,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTheme.label.copyWith(color: colors.onSurface),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      bottomNavigationBar: BottomNavBar(
        currentIndex: 0,
        onTap: widget.onBottomNavTap,
      ),
    );
  }
}
