import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/dataresource/local_database_service.dart';
import '../../data/dataresource/meal_api_services.dart';
import 'search_state.dart';

class SearchCubit extends Cubit<SearchState> {
  SearchCubit({
    MealApiService? apiService,
    LocalDatabaseService? databaseService,
  }) : _api = apiService ?? MealApiService(),
       _database = databaseService ?? LocalDatabaseService.instance,
       super(const SearchState());

  final MealApiService _api;
  final LocalDatabaseService _database;
  Timer? _debounce;
  int _requestId = 0;

  void setMode(SearchMode mode) {
    _debounce?.cancel();
    emit(
      state.copyWith(
        mode: mode,
        clearSelectedValue: true,
        meals: const [],
        clearError: true,
        hasSearched: false,
      ),
    );
  }

  void searchChanged(String value) {
    _debounce?.cancel();
    emit(
      state.copyWith(
        query: value,
        clearSelectedValue: true,
        meals: const [],
        clearError: true,
        hasSearched: false,
      ),
    );
    final query = value.trim();
    if (query.isEmpty) return;
    _debounce = Timer(const Duration(milliseconds: 350), () {
      search(query);
    });
  }

  Future<void> submit(String value) {
    _debounce?.cancel();
    _debounce = null;
    return search(value);
  }

  void clear() {
    _debounce?.cancel();
    _debounce = null;
    emit(
      state.copyWith(
        query: '',
        clearSelectedValue: true,
        meals: const [],
        clearError: true,
        hasSearched: false,
      ),
    );
  }

  Future<void> select(String value) => search(value, selectedValue: value);

  Future<void> search(String value, {String? selectedValue}) async {
    final query = value.trim();
    if (query.isEmpty) return;
    final requestId = ++_requestId;
    emit(
      state.copyWith(
        isLoading: true,
        query: query,
        selectedValue: selectedValue,
        clearError: true,
        hasSearched: true,
      ),
    );
    try {
      final meals = switch (state.mode) {
        SearchMode.search => await _api.searchMeals(query),
        SearchMode.category => await _api.getMealsByCategory(query),
        SearchMode.country => await _api.getMealsByCountry(query),
        SearchMode.ingredient => await _api.getMealsByIngredient(query),
      };
      if (requestId != _requestId || isClosed) return;
      await _database.cacheMeals(meals);
      emit(state.copyWith(isLoading: false, meals: meals, clearError: true));
    } catch (error) {
      if (requestId != _requestId || isClosed) return;
      emit(
        state.copyWith(
          isLoading: false,
          meals: const [],
          errorMessage: _messageFor(error),
        ),
      );
    }
  }

  Future<void> retry() => search(
    state.selectedValue ?? state.query,
    selectedValue: state.selectedValue,
  );

  String _messageFor(Object error) {
    if (error is MealApiException) {
      if (error.type == MealApiErrorType.timeout) {
        return 'The search took too long. Please try again.';
      }
      if (error.type == MealApiErrorType.network) {
        return 'Could not connect. Check your connection and try again.';
      }
      return 'Could not load recipes. Please try again.';
    }
    if (error is TimeoutException) {
      return 'The search took too long. Please try again.';
    }
    return 'Could not load recipes. Check your connection and try again.';
  }

  @override
  Future<void> close() async {
    _debounce?.cancel();
    _api.dispose();
    return super.close();
  }
}
