import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsCubit extends Cubit<ThemeMode> {
  static const _themeKey = 'themeMode';
  static const keys = {_themeKey}; // for the allowList

  final SharedPreferencesWithCache _prefs;

  SettingsCubit(this._prefs) : super(_load(_prefs));

  static ThemeMode _load(SharedPreferencesWithCache prefs) =>
      ThemeMode.values.asNameMap()[prefs.getString(_themeKey)] ??
          ThemeMode.system;

  Future<void> setDarkMode(bool isDark) async {
    final mode = isDark ? ThemeMode.dark : ThemeMode.light;
    await _prefs.setString(_themeKey, mode.name);
    emit(mode);
  }
}