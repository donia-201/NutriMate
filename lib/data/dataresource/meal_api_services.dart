import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/meal.model.dart';

class MealApiService {
  static const String _baseUrl = 'https://www.themealdb.com/api/json/v1/1/';
  final http.Client _client;
  MealApiService({http.Client? client}) : _client = client ?? http.Client();

  Future<Map<String, dynamic>> _getJson(String endpoint) async {
    final response = await _client.get(Uri.parse('$_baseUrl$endpoint'))
        .timeout(const Duration(seconds: 12));
    if (response.statusCode != 200) {
      throw Exception('TheMealDB request failed (${response.statusCode}).');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Unexpected TheMealDB response.');
    }
    return decoded;
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
    final meals = (await _getJson('lookup.php?i=${Uri.encodeQueryComponent(id)}'))['meals'];
    if (meals is List && meals.isNotEmpty && meals.first is Map) {
      return MealModel.fromJson(Map<String, dynamic>.from(meals.first as Map));
    }
    return null;
  }

  Future<List<String>> getCategories() async {
    final categories = (await _getJson('categories.php'))['categories'];
    if (categories is! List) return [];
    return categories.whereType<Map>()
        .map((e) => (e['strCategory'] ?? '').toString())
        .where((e) => e.isNotEmpty).toList();
  }

  Future<List<MealModel>> getMealsByCategory(String category) async {
    final data = await _getJson('filter.php?c=${Uri.encodeQueryComponent(category)}');
    final meals = data['meals'];
    if (meals is! List) return [];
    return meals.whereType<Map>().map((e) => MealModel.fromFilterJson(
      Map<String, dynamic>.from(e), category: category,
    )).where((m) => m.idMeal.isNotEmpty).toList();
  }

  Future<List<MealModel>> getPopularMeals() async {
    final seafood = await getMealsByCategory('Seafood');
    final pasta = await getMealsByCategory('Pasta');
    final unique = <String, MealModel>{};
    for (final meal in [...seafood, ...pasta]) {
      unique.putIfAbsent(meal.idMeal, () => meal);
      if (unique.length == 6) break;
    }
    return unique.values.toList();
  }

  void dispose() => _client.close();
}
