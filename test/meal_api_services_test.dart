import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nutri_mate/data/dataresource/meal_api_services.dart';

void main() {
  test('getPopularMeals keeps a successful partial category result', () async {
    final api = MealApiService(
      client: MockClient((request) async {
        if (request.url.queryParameters['c'] == 'Seafood') {
          return http.Response(
            jsonEncode({
              'meals': [
                {'idMeal': '1', 'strMeal': 'Fish', 'strMealThumb': 'fish.jpg'},
              ],
            }),
            200,
          );
        }
        throw http.ClientException('Pasta service unavailable');
      }),
    );

    final meals = await api.getPopularMeals();

    expect(meals, hasLength(1));
    expect(meals.first.idMeal, '1');
    api.dispose();
  });

  test('network exception is mapped to MealApiException', () async {
    final api = MealApiService(
      client: MockClient((_) => throw http.ClientException('No internet')),
    );

    expect(
      api.getRandomMeal(),
      throwsA(
        isA<MealApiException>().having(
          (error) => error.type,
          'type',
          MealApiErrorType.network,
        ),
      ),
    );
    api.dispose();
  });
}
