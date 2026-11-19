import 'meal.model.dart';

class PlannedMeal {
  final int? localId;
  final String idMeal;
  final String strMeal;
  final String strMealThumb;
  final String? strCategory;
  final String? strArea;
  final DateTime day;
  final String slot;
  final int servings;
  final int calories;

  const PlannedMeal({
    this.localId,
    required this.idMeal,
    required this.strMeal,
    required this.strMealThumb,
    this.strCategory,
    this.strArea,
    required this.day,
    required this.slot,
    this.servings = 1,
    this.calories = 0,
  });

  factory PlannedMeal.fromDbMap(Map<String, Object?> map) => PlannedMeal(
    localId: map['localId'] as int?,
    idMeal: (map['idMeal'] ?? '').toString(),
    strMeal: (map['strMeal'] ?? '').toString(),
    strMealThumb: (map['strMealThumb'] ?? '').toString(),
    strCategory: map['strCategory']?.toString(),
    strArea: map['strArea']?.toString(),
    day: DateTime.parse((map['day'] ?? '').toString()),
    slot: (map['slot'] ?? '').toString(),
    servings: (map['servings'] as int?) ?? 1,
    calories: (map['calories'] as int?) ?? 0,
  );

  factory PlannedMeal.fromMeal({
    required MealModel meal,
    required DateTime day,
    required String slot,
    int servings = 1,
    int calories = 0,
  }) => PlannedMeal(
    idMeal: meal.idMeal,
    strMeal: meal.strMeal,
    strMealThumb: meal.strMealThumb,
    strCategory: meal.strCategory,
    strArea: meal.strArea,
    day: DateTime(day.year, day.month, day.day),
    slot: slot,
    servings: servings,
    calories: calories,
  );

  Map<String, Object?> toDbMap() => {
    'idMeal': idMeal,
    'strMeal': strMeal,
    'strMealThumb': strMealThumb,
    'strCategory': strCategory,
    'strArea': strArea,
    'day': _dayKey(day),
    'slot': slot,
    'servings': servings,
    'calories': calories,
  };

  String get dayKey => _dayKey(day);

  static String _dayKey(DateTime value) =>
      DateTime(value.year, value.month, value.day).toIso8601String();
}
