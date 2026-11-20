import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nutri_mate/data/dataresource/local_database_service.dart';
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
    when(() => database.getPlannedMealsBetween(any(), any(), any()))
        .thenAnswer((_) async {
      if (shouldFail) throw StateError('database unavailable');
      return [];
    });

    final cubit = PlannerCubit(databaseService: database, auth: auth);

    await cubit.initialize();
    expect(cubit.state.errorMessage, 'Could not load your planned meals.');

    shouldFail = false;
    await cubit.retry();
    expect(cubit.state.errorMessage, isNull);
    expect(cubit.state.meals, isEmpty);

    await cubit.close();
  });
}