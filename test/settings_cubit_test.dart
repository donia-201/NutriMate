import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutri_mate/presentation/cubit/settings_cubit.dart';

import 'helpers/test_prefs.dart';

void main() {
  group('SettingsCubit', () {
    test('starts with ThemeMode.system when nothing is saved', () async {
      final cubit = SettingsCubit(await makeTestPrefs());
      expect(cubit.state, ThemeMode.system);
      await cubit.close();
    });

    test('restores the saved theme mode', () async {
      final prefs = await makeTestPrefs(initial: {'themeMode': 'dark'});
      final cubit = SettingsCubit(prefs);
      expect(cubit.state, ThemeMode.dark);
      await cubit.close();
    });

    test('falls back to system for an invalid saved value', () async {
      final prefs = await makeTestPrefs(initial: {'themeMode': 'banana'});
      final cubit = SettingsCubit(prefs);
      expect(cubit.state, ThemeMode.system);
      await cubit.close();
    });

    test('setDarkMode(true) emits dark and saves it', () async {
      final prefs = await makeTestPrefs();
      final cubit = SettingsCubit(prefs);

      final emitted = expectLater(cubit.stream, emits(ThemeMode.dark));
      await cubit.setDarkMode(true);
      await emitted;

      expect(prefs.getString('themeMode'), 'dark');
      await cubit.close();
    });

    test('setDarkMode(false) emits light and saves it', () async {
      final prefs = await makeTestPrefs(initial: {'themeMode': 'dark'});
      final cubit = SettingsCubit(prefs);

      final emitted = expectLater(cubit.stream, emits(ThemeMode.light));
      await cubit.setDarkMode(false);
      await emitted;

      expect(prefs.getString('themeMode'), 'light');
      await cubit.close();
    });
  });
}