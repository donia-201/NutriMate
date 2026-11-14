import 'package:dio/dio.dart';

import '../../core/network/dio_client.dart';
import '../models/meal_analysis_request.dart';
import '../models/meal_analysis_result.dart';
import '../models/healthy_alternative.dart';
import '../models/nutrition_summary.dart';

class AiRemoteDataSource {
  final DioClient _dioClient;
  final bool useMockData;

  AiRemoteDataSource({
    required DioClient dioClient,
    this.useMockData = true,
  }) : _dioClient = dioClient;

  // These paths are provisional until the Backend endpoints are implemented.
  static const String _mealAnalysisPath = '/api/ai/meal-analysis';
  static const String _healthyAlternativesPath =
      '/api/ai/healthy-alternatives';

  Future<MealAnalysisResult> analyzeMeal(
    MealAnalysisRequest request,
  ) async {
    if (useMockData) {
      return _mockMealAnalysis();
    }

    try {
      final response = await _dioClient.post<Map<String, dynamic>>(
        _mealAnalysisPath,
        data: request.toJson(),
      );

      final data = _parseResponse(response.data);

      return MealAnalysisResult.fromJson(data);
    } on DioException {
      rethrow;
    } on FormatException {
      rethrow;
    } catch (error) {
      throw Exception('Failed to analyze meal: $error');
    }
  }

  Future<List<HealthyAlternative>> findHealthyAlternatives(
    MealAnalysisRequest request,
  ) async {
    if (useMockData) {
      return _mockHealthyAlternatives();
    }

    try {
      final response = await _dioClient.post<Map<String, dynamic>>(
        _healthyAlternativesPath,
        data: request.toJson(),
      );

      final data = _parseResponse(response.data);
      final alternativesJson = data['alternatives'];

      if (alternativesJson is! List) {
        throw const FormatException(
          'Invalid alternatives response format.',
        );
      }

      return alternativesJson
          .whereType<Map>()
          .map(
            (item) => HealthyAlternative.fromJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList();
    } on DioException {
      rethrow;
    } on FormatException {
      rethrow;
    } catch (error) {
      throw Exception('Failed to find healthy alternatives: $error');
    }
  }

  Map<String, dynamic> _parseResponse(dynamic responseData) {
    if (responseData is Map<String, dynamic>) {
      return responseData;
    }

    if (responseData is Map) {
      return Map<String, dynamic>.from(responseData);
    }

    throw const FormatException(
      'Invalid AI API response format.',
    );
  }

  MealAnalysisResult _mockMealAnalysis() {
    return const MealAnalysisResult(
      nutrition: NutritionSummary(
        isComplete: false,
        isEstimated: false,
        disclaimer:
            'Nutrition information is not available in the demo response.',
      ),
      assessment:
          'Your meal has been submitted for analysis. '
          'Detailed nutrition information will be available '
          'when the AI service is connected.',
      tips: [
        'Try to include a variety of food groups in your meals.',
        'Consider adding vegetables or fruits for more dietary variety.',
      ],
      alternatives: [],
    );
  }

  List<HealthyAlternative> _mockHealthyAlternatives() {
    return const [];
  }

  void dispose() {
  _dioClient.dispose();
}
}