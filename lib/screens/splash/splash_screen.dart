import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../utils/app_colors.dart';
import '../auth/auth_wrapper.dart';
import '../onboarding/onboarding_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animationController;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _logoScaleAnimation;
  late final Animation<Offset> _logoSlideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    );
    _logoScaleAnimation = Tween<double>(begin: 0.9, end: 1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutBack),
    );
    _logoSlideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeOutCubic,
          ),
        );

    _animationController.forward();
    Future.delayed(const Duration(milliseconds: 300), _navigateNext);
  }

  Future<void> _navigateNext() async {
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    final prefs = await SharedPreferences.getInstance();
    final onboardingComplete = prefs.getBool('onboarding_complete') ?? false;

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) =>
            onboardingComplete ? const AuthWrapper() : const OnboardingScreen(),
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primary, AppColors.primaryDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Stack(
                  children: [
                    Semantics(
                      container: true,
                      label: 'MediQueue splash screen',
                      child: Column(
                        children: [
                          Expanded(
                            flex: 6,
                            child: Center(
                              child: SlideTransition(
                                position: _logoSlideAnimation,
                                child: ScaleTransition(
                                  scale: _logoScaleAnimation,
                                  child: _buildLogoSeal(),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 4,
                            child: Align(
                              alignment: Alignment.topCenter,
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  28,
                                  12,
                                  28,
                                  0,
                                ),
                                child: _buildBottomContent(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildBottomProgressBar(),
          ),
        ],
      ),
    );
  }

  Widget _buildLogoSeal() {
    return Semantics(
      image: true,
      label: 'MediQueue app icon',
      child: SizedBox(
        width: 148,
        height: 148,
        child: Image.asset(
          'assets/images/Hospital_Cross_and_Clock_with_Ascending_Queue-removebg-preview.png',
          width: 148,
          height: 148,
          fit: BoxFit.contain,
          color: AppColors.onPrimary,
          colorBlendMode: BlendMode.srcIn,
          semanticLabel: 'MediQueue logo',
        ),
      ),
    );
  }

  Widget _buildBottomContent() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'MediQueue',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 41,
            fontWeight: FontWeight.w700,
            color: AppColors.onPrimary,
            letterSpacing: 2.8,
            height: 1.0,
            shadows: [
              Shadow(
                color: AppColors.primaryDark.withValues(alpha: 0.36),
                blurRadius: 12,
                offset: Offset(0, 3),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBottomProgressBar() {
    return Semantics(
      liveRegion: true,
      label: 'Loading',
      value: 'Preparing MediQueue',
      child: SizedBox(
        width: double.infinity,
        height: 2.5,
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: 1),
          duration: const Duration(milliseconds: 2300),
          curve: Curves.linear,
          builder: (context, progress, child) {
            return Stack(
              fit: StackFit.expand,
              children: [
                Container(color: Colors.white.withValues(alpha: 0.2)),
                Align(
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: progress,
                    child: child,
                  ),
                ),
              ],
            );
          },
          child: Container(color: Colors.white.withValues(alpha: 0.62)),
        ),
      ),
    );
  }
}
