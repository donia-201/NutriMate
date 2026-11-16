import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:nutrimate/firebase_options.dart';
import 'package:nutrimate/presentation/pages/auth_gate.dart';
import 'package:nutrimate/profile_cubit.dart';
import 'package:nutrimate/settings_cubit.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/app_theme.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options:
    DefaultFirebaseOptions.currentPlatform,
  );
  final prefs = await SharedPreferencesWithCache.create(
      cacheOptions: const SharedPreferencesWithCacheOptions(
        allowList: {...SettingsCubit.keys, ...ProfileCubit.keys},
      ),);

  runApp(
    MultiBlocProvider(
          providers: [
            BlocProvider(create: (_) => SettingsCubit(prefs)),
            BlocProvider(create: (_) => ProfileCubit(prefs)),
          ],
          child: const MyApp(),
      ),
  );

}


class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SettingsCubit, ThemeMode>(
        builder: (context, themeMode) => MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: themeMode,   // ← من الـ Cubit، مش ThemeMode.dark ثابت
          home: const AuthGate(),

      ),
    );
  }
}

