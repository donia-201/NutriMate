import 'package:firebase_auth/firebase_auth.dart' hide EmailAuthProvider;
import 'package:firebase_ui_auth/firebase_ui_auth.dart';
import 'package:flutter/material.dart';
import 'package:nutri_mate/presentation/pages/home_page.dart';
import 'package:nutri_mate/core/app_theme.dart';
import 'package:firebase_ui_oauth_google/firebase_ui_oauth_google.dart';

import 'package:nutri_mate/core/app_widgets.dart';
import 'package:nutri_mate/core/app_config.dart';
import 'package:nutri_mate/core/guest_guard.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({
    super.key,
    this.auth,
    this.homeBuilder,
    this.signInBuilder,
    this.firebaseInitializationError,
  });

  final FirebaseAuth? auth;
  final WidgetBuilder? homeBuilder;

  /// Injected in tests so the real SignInScreen (needs Firebase) isn't built.
  final WidgetBuilder? signInBuilder;
  final String? firebaseInitializationError;

  @override
  Widget build(BuildContext context) {
    if (firebaseInitializationError != null) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                firebaseInitializationError!,
                textAlign: TextAlign.center,
                style: AppTheme.body,
              ),
            ),
          ),
        ),
      );
    }
    final firebaseAuth = auth ?? FirebaseAuth.instance;

    return StreamBuilder<User?>(
      stream: firebaseAuth.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            body: SafeArea(
              child: Center(
                child: Text('Small choices. Lasting nourishment.',
                    style: AppTheme.subTitle),
              ),
            ),
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: SafeArea(
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }
        if (snapshot.hasData == false) {
          if (signInBuilder != null) return signInBuilder!(context);

          // نفس العنوان ونفس الفوتر للشاشتين
          Widget subtitle(BuildContext context, AuthAction authAction) {
            final isSignIn = authAction == AuthAction.signIn;
            return Padding(
              padding: const EdgeInsets.only(bottom: 30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isSignIn ? 'Welcome back' : 'Create your account',
                    style: AppTheme.titleBold,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Small choices. Lasting nourishment.',
                    style: AppTheme.subTitle,
                  ),
                ],
              ),
            );
          }

          Widget footer(BuildContext context, AuthAction authAction) => Column(
            children: [
              const Text(
                'or continue with',
                textAlign: TextAlign.center,
                style: AppTheme.subTitle,
              ),
              const SizedBox(height: 16),
              OAuthProviderButton(
                provider: GoogleProvider(clientId: AppConfig.googleClientId),
                variant: OAuthButtonVariant.icon,
              ),
              const SizedBox(height: 16),
              _GuestButton(auth: firebaseAuth),
              const SizedBox(height: 16),
              const Text(
                'You can explore recipes as a guest, but favorites and synced data require an account.',
                textAlign: TextAlign.center,
                style: AppTheme.small,
              ),
            ],
          );

          return Theme(
            data: AppTheme.authTheme(Theme.of(context)),
            child: openRegisterFirst
                ? RegisterScreen(
              providers: [EmailAuthProvider()],
              oauthButtonVariant: OAuthButtonVariant.icon,
              subtitleBuilder: subtitle,
              footerBuilder: footer,
            )
                : SignInScreen(
              providers: [EmailAuthProvider()],
              oauthButtonVariant: OAuthButtonVariant.icon,
              subtitleBuilder: subtitle,
              footerBuilder: footer,
            ),
          );
        }

        openRegisterFirst = false;
        return homeBuilder?.call(context) ?? const HomePage();
      },
    );
  }
}
class _GuestButton extends StatefulWidget {
  const _GuestButton({required this.auth});

  final FirebaseAuth auth;

  @override
  State<_GuestButton> createState() => _GuestButtonState();
}

class _GuestButtonState extends State<_GuestButton> {
  bool _loading = false;
  String? _error;

  Future<void> _continueAsGuest() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await widget.auth.signInAnonymously();
      // لو نجح، الـ AuthGate هينقل للهوم لوحده
      if (!mounted) return;
      setState(() => _loading = false);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = switch (e.code) {
          'operation-not-allowed' =>
          'Guest sign-in is disabled. Enable Anonymous in Firebase Authentication.',
          'network-request-failed' =>
          'Could not connect. Check your internet connection and try again.',
          _ => e.message ?? 'Could not continue as guest.',
        };
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not continue as guest. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AppButton(
          label: 'Continue as Guest',
          outlined: true,
          isLoading: _loading,
          onPressed: _continueAsGuest,
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: AppTheme.small.copyWith(
              color: Theme.of(context).colorScheme.error,
            ),
          ),
        ],
      ],
    );
  }
}