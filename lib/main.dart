import 'package:flutter/material.dart';
import 'core/utils/app_colors.dart';
import 'presentation/pages/splash_page.dart';

void main() {
  runApp(const NutriMateApp());
}

class NutriMateApp extends StatelessWidget {
  const NutriMateApp({Key? key}): super(key:  key);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NutriMate',
      debugShowCheckedModeBanner: false ,
      theme: ThemeData(
       scaffoldBackgroundColor: AppColors.background,
       useMaterial3: true,
      
      ),
      home: const SplashPage(),
    );
  }
}

