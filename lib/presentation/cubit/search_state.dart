import '../../data/models/meal_model.dart';

enum SearchMode { search, category, country, ingredient }

class SearchState {
  final SearchMode mode;
  final String? selectedValue;
  final String query;
  final List<MealModel> meals;
  final bool isLoading;
  final String? errorMessage;
  final bool hasSearched;

  const SearchState({
    this.mode = SearchMode.category,
    this.selectedValue,
    this.query = '',
    this.meals = const [],
    this.isLoading = false,
    this.errorMessage,
    this.hasSearched = false,
  });

  bool get isIdle => !isLoading && !hasSearched && errorMessage == null;

  SearchState copyWith({
    SearchMode? mode,
    String? selectedValue,
    bool clearSelectedValue = false,
    String? query,
    List<MealModel>? meals,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
    bool? hasSearched,
  }) => SearchState(
    mode: mode ?? this.mode,
    selectedValue: clearSelectedValue
        ? null
        : (selectedValue ?? this.selectedValue),
    query: query ?? this.query,
    meals: meals ?? this.meals,
    isLoading: isLoading ?? this.isLoading,
    errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    hasSearched: hasSearched ?? this.hasSearched,
  );
}
