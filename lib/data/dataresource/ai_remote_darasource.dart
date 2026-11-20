import 'package:dio/dio.dart';

import '../../core/network/ai_api_config.dart';
import '../../core/network/api_exception.dart';
import '../../core/network/dio_client.dart';
import '../models/ai_recipe_model.dart';
import '../models/healthy_alternative.dart';
import '../models/meal_analysis_request.dart';
import '../models/meal_analysis_result.dart';
import '../models/meal_model.dart';
import 'meal_api_services.dart';

/// Calls the application's AI backend. TheMealDB remains the source of truth
/// for recipe identity and display details; AI-generated recipe details are
/// never rendered unless their TheMealDB ID can be verified.
class AiRemoteDataSource {
  AiRemoteDataSource({
    required this._aiDioClient,
    required this._mealApiService,
  });

  final DioClient _aiDioClient;
  final MealApiService _mealApiService;

  Future<MealAnalysisResult> analyzeMeal(
    MealAnalysisRequest request,
  ) async {
    _ensureConfigured();
    _validateRequest(request);

    try {
      final response = await _aiDioClient.post<dynamic>(
        AiApiConfig.mealAnalysisPath,
        data: request.toJson(),
      );
      final data = _unwrapResponse(response.data);
      return MealAnalysisResult.fromJson(data);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    } on ApiException {
      rethrow;
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const ApiException(
        message: 'The AI service returned an invalid meal analysis.',
      );
    }
  }

  Future<List<HealthyAlternative>> findHealthyAlternatives(
    MealAnalysisRequest request,
  ) async {
    _ensureConfigured();
    _validateRequest(request);

    try {
      final response = await _aiDioClient.post<dynamic>(
        AiApiConfig.healthyAlternativesPath,
        data: request.toJson(),
      );
      final data = _unwrapResponse(response.data);
      final rawAlternatives = data['alternatives'];

      if (rawAlternatives is! List) {
        throw const FormatException(
          'The AI response must contain an alternatives list.',
        );
      }

      return _resolveVerifiedAlternatives(rawAlternatives);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    } on ApiException {
      rethrow;
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const ApiException(
        message: 'The AI service could not return healthy alternatives.',
      );
    }
  }

  void _ensureConfigured() {
    if (!AiApiConfig.isConfigured) {
      throw const ApiException(
        message: 'AI service is not connected yet. Configure AI_API_BASE_URL '
            'with your backend URL to enable this feature.',
      );
    }
  }

  void _validateRequest(MealAnalysisRequest request) {
    if (request.mealDescription.trim().isEmpty) {
      throw const ApiException(message: 'Please describe your meal first.');
    }
  }

  Map<String, dynamic> _unwrapResponse(dynamic responseData) {
    if (responseData is! Map) {
      throw const FormatException('Invalid AI API response format.');
    }

    final root = Map<String, dynamic>.from(responseData);
    if (root['success'] == false) {
      throw ApiException(
        message: (root['message'] ?? 'The AI request was not successful.')
            .toString(),
      );
    }
    final nested = root['data'] ?? root['result'];
    if (nested is Map) return Map<String, dynamic>.from(nested);
    return root;
  }

  Future<List<HealthyAlternative>> _resolveVerifiedAlternatives(
    List<dynamic> alternativesJson,
  ) async {
    final candidates = <HealthyAlternative>[];
    final seenIds = <String>{};

    for (final item in alternativesJson.take(10)) {
      if (item is! Map) continue;
      try {
        final alternative = HealthyAlternative.fromJson(
          Map<String, dynamic>.from(item),
        );
        final id = alternative.recipe.id.trim();
        if (id.isEmpty || !RegExp(r'^\d+$').hasMatch(id)) continue;
        if (!seenIds.add(id)) continue;
        candidates.add(alternative);
      } catch (_) {
        // Ignore malformed suggestions; never render unverified AI data.
      }
    }

    final verified = await Future.wait(
      candidates.take(5).map((candidate) async {
        MealModel? meal;
        try {
          meal = await _mealApiService.getMealById(candidate.recipe.id);
        } catch (_) {
          return null;
        }
        if (meal == null || meal.idMeal.isEmpty) return null;

        return HealthyAlternative(
          recipe: AiRecipeModel(
            id: meal.idMeal,
            name: meal.strMeal,
            imageUrl: meal.strMealThumb,
            category: meal.strCategory,
            area: meal.strArea,
            description: meal.strInstructions,
          ),
          reason: candidate.reason,
          improvementSummary: candidate.improvementSummary,
        );
      }),
    );

    return verified.whereType<HealthyAlternative>().toList();
  }

  void dispose() {
    _aiDioClient.dispose();
    _mealApiService.dispose();
  }
}
