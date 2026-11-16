import 'package:dio/dio.dart';

import '../../core/network/dio_client.dart';
import '../../core/network/api_exception.dart';
import '../models/meal_model.dart';

class MealApiService {
  MealApiService({DioClient? client})
    : _client = client ?? DioClient(),
      _ownsClient = client == null;

  final DioClient _client;
  final bool _ownsClient;

  Future<MealModel?> getRandomMeal() async {
    try {
      final response = await _client.get('random.php');

      final meals = response.data['meals'] as List?;

      if (meals == null || meals.isEmpty) {
        return null;
      }

      return MealModel.fromJson(Map<String, dynamic>.from(meals.first));
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    } catch (_) {
      throw ApiException(message: 'Could not load a random meal.');
    }
  }

  Future<List<String>> getCategories() async {
    try {
      final response = await _client.get(
        'list.php',
        queryParameters: {'c': 'list'},
      );

      final categories = response.data['meals'] as List?;

      if (categories == null) return [];

      return categories.map((item) => item['strCategory'].toString()).toList();
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    } catch (_) {
      throw ApiException(message: 'Could not load meal categories.');
    }
  }

  Future<List<MealModel>> getPopularMeals() async {
    try {
      final response = await _client.get(
        'search.php',
        queryParameters: {'s': 'chicken'},
      );

      final meals = response.data['meals'] as List?;

      if (meals == null) return [];

      return meals
          .map((item) => MealModel.fromJson(Map<String, dynamic>.from(item)))
          .toList();
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    } catch (_) {
      throw ApiException(message: 'Could not load suggested meals.');
    }
  }

  Future<List<MealModel>> getMealsByCategory(String category) async {
    try {
      final response = await _client.get(
        'filter.php',
        queryParameters: {'c': category},
      );

      final meals = response.data['meals'] as List?;

      if (meals == null) return [];

      return meals
          .map(
            (item) => MealModel.fromFilterJson(
              Map<String, dynamic>.from(item),
              category: category,
            ),
          )
          .toList();
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    } catch (_) {
      throw ApiException(message: 'Could not load meals for this category.');
    }
  }

  Future<MealModel?> getMealById(String id) async {
    try {
      final response = await _client.get(
        'lookup.php',
        queryParameters: {'i': id},
      );

      final meals = response.data['meals'] as List?;

      if (meals == null || meals.isEmpty) {
        return null;
      }

      return MealModel.fromJson(Map<String, dynamic>.from(meals.first));
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    } catch (_) {
      throw ApiException(message: 'Could not load meal details.');
    }
  }

  void dispose() {
    if (_ownsClient) {
      _client.dispose();
    }
  }
}
