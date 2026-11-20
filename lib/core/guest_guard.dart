import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
/// لما تتحط true، الـ AuthGate يفتح شاشة Register بدل Sign in
bool openRegisterFirst = false;
bool isGuestUser([FirebaseAuth? auth]) {
  final user = (auth ?? FirebaseAuth.instance).currentUser;
  return user == null || user.isAnonymous;
}

/// بترجع true لو المستخدم مسجّل دخول فعلاً، ولو جيست بتعرض dialog وترجع false.
Future<bool> requireSignedIn(BuildContext context, {String? feature}) async {
  if (!isGuestUser()) return true;

  final goSignIn = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Sign in required'),
      content: Text(
        '${feature ?? 'This feature'} is only available for signed-in users. '
            'Please sign in or Register to continue.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Not now'),
        ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Register to continue.'),
          ),

      ],
    ),
  );

  if (goSignIn == true) {
    openRegisterFirst = true;
    if (context.mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
    await FirebaseAuth.instance.signOut();
  }
  return false;
}