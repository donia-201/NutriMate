import 'package:flutter/foundation.dart';

import '../../data/dataresource/local_database_service.dart';
import '../../data/models/meal_model.dart';
import '../../data/models/nutrition_model.dart';

class StagedMealEntry {
  final MealModel meal;
  final NutritionModel? nutrition;
  final DateTime eatenAt;

  const StagedMealEntry({
    required this.meal,
    this.nutrition,
    required this.eatenAt,
  });

  StagedMealEntry copyWith({
    MealModel? meal,
    NutritionModel? nutrition,
    DateTime? eatenAt,
  }) =>
      StagedMealEntry(
        meal: meal ?? this.meal,
        nutrition: nutrition ?? this.nutrition,
        eatenAt: eatenAt ?? this.eatenAt,
      );
}

class MealLogSession extends ChangeNotifier {
  final LocalDatabaseService _database;
  final List<StagedMealEntry> _entries = [];
  DateTime _selectedDateTime = DateTime.now();

  MealLogSession({LocalDatabaseService? database})
      : _database = database ?? LocalDatabaseService.instance;

  List<StagedMealEntry> get entries => List.unmodifiable(_entries);
  DateTime get selectedDateTime => _selectedDateTime;
  bool get hasEntries => _entries.isNotEmpty;

  void stageMeal(
    MealModel meal, {
    NutritionModel? nutrition,
    DateTime? eatenAt,
  }) {
    final timestamp = eatenAt ?? DateTime.now();
    _selectedDateTime = timestamp;
    _entries.add(
      StagedMealEntry(
        meal: meal,
        nutrition: nutrition,
        eatenAt: timestamp,
      ),
    );
    notifyListeners();
  }

  void removeEntryAt(int index) {
    if (index < 0 || index >= _entries.length) return;
    _entries.removeAt(index);
    notifyListeners();
  }

  void updateSelectedDateTime(DateTime dateTime) {
    _selectedDateTime = dateTime;
    for (var i = 0; i < _entries.length; i++) {
      _entries[i] = _entries[i].copyWith(eatenAt: dateTime);
    }
    notifyListeners();
  }

  Future<void> confirmAll(String uid) async {
    for (final entry in _entries) {
      await _database.logMeal(
        uid,
        entry.meal,
        nutrition: entry.nutrition,
        eatenAt: entry.eatenAt,
      );
    }
    _entries.clear();
    notifyListeners();
  }

  void clear() {
    _entries.clear();
    notifyListeners();
  }
}