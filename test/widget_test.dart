import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutri_mate/presentation/cubit/settings_cubit.dart';

import 'helpers/test_prefs.dart';

void main() {
  testWidgets('toggling dark mode switches the app theme', (tester) async {
    final cubit = SettingsCubit(await makeTestPrefs());

    await tester.pumpWidget(
      BlocProvider.value(
        value: cubit,
        child: BlocBuilder<SettingsCubit, ThemeMode>(
          builder: (context, mode) => MaterialApp(
            theme: ThemeData.light(),
            darkTheme: ThemeData.dark(),
            themeMode: mode,
            home: Builder(
              builder: (ctx) => Scaffold(
                body: Text(Theme.of(ctx).brightness.name),
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('light'), findsOneWidget);

    await tester.runAsync(() async {
      await cubit.setDarkMode(true);
      // Let the Bloc stream deliver the new state to BlocBuilder.
      await Future<void>.delayed(Duration.zero);
    });
    await tester.pumpAndSettle();

    expect(find.text('dark'), findsOneWidget);
    await cubit.close();
  });
}