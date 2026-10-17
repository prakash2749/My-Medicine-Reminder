import 'package:medicine_reminder/providers/app_preferences.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:medicine_reminder/core/constants/app_assets.dart';
import 'package:medicine_reminder/core/constants/app_colors.dart';
import 'package:medicine_reminder/core/constants/app_strings.dart';
import 'package:medicine_reminder/core/routes/app_routes.dart';
import 'package:medicine_reminder/providers/auth_provider.dart';

class SplashView extends StatefulWidget {
  const SplashView({super.key});

  @override
  State<SplashView> createState() => _SplashViewState();
}

class _SplashViewState extends State<SplashView> with TickerProviderStateMixin {
  late final AnimationController _entranceController;
  late final AnimationController _pulseController;

  late final Animation<double> _mascotScale;
  late final Animation<double> _mascotFade;
  late final Animation<double> _haloPulse;
  late final Animation<Offset> _textSlide;
  late final Animation<double> _textFade;
  late final Animation<double> _footerFade;

  Timer? _navigationTimer;
  bool _hasNavigated = false;

  @override
  void initState() {
    super.initState();

    // 1. Entrance animation controller (1.2s total)
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    // 2. Ambient breathing pulse controller for glowing halo
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);

    // Mascot scale with playful overshoot
    _mascotScale = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.0, 0.7, curve: Curves.easeOutBack),
      ),
    );

    // Mascot fade in
    _mascotFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.0, 0.45, curve: Curves.easeOut),
      ),
    );

    // Continuous halo glow pulse
    _haloPulse = Tween<double>(begin: 0.85, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Staggered text slide & fade
    _textSlide =
        Tween<Offset>(begin: const Offset(0.0, 0.35), end: Offset.zero).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.4, 0.9, curve: Curves.easeOutCubic),
      ),
    );

    _textFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.4, 0.85, curve: Curves.easeOut),
      ),
    );

    _footerFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.7, 1.0, curve: Curves.easeOut),
      ),
    );

    _entranceController.forward();

    // Splash display duration: 2.8 seconds
    _navigationTimer = Timer(const Duration(milliseconds: 2800), () {
      _navigateToNextScreen();
    });
  }

  Future<void> _navigateToNextScreen() async {
    if (_hasNavigated || !mounted) return;
    _hasNavigated = true;

    final settings = context.read<AppPreferences>();
    await settings.ready;
    if (!mounted) return;
    final authProvider = context.read<AuthProvider>();
    if (authProvider.isPasswordRecovery) {
      context.go(AppRoutes.updatePassword);
      return;
    }

    final destination = (authProvider.isAuthenticated || settings.guestEnabled)
        ? AppRoutes.authGate
        : AppRoutes.getStarted;

    context.go(destination);
  }

  @override
  void dispose() {
    _navigationTimer?.cancel();
    _entranceController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      body: Stack(
        children: [
          // Ambient background gradient glow
          Positioned(
            top: size.height * 0.2,
            left: size.width * 0.15,
            child: AnimatedBuilder(
              animation: _haloPulse,
              builder: (context, _) {
                return Container(
                  width: size.width * 0.7 * _haloPulse.value,
                  height: size.width * 0.7 * _haloPulse.value,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AppColors.primary.withValues(
                          alpha: isDark ? 0.22 : 0.12,
                        ),
                        AppColors.accent.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // Central Animated Content
          Center(
            child: SingleChildScrollView(
              physics: const NeverScrollableScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Mascot Hero with Halo & Float Animation
                    FadeTransition(
                      opacity: _mascotFade,
                      child: ScaleTransition(
                        scale: _mascotScale,
                        child: AnimatedBuilder(
                          animation: _pulseController,
                          builder: (context, child) {
                            return Transform.translate(
                              offset: Offset(0, -6 * _pulseController.value),
                              child: child,
                            );
                          },
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Pulsing glow backdrop
                              AnimatedBuilder(
                                animation: _haloPulse,
                                builder: (context, _) {
                                  return Container(
                                    width: 170 * _haloPulse.value,
                                    height: 170 * _haloPulse.value,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: AppColors.primary.withValues(
                                        alpha: isDark ? 0.15 : 0.08,
                                      ),
                                    ),
                                  );
                                },
                              ),

                              // Mascot Container (GIF with graceful fallbacks)
                              Container(
                                width: 150,
                                height: 150,
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isDark
                                      ? AppColors.cardDark
                                      : Colors.white,
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.primary.withValues(
                                        alpha: isDark ? 0.28 : 0.14,
                                      ),
                                      blurRadius: 32,
                                      offset: const Offset(0, 12),
                                    ),
                                  ],
                                  border: Border.all(
                                    color: isDark
                                        ? AppColors.borderDark
                                        : AppColors.primary.withValues(
                                            alpha: 0.15,
                                          ),
                                    width: 2,
                                  ),
                                ),
                                child: ClipOval(
                                  child: Image.asset(
                                    AppAssets.mascotGif,
                                    fit: BoxFit.contain,
                                    errorBuilder: (_, __, ___) {
                                      // Fallback to static mascot PNG
                                      return Image.asset(
                                        AppAssets.mascot,
                                        fit: BoxFit.contain,
                                        errorBuilder:
                                            (context, error, stackTrace) {
                                          // Fallback to main app logo
                                          return Image.asset(
                                            AppAssets.appLogo,
                                            fit: BoxFit.contain,
                                            errorBuilder: (ctx, err, st) {
                                              return const Icon(
                                                Icons.medication_rounded,
                                                size: 72,
                                                color: AppColors.primary,
                                              );
                                            },
                                          );
                                        },
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 36),

                    // Staggered Title & Tagline
                    SlideTransition(
                      position: _textSlide,
                      child: FadeTransition(
                        opacity: _textFade,
                        child: Column(
                          children: [
                            Text(
                              AppStrings.appName,
                              style: TextStyle(
                                fontSize: 34,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.8,
                                color: isDark
                                    ? AppColors.textPrimaryDark
                                    : AppColors.textPrimaryLight,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              AppStrings.appTagline,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                letterSpacing: 0.1,
                                height: 1.4,
                                color: isDark
                                    ? AppColors.textSecondaryDark
                                    : AppColors.textSecondaryLight,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 48),

                    // Subtle loading progress / breathing indicator
                    FadeTransition(
                      opacity: _footerFade,
                      child: SizedBox(
                        width: 48,
                        height: 3,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: const LinearProgressIndicator(
                            backgroundColor: Colors.transparent,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              AppColors.primary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Safe Skip Button at Top-Right
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            right: 16,
            child: SafeArea(
              child: TextButton(
                onPressed: _navigateToNextScreen,
                style: TextButton.styleFrom(
                  backgroundColor: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.black.withValues(alpha: 0.05),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  foregroundColor: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                ),
                child: const Text(
                  'Skip',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
