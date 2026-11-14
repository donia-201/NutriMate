class MealAnalysisRequest {
  final String mealDescription;
  final List<String> dietaryPreferences;
  final String? additionalRequest;

  const MealAnalysisRequest({
    required this.mealDescription,
    this.dietaryPreferences = const [],
    this.additionalRequest,
  });

  Map<String, dynamic> toJson() {
    return {
      'mealDescription': mealDescription.trim(),
      'dietaryPreferences': dietaryPreferences,
      'additionalRequest': additionalRequest?.trim(),
    };
  }
}