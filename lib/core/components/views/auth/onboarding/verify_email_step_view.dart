import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:medicine_reminder/core/constants/app_colors.dart';
import 'package:medicine_reminder/core/routes/app_routes.dart';
import 'package:medicine_reminder/providers/auth_provider.dart';
import 'package:medicine_reminder/providers/signup_provider.dart';

class VerifyEmailStepView extends StatefulWidget {
  const VerifyEmailStepView({super.key});

  @override
  State<VerifyEmailStepView> createState() => _VerifyEmailStepViewState();
}

class _VerifyEmailStepViewState extends State<VerifyEmailStepView> {
  int _cooldownSeconds = 60;
  Timer? _cooldownTimer;
  bool _isResending = false;
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    _startCooldown();
  }

  void _startCooldown() {
    _cooldownTimer?.cancel();
    setState(() => _cooldownSeconds = 60);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_cooldownSeconds <= 1) {
        timer.cancel();
        if (mounted) setState(() => _cooldownSeconds = 0);
      } else {
        if (mounted) setState(() => _cooldownSeconds--);
      }
    });
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    super.dispose();
  }

  Future<void> _handleResend() async {
    if (_cooldownSeconds > 0 || _isResending) return;

    final signup = context.read<SignupProvider>();
    final auth = context.read<AuthProvider>();

    setState(() {
      _isResending = true;
      _statusMessage = null;
    });

    final success = await auth.resendVerificationEmail(signup.email);

    if (!mounted) return;
    setState(() {
      _isResending = false;
      _statusMessage = success
          ? 'Verification email resent successfully.'
          : 'Please check your spam or try again later.';
    });

    if (success) {
      _startCooldown();
    }
  }

  void _handleVerified() {
    // Navigate into main application
    context.go(AppRoutes.authGate);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final signup = context.watch<SignupProvider>();
    final email = signup.email.isNotEmpty ? signup.email : 'your email';

    return Scaffold(
      backgroundColor: isDark
          ? AppColors.backgroundDark
          : AppColors.backgroundLight,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.surfaceDark
                            : AppColors.tagBgLight,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isDark
                              ? AppColors.borderDark
                              : AppColors.primary.withValues(alpha: 0.25),
                          width: 2,
                        ),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.mark_email_read_outlined,
                          size: 44,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),

                    Text(
                      'Check your inbox',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        color: isDark
                            ? AppColors.textPrimaryDark
                            : AppColors.textPrimaryLight,
                      ),
                    ),
                    const SizedBox(height: 12),

                    Text(
                      'Open the verification link we sent to:',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                      ),
                    ),
                    const SizedBox(height: 4),

                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.surfaceDark
                            : AppColors.tagBgLight,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        email,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: isDark ? AppColors.accent : AppColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    if (signup.wantsCareCircle &&
                        signup.contactName.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20.0),
                        child: Text(
                          'Your Care Circle invitation to ${signup.contactName} will be sent once your account is verified.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondaryLight,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    if (_statusMessage != null) ...[
                      Text(
                        _statusMessage!,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: _statusMessage!.contains('successfully')
                              ? AppColors.success
                              : AppColors.warning,
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    TextButton.icon(
                      onPressed: () => context.pop(),
                      icon: const Icon(Icons.edit_outlined, size: 16),
                      label: const Text('Change email'),
                      style: TextButton.styleFrom(
                        foregroundColor: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                      ),
                    ),
                  ],
                ),
              ),

              // Bottom Actions
              Padding(
                padding: const EdgeInsets.only(bottom: 24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _handleVerified,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          "I’ve verified my email",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: _cooldownSeconds == 0 ? _handleResend : null,
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.primary,
                      ),
                      child: _isResending
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.primary,
                              ),
                            )
                          : Text(
                              _cooldownSeconds > 0
                                  ? 'Resend email in ${_cooldownSeconds}s'
                                  : 'Resend verification email',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: _cooldownSeconds > 0
                                    ? (isDark
                                          ? AppColors.textSecondaryDark
                                          : AppColors.textSecondaryLight)
                                    : AppColors.primary,
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
    );
  }
}
