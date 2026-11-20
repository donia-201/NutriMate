import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/app_theme.dart';
import 'firebase_options.dart';
import 'presentation/pages/splash_page.dart';
import 'presentation/cubit/profile_cubit.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  String? firebaseInitializationError;
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  } on UnsupportedError catch (error) {
    firebaseInitializationError =
        error.message?.toString() ??
            'Firebase is not configured for this platform.';
  } catch (_) {
    firebaseInitializationError =
    'Could not initialize Firebase. Check your configuration and try again.';
  }

  final prefs = await SharedPreferencesWithCache.create(
    cacheOptions: const SharedPreferencesWithCacheOptions(
      allowList: ProfileCubit.keys,
    ),
  );

  runApp(
    BlocProvider(
      create: (_) => ProfileCubit(prefs),
      child: NutriMateApp(
        firebaseInitializationError: firebaseInitializationError,
      ),
    ),
  );
}

class NutriMateApp extends StatelessWidget {
  final String? firebaseInitializationError;
  const NutriMateApp({super.key, this.firebaseInitializationError});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ProfileCubit, ProfileState>(
      buildWhen: (prev, curr) => prev.themeMode != curr.themeMode,
      builder: (context, profile) => MaterialApp(
        title: 'NutriMate',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: profile.themeMode,
        home: SplashPage(
          firebaseInitializationError: firebaseInitializationError,
        ),
      ),
    );
  }
}