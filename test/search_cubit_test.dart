import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nutri_mate/data/dataresource/local_database_service.dart';
import 'package:nutri_mate/data/dataresource/meal_api_services.dart';
import 'package:nutri_mate/data/models/meal_model.dart';
import 'package:nutri_mate/presentation/cubit/search_cubit.dart';
import 'package:nutri_mate/presentation/cubit/search_state.dart';

class _MockMealApiService extends Mock implements MealApiService {}

class _MockLocalDatabaseService extends Mock implements LocalDatabaseService {}

void main() {
  late _MockMealApiService api;
  late _MockLocalDatabaseService database;
  late SearchCubit cubit;

  setUp(() {
    registerFallbackValue(<MealModel>[]);
    api = _MockMealApiService();
    database = _MockLocalDatabaseService();
    cubit = SearchCubit(apiService: api, databaseService: database);
  });

  tearDown(() => cubit.close());

  test('text search uses the existing searchMeals API method', () async {
    const meal = MealModel(
      idMeal: '1',
      strMeal: 'Chicken Soup',
      strMealThumb: 'https://example.com/chicken.jpg',
    );
    cubit.setMode(SearchMode.search);
    when(
      () => api.searchMeals('chicken'),
    ).thenAnswer((_) async => const [meal]);
    when(() => database.cacheMeals(any())).thenAnswer((_) async {});

    await cubit.search('chicken');

    expect(cubit.state.meals, const [meal]);
    expect(cubit.state.isLoading, isFalse);
    expect(cubit.state.errorMessage, isNull);
    verify(() => api.searchMeals('chicken')).called(1);
  });

  test('network error is exposed and retry loads results', () async {
    const meal = MealModel(
      idMeal: '2',
      strMeal: 'Pasta',
      strMealThumb: 'https://example.com/pasta.jpg',
    );
    cubit.setMode(SearchMode.search);
    var shouldFail = true;
    when(() => api.searchMeals('pasta')).thenAnswer((_) async {
      if (shouldFail) {
        throw const MealApiException(
          type: MealApiErrorType.network,
          message: 'Could not connect.',
        );
      }
      return const [meal];
    });
    when(() => database.cacheMeals(any())).thenAnswer((_) async {});

    await cubit.search('pasta');
    expect(cubit.state.errorMessage, contains('Check your connection'));

    shouldFail = false;
    await cubit.retry();
    expect(cubit.state.errorMessage, isNull);
    expect(cubit.state.meals, const [meal]);
  });

  test('submit cancels debounce and searches immediately', () async {
    const meal = MealModel(
      idMeal: '3',
      strMeal: 'Greek Salad',
      strMealThumb: 'https://example.com/salad.jpg',
    );
    cubit.setMode(SearchMode.search);
    when(
      () => api.searchMeals('Greek Salad'),
    ).thenAnswer((_) async => const [meal]);
    when(() => database.cacheMeals(any())).thenAnswer((_) async {});

    cubit.searchChanged('Greek Salad');
    await cubit.submit('Greek Salad');

    expect(cubit.state.meals, const [meal]);
    verify(() => api.searchMeals('Greek Salad')).called(1);
  });

  test('clear resets search state and hides previous results', () {
    cubit.clear();

    expect(cubit.state.hasSearched, isFalse);
    expect(cubit.state.meals, isEmpty);
    expect(cubit.state.query, isEmpty);
  });
}
