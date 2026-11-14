
import 'ai_recipe_model.dart';

class HealthyAlternative {
  final AiRecipeModel recipe;
  final String reason;
  final String? improvementSummary;

  const HealthyAlternative({
    required this.recipe,
    required this.reason,
    this.improvementSummary,
  });

  factory HealthyAlternative.fromJson(Map<String, dynamic> json) {
    return HealthyAlternative(
      recipe: AiRecipeModel.fromJson(
        Map<String, dynamic>.from(json['recipe'] as Map),
      ),
      reason: (json['reason'] ?? '').toString(),
      improvementSummary: json['improvementSummary']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'recipe': recipe.toJson(),
      'reason': reason,
      'improvementSummary': improvementSummary,
    };
  }
}