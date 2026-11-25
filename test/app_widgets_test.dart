import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutri_mate/core/app_widgets.dart';

void main() {
  testWidgets('confirmation dialog reports confirmation and cancellation', (
    tester,
  ) async {
    late Future<bool> result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () {
              result = showActionConfirmationDialog(
                context,
                title: 'Confirm action?',
                message: 'Continue?',
                confirmLabel: 'Proceed',
              );
            },
            child: const Text('Open dialog'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open dialog'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Proceed'));
    await tester.pumpAndSettle();
    expect(await result, isTrue);

    await tester.tap(find.text('Open dialog'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(await result, isFalse);
  });

  testWidgets('dismissal is false and concurrent dialogs are deduplicated', (
    tester,
  ) async {
    late Future<bool> firstResult;
    late Future<bool> secondResult;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () {
              firstResult = showActionConfirmationDialog(
                context,
                title: 'Confirm action?',
                message: 'Continue?',
                confirmLabel: 'Proceed',
              );
              secondResult = showActionConfirmationDialog(
                context,
                title: 'Duplicate action?',
                message: 'This dialog should not open.',
                confirmLabel: 'Proceed',
              );
            },
            child: const Text('Open dialog'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open dialog'));
    await tester.pumpAndSettle();
    expect(find.text('Confirm action?'), findsOneWidget);
    expect(find.text('Duplicate action?'), findsNothing);
    await tester.tapAt(const Offset(1, 1));
    await tester.pumpAndSettle();
    expect(await firstResult, isFalse);
    expect(await secondResult, isFalse);
  });
}
