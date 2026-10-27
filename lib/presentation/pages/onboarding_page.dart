import 'package:flutter/material.dart';
import '../../core/utils/app_colors.dart';
import '../../core/utils/app_assets.dart';
import '../../core/utils/app_text_style.dart';
import '../../models/onboarding_model.dart';
import '../../presentation/pages/home_page.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key}) ;

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;

  final List<OnboardingModel> _items = [
    OnboardingModel(
      image: AppAssets.onboarding1,
      title: 'Discover delicious\nrecipes',
      description:
          'Discover meals from different countries, cuisines,\nand ingredients.',
    ),
    OnboardingModel(
      image: AppAssets.onboarding2,
      title: 'Plan your week with\nease',
      description:
          'Organize breakfast, lunch, and dinner in one\nsimple weekly planner.',
    ),
    OnboardingModel(
      image: AppAssets.onboarding3,
      title: 'Understand what you\neat',
      description:
          'Get personalized nutrition insights and healthier\nalternatives with NutriAI.',
    ),
  ];

  void _onNextPressed() {
    if (_currentIndex < _items.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic,
      );
    } else {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (BuildContext context) => HomePage()),
    );
    }
  }

  void _onSkipPressed() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (BuildContext context) => HomePage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _onSkipPressed,
                  child: Text(
                    'Skip',
                    style: AppTextStyles.subTitle.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),

            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _items.length,
                onPageChanged: (index) {
                  setState(() {
                    _currentIndex = index;
                  });
                },
                itemBuilder: (context, index) {
                  final item = _items[index];
                  return AnimatedBuilder(
                    animation: _pageController,
                    builder: (context, child) {
                      double parallaxFactor = 0.0;
                      if (_pageController.position.haveDimensions) {
                        parallaxFactor = _pageController.page! - index;
                      }
                    return SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Transform.translate(
                              offset: Offset(parallaxFactor * 40, 0),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(28),
                                child: Image.asset(
                                  item.image,
                                  height: size.height * 0.42,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),

                            const SizedBox(height: 40),

                            Text(
                              item.title,
                              textAlign: TextAlign.center,
                              style: AppTextStyles.titleBold.copyWith(
                                fontSize: 24,
                                height: 1.3,
                              ),
                            ),

                            const SizedBox(height: 16),

                            Text(
                              item.description,
                              textAlign: TextAlign.center,
                              style: AppTextStyles.subTitle.copyWith(
                                fontSize: 14,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      );
                    },
                  );
                },
              ),
            ),

            const SizedBox(height: 32),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _items.length,
                  (index) => AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    height: 8,
                    width: _currentIndex == index ? 28 : 8,
                    decoration: BoxDecoration(
                      color: _currentIndex == index
                          ? AppColors.primaryGreen
                          : AppColors.dotInactive,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 32),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _onNextPressed,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    overlayColor: Colors.black.withValues(alpha : 0.1),
                  ),
                  child: Text(
                    _currentIndex == _items.length - 1 ? 'Get Started' : 'Next',
                    style: AppTextStyles.buttonText.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }
}
