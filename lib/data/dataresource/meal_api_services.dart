import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/meal.model.dart';

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
  static const String _baseUrl = 'https://www.themealdb.com/api/json/v1/1/';
  final http.Client _client;
  MealApiService({http.Client? client}) : _client = client ?? http.Client();

  Future<Map<String, dynamic>> _getJson(String endpoint) async {
    try {
      final response = await _client
          .get(Uri.parse('$_baseUrl$endpoint'))
          .timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) {
        throw MealApiException(
          type: MealApiErrorType.http,
          message: 'TheMealDB request failed.',
          statusCode: response.statusCode,
        );
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw const MealApiException(
          type: MealApiErrorType.invalidResponse,
          message: 'Unexpected TheMealDB response.',
        );
      }
      return decoded;
    } on TimeoutException {
      throw const MealApiException(
        type: MealApiErrorType.timeout,
        message: 'The search took too long. Please try again.',
      );
    } on http.ClientException {
      throw const MealApiException(
        type: MealApiErrorType.network,
        message: 'Could not connect to TheMealDB.',
      );
    } on SocketException {
      throw const MealApiException(
        type: MealApiErrorType.network,
        message: 'Could not connect to TheMealDB.',
      );
    } on HandshakeException {
      throw const MealApiException(
        type: MealApiErrorType.network,
        message: 'A secure connection to TheMealDB could not be established.',
      );
    } on HttpException {
      throw const MealApiException(
        type: MealApiErrorType.network,
        message: 'TheMealDB returned an invalid network response.',
      );
    } on FormatException {
      throw const MealApiException(
        type: MealApiErrorType.invalidResponse,
        message: 'Unexpected TheMealDB response.',
      );
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
    final meals = (await _getJson(
      'lookup.php?i=${Uri.encodeQueryComponent(id)}',
    ))['meals'];
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
    final data = await _getJson(
      'filter.php?c=${Uri.encodeQueryComponent(category)}',
    );
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
    final data = await _getJson(
      'filter.php?a=${Uri.encodeQueryComponent(country)}',
    );
    return _parseFilteredMeals(data['meals'], area: country);
  }

  Future<List<MealModel>> getMealsByIngredient(String ingredient) async {
    final data = await _getJson(
      'filter.php?i=${Uri.encodeQueryComponent(ingredient)}',
    );
    return _parseFilteredMeals(data['meals']);
  }

  Future<List<MealModel>> searchMeals(String query) async {
    final data = await _getJson(
      'search.php?s=${Uri.encodeQueryComponent(query)}',
    );
    final meals = data['meals'];
    if (meals is! List) return [];
    return meals
        .whereType<Map>()
        .map((meal) {
          return MealModel.fromJson(Map<String, dynamic>.from(meal));
        })
        .where((meal) => meal.idMeal.isNotEmpty)
        .toList();
  }

  List<MealModel> _parseFilteredMeals(Object? value, {String? area}) {
    if (value is! List) return [];
    return value
        .whereType<Map>()
        .map((meal) {
          return MealModel.fromFilterJson(
            Map<String, dynamic>.from(meal),
            area: area,
          );
        })
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

  void dispose() => _client.close();
}
