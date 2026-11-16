
import 'nutrition_summary.dart';

class AiRecipeModel {
  final String id;
  final String name;
  final String? imageUrl;
  final String? category;
  final String? area;
  final String? description;
  final NutritionSummary? nutrition;

  const AiRecipeModel({
    required this.id,
    required this.name,
    this.imageUrl,
    this.category,
    this.area,
    this.description,
    this.nutrition,
  });

  factory AiRecipeModel.fromJson(Map<String, dynamic> json) {
    final nutritionJson = json['nutrition'];

    return AiRecipeModel(
      id: (json['id'] ?? json['idMeal'] ?? '').toString(),
      name: (json['name'] ?? json['strMeal'] ?? '').toString(),
      imageUrl: (json['imageUrl'] ?? json['strMealThumb'])?.toString(),
      category: (json['category'] ?? json['strCategory'])?.toString(),
      area: (json['area'] ?? json['strArea'])?.toString(),
      description: json['description']?.toString(),
      nutrition: nutritionJson is Map<String, dynamic>
          ? NutritionSummary.fromJson(nutritionJson)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'imageUrl': imageUrl,
      'category': category,
      'area': area,
      'description': description,
      'nutrition': nutrition?.toJson(),
    };
  }
}