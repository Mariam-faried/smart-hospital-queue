import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../utils/app_colors.dart';
import '../auth/auth_wrapper.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<_OnboardingSlide> _slides = const [
    _OnboardingSlide(
      icon: Icons.calendar_month_rounded,
      iconColor: AppColors.primary,
      iconBackgroundColor: AppColors.primaryLight,
      title: 'Book Appointments Easily',
      description:
          'Browse top doctors, choose your preferred time slot, and book in seconds - no phone calls needed.',
    ),
    _OnboardingSlide(
      icon: Icons.confirmation_number_rounded,
      iconColor: AppColors.accent,
      iconBackgroundColor: AppColors.warningSurface,
      title: 'Skip the Waiting Room',
      description:
          "Get a real queue ticket and track your position live. Know exactly when it's your turn - from anywhere.",
    ),
    _OnboardingSlide(
      icon: Icons.notifications_active_rounded,
      iconColor: AppColors.primaryDark,
      iconBackgroundColor: AppColors.infoSurface,
      title: 'Stay Updated in Real Time',
      description:
          'Receive instant updates on your appointment status, queue position, and doctor availability.',
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _completeOnboarding() async {
    await HapticFeedback.lightImpact();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_complete', true);
    if (!mounted) return;
    Navigator.pushReplacement(context, _buildAuthRoute());
  }

  Future<void> _skipOnboarding() async {
    await HapticFeedback.lightImpact();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_complete', true);
    if (!mounted) return;
    Navigator.pushReplacement(context, _buildAuthRoute());
  }

  void _handleNextButton() {
    if (_currentPage == 2) {
      _completeOnboarding();
    } else {
      HapticFeedback.selectionClick();
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _handleBackButton() {
    if (_currentPage == 0) return;
    HapticFeedback.selectionClick();
    _pageController.previousPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  Route<void> _buildAuthRoute() {
    return PageRouteBuilder<void>(
      transitionDuration: const Duration(milliseconds: 320),
      reverseTransitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (_, __, ___) => const AuthWrapper(),
      transitionsBuilder: (_, animation, __, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.04),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isLastPage = _currentPage == _slides.length - 1;
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        actions: [
          if (!isLastPage)
            TextButton(
              onPressed: _skipOnboarding,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.textPrimary,
                minimumSize: const Size(44, 44),
              ),
              child: const Text(
                'Skip',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                itemCount: _slides.length,
                itemBuilder: (context, index) {
                  final slide = _slides[index];
                  final bool isActive = index == _currentPage;

                  return LayoutBuilder(
                    builder: (context, constraints) {
                      final bool isCompact = constraints.maxHeight < 700;
                      final double iconContainerSize = isCompact ? 170 : 200;
                      final double iconSize = isCompact ? 88 : 100;
                      final double iconBottomSpace = isCompact ? 36 : 48;
                      final double titleSize = isCompact ? 24 : 26;
                      final double descriptionSize = isCompact ? 15 : 16;
                      final double verticalLift = isCompact ? 0 : 36;

                      return Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: isCompact ? 12 : 16,
                        ),
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 280),
                          curve: Curves.easeOut,
                          opacity: isActive ? 1 : 0.72,
                          child: AnimatedSlide(
                            duration: const Duration(milliseconds: 280),
                            curve: Curves.easeOut,
                            offset: isActive
                                ? Offset.zero
                                : const Offset(0, 0.04),
                            child: Padding(
                              padding: EdgeInsets.only(bottom: verticalLift),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Semantics(
                                    image: true,
                                    label: slide.title,
                                    child: Container(
                                      width: iconContainerSize,
                                      height: iconContainerSize,
                                      decoration: BoxDecoration(
                                        color: slide.iconBackgroundColor,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: slide.iconColor.withValues(
                                            alpha: 0.28,
                                          ),
                                        ),
                                      ),
                                      child: Icon(
                                        slide.icon,
                                        size: iconSize,
                                        color: slide.iconColor,
                                      ),
                                    ),
                                  ),
                                  SizedBox(height: iconBottomSpace),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 32,
                                    ),
                                    child: Text(
                                      slide.title,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: titleSize,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 40,
                                    ),
                                    child: Text(
                                      slide.description,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: descriptionSize,
                                        color: AppColors.textSecondary,
                                        height: 1.5,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(24, 12, 24, 20 + bottomInset),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Semantics(
                    label:
                        'Onboarding page ${_currentPage + 1} of ${_slides.length}',
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(_slides.length, (index) {
                        final bool isActive = index == _currentPage;

                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeInOut,
                          margin: const EdgeInsets.only(right: 8),
                          width: isActive ? 24 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: isActive
                                ? AppColors.primary
                                : AppColors.divider,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        );
                      }),
                    ),
                  ),
                  Text(
                    '${_currentPage + 1}/${_slides.length}',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_currentPage > 0 && !isLastPage) ...[
                        OutlinedButton.icon(
                          onPressed: _handleBackButton,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.textPrimary,
                            side: const BorderSide(color: AppColors.divider),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 14,
                            ),
                            minimumSize: const Size(44, 46),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          icon: const Icon(Icons.arrow_back_rounded, size: 18),
                          label: const Text('Back'),
                        ),
                        const SizedBox(width: 10),
                      ],
                      ElevatedButton(
                        onPressed: _handleNextButton,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 14,
                          ),
                          minimumSize: const Size(44, 46),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(isLastPage ? 'Get Started' : 'Next'),
                            const SizedBox(width: 6),
                            const Icon(Icons.arrow_forward_rounded, size: 18),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingSlide {
  const _OnboardingSlide({
    required this.icon,
    required this.iconColor,
    required this.iconBackgroundColor,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBackgroundColor;
  final String title;
  final String description;
}
