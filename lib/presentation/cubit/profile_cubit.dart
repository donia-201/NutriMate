import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/services/meal_notification_service.dart';

class ProfileState {
  final String name;
  final String email;
  final String dietary;
  final int calorieGoal;
  final ThemeMode themeMode;
  final bool notificationsEnabled;
  final Map<String, TimeOfDay> reminderTimes;

  const ProfileState({
    required this.name,
    required this.email,
    required this.dietary,
    required this.calorieGoal,
    required this.themeMode,
    this.notificationsEnabled = true,
    this.reminderTimes = MealNotificationService.defaultSlotTimes,
  });

  ProfileState copyWith({
    String? name,
    String? email,
    String? dietary,
    int? calorieGoal,
    ThemeMode? themeMode,
    bool? notificationsEnabled,
    Map<String, TimeOfDay>? reminderTimes,
  }) {
    return ProfileState(
      name: name ?? this.name,
      email: email ?? this.email,
      dietary: dietary ?? this.dietary,
      calorieGoal: calorieGoal ?? this.calorieGoal,
      themeMode: themeMode ?? this.themeMode,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      reminderTimes: reminderTimes ?? this.reminderTimes,
    );
  }
}

class ProfileCubit extends Cubit<ProfileState> {
  static const _dietKey = 'dietary';
  static const _calorieKey = 'calorieGoal';
  static const _themeKey = 'themeMode';
  static const _onboardedKey = 'onboardingSeen';
  static const notificationsKey = 'notificationsEnabled';
  static const notificationsPermissionAskedKey = 'notificationPermissionAsked';
  static const breakfastReminderTimeKey = 'breakfastReminderTimeMinutes';
  static const lunchReminderTimeKey = 'lunchReminderTimeMinutes';
  static const dinnerReminderTimeKey = 'dinnerReminderTimeMinutes';
  static const reminderSlots = ['Breakfast', 'Lunch', 'Dinner'];
  static const defaultReminderTimes = MealNotificationService.defaultSlotTimes;
  static const _reminderTimeKeys = {
    'Breakfast': breakfastReminderTimeKey,
    'Lunch': lunchReminderTimeKey,
    'Dinner': dinnerReminderTimeKey,
  };

  // For the SharedPreferences allowList.
  static const keys = {
    _dietKey,
    _calorieKey,
    _themeKey,
    _onboardedKey,
    notificationsKey,
    notificationsPermissionAskedKey,
    breakfastReminderTimeKey,
    lunchReminderTimeKey,
    dinnerReminderTimeKey,
  };

  static const dietOptions = [
    'None',
    'Vegetarian',
    'Vegan',
    'Gluten-free',
    'Dairy-free',
  ];

  final SharedPreferencesWithCache _prefs;
  final FirebaseAuth _auth;
  final MealNotificationService _notifications;
  StreamSubscription<User?>? _userSub;

  ProfileCubit(
    SharedPreferencesWithCache prefs, {
    FirebaseAuth? auth,
    MealNotificationService? notificationService,
  }) : this._(
         prefs,
         auth ?? FirebaseAuth.instance,
         notificationService ?? MealNotificationService.instance,
       );

  ProfileCubit._(this._prefs, this._auth, this._notifications)
    : super(_load(_prefs, _auth)) {
    // Keeps name/email in sync on sign-in, sign-out and profile updates.
    _userSub = _auth.userChanges().listen((user) {
      if (isClosed) return;
      emit(state.copyWith(name: nameFor(user), email: user?.email ?? ''));
    });
  }

  // Display name -> email prefix -> Guest.
  static String nameFor(User? user) {
    final displayName = user?.displayName?.trim();

    if (displayName != null && displayName.isNotEmpty) {
      return displayName;
    }

    final email = user?.email;

    if (email != null && email.contains('@')) {
      return email.split('@').first;
    }

    return 'Guest';
  }

  static ProfileState _load(
    SharedPreferencesWithCache prefs,
    FirebaseAuth auth,
  ) {
    final user = auth.currentUser;
    final savedDiet = prefs.getString(_dietKey);

    return ProfileState(
      name: nameFor(user),
      email: user?.email ?? '',
      dietary: dietOptions.contains(savedDiet) ? savedDiet! : 'None',
      calorieGoal: prefs.getInt(_calorieKey) ?? 2000,
      themeMode:
          ThemeMode.values.asNameMap()[prefs.getString(_themeKey)] ??
          ThemeMode.system,
      notificationsEnabled: prefs.getBool(notificationsKey) ?? true,
      reminderTimes: reminderTimesFromPrefs(prefs),
    );
  }

