import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutri_mate/core/app_theme.dart';
import 'package:nutri_mate/presentation/pages/about_screen.dart';

void main() {
  testWidgets('AboutScreen shows the app info in the light theme',
          (tester) async {
        await tester.pumpWidget(
          MaterialApp(theme: AppTheme.light, home: const AboutScreen()),
        );

        expect(find.text('About NutriMate'), findsOneWidget);
        expect(find.text('NutriMate'), findsOneWidget);
        expect(find.text('Version'), findsOneWidget);
        expect(find.text('1.0.0'), findsOneWidget);
      });

  testWidgets('AboutScreen builds in the dark theme', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: ThemeMode.dark,
        home: const AboutScreen(),
      ),
    );

    expect(find.text('About NutriMate'), findsOneWidget);
  });
}