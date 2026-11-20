class NutritionModel {
  final double? calories;
  final double? protein;
  final double? carbohydrates;
  final double? fat;
  final double? fiber;

  final String scope;
  final bool isComplete;
  final bool isEstimated;
  final List<String> missingNutrients;
  final List<Map<String, dynamic>> unresolvedIngredients;
  final String? disclaimer;

  const NutritionModel({
    required this.calories,
    required this.protein,
    required this.carbohydrates,
    required this.fat,
    required this.fiber,
    required this.scope,
    required this.isComplete,
    required this.isEstimated,
    required this.missingNutrients,
    required this.unresolvedIngredients,
    this.disclaimer,
  });

  factory NutritionModel.fromJson(Map<String, dynamic> json) {
    final nutrition = json['nutrition'] is Map
        ? Map<String, dynamic>.from(json['nutrition'] as Map)
        : <String, dynamic>{};

    double? readNumber(String key) {
      final value = nutrition[key];
      if (value == null) return null;
      return double.tryParse(value.toString());
    }

    return NutritionModel(
      calories: readNumber('calories'),
      protein: readNumber('protein'),
      carbohydrates: readNumber('carbohydrates'),
      fat: readNumber('fat'),
      fiber: readNumber('fiber'),
      scope: (json['scope'] ?? 'whole_recipe').toString(),
      isComplete: json['isComplete'] == true,
      isEstimated: json['isEstimated'] == true,
      missingNutrients: (json['missingNutrients'] as List? ?? [])
          .map((item) => item.toString())
          .toList(),
      unresolvedIngredients:
          (json['unresolvedIngredients'] as List? ?? [])
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList(),
      disclaimer: json['disclaimer']?.toString(),
    );
  }
}