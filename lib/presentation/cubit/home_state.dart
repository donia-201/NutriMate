import '../../data/models/meal.model.dart';

class HomeState {
  final bool isLoading;
  final bool isOnline;
  final MealModel? mealOfDay;
  final List<MealModel> popularMeals;
  final List<String> categories;
  final List<MealModel> favorites;
  final String? errorMessage;

  const HomeState({
    this.isLoading = true,
    this.isOnline = true,
    this.mealOfDay,
    this.popularMeals = const [],
    this.categories = const [],
    this.favorites = const [],
    this.errorMessage,
  });

  Set<String> get favoriteIds => favorites.map((m) => m.idMeal).toSet();

  HomeState copyWith({
    bool? isLoading, bool? isOnline, MealModel? mealOfDay,
    bool clearMealOfDay = false, List<MealModel>? popularMeals,
    List<String>? categories, List<MealModel>? favorites,
    String? errorMessage, bool clearError = false,
  }) => HomeState(
    isLoading: isLoading ?? this.isLoading,
    isOnline: isOnline ?? this.isOnline,
    mealOfDay: clearMealOfDay ? null : (mealOfDay ?? this.mealOfDay),
    popularMeals: popularMeals ?? this.popularMeals,
    categories: categories ?? this.categories,
    favorites: favorites ?? this.favorites,
    errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
  );
}
