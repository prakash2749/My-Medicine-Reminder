import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:medicine_reminder/core/constants/app_colors.dart';
import 'package:medicine_reminder/core/routes/app_routes.dart';
import 'package:medicine_reminder/core/utils/date_time_utils.dart';
import 'package:medicine_reminder/providers/signup_provider.dart';

import 'widgets/onboarding_step_header.dart';

class MyDayStepView extends StatelessWidget {
  const MyDayStepView({super.key});

  String _formatTime(TimeOfDay time) =>
      DateTimeUtils.formatTimeOfDayTo12Hour(time);

  Future<void> _pickTime({
    required BuildContext context,
    required TimeOfDay initialTime,
    required ValueChanged<TimeOfDay> onSelected,
  }) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              onSurface: Theme.of(context).brightness == Brightness.dark
                  ? AppColors.textPrimaryDark
                  : AppColors.textPrimaryLight,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      onSelected(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final signup = context.watch<SignupProvider>();

    return Scaffold(
      backgroundColor: isDark
          ? AppColors.backgroundDark
          : AppColors.backgroundLight,
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
                      currentStep: 3,
                      totalSteps: 4,
                      onBack: () => context.pop(),
                      title: 'Your day, your rhythm.',
                      subtitle: 'Confirm your usual times. You can change these later.',
                    ),
                    const SizedBox(height: 24),

                    // "My routine changes" toggle switch
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.surfaceDark
                            : AppColors.surfaceLight,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark
                              ? AppColors.borderDark
                              : AppColors.borderLight,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.tune_rounded,
                            color: signup.isRoutineFlexible
                                ? AppColors.primary
                                : (isDark
                                      ? AppColors.textSecondaryDark
                                      : AppColors.textSecondaryLight),
                            size: 22,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'My routine changes',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: isDark
                                        ? AppColors.textPrimaryDark
                                        : AppColors.textPrimaryLight,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'I have flexible or shifting hours',
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
                          Switch.adaptive(
                            value: signup.isRoutineFlexible,
                            activeTrackColor: AppColors.primary,
                            onChanged: (val) {
                              signup.setIsRoutineFlexible(val);
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Daily Schedule Cards (dimmed or hidden if flexible, but shown as editable)
                    Opacity(
                      opacity: signup.isRoutineFlexible ? 0.45 : 1.0,
                      child: AbsorbPointer(
                        absorbing: signup.isRoutineFlexible,
                        child: Column(
                          children: [
                            _buildRoutineTimeCard(
                              context: context,
                              icon: Icons.wb_twilight_rounded,
                              label: 'Wake up',
                              time: signup.wakeUpTime,
                              isDark: isDark,
                              onTap: () => _pickTime(
                                context: context,
                                initialTime: signup.wakeUpTime,
                                onSelected: signup.setWakeUpTime,
                              ),
                            ),
                            const SizedBox(height: 12),
                            _buildRoutineTimeCard(
                              context: context,
                              icon: Icons.breakfast_dining_outlined,
                              label: 'Breakfast',
                              time: signup.breakfastTime,
                              isDark: isDark,
                              onTap: () => _pickTime(
                                context: context,
                                initialTime: signup.breakfastTime,
                                onSelected: signup.setBreakfastTime,
                              ),
                            ),
                            const SizedBox(height: 12),
                            _buildRoutineTimeCard(
                              context: context,
                              icon: Icons.lunch_dining_outlined,
                              label: 'Lunch',
                              time: signup.lunchTime,
                              isDark: isDark,
                              onTap: () => _pickTime(
                                context: context,
                                initialTime: signup.lunchTime,
                                onSelected: signup.setLunchTime,
                              ),
                            ),
                            const SizedBox(height: 12),
                            _buildRoutineTimeCard(
                              context: context,
                              icon: Icons.dinner_dining_outlined,
                              label: 'Dinner',
                              time: signup.dinnerTime,
                              isDark: isDark,
                              onTap: () => _pickTime(
                                context: context,
                                initialTime: signup.dinnerTime,
                                onSelected: signup.setDinnerTime,
                              ),
                            ),
                            const SizedBox(height: 12),
                            _buildRoutineTimeCard(
                              context: context,
                              icon: Icons.bedtime_outlined,
                              label: 'Bedtime',
                              time: signup.bedtimeTime,
                              isDark: isDark,
                              onTap: () => _pickTime(
                                context: context,
                                initialTime: signup.bedtimeTime,
                                onSelected: signup.setBedtimeTime,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.surfaceDark
                            : AppColors.tagBgLight,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.info_outline,
                            size: 18,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Dose times are confirmed after prescription review.',
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
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),

            // Bottom action buttons
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
                      onPressed: () {
                        context.push(AppRoutes.careCircle);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Save my routine',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(width: 8),
                          Icon(Icons.arrow_forward, size: 18),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: () {
                      context.push(AppRoutes.careCircle);
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                    ),
                    child: const Text(
                      'Set up later',
                      style: TextStyle(
                        fontSize: 14,
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
    );
  }

  Widget _buildRoutineTimeCard({
    required BuildContext context,
    required IconData icon,
    required String label,
    required TimeOfDay time,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? AppColors.borderDark : AppColors.borderLight,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: isDark ? AppColors.cardDark : AppColors.tagBgLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 20, color: AppColors.primary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: isDark
                      ? AppColors.textPrimaryDark
                      : AppColors.textPrimaryLight,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isDark ? AppColors.tagBgDark : AppColors.tagBgLight,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isDark
                      ? AppColors.borderDark
                      : AppColors.primary.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _formatTime(time),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isDark ? AppColors.accent : AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.edit_outlined,
                    size: 14,
                    color: isDark ? AppColors.accent : AppColors.primary,
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
