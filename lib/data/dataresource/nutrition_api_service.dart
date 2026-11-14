import 'package:dio/dio.dart';

import '../../core/network/api_exception.dart';
import '../../core/network/dio_client.dart';

class NutritionApiService {
  // Replace YOUR_LAPTOP_IP with your laptop's IPv4 address.
  static const String _baseUrl =
      'http://10.212.121.234:3000/api/';

  NutritionApiService({DioClient? client})
      : _client = client ?? DioClient(baseUrl: _baseUrl),
        _ownsClient = client == null;

  final DioClient _client;
  final bool _ownsClient;

  Future<Map<String, dynamic>> calculateRecipe(
    List<Map<String, dynamic>> ingredients,
  ) async {
    try {
      final response = await _client.post(
        'nutrition/recipe',
        data: {'ingredients': ingredients},
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