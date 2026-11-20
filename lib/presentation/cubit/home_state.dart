import '../../data/models/meal_model.dart';
import '../../data/models/nutrition_model.dart';

class HomeState {
  final bool isLoading;
  final bool isOnline;
  final MealModel? mealOfDay;
  final List<MealModel> popularMeals;
  final List<String> categories;
  final List<MealModel> favorites;
  final String? errorMessage;
  final String? favoriteDetailErrorMessage;

  final NutritionModel? mealNutrition;
  final bool isNutritionLoading;
  final String? nutritionError;

  const HomeState({
    this.isLoading = true,
    this.isOnline = true,
    this.mealOfDay,
    this.popularMeals = const [],
    this.categories = const [],
    this.favorites = const [],
    this.errorMessage,
    this.favoriteDetailErrorMessage,
    this.mealNutrition,
    this.isNutritionLoading = false,
    this.nutritionError,
  });

  Set<String> get favoriteIds =>
      favorites.map((meal) => meal.idMeal).toSet();

  HomeState copyWith({
    bool? isLoading,
    bool? isOnline,
    MealModel? mealOfDay,
    bool clearMealOfDay = false,
    List<MealModel>? popularMeals,
    List<String>? categories,
    List<MealModel>? favorites,
    String? errorMessage,
    bool clearError = false,
    String? favoriteDetailErrorMessage,
    bool clearFavoriteDetailError = false,
    NutritionModel? mealNutrition,
    bool? isNutritionLoading,
    String? nutritionError,
    bool clearNutrition = false,
    bool clearNutritionError = false,
  }) {
    return HomeState(
      isLoading: isLoading ?? this.isLoading,
      isOnline: isOnline ?? this.isOnline,
      mealOfDay: clearMealOfDay ? null : (mealOfDay ?? this.mealOfDay),
      popularMeals: popularMeals ?? this.popularMeals,
      categories: categories ?? this.categories,
      favorites: favorites ?? this.favorites,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      favoriteDetailErrorMessage: clearFavoriteDetailError
          ? null
          : (favoriteDetailErrorMessage ?? this.favoriteDetailErrorMessage),
      mealNutrition:
      clearNutrition ? null : (mealNutrition ?? this.mealNutrition),
      isNutritionLoading: isNutritionLoading ?? this.isNutritionLoading,
      nutritionError: clearNutritionError
          ? null
          : (nutritionError ?? this.nutritionError),
    );
  }
}