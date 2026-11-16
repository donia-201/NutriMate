import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nutrimate/presentation/cubit/profile_cubit.dart';

import 'helpers/test_prefs.dart';

class MockFirebaseAuth extends Mock implements FirebaseAuth {}

class MockUser extends Mock implements User {}

void main() {
  late MockFirebaseAuth auth;
  late MockUser user;

  setUp(() {
    auth = MockFirebaseAuth();
    user = MockUser();
    when(() => auth.currentUser).thenReturn(user);
    when(() => user.displayName).thenReturn(null);
    when(() => user.email).thenReturn('sara@example.com');
    when(() => user.updateDisplayName(any())).thenAnswer((_) async {});
    when(() => user.reload()).thenAnswer((_) async {});
  });

  group('signed-in user name', () {
    test('uses the display name when available', () async {
      when(() => user.displayName).thenReturn('  Sara Ali  ');
      final cubit = ProfileCubit(await makeTestPrefs(), auth: auth);

      expect(cubit.state.name, 'Sara Ali');
      expect(cubit.state.email, 'sara@example.com');
      await cubit.close();
    });

    test('falls back to the email prefix when there is no display name',
            () async {
          final cubit = ProfileCubit(await makeTestPrefs(), auth: auth);

          expect(cubit.state.name, 'sara');
          await cubit.close();
        });

    test('shows Guest for an anonymous user without an email', () async {
      when(() => user.email).thenReturn(null);
      final cubit = ProfileCubit(await makeTestPrefs(), auth: auth);

      expect(cubit.state.name, 'Guest');
      expect(cubit.state.email, '');
      await cubit.close();
    });

    test('shows Guest when nobody is signed in', () async {
      when(() => auth.currentUser).thenReturn(null);
      final cubit = ProfileCubit(await makeTestPrefs(), auth: auth);

      expect(cubit.state.name, 'Guest');
      await cubit.close();
    });
  });

  group('preferences', () {
    test('uses defaults when nothing is saved', () async {
      final cubit = ProfileCubit(await makeTestPrefs(), auth: auth);

      expect(cubit.state.dietary, 'None');
      expect(cubit.state.calorieGoal, 2000);
      await cubit.close();
    });

    test('loads saved preferences', () async {
      final prefs = await makeTestPrefs(
        initial: {'dietary': 'Vegan', 'calorieGoal': 1800},
      );
      final cubit = ProfileCubit(prefs, auth: auth);

      expect(cubit.state.dietary, 'Vegan');
      expect(cubit.state.calorieGoal, 1800);
      await cubit.close();
    });
  });

  group('save', () {
    test('updates the Firebase display name when the name changed', () async {
      final prefs = await makeTestPrefs();
      final cubit = ProfileCubit(prefs, auth: auth);

      await cubit.save(name: 'Sara', dietary: 'Vegan', calorieGoal: 1700);

      verify(() => user.updateDisplayName('Sara')).called(1);
      verify(() => user.reload()).called(1);
      expect(cubit.state.name, 'Sara');
      expect(cubit.state.dietary, 'Vegan');
      expect(cubit.state.calorieGoal, 1700);
      expect(prefs.getString('dietary'), 'Vegan');
      expect(prefs.getInt('calorieGoal'), 1700);
      await cubit.close();
    });

    test('does not touch Firebase when the name is unchanged', () async {
      final cubit = ProfileCubit(await makeTestPrefs(), auth: auth);

      await cubit.save(
        name: cubit.state.name,
        dietary: 'Vegetarian',
        calorieGoal: 2200,
      );

      verifyNever(() => user.updateDisplayName(any()));
      expect(cubit.state.dietary, 'Vegetarian');
      await cubit.close();
    });

    test('saves preferences even when nobody is signed in', () async {
      when(() => auth.currentUser).thenReturn(null);
      final cubit = ProfileCubit(await makeTestPrefs(), auth: auth);

      await cubit.save(name: 'Guest', dietary: 'Vegan', calorieGoal: 1900);

      expect(cubit.state.dietary, 'Vegan');
      expect(cubit.state.calorieGoal, 1900);
      await cubit.close();
    });
  });
}