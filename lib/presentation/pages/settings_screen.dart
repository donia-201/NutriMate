import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:nutri_mate/presentation/cubit/settings_cubit.dart';
import 'package:nutri_mate/core/app_theme.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // الشكل الفعلي الحالي (بيراعي system)
    final mode = context.watch<SettingsCubit>().state;
    final isDark =
        mode == ThemeMode.dark ||
        (mode == ThemeMode.system &&
            Theme.of(context).brightness == Brightness.dark);

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: SwitchListTile(
              secondary: const Icon(Icons.dark_mode_outlined),
              title: const Text('Dark mode'),
              value: isDark,
              onChanged: (v) => context.read<SettingsCubit>().setDarkMode(v),
            ),
          ),
          if (context.watch<SettingsCubit>().errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                context.watch<SettingsCubit>().errorMessage!,
                style: AppTheme.small.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
