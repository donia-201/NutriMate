import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/dataresource/local_database_service.dart';
import '../../data/models/meal_model.dart';
import '../../data/models/planned_meal.dart';
import 'planner_state.dart';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';

const plannerSlots = ['Breakfast', 'Lunch', 'Dinner'];


class PlannerCubit extends Cubit<PlannerState> {
  PlannerCubit({
    LocalDatabaseService? databaseService,
    FirebaseAuth? auth,                      // <-- ده المهم
  })  : _database = databaseService ?? LocalDatabaseService.instance,
        _auth = auth ?? FirebaseAuth.instance,
        super(PlannerState(selectedDay: _dateOnly(DateTime.now()))) {
    _lastUid = _auth.currentUser?.uid;
    _authSub = _auth.authStateChanges().listen((user) {
      if (user?.uid == _lastUid) return;
      _lastUid = user?.uid;
      emit(PlannerState(selectedDay: state.selectedDay));
      loadDay(state.selectedDay);
    });
  }

  final LocalDatabaseService _database;
  final FirebaseAuth _auth;
  StreamSubscription<User?>? _authSub;
  String? _lastUid;

  String get _uid => _auth.currentUser?.uid ?? 'guest';


  @override
  Future<void> close() async {
    await _authSub?.cancel();
    return super.close();
  }

  // TODO: Add a pending-sync flag when planner data is connected to a backend.

  Future<void> initialize() async {
    await loadDay(state.selectedDay);
  }

  Future<void> retry() => loadDay(state.selectedDay);

  Future<void> loadDay(DateTime day) async {
    final selectedDay = _dateOnly(day);
    emit(
      state.copyWith(
        selectedDay: selectedDay,
        isLoading: true,
        clearError: true,
      ),
    );
    try {
      final weekStart = selectedDay.subtract(
        Duration(days: selectedDay.weekday - DateTime.monday),
      );
      final weekMeals = await _database.getPlannedMealsBetween(
        _uid,
        weekStart,
        weekStart.add(const Duration(days: 6)),
      );
      final meals = weekMeals
          .where((meal) => _sameDay(meal.day, selectedDay))
          .toList();
      emit(
        state.copyWith(
          meals: meals,
          weekMeals: weekMeals,
          isLoading: false,
          clearError: true,
        ),
      );
    } catch (_) {
      emit(
        state.copyWith(
          isLoading: false,
          errorMessage: 'Could not load your planned meals.',
        ),
      );
    }
  }

  Future<void> saveMeal({
    required MealModel meal,
    required DateTime day,
    required String slot,
    int servings = 1,
    int calories = 0,
  }) async {
    emit(state.copyWith(isLoading: true, clearError: true));
    try {
      await _database.savePlannedMeal(
        _uid,
        PlannedMeal.fromMeal(
          meal: meal,
          day: day,
          slot: slot,
          servings: servings,
          calories: calories,
        ),
      );
      await loadDay(day);
    } catch (_) {
      emit(
        state.copyWith(
          isLoading: false,
          errorMessage: 'Could not save this meal to your planner.',
        ),
      );
    }
  }

  Future<void> removeMeal(PlannedMeal meal) async {
    emit(state.copyWith(isLoading: true, clearError: true));
    try {
      await _database.removePlannedMeal(_uid,meal);
      await loadDay(state.selectedDay);
    } catch (_) {
      emit(
        state.copyWith(
          isLoading: false,
          errorMessage: 'Could not remove this planned meal.',
        ),
      );
    }
  }

  Future<List<MealModel>> cachedMeals() => _database.getCachedMeals(limit: 50);

  Future<PlannedMeal?> plannedMeal(DateTime day, String slot) =>
      _database.getPlannedMeal(_uid,day, slot);

  static DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  static bool _sameDay(DateTime first, DateTime second) =>
      first.year == second.year &&
      first.month == second.month &&
      first.day == second.day;
}
