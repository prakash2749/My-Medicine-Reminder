import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
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

class _SplashViewState extends State<SplashView>
    with SingleTickerProviderStateMixin {
  VideoPlayerController? _videoController;
  bool _isVideoInitialized = false;
  bool _hasNavigated = false;

  late AnimationController _fadeAnimController;
  late Animation<double> _fadeAnimation;
  Timer? _maxSplashTimer;

  @override
  void initState() {
    super.initState();

    _fadeAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeAnimController,
      curve: Curves.easeInOut,
    );

    _fadeAnimController.forward();

    _initVideo();

    // Fallback timer: if video doesn't play or takes too long, navigate after 3.5 seconds
    _maxSplashTimer = Timer(const Duration(milliseconds: 3500), () {
      _navigateToNextScreen();
    });
  }

  Future<void> _initVideo() async {
    try {
      final controller = VideoPlayerController.asset(AppAssets.launchVideo);
      _videoController = controller;
      await controller.initialize();
      if (!mounted) return;

      setState(() {
        _isVideoInitialized = true;
      });

      controller.setLooping(false);
      controller.setVolume(0.0);
      await controller.play();

      controller.addListener(() {
        if (!mounted || _hasNavigated) return;
        final pos = controller.value.position;
        final dur = controller.value.duration;
        if (dur > Duration.zero && pos >= dur) {
          _navigateToNextScreen();
        }
      });
    } catch (e) {
      debugPrint('Video launch animation fallback to static splash: $e');
      // Timer will trigger navigation
    }
  }

  void _navigateToNextScreen() {
    if (_hasNavigated || !mounted) return;
    _hasNavigated = true;

    final authProvider = context.read<AuthProvider>();
    if (authProvider.isPasswordRecovery) {
      context.go(AppRoutes.updatePassword);
      return;
    }

    final destination = authProvider.isAuthenticated
        ? AppRoutes.authGate
        : AppRoutes.getStarted;

    context.go(destination);
  }

  @override
  void dispose() {
    _maxSplashTimer?.cancel();
    _videoController?.dispose();
    _fadeAnimController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark
        ? AppColors.backgroundDark
        : AppColors.backgroundLight;

    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          Center(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: _isVideoInitialized && _videoController != null
                  ? AspectRatio(
                      aspectRatio: _videoController!.value.aspectRatio,
                      child: VideoPlayer(_videoController!),
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 140,
                          height: 140,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppColors.surfaceDark
                                : Colors.white,
                            borderRadius: BorderRadius.circular(32),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withValues(
                                  alpha: 0.18,
                                ),
                                blurRadius: 24,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Image.asset(
                            AppAssets.appLogo,
                            fit: BoxFit.contain,
                            errorBuilder: (_, _, _) {
                              return const Icon(
                                Icons.medication,
                                size: 72,
                                color: AppColors.primary,
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 28),
                        Text(
                          AppStrings.appName,
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                            color: isDark
                                ? AppColors.textPrimaryDark
                                : AppColors.textPrimaryLight,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          AppStrings.appTagline,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondaryLight,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          Positioned(
            top: 48,
            right: 20,
            child: TextButton(
              onPressed: _navigateToNextScreen,
              style: TextButton.styleFrom(
                foregroundColor: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
              ),
              child: const Text(
                'Skip',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
