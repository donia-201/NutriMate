import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nutri_mate/core/services/meal_notification_service.dart';
import 'package:nutri_mate/presentation/cubit/profile_cubit.dart';

import 'helpers/test_prefs.dart';

class _MockFirebaseAuth extends Mock implements FirebaseAuth {}

class _MockMealNotificationService extends Mock
    implements MealNotificationService {}

void main() {
  late _MockFirebaseAuth auth;
  late _MockMealNotificationService notifications;

  setUp(() {
    auth = _MockFirebaseAuth();
    notifications = _MockMealNotificationService();
    when(() => auth.currentUser).thenReturn(null);
    when(() => auth.userChanges()).thenAnswer((_) => const Stream.empty());
  });

  test('loads the default reminder times', () async {
    final prefs = await makeTestPrefs();
    final cubit = ProfileCubit(
      prefs,
      auth: auth,
      notificationService: notifications,
    );

    expect(cubit.state.reminderTimes, {
      'Breakfast': const TimeOfDay(hour: 8, minute: 0),
      'Lunch': const TimeOfDay(hour: 13, minute: 0),
      'Dinner': const TimeOfDay(hour: 19, minute: 0),
    });

    await cubit.close();
  });

  test('persists a selected reminder time and updates the service', () async {
    const selectedTime = TimeOfDay(hour: 14, minute: 35);
    when(
      () => notifications.setReminderTime('Lunch', selectedTime),
    ).thenAnswer((_) async => true);
    final prefs = await makeTestPrefs();
    final cubit = ProfileCubit(
      prefs,
      auth: auth,
      notificationService: notifications,
    );

    final available = await cubit.setReminderTime('Lunch', selectedTime);

    expect(available, isTrue);
    expect(cubit.state.reminderTimes['Lunch'], selectedTime);
    expect(prefs.getInt(ProfileCubit.lunchReminderTimeKey), 14 * 60 + 35);
    verify(
      () => notifications.setReminderTime('Lunch', selectedTime),
    ).called(1);

    await cubit.close();
  });

  test('turns reminders off when permission is no longer available', () async {
    const selectedTime = TimeOfDay(hour: 9, minute: 15);
    when(
      () => notifications.setReminderTime('Breakfast', selectedTime),
    ).thenAnswer((_) async => false);
    final prefs = await makeTestPrefs(
      initial: {ProfileCubit.notificationsKey: true},
    );
    final cubit = ProfileCubit(
      prefs,
      auth: auth,
      notificationService: notifications,
    );

    await cubit.setReminderTime('Breakfast', selectedTime);

    expect(cubit.state.notificationsEnabled, isFalse);
    expect(prefs.getBool(ProfileCubit.notificationsKey), isFalse);

    await cubit.close();
  });

  test('does not emit after closing during reminder rescheduling', () async {
    const selectedTime = TimeOfDay(hour: 20, minute: 5);
    final serviceCalled = Completer<void>();
    final rescheduling = Completer<bool>();
    when(
      () => notifications.setReminderTime('Dinner', selectedTime),
    ).thenAnswer((_) {
      serviceCalled.complete();
      return rescheduling.future;
    });
    final prefs = await makeTestPrefs();
    final cubit = ProfileCubit(
      prefs,
      auth: auth,
      notificationService: notifications,
    );

    final update = cubit.setReminderTime('Dinner', selectedTime);
    await serviceCalled.future;
    await cubit.close();
    rescheduling.complete(true);

    expect(await update, isTrue);
  });
}
