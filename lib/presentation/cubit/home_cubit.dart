import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/dataresource/local_database_service.dart';
import '../../data/dataresource/meal_api_services.dart';
import '../../data/models/meal.model.dart';
import 'home_state.dart';

class HomeCubit extends Cubit<HomeState> {
  HomeCubit({MealApiService? apiService, LocalDatabaseService? databaseService,
    Connectivity? connectivity})
      : _api = apiService ?? MealApiService(),
        _database = databaseService ?? LocalDatabaseService.instance,
        _connectivity = connectivity ?? Connectivity(),
        super(const HomeState());

  final MealApiService _api;
  final LocalDatabaseService _database;
  final Connectivity _connectivity;
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  bool _refreshing = false;

  Future<void> initialize() async {
    final favorites = await _database.getFavorites();
    final cached = await _database.getCachedMeals();
    final connection = await _connectivity.checkConnectivity();
    final online = connection.any((r) => r != ConnectivityResult.none);

    emit(state.copyWith(
      favorites: favorites,
      isOnline: online,
      mealOfDay: state.mealOfDay ?? (cached.isNotEmpty ? cached.first : null),
      popularMeals: state.popularMeals.isNotEmpty ? state.popularMeals : cached.take(6).toList(),
      isLoading: online,
      clearError: true,
    ));

    _subscription ??= _connectivity.onConnectivityChanged.listen((results) {
      final onlineNow = results.any((r) => r != ConnectivityResult.none);
      if (onlineNow != state.isOnline) {
        emit(state.copyWith(isOnline: onlineNow));
        if (onlineNow) refresh();
      }
    });

    if (online) {
      await refresh();
    } else {
      emit(state.copyWith(isLoading: false, errorMessage: cached.isEmpty
          ? 'You are offline. Connect to the internet to load recipes.'
          : 'Offline mode — showing saved recipes.'));
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
      final fetched = <MealModel>[? meal, ...popular];
      await _database.cacheMeals(fetched);
      emit(state.copyWith(
        isLoading: false,
        isOnline: true,
        mealOfDay: meal ?? state.mealOfDay,
        categories: categories.isNotEmpty ? categories : state.categories,
        popularMeals: popular.isNotEmpty ? popular : state.popularMeals,
        favorites: await _database.getFavorites(),
        clearError: true,
      ));
    } catch (_) {
      final cached = await _database.getCachedMeals();
      emit(state.copyWith(
        isLoading: false,
        isOnline: false,
        mealOfDay: state.mealOfDay ?? (cached.isNotEmpty ? cached.first : null),
        popularMeals: state.popularMeals.isNotEmpty ? state.popularMeals : cached.take(6).toList(),
        favorites: await _database.getFavorites(),
        errorMessage: cached.isEmpty
            ? 'Could not load recipes. Check your internet connection and try again.'
            : 'Connection unavailable. Showing saved recipes.',
      ));
    } finally {
      _refreshing = false;
    }
  }

  Future<void> toggleFavorite(MealModel meal) async {
    try {
      final currentlyFavorite = state.favoriteIds.contains(meal.idMeal);
      var toSave = meal;
      if (!currentlyFavorite && !meal.detailsLoaded && state.isOnline) {
        try {
          final details = await _api.getMealById(meal.idMeal);
          if (details != null) toSave = meal.mergeDetails(details);
        } catch (_) {}
      }
      await _database.setFavorite(toSave, !currentlyFavorite);
      await _database.cacheMeals([toSave]);
      emit(state.copyWith(favorites: await _database.getFavorites(), clearError: true));
    } catch (_) {
      emit(state.copyWith(errorMessage: 'Could not update favorites. Please try again.'));
    }
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    _api.dispose();
    return super.close();
  }
}
