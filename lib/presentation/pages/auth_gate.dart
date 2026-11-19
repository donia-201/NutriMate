import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nutri_mate/presentation/pages/home_page.dart';
import 'package:nutri_mate/core/app_theme.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'package:nutri_mate/core/app_widgets.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({
    super.key,
    this.auth,
    this.homeBuilder,
    this.signInBuilder,
    this.firebaseInitializationError,
    this.googleSignIn,
  });

  final FirebaseAuth? auth;
  final WidgetBuilder? homeBuilder;

  /// Injected in tests so the real SignInScreen (needs Firebase) isn't built.
  final WidgetBuilder? signInBuilder;
  final String? firebaseInitializationError;
  final GoogleSignIn? googleSignIn;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _guestLoading = false;
  String? _guestError;
  bool _googleLoading = false;
  String? _googleError;
  bool _emailLoading = false;
  bool _signUpMode = false;
  String? _emailError;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _submitEmail(FirebaseAuth firebaseAuth) async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.isEmpty) {
      setState(() => _emailError = 'Enter your email and password.');
      return;
    }
    setState(() {
      _emailLoading = true;
      _emailError = null;
    });
    try {
      if (_signUpMode) {
        await firebaseAuth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
      } else {
        await firebaseAuth.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
      }
      if (!mounted) return;
      setState(() {
        _emailLoading = false;
        _emailError = null;
      });
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      setState(() {
        _emailLoading = false;
        _emailError = error.message ?? 'Authentication failed.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _emailLoading = false;
        _emailError = 'Authentication failed. Please try again.';
      });
    }
  }

  Future<void> _continueWithGoogle(FirebaseAuth firebaseAuth) async {
    if (_googleLoading) return;
    setState(() {
      _googleLoading = true;
      _googleError = null;
    });
    try {
      final googleSignIn = widget.googleSignIn ?? GoogleSignIn();
      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        if (!mounted) return;
        setState(() {
          _googleLoading = false;
          _googleError = 'Google Sign-In was cancelled.';
        });
        return;
      }
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      await firebaseAuth.signInWithCredential(credential);
      if (!mounted) return;
      setState(() => _googleLoading = false);
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      setState(() {
        _googleLoading = false;
        _googleError = error.message ?? 'Google Sign-In failed.';
      });
    } on PlatformException catch (error) {
      if (!mounted) return;
      final message = error.code == '10'
          ? 'Google Sign-In is not configured for this Android app. '
                'Add the package com.example.nutrimate and its debug/release SHA-1 '
                'and SHA-256 fingerprints in Firebase, then download google-services.json.'
          : 'Google Sign-In failed (${error.code}). '
                '${error.message ?? 'Check Firebase and Android OAuth configuration.'}';
      setState(() {
        _googleLoading = false;
        _googleError = message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _googleLoading = false;
        _googleError =
            'Google Sign-In failed. Check Firebase and Google configuration.';
      });
    }
  }

  Future<void> _continueAsGuest(FirebaseAuth firebaseAuth) async {
    if (_guestLoading) return;
    setState(() {
      _guestLoading = true;
      _guestError = null;
    });
    try {
      await firebaseAuth.signInAnonymously();
      if (!mounted) return;
      setState(() => _guestLoading = false);
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      final message = switch (error.code) {
        'operation-not-allowed' =>
          'Guest sign-in is disabled. Enable Anonymous in Firebase Authentication.',
        'network-request-failed' =>
          'Could not connect. Check your internet connection and try again.',
        _ => error.message ?? 'Could not continue as guest.',
      };
      setState(() {
        _guestLoading = false;
        _guestError = message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _guestLoading = false;
        _guestError = 'Could not continue as guest. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.firebaseInitializationError != null) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.cloud_off_outlined, size: 48),
                  const SizedBox(height: 16),
                  Text(
                    widget.firebaseInitializationError!,
                    textAlign: TextAlign.center,
                    style: AppTheme.body,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => setState(() {}),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final firebaseAuth = widget.auth ?? FirebaseAuth.instance;

    return StreamBuilder<User?>(
      stream: firebaseAuth.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            body: SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline),
                      const SizedBox(height: 12),
                      Text(
                        'Authentication is unavailable.',
                        textAlign: TextAlign.center,
                        style: AppTheme.titleBold.copyWith(fontSize: 18),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Check your internet connection and Firebase configuration.',
                        textAlign: TextAlign.center,
                        style: AppTheme.subTitle,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => setState(() {}),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            body: SafeArea(child: Center(child: CircularProgressIndicator())),
          );
        }
        if (snapshot.hasData == false) {
          if (widget.signInBuilder != null) {
            return widget.signInBuilder!(context);
          }

          return Theme(
            data: AppTheme.authTheme(Theme.of(context)),
            child: Scaffold(
              resizeToAvoidBottomInset: true,
              body: SafeArea(
                child: SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.manual,
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        _signUpMode ? 'Create your account' : 'Welcome back',
                        style: AppTheme.titleBold,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Small choices. Lasting nourishment.',
                        style: AppTheme.subTitle,
                      ),
                      const SizedBox(height: 24),
                      AppTextField(
                        label: 'Email',
                        controller: _emailController,
                        focusNode: _emailFocus,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        onFieldSubmitted: (_) => _passwordFocus.requestFocus(),
                      ),
                      const SizedBox(height: 16),
                      AppTextField(
                        label: 'Password',
                        controller: _passwordController,
                        focusNode: _passwordFocus,
                        isPassword: true,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _submitEmail(firebaseAuth),
                      ),
                      if (_emailError != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          _emailError!,
                          textAlign: TextAlign.center,
                          style: AppTheme.small.copyWith(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      AppButton(
                        label: _signUpMode ? 'Sign Up' : 'Sign In',
                        isLoading: _emailLoading,
                        onPressed: () => _submitEmail(firebaseAuth),
                      ),
                      TextButton(
                        onPressed: _emailLoading
                            ? null
                            : () => setState(() {
                                _signUpMode = !_signUpMode;
                                _emailError = null;
                              }),
                        child: Text(
                          _signUpMode
                              ? 'Already have an account? Sign In'
                              : 'New here? Create an account',
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'or continue with',
                        textAlign: TextAlign.center,
                        style: AppTheme.subTitle,
                      ),
                      const SizedBox(height: 16),
                      AppButton(
                        label: 'Continue with Google',
                        outlined: true,
                        isLoading: _googleLoading,
                        onPressed: () => _continueWithGoogle(firebaseAuth),
                      ),
                      if (_googleError != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          _googleError!,
                          textAlign: TextAlign.center,
                          style: AppTheme.small.copyWith(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      AppButton(
                        label: 'Continue as Guest',
                        outlined: true,
                        isLoading: _guestLoading,
                        onPressed: () => _continueAsGuest(firebaseAuth),
                      ),
                      if (_guestError != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          _guestError!,
                          textAlign: TextAlign.center,
                          style: AppTheme.small.copyWith(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      const Text(
                        'You can explore recipes as a guest, but favorites and synced data require an account.',
                        textAlign: TextAlign.center,
                        style: AppTheme.small,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }
        return widget.homeBuilder?.call(context) ?? const HomePage();
      },
    );
  }
}
