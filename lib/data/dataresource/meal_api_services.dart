import 'package:dio/dio.dart';

import '../../core/network/dio_client.dart';
import '../models/meal_model.dart';

enum MealApiErrorType { network, timeout, http, invalidResponse }

class MealApiException implements Exception {
  final MealApiErrorType type;
  final String message;
  final int? statusCode;

  const MealApiException({
    required this.type,
    required this.message,
    this.statusCode,
  });

  @override
  String toString() => message;
}

class MealApiService {
  MealApiService({DioClient? client})
      : _client = client ?? DioClient(),
        _ownsClient = client == null;

  final DioClient _client;
  final bool _ownsClient;

  Future<Map<String, dynamic>> _getJson(
      String endpoint, {
        Map<String, dynamic>? query,
      }) async {
    try {
      final response = await _client.get(endpoint, queryParameters: query);
      final code = response.statusCode;
      if (code != null && code != 200) {
        throw MealApiException(
          type: MealApiErrorType.http,
          message: 'TheMealDB request failed.',
          statusCode: code,
        );
      }
      final data = response.data;
      if (data is Map) return Map<String, dynamic>.from(data);
      throw const MealApiException(
        type: MealApiErrorType.invalidResponse,
        message: 'Unexpected TheMealDB response.',
      );
    } on DioException catch (error) {
      switch (error.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          throw const MealApiException(
            type: MealApiErrorType.timeout,
            message: 'The search took too long. Please try again.',
          );
        case DioExceptionType.badResponse:
          throw MealApiException(
            type: MealApiErrorType.http,
            message: 'TheMealDB request failed.',
            statusCode: error.response?.statusCode,
          );
        case DioExceptionType.badCertificate:
          throw const MealApiException(
            type: MealApiErrorType.network,
            message:
            'A secure connection to TheMealDB could not be established.',
          );
        default:
          throw const MealApiException(
            type: MealApiErrorType.network,
            message: 'Could not connect to TheMealDB.',
          );
      }
    }
  }

  Future<MealModel?> getRandomMeal() async {
    final meals = (await _getJson('random.php'))['meals'];
    if (meals is List && meals.isNotEmpty && meals.first is Map) {
      return MealModel.fromJson(Map<String, dynamic>.from(meals.first as Map));
    }
    return null;
  }

  Future<MealModel?> getMealById(String id) async {
    if (id.trim().isEmpty) return null;
    final meals = (await _getJson('lookup.php', query: {'i': id}))['meals'];
    if (meals is List && meals.isNotEmpty && meals.first is Map) {
      return MealModel.fromJson(Map<String, dynamic>.from(meals.first as Map));
    }
    return null;
  }

  Future<List<String>> getCategories() async {
    final categories = (await _getJson('categories.php'))['categories'];
    if (categories is! List) return [];
    return categories
        .whereType<Map>()
        .map((e) => (e['strCategory'] ?? '').toString())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  Future<List<MealModel>> getMealsByCategory(String category) async {
    final data = await _getJson('filter.php', query: {'c': category});
    final meals = data['meals'];
    if (meals is! List) return [];
    return meals
        .whereType<Map>()
        .map(
          (e) => MealModel.fromFilterJson(
        Map<String, dynamic>.from(e),
        category: category,
      ),
    )
        .where((m) => m.idMeal.isNotEmpty)
        .toList();
  }

  Future<List<MealModel>> getMealsByCountry(String country) async {
    final data = await _getJson('filter.php', query: {'a': country});
    return _parseFilteredMeals(data['meals'], area: country);
  }

  Future<List<MealModel>> getMealsByIngredient(String ingredient) async {
    final data = await _getJson('filter.php', query: {'i': ingredient});
    return _parseFilteredMeals(data['meals']);
  }

  Future<List<MealModel>> searchMeals(String query) async {
    final data = await _getJson('search.php', query: {'s': query});
    final meals = data['meals'];
    if (meals is! List) return [];
    return meals
        .whereType<Map>()
        .map((meal) => MealModel.fromJson(Map<String, dynamic>.from(meal)))
        .where((meal) => meal.idMeal.isNotEmpty)
        .toList();
  }

  List<MealModel> _parseFilteredMeals(Object? value, {String? area}) {
    if (value is! List) return [];
    return value
        .whereType<Map>()
        .map(
          (meal) => MealModel.fromFilterJson(
        Map<String, dynamic>.from(meal),
        area: area,
      ),
    )
        .where((meal) => meal.idMeal.isNotEmpty)
        .toList();
  }

  Future<List<MealModel>> getPopularMeals() async {
    final unique = <String, MealModel>{};
    Object? firstError;
    for (final category in const ['Seafood', 'Pasta']) {
      try {
        final meals = await getMealsByCategory(category);
        for (final meal in meals) {
          unique.putIfAbsent(meal.idMeal, () => meal);
          if (unique.length == 6) break;
        }
        if (unique.length == 6) break;
      } catch (error) {
        firstError ??= error;
      }
    }
    if (unique.isNotEmpty) return unique.values.toList();
    if (firstError != null) throw firstError;
    return unique.values.toList();
  }

  void dispose() {
    if (_ownsClient) {
      _client.dispose();
    }
  }
}