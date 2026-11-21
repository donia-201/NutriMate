import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/dataresource/local_database_service.dart';
import '../../data/dataresource/meal_api_services.dart';
import '../../data/models/meal_model.dart';
import '../../data/repositories/nutrition_repository.dart';
import 'favorites_cubit.dart';
import 'favorites_state.dart';
import 'home_state.dart';

class HomeCubit extends Cubit<HomeState> {
  HomeCubit({
    MealApiService? apiService,
    LocalDatabaseService? databaseService,
    NutritionRepository? nutritionRepository,
    Connectivity? connectivity,
    FavoritesCubit? favoritesCubit,
  })  : _api = apiService ?? MealApiService(),
        _database = databaseService ?? LocalDatabaseService.instance,
        _nutritionRepository = nutritionRepository ?? NutritionRepository(),
        _connectivity = connectivity ?? Connectivity(),
        _favorites = favoritesCubit ?? FavoritesCubit(),
        _ownsFavorites = favoritesCubit == null,
        _ownsApi = apiService == null,
        _ownsNutritionRepository = nutritionRepository == null,
        super(const HomeState()) {
    // المفضلة بتيجي من FavoritesCubit (per-user). أي تغيير فيها، سواء من
    // الهوم أو من شاشة الـ Favorites أو من تغيير الحساب، بيوصل هنا لوحده.
    _favoritesSub = _favorites.stream.listen((FavoritesState s) {
      if (isClosed) return;
      emit(state.copyWith(favorites: s.meals));
    });
  }

  final MealApiService _api;
  final LocalDatabaseService _database;
  final NutritionRepository _nutritionRepository;
  final Connectivity _connectivity;
  final FavoritesCubit _favorites;
  final bool _ownsFavorites;
  StreamSubscription<FavoritesState>? _favoritesSub;

  final bool _ownsApi;
  final bool _ownsNutritionRepository;

  StreamSubscription<List<ConnectivityResult>>? _subscription;
  bool _refreshing = false;

  Future<void> initialize() async {
    try {
      final favorites = _favorites.state.meals;
      final cached = await _database.getCachedMeals();
      if (isClosed) return;
      final connection = await _connectivity.checkConnectivity();
      if (isClosed) return;
      final online = connection.any((r) => r != ConnectivityResult.none);

      emit(
        state.copyWith(
          favorites: favorites,
          isOnline: online,
          mealOfDay:
          state.mealOfDay ?? (cached.isNotEmpty ? cached.first : null),
          popularMeals: state.popularMeals.isNotEmpty
              ? state.popularMeals
              : cached.take(6).toList(),
          isLoading: online,
          clearError: true,
        ),
      );

      _subscription ??= _connectivity.onConnectivityChanged.listen((results) {
        if (isClosed) return;
        final onlineNow = results.any((r) => r != ConnectivityResult.none);
        if (onlineNow != state.isOnline) {
          emit(state.copyWith(isOnline: onlineNow));
          if (onlineNow) refresh();
        }
      });

      if (online) {
        await refresh();
      } else if (!isClosed) {
        emit(
          state.copyWith(
            isLoading: false,
            errorMessage: cached.isEmpty
                ? 'You are offline. Connect to the internet to load recipes.'
                : 'Offline mode — showing saved recipes.',
          ),
        );
      }
    } catch (_) {
      if (isClosed) return;
      emit(
        state.copyWith(
          isLoading: false,
          isOnline: false,
          errorMessage: 'Could not load saved or online recipe data.',
        ),
      );
    }
  }

