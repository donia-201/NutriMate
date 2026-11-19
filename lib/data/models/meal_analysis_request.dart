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
    final additional = additionalRequest?.trim();
    return {
      'mealDescription': mealDescription.trim(),
      'dietaryPreferences': dietaryPreferences,
      if (additional != null && additional.isNotEmpty)
        'additionalRequest': additional,
    };
  }
}
