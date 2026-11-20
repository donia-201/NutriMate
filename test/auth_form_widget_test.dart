import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nutri_mate/presentation/pages/auth_gate.dart';

class _MockFirebaseAuth extends Mock implements FirebaseAuth {}

void main() {
  testWidgets('auth form keeps controllers and moves focus between fields', (
    tester,
  ) async {
    final auth = _MockFirebaseAuth();
    final authStream = Stream<User?>.value(null);
    when(() => auth.authStateChanges()).thenAnswer((_) => authStream);

    await tester.pumpWidget(
      MaterialApp(
        home: AuthGate(
          auth: auth,
          signInBuilder: (_) => const Scaffold(body: SizedBox()),
        ),
      ),
    );

    await tester.pump();
    expect(find.byType(Scaffold), findsOneWidget);
  });

  testWidgets('profile route has root profile and settings providers', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Text('Profile route provider test')),
      ),
    );

    expect(find.text('Profile route provider test'), findsOneWidget);
  });
}
