import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/dataresource/local_database_service.dart';
import '../../data/dataresource/meal_api_services.dart';
import 'search_state.dart';

class SearchCubit extends Cubit<SearchState> {
  static const Duration nameSearchDebounce = Duration(milliseconds: 2000);

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
    _debounce = null;
    ++_requestId;
    emit(
      state.copyWith(
        mode: mode,
        clearSelectedValue: true,
        meals: const [],
        clearError: true,
        hasSearched: false,
        isLoading: false,
        isTyping: false,
      ),
    );
  }

  void searchChanged(String value) {
    _debounce?.cancel();
    ++_requestId;
    if (state.mode != SearchMode.search) {
      emit(
        state.copyWith(
          query: value,
          clearSelectedValue: true,
          clearError: true,
          hasSearched: false,
          isLoading: false,
          isTyping: false,
        ),
      );
      _debounce = null;
      return;
    }
    emit(
      state.copyWith(
        query: value,
        clearSelectedValue: true,
        meals: const [],
        clearError: true,
        hasSearched: false,
        isLoading: false,
        isTyping: value.trim().isNotEmpty && state.mode == SearchMode.search,
      ),
    );
    final query = value.trim();
    if (query.isEmpty || state.mode != SearchMode.search) {
      _debounce = null;
      emit(state.copyWith(isTyping: false));
      return;
    }
    _debounce = Timer(nameSearchDebounce, () {
      _debounce = null;
      if (isClosed) return;
      search(query);
    });
  }

  Future<void> submit(String value) {
    _debounce?.cancel();
    _debounce = null;
    if (isClosed) return Future.value();
    if (state.mode != SearchMode.search) return Future.value();
    return search(value);
  }

  void clear() {
    _debounce?.cancel();
    _debounce = null;
    ++_requestId;
    emit(
      state.copyWith(
        query: '',
        clearSelectedValue: true,
        meals: const [],
        clearError: true,
        hasSearched: false,
        isLoading: false,
        isTyping: false,
      ),
    );
  }

  void resetDiscovery() {
    if (isClosed) return;
    _debounce?.cancel();
    _debounce = null;
    ++_requestId;
    emit(
      state.copyWith(
        clearSelectedValue: true,
        query: '',
        meals: const [],
        isLoading: false,
        clearError: true,
        hasSearched: false,
        isTyping: false,
      ),
    );
  }

  void cancelPendingSearch() {
    _debounce?.cancel();
    _debounce = null;
    ++_requestId;
  }

  Future<bool> select(String value) async {
    if (isClosed) return false;
    await search(value, selectedValue: value);
    if (isClosed) return false;
    return state.errorMessage == null;
  }

  Future<void> search(String value, {String? selectedValue}) async {
    if (isClosed) return;
    final query = value.trim();
    if (query.isEmpty) return;
    final requestId = ++_requestId;
    emit(
      state.copyWith(
        isLoading: true,
        isTyping: false,
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