  Future<void> refresh() async {
    if (_refreshing) return;

    _refreshing = true;
    emit(state.copyWith(isLoading: true, clearError: true));

    try {
      final meal = await _api.getRandomMeal();
      final categories = await _api.getCategories();
      final popular = await _api.getPopularMeals();
      final fetched = <MealModel>[?meal, ...popular];
      await _database.cacheMeals(fetched);
      if (isClosed) return;
      final favorites = _favorites.state.meals;

      final selectedMeal = meal ?? state.mealOfDay;

      emit(
        state.copyWith(
          isLoading: false,
          isOnline: true,
          mealOfDay: selectedMeal,
          categories: categories.isNotEmpty ? categories : state.categories,
          popularMeals: popular.isNotEmpty ? popular : state.popularMeals,
          favorites: favorites,
          clearError: true,
          clearNutrition: true,
          clearNutritionError: true,
          isNutritionLoading: false,
        ),
      );

      if (selectedMeal != null) {
        unawaited(loadMealNutrition(selectedMeal));
      }
    } catch (_) {
      List<MealModel> cached = const [];
      try {
        cached = await _database.getCachedMeals();
      } catch (_) {}
      if (isClosed) return;
      final favorites = _favorites.state.meals;
      emit(
        state.copyWith(
          isLoading: false,
          isOnline: false,
          mealOfDay:
          state.mealOfDay ?? (cached.isNotEmpty ? cached.first : null),
          popularMeals: state.popularMeals.isNotEmpty
              ? state.popularMeals
              : cached.take(6).toList(),
          favorites: favorites,
          errorMessage: cached.isEmpty
              ? 'Could not load recipes. Check your internet connection and try again.'
              : 'Connection unavailable. Showing saved recipes.',
        ),
      );
    } finally {
      _refreshing = false;
    }
  }

  Future<void> loadMealNutrition(MealModel meal) async {
    if (!state.isOnline) {
      emit(state.copyWith(
        clearNutrition: true,
        isNutritionLoading: false,
        nutritionError: 'Nutrition calculation requires an internet connection.',
      ));
      return;
    }

    emit(state.copyWith(
      isNutritionLoading: true,
      clearNutrition: true,
      clearNutritionError: true,
    ));

    try {
      var detailedMeal = meal;

      // Filter results and cached meals may not contain ingredients.
      if (detailedMeal.ingredients.isEmpty) {
        final details = await _api.getMealById(meal.idMeal);

        if (details == null || details.ingredients.isEmpty) {
          throw Exception('No ingredient details found for this meal.');
        }

        detailedMeal = meal.mergeDetails(details);

        await _database.cacheMeals([detailedMeal]);

        if (state.mealOfDay?.idMeal == meal.idMeal) {
          emit(state.copyWith(mealOfDay: detailedMeal));
        }
      }

      final nutrition =
      await _nutritionRepository.calculateMealNutrition(
        detailedMeal.ingredients,
      );

      // Ignore an old response if the Meal of the Day has changed.
      if (isClosed) return;
      if (state.mealOfDay?.idMeal != meal.idMeal) return;

      emit(state.copyWith(
        mealNutrition: nutrition,
        isNutritionLoading: false,
        clearNutritionError: true,
      ));
    } catch (error) {
      if (isClosed) return;
      if (state.mealOfDay?.idMeal != meal.idMeal) return;

      emit(state.copyWith(
        isNutritionLoading: false,
        nutritionError: error.toString(),
      ));
    }
  }

  Future<void> toggleFavorite(MealModel meal) async {
    try {
      final currentlyFavorite = state.favoriteIds.contains(meal.idMeal);

      var toSave = meal;

      if (!currentlyFavorite && !meal.detailsLoaded && state.isOnline) {
        try {
          final details = await _api.getMealById(meal.idMeal);
          if (isClosed) return;
          if (details != null) {
            toSave = meal.mergeDetails(details);
          } else {
            emit(
              state.copyWith(
                favoriteDetailErrorMessage:
                'Could not load recipe details. Try again before favoriting.',
              ),
            );
            return;
          }
        } catch (_) {
          if (isClosed) return;
          emit(
            state.copyWith(
              favoriteDetailErrorMessage:
              'Could not load recipe details. Please check your connection.',
            ),
          );
          return;
        }
      }

      final ok = await _favorites.toggle(toSave);
      if (isClosed) return;

      if (!ok) {
        emit(
          state.copyWith(
            errorMessage: _favorites.state.errorMessage ??
                'Could not update favorites. Please try again.',
          ),
        );
        return;
      }

      await _database.cacheMeals([toSave]);
      if (isClosed) return;

      // القايمة نفسها اتحدّثت من الـ listener فوق.
      emit(
        state.copyWith(
          favorites: _favorites.state.meals,
          clearError: true,
          clearFavoriteDetailError: true,
        ),
      );
    } catch (_) {
      if (isClosed) return;
      emit(
        state.copyWith(
          errorMessage: 'Could not update favorites. Please try again.',
        ),
      );
    }
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    await _favoritesSub?.cancel();

    if (_ownsFavorites) {
      await _favorites.close();
    }

    if (_ownsApi) {
      _api.dispose();
    }

    if (_ownsNutritionRepository) {
      _nutritionRepository.dispose();
    }

    return super.close();
  }
}