import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:medicine_reminder/core/constants/app_colors.dart';
import 'package:medicine_reminder/core/routes/app_routes.dart';
import 'package:medicine_reminder/providers/signup_provider.dart';
import 'widgets/onboarding_step_header.dart';

class CareCircleStepView extends StatefulWidget {
  const CareCircleStepView({super.key});

  @override
  State<CareCircleStepView> createState() => _CareCircleStepViewState();
}

class _CareCircleStepViewState extends State<CareCircleStepView> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();

  String? _nameError;
  String? _phoneError;
  String? _agreementError;

  @override
  void initState() {
    super.initState();
    final signup = context.read<SignupProvider>();
    _nameController.text = signup.contactName;
    _phoneController.text = signup.phoneNumber;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _handleContinue() {
    final signup = context.read<SignupProvider>();

    if (signup.wantsCareCircle) {
      final name = _nameController.text.trim();
      final phone = _phoneController.text.trim();

      setState(() {
        _nameError = name.isEmpty ? 'Please enter a contact name.' : null;
        _phoneError = phone.isEmpty ? 'Please enter a phone number.' : null;
        _agreementError = !signup.agreedToShareAlerts
            ? 'Please agree to share alerts to invite this person.'
            : null;
      });

      if (_nameError == null &&
          _phoneError == null &&
          _agreementError == null) {
        signup.setContactName(name);
        signup.setPhoneNumber(phone);
        Navigator.of(context).pushNamed(AppRoutes.createAccount);
      }
    } else {
      Navigator.of(context).pushNamed(AppRoutes.createAccount);
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
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 12),
                    OnboardingStepHeader(
                      currentStep: 4,
                      totalSteps: 4,
                      onBack: () => Navigator.of(context).pop(),
                      title: 'A little support helps.',
                      subtitle:
                          'Would you like someone to receive an alert when a dose hasn’t been confirmed?',
                    ),
                    const SizedBox(height: 24),

                    // Choice 1: Yes, invite someone
                    _buildSelectionCard(
                      isSelected: signup.wantsCareCircle,
                      icon: Icons.group_add_outlined,
                      title: 'Yes, invite someone',
                      subtitle:
                          'A caregiver, family member, or friend will receive a nudge.',
                      isDark: isDark,
                      onTap: () => signup.setWantsCareCircle(true),
                    ),

                    const SizedBox(height: 12),

                    // Choice 2: Maybe later
                    _buildSelectionCard(
                      isSelected: !signup.wantsCareCircle,
                      icon: Icons.person_outline,
                      title: 'Maybe later',
                      subtitle:
                          'You can always add care circle contacts anytime from settings.',
                      isDark: isDark,
                      onTap: () => signup.setWantsCareCircle(false),
                    ),

                    // Expandable Contact Form if Yes
                    AnimatedCrossFade(
                      firstChild: const SizedBox.shrink(),
                      secondChild: Padding(
                        padding: const EdgeInsets.only(top: 24.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Contact Name *',
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
                              controller: _nameController,
                              style: TextStyle(
                                color: isDark
                                    ? AppColors.textPrimaryDark
                                    : AppColors.textPrimaryLight,
                              ),
                              decoration: InputDecoration(
                                hintText: "e.g. Sarah Smith",
                                filled: true,
                                fillColor: isDark
                                    ? AppColors.surfaceDark
                                    : AppColors.surfaceLight,
                                prefixIcon: const Icon(
                                  Icons.badge_outlined,
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
                                errorText: _nameError,
                              ),
                              onChanged: (val) {
                                signup.setContactName(val);
                                if (_nameError != null) {
                                  setState(() => _nameError = null);
                                }
                              },
                            ),
                            const SizedBox(height: 18),

                            Text(
                              'Mobile Number *',
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
                              controller: _phoneController,
                              keyboardType: TextInputType.phone,
                              style: TextStyle(
                                color: isDark
                                    ? AppColors.textPrimaryDark
                                    : AppColors.textPrimaryLight,
                              ),
                              decoration: InputDecoration(
                                hintText: "(555) 000-0000",
                                prefixText: "${signup.countryCode} ",
                                prefixStyle: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: isDark
                                      ? AppColors.accent
                                      : AppColors.primary,
                                ),
                                filled: true,
                                fillColor: isDark
                                    ? AppColors.surfaceDark
                                    : AppColors.surfaceLight,
                                prefixIcon: const Icon(
                                  Icons.phone_outlined,
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
                                errorText: _phoneError,
                              ),
                              onChanged: (val) {
                                signup.setPhoneNumber(val);
                                if (_phoneError != null) {
                                  setState(() => _phoneError = null);
                                }
                              },
                            ),
                            const SizedBox(height: 18),

                            // Relationship Dropdown
                            Text(
                              'Relationship (Optional)',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? AppColors.textPrimaryDark
                                    : AppColors.textPrimaryLight,
                              ),
                            ),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<String>(
                              initialValue: signup.relationship,
                              dropdownColor: isDark
                                  ? AppColors.surfaceDark
                                  : AppColors.surfaceLight,
                              style: TextStyle(
                                color: isDark
                                    ? AppColors.textPrimaryDark
                                    : AppColors.textPrimaryLight,
                              ),
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: isDark
                                    ? AppColors.surfaceDark
                                    : AppColors.surfaceLight,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(
                                    color: isDark
                                        ? AppColors.borderDark
                                        : AppColors.borderLight,
                                  ),
                                ),
                              ),
                              hint: Text(
                                'Select relationship',
                                style: TextStyle(
                                  color: isDark
                                      ? AppColors.textSecondaryDark
                                      : AppColors.textSecondaryLight
                                          .withValues(alpha: 0.6),
                                ),
                              ),
                              items: SignupProvider.availableRelationships
                                  .map((rel) {
                                    return DropdownMenuItem(
                                      value: rel,
                                      child: Text(rel),
                                    );
                                  })
                                  .toList(),
                              onChanged: (val) => signup.setRelationship(val),
                            ),
                            const SizedBox(height: 18),

                            // Alert delay picker
                            Text(
                              'Alert delay: ${signup.alertDelayMinutes} minutes',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? AppColors.textPrimaryDark
                                    : AppColors.textPrimaryLight,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Time to wait after missed dose before alerting contact.',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark
                                    ? AppColors.textSecondaryDark
                                    : AppColors.textSecondaryLight,
                              ),
                            ),
                            Slider(
                              value: signup.alertDelayMinutes.toDouble(),
                              min: 15,
                              max: 90,
                              divisions: 5,
                              activeColor: AppColors.primary,
                              label: '${signup.alertDelayMinutes} mins',
                              onChanged: (val) =>
                                  signup.setAlertDelayMinutes(val.toInt()),
                            ),

                            // Checkbox agreement
                            CheckboxListTile(
                              contentPadding: EdgeInsets.zero,
                              activeColor: AppColors.primary,
                              value: signup.agreedToShareAlerts,
                              onChanged: (val) {
                                signup.setAgreedToShareAlerts(val ?? false);
                                if (val == true && _agreementError != null) {
                                  setState(() => _agreementError = null);
                                }
                              },
                              title: Text(
                                'I agree to share unconfirmed-dose alerts with this person.',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isDark
                                      ? AppColors.textPrimaryDark
                                      : AppColors.textPrimaryLight,
                                ),
                              ),
                              controlAffinity: ListTileControlAffinity.leading,
                            ),
                            if (_agreementError != null) ...[
                              Padding(
                                padding: const EdgeInsets.only(left: 8.0),
                                child: Text(
                                  _agreementError!,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.error,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                            ],

                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? AppColors.surfaceDark
                                    : AppColors.tagBgLight,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(
                                    Icons.lock_outline,
                                    size: 18,
                                    color: AppColors.primary,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Medicine details stay private by default. Your contact must accept the invitation.',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isDark
                                          ? AppColors.accent
                                          : AppColors.primary,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      crossFadeState: signup.wantsCareCircle
                          ? CrossFadeState.showSecond
                          : CrossFadeState.showFirst,
                      duration: const Duration(milliseconds: 250),
                    ),

                    const SizedBox(height: 32),
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
                      onPressed: _handleContinue,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            signup.wantsCareCircle
                                ? 'Continue to account'
                                : 'Next: Create Account',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.arrow_forward, size: 18),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectionCard({
    required bool isSelected,
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? AppColors.tagBgDark : AppColors.tagBgLight)
              : (isDark ? AppColors.surfaceDark : AppColors.surfaceLight),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : (isDark ? AppColors.borderDark : AppColors.borderLight),
            width: isSelected ? 1.8 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary
                    : (isDark ? AppColors.cardDark : AppColors.borderLight),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: isSelected ? Colors.white : AppColors.primary,
                size: 22,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: isSelected
                          ? (isDark ? AppColors.accent : AppColors.primary)
                          : (isDark
                              ? AppColors.textPrimaryDark
                              : AppColors.textPrimaryLight),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? AppColors.primary : Colors.transparent,
                border: Border.all(
                  color: isSelected
                      ? AppColors.primary
                      : (isDark ? AppColors.borderDark : AppColors.borderLight),
                  width: 1.5,
                ),
              ),
              child: isSelected
                  ? const Icon(Icons.check, size: 16, color: Colors.white)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
