import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProfileState {
  final String name;
  final String email;
  final String dietary;
  final int calorieGoal;
  final ThemeMode themeMode;

  const ProfileState({
    required this.name,
    required this.email,
    required this.dietary,
    required this.calorieGoal,
    required this.themeMode,
  });

  ProfileState copyWith({
    String? name,
    String? email,
    String? dietary,
    int? calorieGoal,
    ThemeMode? themeMode,
  }) {
    return ProfileState(
      name: name ?? this.name,
      email: email ?? this.email,
      dietary: dietary ?? this.dietary,
      calorieGoal: calorieGoal ?? this.calorieGoal,
      themeMode: themeMode ?? this.themeMode,
    );
  }
}

class ProfileCubit extends Cubit<ProfileState> {
  static const _dietKey = 'dietary';
  static const _calorieKey = 'calorieGoal';
  static const _themeKey = 'themeMode';
  static const _onboardedKey = 'onboardingSeen';

  // For the SharedPreferences allowList.
  static const keys = {
    _dietKey,
    _calorieKey,
    _themeKey,
    _onboardedKey,
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
  StreamSubscription<User?>? _userSub;

  ProfileCubit(
      SharedPreferencesWithCache prefs, {
        FirebaseAuth? auth,
      }) : this._(prefs, auth ?? FirebaseAuth.instance);

  ProfileCubit._(this._prefs, this._auth)
      : super(_load(_prefs, _auth)) {
    // Keeps name/email in sync on sign-in, sign-out and profile updates.
    _userSub = _auth.userChanges().listen((user) {
      emit(
        state.copyWith(
          name: nameFor(user),
          email: user?.email ?? '',
        ),
      );
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
      themeMode: ThemeMode.values.asNameMap()[prefs.getString(_themeKey)] ??
          ThemeMode.system,
    );
  }

  // Only accounts that sign in with email + password have a password to change.
  // Google and anonymous users don't.
  bool get canChangePassword =>
      _auth.currentUser?.providerData.any(
            (p) => p.providerId == 'password',
      ) ??
          false;

  // Checks whether the user has already seen onboarding.
  bool get onboardingSeen =>
      _prefs.getBool(_onboardedKey) ?? false;

  // Marks onboarding as completed.
  Future<void> markOnboardingSeen() =>
      _prefs.setBool(_onboardedKey, true);

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

    final shownName = _auth.currentUser?.displayName?.trim();

    emit(
      state.copyWith(
        name: (shownName != null && shownName.isNotEmpty)
            ? shownName
            : name,
        dietary: dietary,
        calorieGoal: calorieGoal,
      ),
    );
  }

  Future<void> setDarkMode(bool isDark) async {
    final mode = isDark ? ThemeMode.dark : ThemeMode.light;

    await _prefs.setString(_themeKey, mode.name);

    emit(
      state.copyWith(
        themeMode: mode,
      ),
    );
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
      EmailAuthProvider.credential(
        email: user.email!,
        password: password,
      ),
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