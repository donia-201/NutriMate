
import 'healthy_alternative.dart';
import 'nutrition_summary.dart';

class MealAnalysisResult {
  final NutritionSummary nutrition;
  final double? balanceScore;
  final String assessment;
  final List<String> tips;
  final List<HealthyAlternative> alternatives;

  const MealAnalysisResult({
    required this.nutrition,
    this.balanceScore,
    this.assessment = '',
    this.tips = const [],
    this.alternatives = const [],
  });

  factory MealAnalysisResult.fromJson(Map<String, dynamic> json) {
    final nutritionJson = json['nutrition'];

    final alternativesJson = json['alternatives'];
    final tipsJson = json['tips'];

    return MealAnalysisResult(
      nutrition: NutritionSummary.fromJson(
        nutritionJson is Map
            ? Map<String, dynamic>.from(nutritionJson)
            : <String, dynamic>{},
      ),
      balanceScore: _parseScore(json['balanceScore']),
      assessment: (json['assessment'] ?? '').toString(),
      tips: tipsJson is List
          ? tipsJson.map((item) => item.toString()).toList()
          : [],
      alternatives: alternativesJson is List
          ? alternativesJson
              .whereType<Map>()
              .map(
                (item) => HealthyAlternative.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              )
              .toList()
          : [],
    );
  }

  static double? _parseScore(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }
}