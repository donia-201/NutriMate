import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nutri_mate/data/dataresource/local_database_service.dart';
import 'package:nutri_mate/data/models/meal_model.dart';
import 'package:nutri_mate/data/models/planned_meal.dart';
import 'package:nutri_mate/presentation/cubit/planner_cubit.dart';

class _MockLocalDatabaseService extends Mock implements LocalDatabaseService {}

class _MockFirebaseAuth extends Mock implements FirebaseAuth {}

void main() {
  test('planner loads an empty local day and supports retry', () async {
    registerFallbackValue(DateTime(2026));

    final auth = _MockFirebaseAuth();
    when(() => auth.currentUser).thenReturn(null);
    when(() => auth.authStateChanges()).thenAnswer((_) => const Stream.empty());

    final database = _MockLocalDatabaseService();
    var shouldFail = true;
    when(() => database.getPlannedMealsBetween(any(), any(), any())).thenAnswer(
      (_) async {
        if (shouldFail) throw StateError('database unavailable');
        return [];
      },
    );

    final cubit = PlannerCubit(databaseService: database, auth: auth);

    await cubit.initialize();
    expect(cubit.state.errorMessage, 'Could not load your planned meals.');

    shouldFail = false;
    await cubit.retry();
    expect(cubit.state.errorMessage, isNull);
    expect(cubit.state.meals, isEmpty);

    await cubit.close();
  });

  test('planner blocks saving and removing meals on past days', () async {
    registerFallbackValue(DateTime(2026));
    registerFallbackValue(
      PlannedMeal(
        idMeal: '1',
        strMeal: 'Test meal',
        strMealThumb: '',
        day: DateTime(2026),
        slot: 'Lunch',
      ),
    );

    final auth = _MockFirebaseAuth();
    when(() => auth.currentUser).thenReturn(null);
    when(() => auth.authStateChanges()).thenAnswer((_) => const Stream.empty());

    final database = _MockLocalDatabaseService();
    final cubit = PlannerCubit(databaseService: database, auth: auth);

    await cubit.saveMeal(
      meal: const MealModel(
        idMeal: '1',
        strMeal: 'Test meal',
        strMealThumb: '',
      ),
      day: DateTime.now().subtract(const Duration(days: 1)),
      slot: 'Lunch',
    );

    expect(
      cubit.state.errorMessage,
      'Past dates are view-only. Choose today or a future day.',
    );

    await cubit.removeMeal(
      PlannedMeal(
        idMeal: '1',
        strMeal: 'Test meal',
        strMealThumb: '',
        day: DateTime.now().subtract(const Duration(days: 1)),
        slot: 'Lunch',
      ),
    );

    expect(
      cubit.state.errorMessage,
      'Past planned meals cannot be changed or removed.',
    );
    verifyNever(() => database.savePlannedMeal(any(), any()));
    verifyNever(() => database.removePlannedMeal(any(), any()));

    await cubit.close();
  });

  test('planner blocks guests from saving meals', () async {
    registerFallbackValue(
      PlannedMeal(
        idMeal: '1',
        strMeal: 'Test meal',
        strMealThumb: '',
        day: DateTime.now(),
        slot: 'Lunch',
      ),
    );

    final auth = _MockFirebaseAuth();
    when(() => auth.currentUser).thenReturn(null);
    when(() => auth.authStateChanges()).thenAnswer((_) => const Stream.empty());

    final database = _MockLocalDatabaseService();
    final cubit = PlannerCubit(databaseService: database, auth: auth);

    await cubit.saveMeal(
      meal: const MealModel(
        idMeal: '1',
        strMeal: 'Test meal',
        strMealThumb: '',
      ),
      day: DateTime.now().add(const Duration(days: 1)),
      slot: 'Lunch',
    );

    expect(cubit.state.errorMessage, 'Sign in to add meals to your planner.');
    verifyNever(() => database.savePlannedMeal(any(), any()));

    await cubit.close();
  });
}
