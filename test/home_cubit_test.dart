import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nutri_mate/data/dataresource/local_database_service.dart';
import 'package:nutri_mate/data/dataresource/meal_api_services.dart';
import 'package:nutri_mate/data/models/meal_model.dart';
import 'package:nutri_mate/presentation/cubit/favorites_cubit.dart';
import 'package:nutri_mate/presentation/cubit/home_cubit.dart';

class _MockMealApiService extends Mock implements MealApiService {}

class _MockLocalDatabaseService extends Mock implements LocalDatabaseService {}

class _MockConnectivity extends Mock implements Connectivity {}

class _MockFirebaseAuth extends Mock implements FirebaseAuth {}

void main() {
  late _MockMealApiService api;
  late _MockLocalDatabaseService database;
  late _MockConnectivity connectivity;
  late _MockFirebaseAuth auth;
  late FavoritesCubit favorites;

  setUpAll(() {
    registerFallbackValue(<MealModel>[]);
    registerFallbackValue(
      const MealModel(
        idMeal: 'fallback',
        strMeal: 'Fallback',
        strMealThumb: '',
      ),
    );
  });

  setUp(() {
    api = _MockMealApiService();
    database = _MockLocalDatabaseService();
    connectivity = _MockConnectivity();
    auth = _MockFirebaseAuth();

 
    when(() => auth.currentUser).thenReturn(null);
    when(
          () => auth.authStateChanges(),
    ).thenAnswer((_) => const Stream<User?>.empty());

    favorites = FavoritesCubit(databaseService: database, auth: auth);
  });

  tearDown(() async {
    await favorites.close();
  });

  test('initialize emits error instead of remaining loading', () async {

    when(() => database.getCachedMeals(limit: any(named: 'limit'))).thenThrow(
      const LocalDatabaseException(
        type: LocalDatabaseErrorType.read,
        message: 'Could not read cached meals.',
      ),
    );
    final cubit = HomeCubit(
      apiService: api,
      databaseService: database,
      connectivity: connectivity,
      favoritesCubit: favorites,
    );

    await cubit.initialize();

    expect(cubit.state.isLoading, isFalse);
    expect(cubit.state.errorMessage, contains('Could not load'));
    await cubit.close();
  });

  test(
    'toggleFavorite surfaces detail fetch error and does not save partial meal',
        () async {
      const meal = MealModel(
        idMeal: '10',
        strMeal: 'Soup',
        strMealThumb: 'https://example.com/soup.jpg',
      );
      when(() => database.getFavorites('test_user_123')).thenAnswer((_) async => const []);

      when(
            () => database.getCachedMeals(limit: any(named: 'limit')),
      ).thenAnswer((_) async => const []);
      when(() => database.cacheMeals(any())).thenAnswer((_) async {});
      when(
            () => connectivity.checkConnectivity(),
      ).thenAnswer((_) async => const [ConnectivityResult.wifi]);
      when(
            () => connectivity.onConnectivityChanged,
      ).thenAnswer((_) => const Stream<List<ConnectivityResult>>.empty());
      when(() => api.getRandomMeal()).thenAnswer((_) async => null);
      when(() => api.getCategories()).thenAnswer((_) async => const []);
      when(() => api.getPopularMeals()).thenAnswer((_) async => const []);
      when(() => api.getMealById('10')).thenThrow(
        const MealApiException(
          type: MealApiErrorType.network,
          message: 'Could not connect.',
        ),
      );
      final cubit = HomeCubit(
        apiService: api,
        databaseService: database,
        connectivity: connectivity,
        favoritesCubit: favorites,
      );
      await cubit.initialize();

      await cubit.toggleFavorite(meal);

      expect(
        cubit.state.favoriteDetailErrorMessage,
        contains('Could not load recipe details'),
      );

      verifyNever(() => database.setFavorite(any(), any(), any()));
      await cubit.close();
    },
  );
}