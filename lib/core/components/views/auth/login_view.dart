import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:medicine_reminder/core/constants/app_colors.dart';
import 'package:medicine_reminder/core/constants/app_strings.dart';
import 'package:medicine_reminder/core/routes/app_routes.dart';
import 'package:medicine_reminder/providers/auth_provider.dart';
import 'package:medicine_reminder/providers/theme_provider.dart';

class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();

  bool _isSignUp = false;
  bool _obscurePassword = true;
  String? _localError;
  AutovalidateMode _autovalidateMode = AutovalidateMode.disabled;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _handleAuthSubmit() async {
    setState(() {
      _autovalidateMode = AutovalidateMode.onUserInteraction;
      _localError = null;
    });

    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (_isSignUp) {
      final result = await auth.signUp(
        email: email,
        password: password,
        fullName: _nameController.text.trim(),
      );

      if (!mounted) return;

      if (result.success) {
        if (result.needsEmailVerification) {
          _showEmailVerificationDialog(email);
        } else {
          Navigator.of(context).pushReplacementNamed(AppRoutes.authGate);
        }
      } else {
        setState(() => _localError = result.errorMessage ?? 'Registration failed');
      }
    } else {
      final result = await auth.signIn(email: email, password: password);

      if (!mounted) return;

      if (result.success) {
        Navigator.of(context).pushReplacementNamed(AppRoutes.authGate);
      } else {
        final errorMsg = result.errorMessage ?? 'Authentication failed';
        setState(() => _localError = errorMsg);

        if (result.needsEmailVerification) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Email unverified. Check inbox or resend.'),
              action: SnackBarAction(
                label: 'Resend',
                textColor: Colors.white,
                onPressed: () => _handleResendVerification(email),
              ),
              backgroundColor: AppColors.primary,
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMsg),
              backgroundColor: AppColors.error,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  Future<void> _handleResendVerification(String email) async {
    final auth = context.read<AuthProvider>();
    final sent = await auth.resendVerificationEmail(email);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          sent
              ? 'Verification email resent to $email'
              : 'Could not resend email. Please try again shortly.',
        ),
        backgroundColor: sent ? AppColors.primary : AppColors.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showEmailVerificationDialog(String email) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(Icons.mark_email_read_outlined, color: AppColors.primary, size: 28),
            SizedBox(width: 10),
            Text('Verify Your Email'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'We sent a verification link to:\n$email',
              style: const TextStyle(fontSize: 14.5, height: 1.4, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            const Text(
              'Please check your inbox and tap the link to confirm your account before logging in.',
              style: TextStyle(fontSize: 13.5, height: 1.4, color: AppColors.textSecondaryLight),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _handleResendVerification(email);
            },
            child: const Text('Resend Email'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(110, 42),
              padding: const EdgeInsets.symmetric(horizontal: 18),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _isSignUp = false;
                _localError = null;
                _autovalidateMode = AutovalidateMode.disabled;
              });
              _formKey.currentState?.reset();
            },
            child: const Text('Go to Log In'),
          ),
        ],
      ),
    );
  }




  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authProvider = context.watch<AuthProvider>();

    final bg = isDark ? AppColors.backgroundDark : AppColors.backgroundLight;
    final textPrimary = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final textSecondary = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final tagBg = isDark ? AppColors.tagBgDark : AppColors.tagBgLight;
    final tagText = isDark ? AppColors.tagTextDark : AppColors.tagTextLight;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Form(
                key: _formKey,
                autovalidateMode: _autovalidateMode,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top App Bar row with Breadcrumb Tag & Theme Switcher
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Notify Badge Tag (matches Figma breadcrumb: NOTIFY / LOG IN)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: tagBg,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: tagText,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _isSignUp ? AppStrings.authTagRegister : AppStrings.authTagLogin,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.8,
                                  color: tagText,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Theme Mode Toggle
                        Consumer<ThemeProvider>(
                          builder: (context, themeProvider, _) {
                            return IconButton(
                              icon: Icon(
                                themeProvider.isDarkMode ? Icons.light_mode : Icons.dark_mode,
                                color: textSecondary,
                                size: 22,
                              ),
                              tooltip: 'Toggle Theme',
                              onPressed: () => themeProvider.toggleTheme(),
                            );
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: 28),

                    // Header Title
                    Text(
                      _isSignUp ? AppStrings.createAccountTitle : AppStrings.welcomeBack,
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.8,
                        color: textPrimary,
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Header Subtitle
                    Text(
                      _isSignUp ? AppStrings.createAccountSubtitle : AppStrings.loginSubtitle,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w400,
                        height: 1.4,
                        color: textSecondary,
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Error Message banner if any
                    if (_localError != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.error.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline, size: 20, color: AppColors.error),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _localError!,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.error,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Sign Up: Full Name Field
                    if (_isSignUp) ...[
                      Text(
                        AppStrings.fullNameLabel,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _nameController,
                        textInputAction: TextInputAction.next,
                        style: TextStyle(color: textPrimary, fontSize: 15),
                        decoration: const InputDecoration(
                          hintText: AppStrings.fullNamePlaceholder,
                          prefixIcon: Icon(Icons.person_outline, size: 20),
                        ),
                        onChanged: (_) {
                          if (_localError != null) setState(() => _localError = null);
                        },
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Please enter your name';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 18),
                    ],

                    // Email Field
                    Text(
                      AppStrings.emailLabel,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      style: TextStyle(color: textPrimary, fontSize: 15),
                      decoration: const InputDecoration(
                        hintText: AppStrings.emailPlaceholder,
                        prefixIcon: Icon(Icons.mail_outline_rounded, size: 20),
                      ),
                      onChanged: (_) {
                        if (_localError != null) setState(() => _localError = null);
                      },
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Please enter your email';
                        }
                        if (!val.contains('@') || !val.contains('.')) {
                          return 'Please enter a valid email address';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 18),

                    // Password Field
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          AppStrings.passwordLabel,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: textPrimary,
                          ),
                        ),
                        if (!_isSignUp)
                          InkWell(
                            onTap: () {
                              Navigator.of(context).pushNamed(AppRoutes.forgotPassword);
                            },
                            borderRadius: BorderRadius.circular(4),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                              child: Text(
                                AppStrings.forgotPassword,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? AppColors.accent : AppColors.primary,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _handleAuthSubmit(),
                      style: TextStyle(color: textPrimary, fontSize: 15),
                      decoration: InputDecoration(
                        hintText: _isSignUp ? 'Create a strong password' : '••••••••••',
                        prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                            size: 20,
                            color: textSecondary,
                          ),
                          onPressed: () {
                            setState(() => _obscurePassword = !_obscurePassword);
                          },
                        ),
                      ),
                      onChanged: (_) {
                        if (_localError != null) setState(() => _localError = null);
                      },
                      validator: (val) {
                        if (val == null || val.isEmpty) {
                          return 'Please enter your password';
                        }
                        if (val.length < 6) {
                          return 'Password must be at least 6 characters';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 24),

                    // Primary Action: Log In / Create Account Button
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: authProvider.isLoading ? null : _handleAuthSubmit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: authProvider.isLoading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : Text(
                                _isSignUp ? AppStrings.createAccount : AppStrings.logIn,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Toggle Sign In / Create Account
                    Center(
                      child: Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            _isSignUp ? AppStrings.alreadyHaveAccount : AppStrings.dontHaveAccount,
                            style: TextStyle(
                              fontSize: 14,
                              color: textSecondary,
                            ),
                          ),
                          const SizedBox(width: 6),
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _isSignUp = !_isSignUp;
                                _localError = null;
                                _autovalidateMode = AutovalidateMode.disabled;
                              });
                              _formKey.currentState?.reset();
                            },
                            child: Text(
                              _isSignUp ? AppStrings.logIn : AppStrings.createAccount,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: isDark ? AppColors.accent : AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Terms Notice (matching Figma Create account & Log in flow)
                    Center(
                      child: Text(
                        AppStrings.termsNotice,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: textSecondary.withValues(alpha: 0.7),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
