import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nutri_mate/core/services/meal_notification_service.dart';
import 'package:nutri_mate/data/dataresource/local_database_service.dart';
import 'package:nutri_mate/data/models/meal_model.dart';
import 'package:nutri_mate/data/models/planned_meal.dart';
import 'package:nutri_mate/presentation/cubit/favorites_cubit.dart';
import 'package:nutri_mate/presentation/cubit/planner_cubit.dart';

class _MockLocalDatabaseService extends Mock implements LocalDatabaseService {}

class _MockFirebaseAuth extends Mock implements FirebaseAuth {}

class _MockUser extends Mock implements User {}

class _MockMealNotificationService extends Mock
    implements MealNotificationService {}

class _MockFavoritesCubit extends Mock implements FavoritesCubit {}

class _FakeMealModel extends Fake implements MealModel {}

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

  test('saving a meal refreshes planner, favorites, and reminders', () async {
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
    registerFallbackValue(_FakeMealModel());

    final user = _MockUser();
    when(() => user.uid).thenReturn('user-1');
    when(() => user.isAnonymous).thenReturn(false);

    final auth = _MockFirebaseAuth();
    when(() => auth.currentUser).thenReturn(user);
    when(() => auth.authStateChanges()).thenAnswer((_) => const Stream.empty());

    final plannedMeals = <PlannedMeal>[];
    var isFavorite = false;
    final database = _MockLocalDatabaseService();
    when(
      () => database.getPlannedMealsBetween(any(), any(), any()),
    ).thenAnswer((_) async => List.of(plannedMeals));
    when(() => database.savePlannedMeal(any(), any())).thenAnswer((
      invocation,
    ) async {
      plannedMeals.add(invocation.positionalArguments[1] as PlannedMeal);
    });
    when(
      () => database.isFavorite('user-1', '1'),
    ).thenAnswer((_) async => isFavorite);
    when(() => database.setFavorite('user-1', any(), true)).thenAnswer((
      _,
    ) async {
      isFavorite = true;
    });

    final notifications = _MockMealNotificationService();
    when(() => notifications.syncScheduledMeals()).thenAnswer((_) async {});
    final favorites = _MockFavoritesCubit();
    when(() => favorites.load()).thenAnswer((_) async {});

    final cubit = PlannerCubit(
      databaseService: database,
      auth: auth,
      notificationService: notifications,
      favoritesCubit: favorites,
    );
    final today = PlannerCubit.dateOnly(DateTime.now());
    const meal = MealModel(idMeal: '1', strMeal: 'Test meal', strMealThumb: '');

    await cubit.loadDay(today);
    await cubit.saveMeal(meal: meal, day: today, slot: 'Lunch');

    expect(cubit.state.selectedDay, today);
    expect(cubit.state.meals, hasLength(1));
    expect(cubit.state.meals.single.strMeal, 'Test meal');
    verify(() => favorites.load()).called(1);
    verify(() => notifications.syncScheduledMeals()).called(2);

    await cubit.close();
  });
}
