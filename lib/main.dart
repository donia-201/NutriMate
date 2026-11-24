import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nutri_mate/presentation/cubit/favorites_cubit.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/app_theme.dart';
import 'firebase_options.dart';
import 'presentation/pages/splash_page.dart';
import 'presentation/cubit/profile_cubit.dart';
import 'core/services/meal_notification_service.dart';
import 'presentation/cubit/notifications_cubit.dart';

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
  const firstLaunchKey = 'notificationPermissionAsked';
  final firstLaunchNotAsked = prefs.getBool(firstLaunchKey) == null;
  await MealNotificationService.instance.initialize(
    enabled: prefs.getBool(ProfileCubit.notificationsKey) ?? true,
  );
  if (firstLaunchNotAsked) {
    final granted = await MealNotificationService.instance.requestPermission();
    await prefs.setBool(firstLaunchKey, true);
    await prefs.setBool(ProfileCubit.notificationsKey, granted);
  }
  final notificationsEnabled =
      prefs.getBool(ProfileCubit.notificationsKey) ?? true;
  final notificationPermissionGranted = await MealNotificationService.instance
      .initialize(enabled: notificationsEnabled);
  if (notificationsEnabled && !notificationPermissionGranted) {
    await prefs.setBool(ProfileCubit.notificationsKey, false);
  }

  runApp(
    MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => ProfileCubit(prefs)),
        // فوق الـ MaterialApp عشان الهوم والبروفايل وصفحة الـ AI يشوفوه.
        BlocProvider(create: (_) => FavoritesCubit()),
        BlocProvider(create: (_) => NotificationsCubit()..load()),
      ],
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
        builder: (context, child) {
          // Keep the status bar and navigation bar icons readable in both modes.
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final icons = isDark ? Brightness.light : Brightness.dark;

          return AnnotatedRegion<SystemUiOverlayStyle>(
            value: SystemUiOverlayStyle(
              statusBarColor: Colors.transparent,
              statusBarIconBrightness: icons,
              statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
              systemNavigationBarColor: Colors.transparent,
              systemNavigationBarIconBrightness: icons,
              systemNavigationBarContrastEnforced: false,
            ),
            child: child ?? const SizedBox.shrink(),
          );
        },
        home: SplashPage(
          firebaseInitializationError: firebaseInitializationError,
        ),
      ),
    );
  }
}
