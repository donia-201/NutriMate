import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutri_mate/core/network/dio_client.dart';
import 'package:nutri_mate/data/dataresource/meal_api_services.dart';

class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.handler);

  final Future<ResponseBody> Function(RequestOptions options) handler;

  @override
  Future<ResponseBody> fetch(
      RequestOptions options,
      Stream<Uint8List>? requestStream,
      Future<void>? cancelFuture,
      ) => handler(options);

  @override
  void close({bool force = false}) {}
}

MealApiService _serviceWith(
    Future<ResponseBody> Function(RequestOptions options) handler,
    ) {
  final client = DioClient();
  client.dio.httpClientAdapter = _FakeAdapter(handler);
  return MealApiService(client: client);
}

void main() {
  test('getPopularMeals keeps a successful partial category result', () async {
    final api = _serviceWith((options) async {
      if (options.uri.queryParameters['c'] == 'Seafood') {
        return ResponseBody.fromString(
          jsonEncode({
            'meals': [
              {'idMeal': '1', 'strMeal': 'Fish', 'strMealThumb': 'fish.jpg'},
            ],
          }),
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      }
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.connectionError,
      );
    });

    final meals = await api.getPopularMeals();

    expect(meals, hasLength(1));
    expect(meals.first.idMeal, '1');
    api.dispose();
  });

  test('network exception is mapped to MealApiException', () async {
    final api = _serviceWith((options) async {
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.connectionError,
      );
    });

    await expectLater(
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