  static Map<String, TimeOfDay> reminderTimesFromPrefs(
    SharedPreferencesWithCache prefs,
  ) => Map.unmodifiable({
    for (final slot in reminderSlots)
      slot: _timeFromMinutes(
        prefs.getInt(_reminderTimeKeys[slot]!),
        defaultReminderTimes[slot]!,
      ),
  });

  static TimeOfDay _timeFromMinutes(int? minutes, TimeOfDay fallback) {
    if (minutes == null || minutes < 0 || minutes >= 24 * 60) return fallback;
    return TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60);
  }

  // Only accounts that sign in with email + password have a password to change.
  // Google and anonymous users don't.
  bool get canChangePassword =>
      _auth.currentUser?.providerData.any((p) => p.providerId == 'password') ??
      false;

  // Checks whether the user has already seen onboarding.
  bool get onboardingSeen => _prefs.getBool(_onboardedKey) ?? false;

  // Marks onboarding as completed.
  Future<void> markOnboardingSeen() => _prefs.setBool(_onboardedKey, true);

  Future<void> save({
    required String name,
    required String dietary,
    required int calorieGoal,
  }) async {
    final user = _auth.currentUser;

    if (user != null && name != state.name) {
      await user.updateDisplayName(name);
      await user.reload();
    }

    await _prefs.setString(_dietKey, dietary);
    await _prefs.setInt(_calorieKey, calorieGoal);
    if (isClosed) return;

    final shownName = _auth.currentUser?.displayName?.trim();

    emit(
      state.copyWith(
        name: (shownName != null && shownName.isNotEmpty) ? shownName : name,
        dietary: dietary,
        calorieGoal: calorieGoal,
      ),
    );
  }

  Future<void> setDarkMode(bool isDark) async {
    final mode = isDark ? ThemeMode.dark : ThemeMode.light;

    await _prefs.setString(_themeKey, mode.name);
    if (isClosed) return;

    emit(state.copyWith(themeMode: mode));
  }

  Future<bool> setNotificationsEnabled(bool enabled) async {
    final granted = await _notifications.setEnabled(enabled);
    await _prefs.setBool(notificationsKey, granted);
    if (isClosed) return granted;
    emit(state.copyWith(notificationsEnabled: granted));
    return granted;
  }

  Future<bool> setReminderTime(String slot, TimeOfDay time) async {
    final key = _reminderTimeKeys[slot];
    if (key == null) {
      throw ArgumentError.value(slot, 'slot', 'Unknown meal reminder slot');
    }

    final reminderTimes = Map<String, TimeOfDay>.of(state.reminderTimes)
      ..[slot] = time;
    await _prefs.setInt(key, time.hour * 60 + time.minute);
    if (isClosed) return _notifications.setReminderTime(slot, time);

    emit(state.copyWith(reminderTimes: Map.unmodifiable(reminderTimes)));

    final remindersAvailable = await _notifications.setReminderTime(slot, time);
    if (isClosed) return remindersAvailable;
    if (!remindersAvailable && state.notificationsEnabled) {
      await _prefs.setBool(notificationsKey, false);
      if (isClosed) return false;
      emit(state.copyWith(notificationsEnabled: false));
    }
    return remindersAvailable;
  }

  User _emailUser() {
    final user = _auth.currentUser;

    if (user == null || user.email == null) {
      throw StateError('No signed-in user with an email');
    }

    return user;
  }

  // Required by Firebase before sensitive operations like changing a password.
  Future<void> reauthenticate(String password) async {
    final user = _emailUser();

    await user.reauthenticateWithCredential(
      EmailAuthProvider.credential(email: user.email!, password: password),
    );
  }

  Future<void> updatePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await reauthenticate(currentPassword);
    await _emailUser().updatePassword(newPassword);
  }

  @override
  Future<void> close() async {
    await _userSub?.cancel();
    return super.close();
  }
}
