import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/app_theme.dart';
import '../../core/app_widgets.dart';
import '../../core/network/ai_api_config.dart';
import '../../core/network/dio_client.dart';
import '../../data/dataresource/ai_remote_darasource.dart';
import '../../data/dataresource/local_database_service.dart';
import '../../data/dataresource/meal_api_services.dart';
import '../../data/models/meal_model.dart';
import '../../data/models/nutrition_model.dart';
import '../../data/repositories/ai_repository.dart';
import '../../data/repositories/nutrition_repository.dart';
import '../cubit/ai_chat_cubit.dart';
import '../cubit/planner_cubit.dart';
import 'ai_assistant_page.dart';
import 'add_to_planner_sheet.dart';
import 'cooking_details_page.dart';
import '../cubit/favorites_cubit.dart';
import '../cubit/favorites_state.dart';

class MealDetailsPage extends StatefulWidget {
  final MealModel meal;

  const MealDetailsPage({super.key, required this.meal});

  @override
  State<MealDetailsPage> createState() => _MealDetailsPageState();
}

class _MealDetailsPageState extends State<MealDetailsPage> {
  final MealApiService _api = MealApiService();
  final NutritionRepository _nutritionRepository = NutritionRepository();
  final LocalDatabaseService _database = LocalDatabaseService.instance;

  late MealModel _meal;
  NutritionModel? _nutrition;
  bool _isLoading = true;
  bool _isSavingFavorite = false;
  bool _isLogging = false;
  String? _error;
  String? _detailsNotice;

  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? 'guest';

  @override
  void initState() {
    super.initState();
    _meal = widget.meal;
    _loadMeal();
  }

