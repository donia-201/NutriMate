import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsCubit extends Cubit<ThemeMode> {
  static const _themeKey = 'themeMode';
  static const keys = {_themeKey}; // for the allowList

  final SharedPreferencesWithCache _prefs;
  String? preferenceError;

  SettingsCubit(this._prefs) : super(_load(_prefs)) {
    try {
      _prefs.getString(_themeKey);
    } catch (_) {
      preferenceError = 'Could not read theme preference.';
    }
  }

  String? get errorMessage => preferenceError;

  static ThemeMode _load(SharedPreferencesWithCache prefs) {
    try {
      return ThemeMode.values.asNameMap()[prefs.getString(_themeKey)] ??
          ThemeMode.system;
    } catch (_) {
      return ThemeMode.system;
    }
  }

  Future<void> setDarkMode(bool isDark) async {
    final mode = isDark ? ThemeMode.dark : ThemeMode.light;
    try {
      await _prefs.setString(_themeKey, mode.name);
      if (isClosed) return;
      preferenceError = null;
      emit(mode);
    } catch (_) {
      if (isClosed) return;
      preferenceError = 'Could not save theme preference.';
      emit(state);
    }
  }
}
