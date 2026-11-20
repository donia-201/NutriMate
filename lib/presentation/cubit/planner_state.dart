import '../../data/models/planned_meal.dart';

class PlannerState {
  final DateTime selectedDay;
  final List<PlannedMeal> meals;
  final List<PlannedMeal> weekMeals;
  final bool isLoading;
  final String? errorMessage;

  const PlannerState({
    required this.selectedDay,
    this.meals = const [],
    this.weekMeals = const [],
    this.isLoading = true,
    this.errorMessage,
  });

  PlannerState copyWith({
    DateTime? selectedDay,
    List<PlannedMeal>? meals,
    List<PlannedMeal>? weekMeals,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) => PlannerState(
    selectedDay: selectedDay ?? this.selectedDay,
    meals: meals ?? this.meals,
    weekMeals: weekMeals ?? this.weekMeals,
    isLoading: isLoading ?? this.isLoading,
    errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
  );
}