  Future<void> _loadMeal() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _detailsNotice = null;
    });

    try {
      if (!_meal.detailsLoaded || _meal.ingredients.isEmpty) {
        try {
          final details = await _api.getMealById(_meal.idMeal);
          if (details != null) {
            _meal = _meal.mergeDetails(details);
            await _database.cacheMeals([_meal]);
          } else {
            _detailsNotice = 'Some recipe details could not be loaded.';
          }
        } catch (_) {
          _detailsNotice =
              'Some recipe details could not be loaded. Check your connection and retry.';
        }
      }

      NutritionModel? nutrition;
      if (_meal.ingredients.isNotEmpty) {
        try {
          nutrition = await _nutritionRepository.calculateMealNutrition(
            _meal.ingredients,
          );
        } catch (_) {
          // Nutrition is an estimate and may be unavailable for some ingredients.
        }
      }

      if (!mounted) return;
      setState(() {
        _nutrition = nutrition;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleFavorite() async {
    if (_isSavingFavorite) return;
    setState(() => _isSavingFavorite = true);
    try {
      final favorites = context.read<FavoritesCubit>();
      final isFavorite = favorites.isFavorite(_meal.idMeal);
      if (isFavorite) {
        final confirmed = await showActionConfirmationDialog(
          context,
          title: 'Remove from favorites?',
          message: 'Remove ${_meal.strMeal} from your favorites?',
          confirmLabel: 'Remove',
          icon: Icons.favorite_border,
          accentColor: Theme.of(context).colorScheme.error,
        );
        if (!confirmed || !mounted) {
          if (mounted) setState(() => _isSavingFavorite = false);
          return;
        }
      }

      final ok = await favorites.toggle(_meal);
      if (!mounted) return;
      if (!ok) {
        setState(() => _isSavingFavorite = false);
        _message(
          favorites.state.errorMessage ??
              'Could not update favorites. Please try again.',
        );
        return;
      }
      setState(() {
        _isSavingFavorite = false;
      });
      _message(
        favorites.isFavorite(_meal.idMeal)
            ? 'Added to your favorites.'
            : 'Removed from favorites.',
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSavingFavorite = false);
      _message('Could not update favorites. Please try again.');
    }
  }

  Future<void> _logAsEaten() async {
    if (_isLogging) return;
    setState(() => _isLogging = true);
    try {
      await _database.logMeal(_uid, _meal, nutrition: _nutrition);
      if (!mounted) return;
      setState(() => _isLogging = false);
      _message('Meal logged as eaten.');
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLogging = false);
      _message('Could not log this meal. Please try again.');
    }
  }

  void _message(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  String get _aiMealDescription {
    final ingredientText = _meal.ingredients
        .map((ingredient) => '${ingredient.measure} ${ingredient.name}'.trim())
        .join(', ');
    return ingredientText.isEmpty
        ? _meal.strMeal
        : '${_meal.strMeal}. Ingredients: $ingredientText';
  }

  void _openHealthierAlternatives() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BlocProvider(
          create: (_) {
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
            return AiChatCubit(
              repository: AiRepository(dataSource: dataSource),
            );
          },
          child: AiAssistantPage(
            initialMealDescription: _aiMealDescription,
            initialMode: AiAssistantMode.mealAnalysis,
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _api.dispose();
    _nutritionRepository.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return BlocBuilder<FavoritesCubit, FavoritesState>(
      builder: (context, favorites) {
        final isFavorite = favorites.ids.contains(_meal.idMeal);
        return Scaffold(
          appBar: AppBar(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            title: const Text('Recipe'),
          ),
          body: SafeArea(
            top: false,
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? _buildError(colors)
                : _buildDetails(colors, isFavorite),
          ),
        );
      },
    );
  }

  Widget _buildError(ColorScheme colors) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.restaurant_menu, size: 42),
          const SizedBox(height: 12),
          Text(_error!, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _loadMeal,
            icon: const Icon(Icons.refresh),
            label: const Text('Try again'),
          ),
        ],
      ),
    ),
  );

  Widget _buildDetails(ColorScheme colors, bool isFavorite) => ListView(
    padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
    children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Image.network(
          _meal.strMealThumb,
          height: 245,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => Container(
            height: 245,
            color: colors.surfaceContainerHighest,
            child: const Icon(Icons.restaurant, size: 54),
          ),
        ),
      ),
      Transform.translate(
        offset: const Offset(0, -28),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 18, 14, 18),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(26),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.07),
                blurRadius: 18,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _meal.strMeal,
                      style: AppTheme.titleBold.copyWith(
                        color: colors.onSurface,
                        fontSize: 23,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      [
                        _meal.strCategory ?? 'Recipe',
                        _meal.strArea ?? 'International',
                      ].join(' - '),
                      style: AppTheme.small.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: _isSavingFavorite ? null : _toggleFavorite,
                icon: Icon(
                  isFavorite ? Icons.favorite : Icons.favorite_border,
                  color: isFavorite ? Colors.redAccent : colors.primary,
                  size: 29,
                ),
              ),
            ],
          ),
        ),
      ),
      if (_detailsNotice != null)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            _detailsNotice!,
            style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
          ),
        ),
      Transform.translate(
        offset: const Offset(0, -18),
        child: _nutritionCard(colors),
      ),
      const SizedBox(height: 2),
      SizedBox(
        height: 54,
        child: FilledButton(
          onPressed: () async {
            await showAddToPlannerSheet(
              context,
              _meal,
              cubit: context.read<PlannerCubit>(),
              calories: _nutrition?.calories?.round() ?? 0,
            );
            if (!context.mounted) return;
          },
          child: const Text('Add to Planner'),
        ),
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _isSavingFavorite ? null : _toggleFavorite,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(54),
              ),
              child: Text(
                isFavorite ? 'Remove from Favorites' : 'Add to Favorites',
                textAlign: TextAlign.center,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: OutlinedButton(
              onPressed: _isLogging ? null : _logAsEaten,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(54),
              ),
              child: Text(_isLogging ? 'Logging...' : 'Log as eaten'),
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      SizedBox(
        height: 52,
        child: FilledButton.icon(
          onPressed: _openHealthierAlternatives,
          style: FilledButton.styleFrom(
            backgroundColor: colors.primary,
            foregroundColor: colors.onPrimary,
            disabledBackgroundColor: colors.primary.withValues(alpha: 0.5),
            disabledForegroundColor: colors.onPrimary.withValues(alpha: 0.7),
            minimumSize: const Size.fromHeight(52),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          icon: const Icon(Icons.auto_awesome),
          label: const Text('Make it healthier with AI'),
        ),
      ),
      const SizedBox(height: 20),
      InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => CookingDetailsPage(meal: _meal)),
        ),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Ingredients, steps & cooking video',
                  style: AppTheme.small.copyWith(
                    color: colors.onSurfaceVariant,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
              Icon(Icons.keyboard_arrow_down, color: colors.onSurfaceVariant),
            ],
          ),
        ),
      ),
    ],
  );

  Widget _nutritionCard(ColorScheme colors) {
    final nutrition = _nutrition;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Estimated - ${_nutrition?.scope == 'per_serving' ? 'per serving' : 'whole recipe'}',
            style: AppTheme.titleBold.copyWith(
              fontSize: 17,
              color: colors.onSurface,
            ),
          ),
          const SizedBox(height: 18),
          if (nutrition == null)
            Text(
              'Nutrition information is currently unavailable.',
              style: TextStyle(color: colors.onSurfaceVariant),
            )
          else
            Row(
              children: [
                _macro(colors, 'Calories', nutrition.calories, 'kcal'),
                _macro(colors, 'Protein', nutrition.protein, 'g'),
                _macro(colors, 'Carbs', nutrition.carbohydrates, 'g'),
                _macro(colors, 'Fat', nutrition.fat, 'g'),
              ],
            ),
          const SizedBox(height: 12),
          Text(
            nutrition?.disclaimer ??
                'Nutrition values are estimates, not a lab measurement.',
            style: AppTheme.small.copyWith(
              color: colors.onSurfaceVariant,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _macro(ColorScheme colors, String label, double? value, String unit) {
    final display = value == null
        ? '-'
        : (value == value.roundToDouble()
              ? value.toStringAsFixed(0)
              : value.toStringAsFixed(1));
    return Expanded(
      child: Column(
        children: [
          Container(
            width: 62,
            height: 62,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: colors.outlineVariant, width: 3),
            ),
            child: FittedBox(
              child: Text(
                '$display${label == 'Calories' ? '' : unit}',
                style: TextStyle(
                  color: colors.onSurface,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: 3),
          Text(
            label == 'Calories' ? 'kcal' : unit,
            style: TextStyle(fontSize: 10, color: colors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
