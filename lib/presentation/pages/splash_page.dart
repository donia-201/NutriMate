import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/utils/app_colors.dart';
import '../../core/utils/app_text_style.dart';
import '../cubit/profile_cubit.dart';
import 'auth_gate.dart';
import 'onboarding_page.dart';

class SplashPage extends StatefulWidget {
  final String? firebaseInitializationError;

  const SplashPage({
    super.key,
    this.firebaseInitializationError,
  });

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  Timer? _navigationTimer;

  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _bowlScaleAnimation;
  late Animation<double> _sproutScaleAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );

    _fadeAnimation =
        Tween<double>(begin: 0.0, end: 1.0).animate(
          CurvedAnimation(
            parent: _controller,
            curve: const Interval(
              0.0,
              0.5,
              curve: Curves.easeIn,
            ),
          ),
        );

    _slideAnimation =
        Tween<Offset>(
          begin: const Offset(0, 0.2),
          end: Offset.zero,
        ).animate(
          CurvedAnimation(
            parent: _controller,
            curve: const Interval(
              0.0,
              0.6,
              curve: Curves.easeOutCubic,
            ),
          ),
        );

    _bowlScaleAnimation =
        Tween<double>(begin: 0.6, end: 1.0).animate(
          CurvedAnimation(
            parent: _controller,
            curve: const Interval(
              0.0,
              0.5,
              curve: Curves.easeOutBack,
            ),
          ),
        );

    _sproutScaleAnimation =
        Tween<double>(begin: 0.0, end: 1.0).animate(
          CurvedAnimation(
            parent: _controller,
            curve: const Interval(
              0.4,
              0.85,
              curve: Curves.elasticOut,
            ),
          ),
        );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _controller.forward();
      }
    });

    _navigationTimer = Timer(
      const Duration(seconds: 3),
          () {
        if (!mounted) return;

        final seen =
            context.read<ProfileCubit>().onboardingSeen;

        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) =>
            seen ? const AuthGate() : const OnboardingPage(),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _navigationTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: Column(
                mainAxisAlignment:
                MainAxisAlignment.center,
                children: [
                  const Spacer(),

                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppColors.primaryGreen
                          .withValues(alpha: 0.08),
                      borderRadius:
                      BorderRadius.circular(40),
                    ),
                    child: SizedBox(
                      width: 100,
                      height: 100,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          ScaleTransition(
                            scale:
                            _bowlScaleAnimation,
                            child: Image.asset(
                              'assets/salad.png',
                              width: 90,
                              height: 90,
                              fit: BoxFit.contain,
                            ),
                          ),

                          Positioned(
                            top: 11,
                            child: ScaleTransition(
                              scale:
                              _sproutScaleAnimation,
                              alignment:
                              Alignment.bottomCenter,
                              child: Image.asset(
                                'assets/sprout.png',
                                width: 55,
                                height: 50,
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 40),

                  const Text(
                    'NutriMate',
                    style: AppTextStyles.titleBold,
                  ),

                  const SizedBox(height: 16),

                  const Text(
                    'Eat smart. Plan better.',
                    style: AppTextStyles.subTitle,
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 8),

                  Text(
                    'A little nourishment. A better every day.',
                    style: AppTextStyles.subTitle.copyWith(
                      fontSize: 13,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const Spacer(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}