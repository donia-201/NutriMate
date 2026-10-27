import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nutri_mate/main.dart';

void main() {
  testWidgets('NutriMate app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const NutriMateApp());
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
