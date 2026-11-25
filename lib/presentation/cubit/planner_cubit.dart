import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/dataresource/local_database_service.dart';
import '../../data/models/meal_model.dart';
import '../../data/models/planned_meal.dart';
import 'planner_state.dart';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/services/meal_notification_service.dart';
import 'favorites_cubit.dart';

const plannerSlots = ['Breakfast', 'Lunch', 'Dinner'];

class PlannerCubit extends Cubit<PlannerState> {
  PlannerCubit({
    LocalDatabaseService? databaseService,
    FirebaseAuth? auth, // <-- ده المهم
    MealNotificationService? notificationService,
    FavoritesCubit? favoritesCubit,
  }) : _database = databaseService ?? LocalDatabaseService.instance,
       _auth = auth ?? FirebaseAuth.instance,
       _notifications = notificationService ?? MealNotificationService.instance,
       _favorites = favoritesCubit,
       super(PlannerState(selectedDay: _dateOnly(DateTime.now()))) {
    _lastUid = _auth.currentUser?.uid;
    _authSub = _auth.authStateChanges().listen((user) {
      if (user?.uid == _lastUid) return;
      _lastUid = user?.uid;
      if (isClosed) return;
      emit(PlannerState(selectedDay: state.selectedDay));
      loadDay(state.selectedDay);
    });
  }

  final LocalDatabaseService _database;
  final FirebaseAuth _auth;
  final MealNotificationService _notifications;
  final FavoritesCubit? _favorites;
  StreamSubscription<User?>? _authSub;
  String? _lastUid;
  int _loadGeneration = 0;

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
    if (isClosed) return;
    final generation = ++_loadGeneration;
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
      await _ensurePlannedMealsFavorited(weekMeals);
      if (isClosed || generation != _loadGeneration) return;
      emit(
        state.copyWith(
          meals: meals,
          weekMeals: weekMeals,
          isLoading: false,
          clearError: true,
        ),
      );
      if (!isClosed && generation == _loadGeneration) {
        await _notifications.syncScheduledMeals();
      }
    } catch (_) {
      if (isClosed || generation != _loadGeneration) return;
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
    if (isClosed) return;
    if (isPastDay(day)) {
      emit(
        state.copyWith(
          isLoading: false,
          errorMessage:
              'Past dates are view-only. Choose today or a future day.',
        ),
      );
      return;
    }
    final user = _auth.currentUser;
    if (user == null || user.isAnonymous) {
      emit(
        state.copyWith(
          isLoading: false,
          errorMessage: 'Sign in to add meals to your planner.',
        ),
      );
      return;
    }
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
      await _ensurePlannedMealsFavorited([
        PlannedMeal.fromMeal(
          meal: meal,
          day: day,
          slot: slot,
          servings: servings,
          calories: calories,
        ),
      ]);
      await loadDay(day);
    } catch (_) {
      if (isClosed) return;
      emit(
        state.copyWith(
          isLoading: false,
          errorMessage: 'Could not save this meal to your planner.',
        ),
      );
    }
  }

  Future<void> removeMeal(PlannedMeal meal) async {
    if (isClosed) return;
    if (isPastDay(meal.day)) {
      emit(
        state.copyWith(
          isLoading: false,
          errorMessage: 'Past planned meals cannot be changed or removed.',
        ),
      );
      return;
    }
    emit(state.copyWith(isLoading: true, clearError: true));
    try {
      await _database.removePlannedMeal(_uid, meal);
      await loadDay(state.selectedDay);
    } catch (_) {
      if (isClosed) return;
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
      _database.getPlannedMeal(_uid, day, slot);

  Future<void> _ensurePlannedMealsFavorited(
    List<PlannedMeal> plannedMeals,
  ) async {
    final user = _auth.currentUser;
    if (user == null || user.isAnonymous) return;

    final seen = <String>{};
    var addedFavorite = false;
    for (final planned in plannedMeals) {
      if (!seen.add(planned.idMeal)) continue;
      final favorite = await _database.isFavorite(_uid, planned.idMeal);
      if (favorite) continue;
      await _database.setFavorite(
        _uid,
        MealModel(
          idMeal: planned.idMeal,
          strMeal: planned.strMeal,
          strMealThumb: planned.strMealThumb,
          strCategory: planned.strCategory,
          strArea: planned.strArea,
        ),
        true,
      );
      addedFavorite = true;
    }
    if (addedFavorite && !isClosed) await _favorites?.load();
  }

  static DateTime dateOnly(DateTime value) => _dateOnly(value);

  static bool isPastDay(DateTime value) {
    final today = _dateOnly(DateTime.now());
    return _dateOnly(value).isBefore(today);
  }

  static DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  static bool _sameDay(DateTime first, DateTime second) =>
      first.year == second.year &&
      first.month == second.month &&
      first.day == second.day;
}
