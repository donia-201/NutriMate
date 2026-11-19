import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nutri_mate/data/dataresource/local_database_service.dart';
import 'package:nutri_mate/presentation/cubit/planner_cubit.dart';

class _MockLocalDatabaseService extends Mock implements LocalDatabaseService {}

void main() {
  test('planner loads an empty local day and supports retry', () async {
    registerFallbackValue(DateTime(2026));
    final database = _MockLocalDatabaseService();
    var shouldFail = true;
    when(() => database.getPlannedMealsBetween(any(), any())).thenAnswer((
      _,
    ) async {
      if (shouldFail) throw StateError('database unavailable');
      return [];
    });
    final cubit = PlannerCubit(databaseService: database);

    await cubit.initialize();
    expect(cubit.state.errorMessage, 'Could not load your planned meals.');

    shouldFail = false;
    await cubit.retry();
    expect(cubit.state.errorMessage, isNull);
    expect(cubit.state.meals, isEmpty);

    await cubit.close();
  });
}
