import '../../core/network/api_exception.dart';
import '../dataresource/nutrition_api_service.dart';
import '../models/meal_model.dart';
import '../models/nutrition_model.dart';

class NutritionRepository {
  NutritionRepository({NutritionApiService? service})
      : _service = service ?? NutritionApiService(),
        _ownsService = service == null;

  final NutritionApiService _service;
  final bool _ownsService;

  Future<NutritionModel> calculateMealNutrition(
    List<MealIngredient> ingredients,
  ) async {
    if (ingredients.isEmpty) {
      throw const ApiException(
        message: 'No ingredients available for nutrition calculation.',
      );
    }

    final payload = ingredients
        .map((ingredient) => ingredient.toJson())
        .toList();

    final response = await _service.calculateRecipe(payload);

    if (response['success'] != true) {
      throw ApiException(
        message: (response['message'] ??
                'Nutrition calculation failed.')
            .toString(),
      );
    }

    return NutritionModel.fromJson(response);
  }

  void dispose() {
    if (_ownsService) {
      _service.dispose();
    }
  }
}