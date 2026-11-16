import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsCubit extends Cubit<ThemeMode> {
  static const _themeKey = 'themeMode';
  static const keys = {_themeKey}; // للـ allowList

  final SharedPreferencesWithCache _prefs;

  // الحالة الأولية بتتقرا من الحفظ، وأول مرة بتبقى system
  SettingsCubit(this._prefs)
      : super(
    ThemeMode.values.asNameMap()[_prefs.getString(_themeKey)] ??
        ThemeMode.system,
  );

  Future<void> setDarkMode(bool isDark) async {
    final mode = isDark ? ThemeMode.dark : ThemeMode.light;
    await _prefs.setString(_themeKey, mode.name);
    emit(mode);
  }
}