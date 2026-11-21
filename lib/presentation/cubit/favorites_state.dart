import '../../data/models/meal_model.dart';

class FavoritesState {
  /// الـ uid اللي الـ meals دي بتاعته (null = مفيش يوزر داخل).
  final String? uid;
  final List<MealModel> meals;
  final bool isLoading;
  final String? errorMessage;

  const FavoritesState({
    this.uid,
    this.meals = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  Set<String> get ids => meals.map((meal) => meal.idMeal).toSet();

  FavoritesState copyWith({
    List<MealModel>? meals,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) => FavoritesState(
    uid: uid,
    meals: meals ?? this.meals,
    isLoading: isLoading ?? this.isLoading,
    errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
  );
}