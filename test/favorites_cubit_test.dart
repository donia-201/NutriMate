import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nutri_mate/data/dataresource/local_database_service.dart';
import 'package:nutri_mate/data/models/meal_model.dart';
import 'package:nutri_mate/presentation/cubit/favorites_cubit.dart';

class _MockLocalDatabaseService extends Mock implements LocalDatabaseService {}

class _MockFirebaseAuth extends Mock implements FirebaseAuth {}

class _MockUser extends Mock implements User {}

void main() {
  const soup = MealModel(
    idMeal: '10',
    strMeal: 'Soup',
    strMealThumb: 'https://example.com/soup.jpg',
  );

  late _MockLocalDatabaseService database;
  late _MockFirebaseAuth auth;
  late StreamController<User?> authChanges;
  late _MockUser userA;
  late _MockUser userB;

  setUpAll(() {
    registerFallbackValue(soup);
  });

  setUp(() {
    database = _MockLocalDatabaseService();
    auth = _MockFirebaseAuth();
    authChanges = StreamController<User?>.broadcast();

    userA = _MockUser();
    userB = _MockUser();
    when(() => userA.uid).thenReturn('a');
    when(() => userA.isAnonymous).thenReturn(false);
    when(() => userB.uid).thenReturn('b');
    when(() => userB.isAnonymous).thenReturn(false);

    when(() => auth.currentUser).thenReturn(userA);
    when(() => auth.authStateChanges()).thenAnswer((_) => authChanges.stream);
  });

  tearDown(() async {
    await authChanges.close();
  });

  test('loads only the favorites of the signed-in user', () async {
    when(() => database.getFavorites('a')).thenAnswer((_) async => [soup]);

    final cubit = FavoritesCubit(databaseService: database, auth: auth);
    await pumpEventQueue();

    expect(cubit.state.uid, 'a');
    expect(cubit.state.ids, {'10'});
    verify(() => database.getFavorites('a')).called(1);
    verifyNever(() => database.getFavorites('b'));
    await cubit.close();
  });

  test('switching account shows the other account favorites', () async {
    when(() => database.getFavorites('a')).thenAnswer((_) async => [soup]);
    when(() => database.getFavorites('b')).thenAnswer((_) async => const []);

    final cubit = FavoritesCubit(databaseService: database, auth: auth);
    await pumpEventQueue();
    expect(cubit.state.ids, {'10'});

    authChanges.add(userB);
    await pumpEventQueue();

    expect(cubit.state.uid, 'b');
    expect(cubit.state.meals, isEmpty);
    verify(() => database.getFavorites('b')).called(1);
    await cubit.close();
  });

  test('sign out clears the favorites without querying the database', () async {
    when(() => database.getFavorites('a')).thenAnswer((_) async => [soup]);

    final cubit = FavoritesCubit(databaseService: database, auth: auth);
    await pumpEventQueue();

    authChanges.add(null);
    await pumpEventQueue();

    expect(cubit.state.uid, isNull);
    expect(cubit.state.meals, isEmpty);
    verify(() => database.getFavorites(any())).called(1); // بس بتاع 'a'
    await cubit.close();
  });

  test('toggle writes under the current uid and reloads', () async {
    var saved = false;
    when(() => database.getFavorites('a')).thenAnswer(
          (_) async => saved ? [soup] : const <MealModel>[],
    );
    when(() => database.setFavorite('a', any(), true)).thenAnswer((_) async {
      saved = true;
    });

    final cubit = FavoritesCubit(databaseService: database, auth: auth);
    await pumpEventQueue();
    expect(cubit.state.meals, isEmpty);

    final ok = await cubit.toggle(soup);

    expect(ok, isTrue);
    expect(cubit.state.ids, {'10'});
    verify(() => database.setFavorite('a', any(), true)).called(1);
    await cubit.close();
  });

  test('toggle without a signed-in user does nothing', () async {
    when(() => auth.currentUser).thenReturn(null);

    final cubit = FavoritesCubit(databaseService: database, auth: auth);
    await pumpEventQueue();

    final ok = await cubit.toggle(soup);

    expect(ok, isFalse);
    verifyNever(() => database.setFavorite(any(), any(), any()));
    await cubit.close();
  });

  test('guest (anonymous) user cannot add favorites', () async {
    final guest = _MockUser();
    when(() => guest.uid).thenReturn('guest-uid');
    when(() => guest.isAnonymous).thenReturn(true);
    when(() => auth.currentUser).thenReturn(guest);
    when(() => database.getFavorites('guest-uid'))
        .thenAnswer((_) async => const []);

    final cubit = FavoritesCubit(databaseService: database, auth: auth);
    await pumpEventQueue();

    final ok = await cubit.toggle(soup);

    expect(ok, isFalse);
    expect(cubit.state.errorMessage, contains('Sign in'));
    verifyNever(() => database.setFavorite(any(), any(), any()));
    await cubit.close();
  });
}