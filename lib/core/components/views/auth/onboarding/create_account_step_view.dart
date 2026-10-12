import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:medicine_reminder/core/constants/app_colors.dart';
import 'package:medicine_reminder/core/routes/app_routes.dart';
import 'package:medicine_reminder/core/services/onboarding_service.dart';
import 'package:medicine_reminder/providers/auth_provider.dart';
import 'package:medicine_reminder/providers/signup_provider.dart';

class CreateAccountStepView extends StatefulWidget {
  const CreateAccountStepView({super.key});

  @override
  State<CreateAccountStepView> createState() => _CreateAccountStepViewState();
}

class _CreateAccountStepViewState extends State<CreateAccountStepView> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;
  String? _localError;
  bool _submittedOnce = false;

  @override
  void initState() {
    super.initState();
    final signup = context.read<SignupProvider>();
    _emailController.text = signup.email;
    _passwordController.text = signup.password;
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleCreateAccount() async {
    final signup = context.read<SignupProvider>();
    final auth = context.read<AuthProvider>();

    setState(() {
      _submittedOnce = true;
      _localError = null;
    });

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    signup.setEmail(email);
    signup.setPassword(password);

    if (!signup.isEmailValid) {
      setState(() => _localError = 'Please enter a valid email address.');
      return;
    }

    if (!signup.isPasswordValid) {
      setState(() => _localError = 'Please satisfy all password criteria.');
      return;
    }

    if (!signup.agreedToTerms) {
      setState(
        () => _localError = 'Please accept the Terms of Service to continue.',
      );
      return;
    }

    signup.setSubmitting(true);

    try {
      final result = await auth.signUp(
        email: email,
        password: password,
        fullName: signup.name.isNotEmpty ? signup.name : null,
      );

      if (!mounted) return;
      signup.setSubmitting(false);

      if (result.success) {
        final userId = result.user?.id ?? auth.user?.id;
        if (userId != null) {
          try {
            await OnboardingService().saveOnboardingProfile(
              userId: userId,
              signupData: signup,
            );
          } catch (e) {
            debugPrint('Failed to sync onboarding data to Supabase: $e');
          }
        }
        if (!mounted) return;
        Navigator.of(context).pushReplacementNamed(AppRoutes.authGate);
      } else {
        setState(() {
          _localError = result.errorMessage ?? 'Failed to create account.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      signup.setSubmitting(false);
      setState(() {
        _localError = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final signup = context.watch<SignupProvider>();

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back),
                          onPressed: () => Navigator.of(context).pop(),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          color: isDark
                              ? AppColors.textPrimaryDark
                              : AppColors.textPrimaryLight,
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppColors.surfaceDark
                                : AppColors.tagBgLight,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isDark
                                  ? AppColors.borderDark
                                  : AppColors.primary.withValues(alpha: 0.2),
                            ),
                          ),
                          child: Text(
                            'Final Step',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? AppColors.accent
                                  : AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    Text(
                      'Your routine is ready.\nLet’s keep it safe.',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        height: 1.25,
                        color: isDark
                            ? AppColors.textPrimaryDark
                            : AppColors.textPrimaryLight,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Save your setup and restore it on another phone.',
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Error banner
                    if (_localError != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.error.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.error_outline,
                              color: AppColors.error,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _localError!,
                                style: const TextStyle(
                                  color: AppColors.error,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // Email Input
                    Text(
                      'Email Address',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? AppColors.textPrimaryDark
                            : AppColors.textPrimaryLight,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      autocorrect: false,
                      style: TextStyle(
                        color: isDark
                            ? AppColors.textPrimaryDark
                            : AppColors.textPrimaryLight,
                      ),
                      decoration: InputDecoration(
                        hintText: 'you@example.com',
                        filled: true,
                        fillColor: isDark
                            ? AppColors.surfaceDark
                            : AppColors.surfaceLight,
                        prefixIcon: const Icon(
                          Icons.email_outlined,
                          color: AppColors.primary,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: isDark
                                ? AppColors.borderDark
                                : AppColors.borderLight,
                          ),
                        ),
                        errorText:
                            (_submittedOnce && !signup.isEmailValid)
                                ? 'Invalid email format'
                                : null,
                      ),
                      onChanged: (val) {
                        signup.setEmail(val);
                        if (_localError != null) {
                          setState(() => _localError = null);
                        }
                      },
                    ),
                    const SizedBox(height: 20),

                    // Password Input
                    Text(
                      'Password',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? AppColors.textPrimaryDark
                            : AppColors.textPrimaryLight,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      style: TextStyle(
                        color: isDark
                            ? AppColors.textPrimaryDark
                            : AppColors.textPrimaryLight,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Create a password',
                        filled: true,
                        fillColor: isDark
                            ? AppColors.surfaceDark
                            : AppColors.surfaceLight,
                        prefixIcon: const Icon(
                          Icons.lock_outline,
                          color: AppColors.primary,
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondaryLight,
                          ),
                          onPressed: () {
                            setState(
                              () => _obscurePassword = !_obscurePassword,
                            );
                          },
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: isDark
                                ? AppColors.borderDark
                                : AppColors.borderLight,
                          ),
                        ),
                      ),
                      onChanged: (val) {
                        signup.setPassword(val);
                        if (_localError != null) {
                          setState(() => _localError = null);
                        }
                      },
                    ),
                    const SizedBox(height: 14),

                    // Password requirements checklist
                    _buildRequirementRow(
                      satisfied: signup.isPasswordLengthValid,
                      label: 'At least 8 characters',
                      isDark: isDark,
                    ),
                    const SizedBox(height: 6),
                    _buildRequirementRow(
                      satisfied: signup.hasPasswordNumber,
                      label: 'At least one number (0-9)',
                      isDark: isDark,
                    ),
                    const SizedBox(height: 6),
                    _buildRequirementRow(
                      satisfied: signup.hasPasswordSpecialOrUpper,
                      label: 'At least one uppercase letter or symbol',
                      isDark: isDark,
                    ),
                    const SizedBox(height: 20),

                    // Terms agreement
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      activeColor: AppColors.primary,
                      value: signup.agreedToTerms,
                      onChanged: (val) {
                        signup.setAgreedToTerms(val ?? false);
                        if (val == true && _localError != null) {
                          setState(() => _localError = null);
                        }
                      },
                      title: Text(
                        'I agree to the Terms of Service and Privacy Policy.',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark
                              ? AppColors.textPrimaryDark
                              : AppColors.textPrimaryLight,
                        ),
                      ),
                      controlAffinity: ListTileControlAffinity.leading,
                    ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),

            // Bottom action
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 16.0,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed:
                          signup.isSubmitting ? null : _handleCreateAccount,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: signup.isSubmitting
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Create account',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Already registered? ',
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight,
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          Navigator.of(context).pushNamed(AppRoutes.login);
                        },
                        child: const Text(
                          'Log in',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
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

  Widget _buildRequirementRow({
    required bool satisfied,
    required String label,
    required bool isDark,
  }) {
    return Row(
      children: [
        Icon(
          satisfied
              ? Icons.check_circle_rounded
              : Icons.radio_button_unchecked_rounded,
          size: 16,
          color: satisfied
              ? AppColors.primary
              : (isDark ? AppColors.borderDark : AppColors.borderLight),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: satisfied ? FontWeight.w600 : FontWeight.w400,
            color: satisfied
                ? (isDark ? AppColors.accent : AppColors.primary)
                : (isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight),
          ),
        ),
      ],
    );
  }
}
