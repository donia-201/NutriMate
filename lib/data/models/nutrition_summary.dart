
class NutritionSummary {
  final double? calories;
  final double? protein;
  final double? carbohydrates;
  final double? fat;
  final double? fiber;

  final bool isComplete;
  final bool isEstimated;
  final String? scope;
  final List<String> missingNutrients;
  final List<String> unresolvedIngredients;
  final String? disclaimer;

  const NutritionSummary({
    this.calories,
    this.protein,
    this.carbohydrates,
    this.fat,
    this.fiber,
    this.isComplete = false,
    this.isEstimated = false,
    this.scope,
    this.missingNutrients = const [],
    this.unresolvedIngredients = const [],
    this.disclaimer,
  });

  factory NutritionSummary.fromJson(Map<String, dynamic> json) {
    double? parseNumber(dynamic value) {
      if (value is num) return value.toDouble();
      return double.tryParse(value?.toString() ?? '');
    }

    List<String> parseStringList(dynamic value) {
      if (value is! List) return [];
      return value.map((item) => item.toString()).toList();
    }

    return NutritionSummary(
      calories: parseNumber(json['calories']),
      protein: parseNumber(json['protein']),
      carbohydrates: parseNumber(
        json['carbohydrates'] ?? json['carbs'],
      ),
      fat: parseNumber(json['fat']),
      fiber: parseNumber(json['fiber']),
      isComplete: json['isComplete'] == true,
      isEstimated: json['isEstimated'] == true,
      scope: json['scope']?.toString(),
      missingNutrients: parseStringList(json['missingNutrients']),
      unresolvedIngredients:
          parseStringList(json['unresolvedIngredients']),
      disclaimer: json['disclaimer']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'calories': calories,
      'protein': protein,
      'carbohydrates': carbohydrates,
      'fat': fat,
      'fiber': fiber,
      'isComplete': isComplete,
      'isEstimated': isEstimated,
      'scope': scope,
      'missingNutrients': missingNutrients,
      'unresolvedIngredients': unresolvedIngredients,
      'disclaimer': disclaimer,
    };
  }
}