import 'package:dio/dio.dart';

import '../../core/network/api_exception.dart';
import '../../core/network/dio_client.dart';

class NutritionApiService {
  static const String _baseUrl = String.fromEnvironment(
    'NUTRITION_API_BASE_URL',
    defaultValue: 'https://nutrimate-production.up.railway.app/api/',
  );

  NutritionApiService({DioClient? client})
      : _client = client ??
            DioClient(
              baseUrl: _baseUrl.trim().isEmpty
                  ? 'https://invalid.invalid/'
                  : _baseUrl,
            ),
        _ownsClient = client == null,
        _isConfigured =
            client != null || _baseUrl.trim().isNotEmpty;

  final DioClient _client;
  final bool _ownsClient;
  final bool _isConfigured;

  Future<Map<String, dynamic>> calculateRecipe(
    List<Map<String, dynamic>> ingredients,
  ) async {
    if (!_isConfigured) {
      throw const ApiException(
        message:
            'Nutrition service is not configured. '
            'Set NUTRITION_API_BASE_URL.',
      );
    }

    if (ingredients.isEmpty) {
      throw const ApiException(
        message: 'Please provide at least one ingredient.',
      );
    }

    try {
      final response = await _client.post<dynamic>(
        'nutrition/recipe',
        data: {
          'ingredients': ingredients,
        },
      );

      if (response.data is! Map) {
        throw const ApiException(
          message: 'Invalid nutrition response from server.',
        );
      }

      return Map<String, dynamic>.from(response.data as Map);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException(
        message: 'Could not calculate recipe nutrition.',
      );
    }
  }

  void dispose() {
    if (_ownsClient) {
      _client.dispose();
    }
  }
}