import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nutrimate/presentation/pages/auth_gate.dart';

class MockFirebaseAuth extends Mock implements FirebaseAuth {}

class MockUser extends Mock implements User {}

class MockUserCredential extends Mock implements UserCredential {}

void main() {
  late MockFirebaseAuth auth;
  late StreamController<User?> authStream;

  setUp(() {
    auth = MockFirebaseAuth();
    authStream = StreamController<User?>();
    when(() => auth.authStateChanges()).thenAnswer((_) => authStream.stream);
  });

  tearDown(() => authStream.close());

  Widget buildGate() => MaterialApp(
    home: AuthGate(
      auth: auth,
      homeBuilder: (_) => const Scaffold(body: Text('HOME')),
      signInBuilder: (_) => Scaffold(
        body: Column(
          children: [
            const Text('SIGN IN'),
            TextButton(
              onPressed: () => auth.signInAnonymously(),
              child: const Text('Continue as Guest'),
            ),
          ],
        ),
      ),
    ),
  );

  testWidgets('shows a loading indicator while waiting for auth state',
          (tester) async {
        await tester.pumpWidget(buildGate());

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(find.text('HOME'), findsNothing);
      });

  testWidgets('shows the home page when a user is signed in', (tester) async {
    await tester.pumpWidget(buildGate());

    authStream.add(MockUser());
    await tester.pump();

    expect(find.text('HOME'), findsOneWidget);
  });

  testWidgets('shows the error message when the auth stream fails',
          (tester) async {
        await tester.pumpWidget(buildGate());

        authStream.addError(Exception('auth failed'));
        await tester.pump();

        expect(find.text('Small choices. Lasting nourishment.'), findsOneWidget);
        expect(find.text('HOME'), findsNothing);
      });

  testWidgets('shows the sign-in screen when signed out', (tester) async {
    await tester.pumpWidget(buildGate());

    authStream.add(null);
    await tester.pump();

    expect(find.text('HOME'), findsNothing);
    expect(find.text('SIGN IN'), findsOneWidget);
  });

  testWidgets('guest button signs in anonymously', (tester) async {
    when(() => auth.signInAnonymously())
        .thenAnswer((_) async => MockUserCredential());
    await tester.pumpWidget(buildGate());

    authStream.add(null);
    await tester.pump();

    await tester.tap(find.text('Continue as Guest'));
    await tester.pump();

    verify(() => auth.signInAnonymously()).called(1);
  });
}